{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Cluster.Kind
  ( KindFilesystemLayout (..)
  , LayoutIdentity (..)
  , LayoutError (..)
  , ClusterObservation (..)
  , ReconcileAction (..)
  , ReconcileReport (..)
  , clusterName
  , nodeContainerName
  , discoverCluster
  , planActions
  , reconcileKind
  , renderKindConfig
  , renderKindConfigFor
  , validateLayoutIdentities
  , deleteKindCluster
  ) where

import Amoebius.Host.Context
import Amoebius.Host.Ensure
import Control.Concurrent (threadDelay)
import Control.Monad (forM_)
import Data.ByteString.Lazy.Char8 qualified as ByteString
import Data.List (intercalate)
import Data.Text (Text)
import System.Directory (doesDirectoryExist, doesFileExist)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))

clusterName :: String
clusterName = "amoebius-phase24"

nodeContainerName :: String
nodeContainerName = clusterName <> "-control-plane"

-- | The two layouts enforceable by the v1 containerd engine. SplitImage is
-- retained as an explicit rejection arm so it cannot silently alias imagefs.
data KindFilesystemLayout = KindUnified | KindSplitRuntime | KindSplitImage
  deriving stock (Eq, Ord, Show)

data LayoutIdentity = LayoutIdentity
  { layoutDevice :: Text
  , layoutQuotaId :: Text
  , layoutHardBytes :: Integer
  }
  deriving stock (Eq, Ord, Show)

data LayoutError
  = UnsupportedEnforcement KindFilesystemLayout
  | BackingAlias Text
  | FilesystemLayoutMismatch Text
  | MissingHardQuota Text
  deriving stock (Eq, Ord, Show)

data ClusterObservation = ClusterObservation
  { clusterRegistered :: Bool
  , nodeContainerState :: Maybe String
  , nodeEnvelopeConverged :: Bool
  , kubeletEnvelopeConverged :: Bool
  , addonEnvelopesConverged :: Bool
  , kubeconfigPresent :: Bool
  , nodeReady :: Bool
  }
  deriving stock (Eq, Show)

data ReconcileAction = CreateCluster | StartNode | EnsureNodeEnvelope | EnsureKubeletEnvelope | ExportKubeconfig | WaitReady | EnsureAddonEnvelopes
  deriving stock (Eq, Ord, Show)

data ReconcileReport = ReconcileReport
  { reconcileBefore :: ClusterObservation
  , reconcileActions :: [ReconcileAction]
  , reconcileAfter :: ClusterObservation
  }
  deriving stock (Eq, Show)

discoverCluster :: BinaryContext -> IO ClusterObservation
discoverCluster context = do
  clusters <- runTool (contextKind context) ["get", "clusters"]
  let registered = clusterName `elem` lines (ByteString.unpack (toolStdout clusters))
  stateResult <- runTool (contextDocker context) ["inspect", "--format", "{{.State.Status}}", nodeContainerName]
  let state = case toolExitCode stateResult of
        ExitSuccess -> Just (headOr "unknown" (lines (ByteString.unpack (toolStdout stateResult))))
        ExitFailure _ -> Nothing
  nodeEnvelope <- if registered && state == Just "running"
    then do
      result <- runTool (contextDocker context)
        ["inspect", "--format", "{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}} {{.HostConfig.MemorySwap}}", nodeContainerName]
      pure (toolExitCode result == ExitSuccess && ByteString.unpack (toolStdout result) == "2000000000 4294967296 4294967296\n")
    else pure False
  kubeletEnvelope <- if registered && state == Just "running"
    then do
      kubeletResult <- runTool (contextDocker context)
        [ "exec", nodeContainerName, "/usr/bin/systemctl", "show", "kubelet.service"
        , "--property=CPUQuotaPerSecUSec", "--property=MemoryMax"
        ]
      containerdResult <- runTool (contextDocker context)
        [ "exec", nodeContainerName, "/usr/bin/systemctl", "show", "containerd.service"
        , "--property=CPUQuotaPerSecUSec", "--property=MemoryMax"
        ]
      let kubeletRendered = ByteString.unpack (toolStdout kubeletResult)
          containerdRendered = ByteString.unpack (toolStdout containerdResult)
      pure
        ( toolExitCode kubeletResult == ExitSuccess
        && toolExitCode containerdResult == ExitSuccess
        && "CPUQuotaPerSecUSec=500ms" `contains` kubeletRendered
        && "MemoryMax=536870912" `contains` kubeletRendered
        && "CPUQuotaPerSecUSec=500ms" `contains` containerdRendered
        && "MemoryMax=1073741824" `contains` containerdRendered
        )
    else pure False
  kubeconfig <- doesFileExist (contextKubeconfig context)
  ready <- if kubeconfig
    then do
      result <- runTool (contextKubectl context)
        ["--kubeconfig", contextKubeconfig context, "get", "nodes", "-o", "jsonpath={.items[0].status.conditions[?(@.type=='Ready')].status}"]
      pure (toolExitCode result == ExitSuccess && ByteString.unpack (toolStdout result) == "True")
    else pure False
  addonEnvelopes <- if ready
    then and <$> traverse observeAddonEnvelope addonEnvelopeSpecs
    else pure False
  pure (ClusterObservation registered state nodeEnvelope kubeletEnvelope addonEnvelopes kubeconfig ready)
 where
  observeAddonEnvelope (namespace, resourceKind, resourceName, _containerName, cpuRequest, cpuLimit, memoryRequest, memoryLimit, ephemeralRequest, ephemeralLimit) = do
    result <- runTool (contextKubectl context)
      [ "--kubeconfig", contextKubeconfig context, "-n", namespace
      , "get", resourceKind, resourceName
      , "-o", "jsonpath={.spec.template.spec.containers[0].resources.requests.cpu}|{.spec.template.spec.containers[0].resources.limits.cpu}|{.spec.template.spec.containers[0].resources.requests.memory}|{.spec.template.spec.containers[0].resources.limits.memory}|{.spec.template.spec.containers[0].resources.requests.ephemeral-storage}|{.spec.template.spec.containers[0].resources.limits.ephemeral-storage}"
      ]
    pure
      ( toolExitCode result == ExitSuccess
      && ByteString.unpack (toolStdout result) == intercalate "|" [cpuRequest, cpuLimit, memoryRequest, memoryLimit, ephemeralRequest, ephemeralLimit]
      )

planActions :: ClusterObservation -> [ReconcileAction]
planActions observed
  | not (clusterRegistered observed) = [CreateCluster, EnsureNodeEnvelope, EnsureKubeletEnvelope, WaitReady, EnsureAddonEnvelopes]
  | otherwise =
      [StartNode | nodeContainerState observed /= Just "running"]
        <> [EnsureNodeEnvelope | not (nodeEnvelopeConverged observed)]
        <> [EnsureKubeletEnvelope | not (kubeletEnvelopeConverged observed)]
        <> [ExportKubeconfig | not (kubeconfigPresent observed)]
        <> [WaitReady | not (nodeReady observed)]
        <> [EnsureAddonEnvelopes | not (addonEnvelopesConverged observed)]

reconcileKind
  :: BinaryContext
  -> KindFilesystemLayout
  -> Maybe ValidatedKindCreate
  -> IO (Either String ReconcileReport)
reconcileKind context layout createToken = do
  before <- discoverCluster context
  let actions = planActions before
  result <- enact actions
  case result of
    Left problem -> pure (Left problem)
    Right () -> do
      after <- discoverCluster context
      if clusterRegistered after && nodeContainerState after == Just "running" && nodeEnvelopeConverged after && kubeletEnvelopeConverged after && addonEnvelopesConverged after && kubeconfigPresent after && nodeReady after
        then pure (Right (ReconcileReport before actions after))
        else pure (Left ("reconcile-did-not-converge:" <> show after))
 where
  enact [] = pure (Right ())
  enact (action : rest) = do
    outcome <- enactOne action
    case outcome of
      Left problem -> pure (Left problem)
      Right () -> enact rest
  enactOne CreateCluster = case createToken of
    Nothing -> pure (Left "validated-kind-create-token-absent")
    Just token -> do
      observed <- observePhysicalHost context
      case observed of
        Left problem -> pure (Left (renderHostAdmissionError problem))
        Right current -> do
          consumed <- consumeKindCreate token current
          case consumed of
            Left problem -> pure (Left (renderHostAdmissionError problem))
            Right () -> do
              let config = contextStateDirectory context </> "kind-config.yaml"
              pathsPresent <- and <$> traverse doesDirectoryExist (layoutHostPaths layout)
              if not pathsPresent
                then pure (Left "FilesystemLayoutMismatch:hard-backing-path-absent")
                else case renderKindConfigFor layout of
                  Left problem -> pure (Left (show problem))
                  Right rendered -> do
                    writeProcessEnvelopePatches
                    writeFile config rendered
                    command <- runTool (contextKind context)
                      [ "create", "cluster", "--name", clusterName
                      , "--image", "kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5"
                      , "--config", config, "--kubeconfig", contextKubeconfig context, "--wait", "180s"
                      ]
                    commandSuccess "kind-create" command
  enactOne StartNode = commandSuccess "docker-start" =<< runTool (contextDocker context) ["start", nodeContainerName]
  enactOne EnsureNodeEnvelope = commandSuccess "node-container-envelope" =<< runTool (contextDocker context)
    ["update", "--cpus", "2", "--memory", "4g", "--memory-swap", "4g", nodeContainerName]
  enactOne EnsureKubeletEnvelope = do
    kubeletResult <- retryCommand 60 "kubelet-envelope" (contextDocker context)
      [ "exec", nodeContainerName, "/usr/bin/systemctl", "set-property"
      , "kubelet.service", "CPUQuota=50%", "MemoryMax=536870912"
      ]
    case kubeletResult of
      Left problem -> pure (Left problem)
      Right () -> retryCommand 60 "containerd-envelope" (contextDocker context)
        [ "exec", nodeContainerName, "/usr/bin/systemctl", "set-property"
        , "containerd.service", "CPUQuota=50%", "MemoryMax=1073741824"
        ]
  enactOne ExportKubeconfig = commandSuccess "kind-export-kubeconfig" =<< runTool (contextKind context)
    ["export", "kubeconfig", "--name", clusterName, "--kubeconfig", contextKubeconfig context]
  enactOne WaitReady = waitReady 90
  enactOne EnsureAddonEnvelopes = enactAddonEnvelopes addonEnvelopeSpecs
  waitReady :: Int -> IO (Either String ())
  waitReady attempts
    | attempts <= 0 = pure (Left "kubectl-wait-failed:node-did-not-become-ready")
    | otherwise = do
        result <- runTool (contextKubectl context)
          ["--kubeconfig", contextKubeconfig context, "get", "nodes", "-o", "jsonpath={.items[0].status.conditions[?(@.type=='Ready')].status}"]
        if toolExitCode result == ExitSuccess && ByteString.unpack (toolStdout result) == "True"
          then pure (Right ())
          else threadDelay 2000000 >> waitReady (attempts - 1)
  retryCommand :: Int -> String -> AbsExe -> [String] -> IO (Either String ())
  retryCommand attempts label executable arguments
    | attempts <= 0 = commandSuccess label =<< runTool executable arguments
    | otherwise = do
        result <- runTool executable arguments
        case toolExitCode result of
          ExitSuccess -> pure (Right ())
          ExitFailure _ -> threadDelay 1000000 >> retryCommand (attempts - 1) label executable arguments
  enactAddonEnvelopes [] = waitPodEnvelopes 120
  enactAddonEnvelopes ((namespace, resourceKind, resourceName, containerName, cpuRequest, cpuLimit, memoryRequest, memoryLimit, ephemeralRequest, ephemeralLimit) : rest) = do
    let patch = "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"" <> containerName
          <> "\",\"resources\":{\"requests\":{\"cpu\":\"" <> cpuRequest <> "\",\"memory\":\"" <> memoryRequest
          <> "\",\"ephemeral-storage\":\"" <> ephemeralRequest <> "\"},\"limits\":{\"cpu\":\"" <> cpuLimit <> "\",\"memory\":\"" <> memoryLimit
          <> "\",\"ephemeral-storage\":\"" <> ephemeralLimit <> "\"}}}]}}}}"
    patched <- commandSuccess ("addon-envelope:" <> namespace <> "/" <> resourceName) =<< runTool (contextKubectl context)
      [ "--kubeconfig", contextKubeconfig context, "-n", namespace
      , "patch", resourceKind, resourceName, "--type=strategic", "--patch", patch
      ]
    case patched of
      Left problem -> pure (Left problem)
      Right () -> do
        rolled <- commandSuccess ("addon-rollout:" <> namespace <> "/" <> resourceName) =<< runTool (contextKubectl context)
          [ "--kubeconfig", contextKubeconfig context, "-n", namespace
          , "rollout", "status", resourceKind <> "/" <> resourceName, "--timeout=120s"
          ]
        case rolled of
          Left problem -> pure (Left problem)
          Right () -> enactAddonEnvelopes rest
  waitPodEnvelopes :: Int -> IO (Either String ())
  waitPodEnvelopes attempts
    | attempts <= 0 = pure (Left "addon-envelope-pods-failed:unknown-commitment-remained")
    | otherwise = do
        result <- runTool (contextKubectl context)
          [ "--kubeconfig", contextKubeconfig context, "get", "pods", "-A"
          , "-o", "jsonpath={range .items[*]}{range .spec.containers[*]}{.resources.requests.cpu}|{.resources.limits.cpu}|{.resources.requests.memory}|{.resources.limits.memory}|{.resources.requests.ephemeral-storage}|{.resources.limits.ephemeral-storage}{'\\n'}{end}{end}"
          ]
        let rows = filter (not . null) (lines (ByteString.unpack (toolStdout result)))
            complete row = length (splitOnPipe row) == 6 && all (not . null) (splitOnPipe row)
        if toolExitCode result == ExitSuccess && not (null rows) && all complete rows
          then pure (Right ())
          else threadDelay 1000000 >> waitPodEnvelopes (attempts - 1)

commandSuccess :: String -> ToolResult -> IO (Either String ())
commandSuccess label result = pure $ case toolExitCode result of
  ExitSuccess -> Right ()
  ExitFailure code -> Left (label <> "-failed:" <> show code <> ":" <> ByteString.unpack (toolStderr result) <> ByteString.unpack (toolStdout result))

renderKindConfig :: String
renderKindConfig = either (error . show) id (renderKindConfigFor KindUnified)

renderKindConfigFor :: KindFilesystemLayout -> Either LayoutError String
renderKindConfigFor KindSplitImage = Left (UnsupportedEnforcement KindSplitImage)
renderKindConfigFor layout = Right (intercalate "\n" (
  [ "kind: Cluster"
  , "apiVersion: kind.x-k8s.io/v1alpha4"
  , "nodes:"
  , "- role: control-plane"
  ]
  <> extraMounts layout
  <>
  [ "kubeadmConfigPatches:"
  , "- |"
  , "  kind: ClusterConfiguration"
  , "  apiServer:"
  , "    extraArgs:"
  , "      - name: event-ttl"
  , "        value: 1h"
  , "      - name: audit-log-maxsize"
  , "        value: '16'"
  , "      - name: audit-log-maxbackup"
  , "        value: '2'"
  , "      - name: audit-log-maxage"
  , "        value: '1'"
  , "      - name: audit-log-path"
  , "        value: /var/log/kubernetes/audit/audit.log"
  , "      - name: audit-policy-file"
  , "        value: /etc/kubernetes/audit-policy.yaml"
  , "    extraVolumes:"
  , "    - name: audit-policy"
  , "      hostPath: /kind/patches/audit-policy.yaml"
  , "      mountPath: /etc/kubernetes/audit-policy.yaml"
  , "      readOnly: true"
  , "      pathType: File"
  , "    - name: audit-log"
  , "      hostPath: /var/log/kubernetes/audit"
  , "      mountPath: /var/log/kubernetes/audit"
  , "      pathType: DirectoryOrCreate"
  , "  etcd:"
  , "    local:"
  , "      extraArgs:"
  , "        - name: quota-backend-bytes"
  , "          value: '1073741824'"
  , "        - name: max-wals"
  , "          value: '5'"
  , "- |"
  , "  kind: KubeletConfiguration"
  , "  serializeImagePulls: true"
  , "  containerLogMaxSize: 16Mi"
  , "  containerLogMaxFiles: 3"
  , "- |"
  , "  kind: InitConfiguration"
  , "  patches:"
  , "    directory: /kind/patches"
  , ""
  ]))
 where
  extraMounts KindUnified =
    [ "  extraMounts:"
    , "  - hostPath: /var/lib/amoebius/phase24/unified/kubelet"
    , "    containerPath: /var/lib/kubelet"
    , "  - hostPath: /var/lib/amoebius/phase24/unified/containerd"
    , "    containerPath: /var/lib/containerd"
    , "  - hostPath: /var/lib/amoebius/phase24/unified/system/etcd"
    , "    containerPath: /var/lib/etcd"
    , "  - hostPath: /var/lib/amoebius/phase24/unified/system/audit"
    , "    containerPath: /var/log/kubernetes/audit"
    , "  - hostPath: /var/lib/amoebius/phase24/unified/system/pods"
    , "    containerPath: /var/log/pods"
    , "  - hostPath: /var/lib/amoebius/phase24/patches"
    , "    containerPath: /kind/patches"
    ]
  extraMounts KindSplitRuntime =
    [ "  extraMounts:"
    , "  - hostPath: /var/lib/amoebius/phase24/nodefs/kubelet"
    , "    containerPath: /var/lib/kubelet"
    , "  - hostPath: /var/lib/amoebius/phase24/imagefs/containerd"
    , "    containerPath: /var/lib/containerd"
    , "  - hostPath: /var/lib/amoebius/phase24/nodefs/system/etcd"
    , "    containerPath: /var/lib/etcd"
    , "  - hostPath: /var/lib/amoebius/phase24/nodefs/system/audit"
    , "    containerPath: /var/log/kubernetes/audit"
    , "  - hostPath: /var/lib/amoebius/phase24/nodefs/system/pods"
    , "    containerPath: /var/log/pods"
    , "  - hostPath: /var/lib/amoebius/phase24/patches"
    , "    containerPath: /kind/patches"
    ]
  extraMounts KindSplitImage = []


layoutHostPaths :: KindFilesystemLayout -> [FilePath]
layoutHostPaths KindUnified =
  [ "/var/lib/amoebius/phase24/unified/kubelet"
  , "/var/lib/amoebius/phase24/unified/containerd"
  , "/var/lib/amoebius/phase24/unified/system/etcd"
  , "/var/lib/amoebius/phase24/unified/system/audit"
  , "/var/lib/amoebius/phase24/unified/system/pods"
  , "/var/lib/amoebius/phase24/patches"
  ]
layoutHostPaths KindSplitRuntime =
  [ "/var/lib/amoebius/phase24/nodefs/kubelet"
  , "/var/lib/amoebius/phase24/imagefs/containerd"
  , "/var/lib/amoebius/phase24/nodefs/system/etcd"
  , "/var/lib/amoebius/phase24/nodefs/system/audit"
  , "/var/lib/amoebius/phase24/nodefs/system/pods"
  , "/var/lib/amoebius/phase24/patches"
  ]
layoutHostPaths KindSplitImage = []

writeProcessEnvelopePatches :: IO ()
writeProcessEnvelopePatches = do
  forM_ processEnvelopes $ \(component, cpuRequest, cpuLimit, memoryRequest, memoryLimit, ephemeralRequest, ephemeralLimit) ->
    writeFile ("/var/lib/amoebius/phase24/patches/" <> component <> "+strategic.yaml") (intercalate "\n"
    [ "spec:"
    , "  containers:"
    , "  - name: " <> component
    , "    resources:"
    , "      requests:"
    , "        cpu: " <> cpuRequest
    , "        memory: " <> memoryRequest
    , "        ephemeral-storage: " <> ephemeralRequest
    , "      limits:"
    , "        cpu: " <> cpuLimit
    , "        memory: " <> memoryLimit
    , "        ephemeral-storage: " <> ephemeralLimit
    , ""
    ])
  writeFile "/var/lib/amoebius/phase24/patches/audit-policy.yaml" (intercalate "\n"
    [ "apiVersion: audit.k8s.io/v1"
    , "kind: Policy"
    , "rules:"
    , "- level: Metadata"
    , ""
    ])
 where
  processEnvelopes =
    [ ("etcd", "250m", "500m", "512Mi", "1Gi", "64Mi", "256Mi")
    , ("kube-apiserver", "250m", "1", "512Mi", "1Gi", "64Mi", "256Mi")
    , ("kube-controller-manager", "100m", "500m", "128Mi", "512Mi", "64Mi", "256Mi")
    , ("kube-scheduler", "100m", "500m", "128Mi", "512Mi", "64Mi", "256Mi")
    ]

-- | Validate an OS-boundary readback independently of the renderer.
validateLayoutIdentities
  :: KindFilesystemLayout
  -> LayoutIdentity
  -> LayoutIdentity
  -> LayoutIdentity
  -> Either LayoutError ()
validateLayoutIdentities KindSplitImage _ _ _ = Left (UnsupportedEnforcement KindSplitImage)
validateLayoutIdentities layout nodefs content snapshots
  | any ((<= 0) . layoutHardBytes) [nodefs, content, snapshots] = Left (MissingHardQuota "zero-or-unknown")
  | content /= snapshots = Left (FilesystemLayoutMismatch "containerd-content-snapshot-roots")
  | layout == KindUnified && nodefs /= content = Left (FilesystemLayoutMismatch "unified-roots-not-identical")
  | layout == KindSplitRuntime && layoutDevice nodefs == layoutDevice content = Left (BackingAlias "split-runtime")
  | layout == KindSplitRuntime && layoutQuotaId nodefs == layoutQuotaId content = Left (BackingAlias "split-runtime-quota")
  | otherwise = Right ()

deleteKindCluster :: BinaryContext -> IO (Either String ())
deleteKindCluster context = do
  result <- runTool (contextKind context) ["delete", "cluster", "--name", clusterName, "--kubeconfig", contextKubeconfig context]
  commandSuccess "kind-delete" result

headOr :: value -> [value] -> value
headOr fallback values = case values of
  [] -> fallback
  first : _ -> first

contains :: String -> String -> Bool
contains needle haystack = any (prefix needle) (tails haystack)
 where
  tails [] = [[]]
  tails value@(_ : rest) = value : tails rest
  prefix [] _ = True
  prefix _ [] = False
  prefix (left : moreLeft) (right : moreRight) = left == right && prefix moreLeft moreRight

splitOnPipe :: String -> [String]
splitOnPipe [] = [""]
splitOnPipe source = case break (== '|') source of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitOnPipe rest

addonEnvelopeSpecs :: [(String, String, String, String, String, String, String, String, String, String)]
addonEnvelopeSpecs =
  [ ("kube-system", "deployment", "coredns", "coredns", "100m", "200m", "64Mi", "128Mi", "32Mi", "128Mi")
  , ("kube-system", "daemonset", "kube-proxy", "kube-proxy", "50m", "100m", "64Mi", "128Mi", "32Mi", "128Mi")
  , ("kube-system", "daemonset", "kindnet", "kindnet-cni", "50m", "100m", "64Mi", "128Mi", "32Mi", "128Mi")
  , ("local-path-storage", "deployment", "local-path-provisioner", "local-path-provisioner", "50m", "100m", "64Mi", "128Mi", "32Mi", "128Mi")
  ]
