{-# LANGUAGE OverloadedStrings #-}

-- Independent object inventory and dependency projections. Architecture and
-- accelerators are operator-authored values, never observations of this host.
module DslExtensionRuntime (runtimeRows, binaryRuntimeRows) where

import Control.Monad (guard)
import Data.Aeson (Value (..), object, (.=), toJSON)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import DslBinarySubstrates (normal, listAt, textAt, one, field, naturalAt, unionTag, unionPayload, textOf)
import Dhall.Core qualified as Core
import DslConformance (expectedDeclaration, frame)
import DslExtensionContract (inferenceGrid, linkedIds, declarationWorkflows, extensionExampleNames)
import DslParse
import DslMonitoringContract (runtimeMonitorControls, expectedSloRows, expectedTensorRows)
import DslRecipe (recipeRows)
import DslStages
import DslTables
import System.FilePath ((</>))

runtimeRows :: FilePath -> IO [Row]
runtimeRows suite = do
  rows <- concat <$> traverse observe inferenceGrid
  controls <- readTable (suite </> "extensions/runtime/scope-controls.tsv")
  reentry <- readTable (suite </> "extensions/runtime/reentry-controls.tsv")
  origins <- readTable (suite </> "extensions/runtime/authority-origins.tsv")
  examples <- readTable (suite </> "extensions/runtime/corpus.tsv")
  rendered <- readTable (suite </> "extensions/runtime/corpus-files.tsv")
  stages <- readTable (suite </> "extensions/runtime/chain-stage-controls.tsv")
  monitoring <- readTable (suite </> "extensions/runtime/monitoring-controls.tsv")
  slo <- readTable (suite </> "extensions/runtime/monitoring-slo.tsv")
  tensor <- readTable (suite </> "extensions/runtime/monitoring-tensorboard.tsv")
  pure (rows <>
    [expectEqual "workflow.monitoring.controls" [[name, result] | (name, result) <- runtimeMonitorControls] monitoring,
     expectEqual "workflow.monitoring.slo" (map (\(name, value) -> [name, value])
       (expectedSloRows ("notes-" <> sentinel) ("engine-" <> sentinel) ("assets-" <> sentinel))) slo,
     expectEqual "workflow.monitoring.tensorboard" (map (\(name, value) -> [name, value])
       (expectedTensorRows ("notes-" <> sentinel) ("engine-" <> sentinel) ("assets-" <> sentinel))) tensor] <>
    [expectEqual "runtime.corpus.complete-examples" (map pure extensionExampleNames) examples,
     expectEqual "runtime.corpus.complete-rendered-files" [["examples/" <> name <> ".dhall"] | name <- extensionExampleNames] rendered,
     expectEqual "workflow.extension-chain.stage-controls"
       [["legal", "accepted:26"], ["missing-provider-objects", "ExtensionBindingRequired", "extension-chain",
         "ExtensionChainFailed (ExtensionBindingRequired \"engine-" <> sentinel <> "\")"]] stages] <>
    [expectEqual "scope.render.missing-authority-refused"
      [["attested", "accepted:22"], ["missing-authorities", "UnattestedScope"],
       ["missing-inference-authority", "UnattestedScope"]] controls,
     expectEqual "scope.authority.reentry-controls"
       [["same-scope", "accepted:payload"], ["different-need", "ReentryScopeMismatch"],
        ["different-tenant", "ReentryTenantMismatch"], ["bottom-scope-eliminator", "exception"]] reentry,
     expectEqual "scope.authority.origins"
       [[issuer, application, need, attestedScopeLabel issuer application need] | (issuer, application, need) <-
         [("core/ObjectStore", "notes-" <> sentinel, "assets-" <> sentinel),
          ("extension/infernix", "notes-" <> sentinel, "engine-" <> sentinel),
          ("principal/tenant-other", "subject-other", "request"),
          ("principal/ténant", "sübject", "request")]] origins])
 where
  observe (name, _, _, _) = runtimeView name sentinel
    (suite </> "extensions/runtime" </> Text.unpack name </> "compiled")
    (suite </> "extensions/runtime" </> Text.unpack name </> "applied")

binaryRuntimeRows :: FilePath -> IO [Row]
binaryRuntimeRows suite = do
  input <- readText (suite </> "binary/input/root.dhall")
  frozen <- readText (suite </> "binary/compiled/frozen.dhall")
  let nonce = do
        root <- input >>= normal
        app <- listAt "rootApps" root >>= one
        name <- textAt "appName" app
        value <- Text.stripPrefix "notes-" name
        guard (Text.length value == 32 && Text.all (`elem` (['0'..'9'] <> ['a'..'f'])) value)
        pure value
  case nonce of
    Nothing -> pure [check "binary.extensions.input" False "missing or invalid challenged input"]
    Just value -> do
      rows <- runtimeView "binary.extensions" value (suite </> "binary/compiled") (suite </> "binary/applied")
      pure ([check "binary.extensions.input-contract" ((input >>= extensionChallenge) == Just value)
                "the input differs from the independent four-need CPU challenge",
             check "binary.extensions.freeze-equivalent" ((input >>= normal) /= Nothing && (input >>= normal) == (frozen >>= normal))
                "the frozen program differs from the submitted input"] <> rows)

extensionChallenge :: Text -> Maybe Text
extensionChallenge source = do
  root <- normal source
  cluster <- listAt "rootClusters" root >>= one
  guard (textAt "clusterName" cluster == Just "kind-a")
  topology <- field "clusterTopology" cluster >>= unionPayload "KindTopology"
  guard (textAt "kindHost" topology == Just "kind-host" && naturalAt "kindReplicas" topology == Just 1)
  host <- listAt "clusterHosts" cluster >>= one
  guard (traverse (`textAt` host) ["hostName", "hostOs", "hostArch"] == Just ["kind-host", "linux", "amd64"])
  guard (traverse (`naturalAt` host) ["hostCpu", "hostMemory", "hostEphemeral", "hostPods"] == Just [64, 256, 2000, 110])
  guard (field "hostGpu" host == Just (Core.BoolLit False) && listAt "hostTaints" host == Just [])
  app <- listAt "rootApps" root >>= one
  name <- textAt "appName" app
  nonce <- Text.stripPrefix "notes-" name
  let needPairs = [("ObjectStore", "assets-" <> nonce), ("Registry", "images-" <> nonce),
                   ("MessageBus", "events-" <> nonce), ("InferenceEngine", "engine-" <> nonce)]
  needs <- listAt "needs" app
  guard (length needs == 4 && and [textAt "needName" value == Just need && maybe False (unionTag arm) (field "needCapability" value)
    | ((arm, need), value) <- zip needPairs needs])
  workload <- field "workload" app
  requests <- field "workloadRequests" workload
  limits <- field "workloadLimits" workload
  guard (traverse (`naturalAt` requests) ["podCpu", "podMemory", "podEphemeral"] == Just [1, 2, 4]
    && traverse (`naturalAt` limits) ["podCpu", "podMemory", "podEphemeral"] == Just [2, 4, 8])
  case field "workloadHeadroom" workload of Just (Core.App Core.None _) -> pure (); _ -> Nothing
  deployment <- listAt "rootDeployments" root >>= one
  guard (textAt "deploymentOf" deployment == Just name)
  distribution <- field "distribution" deployment
  guard (naturalAt "replicas" distribution == Just 1)
  bindings <- listAt "bindings" deployment
  guard (length bindings == 4 && and [textAt "bindingNeed" value == Just need && textAt "bindingProvider" value == Just "Canonical"
    && maybe False (unionTag "SingleNode") (field "bindingShape" value)
    && case field "bindingInference" value of
      Just (Core.Some inference) | arm == "InferenceEngine" ->
        maybe False (unionTag "LinuxCpu") (field "engineRuntime" inference) && maybe False (unionTag "LlamaCpp") (field "engineFamily" inference)
      Just (Core.App Core.None _) -> arm /= "InferenceEngine"
      _ -> False
    | ((arm, need), value) <- zip needPairs bindings])
  extensions <- listAt "rootExtensions" root
  guard (traverse (textAt "extensionId") extensions == Just linkedIds)
  case extensions of
    [build, coordination, inference, training] -> do
      cache <- field "extensionParameters" build >>= unionPayload "BuildCacheParameters"
      guard (traverse (`naturalAt` cache) ["cacheBudgetBytes", "cacheTemporaryBytes", "cacheFirstMissConcurrency"] == Just [4096, 1024, 3])
      guard ((field "extensionParameters" coordination >>= unionPayload "CoordinationParameters" >>= textOf) == Just ("events-" <> nonce))
      guard ((field "extensionParameters" inference >>= unionPayload "InferenceParameters") == Just (Core.NaturalLit 8192))
      guard ((field "extensionParameters" training >>= unionPayload "TrainingParameters" >>= textOf) == Just ("assets-" <> nonce))
    _ -> Nothing
  pure nonce

runtimeView :: Text -> Text -> FilePath -> FilePath -> IO [Row]
runtimeView name nonce compiled applied = do
  manifest <- readBytes (compiled </> "manifest.json")
  appliedManifest <- readBytes (applied </> "manifest.json")
  plan <- readBytes (compiled </> "chain.dump")
  dry <- readText (compiled </> "dry-run.dump")
  workflows <- readTable (compiled </> "workflow.tsv")
  lowered <- readTable (compiled </> "lowered.dump")
  fake <- fakeTranscriptRows ("runtime." <> name <> ".fake") (applied </> "fake") (maybe [] splitPayloads manifest)
  let cuda = "cuda-" `Text.isPrefixOf` name
      architecture = if "-arm64" `Text.isSuffixOf` name then "arm64" else "amd64"
      cpuLane = "linux-cpu/" <> architecture
      cudaLane = "linux-cuda/" <> architecture
  recipes <- recipeRows compiled ("runtime." <> name <> ".image") ("notes-" <> nonce) False
    ([(cpuLane, "amoebius-base-cpu-" <> architecture, "ubuntu:24.04")] <>
      [(cudaLane, "amoebius-base-cuda-" <> architecture, "nvidia/cuda:12.8.2-devel-ubuntu24.04") | cuda])
  let engineKind = if cuda then "DaemonSet" else "Deployment"
      app = "notes-" <> nonce
      need = "engine-" <> nonce
      params = baselineParams {paramApp = app, paramNeeds = [NeedP ObjectStoreArm ("assets-" <> nonce) Single]}
      namespace slug = case slug of "registry" -> "amoebius-registry"; _ -> "amoebius-pulsar"
      peers = concat [provider slug (prefix <> nonce) (namespace slug) | (slug, prefix) <- [("registry", "images-"), ("messagebus", "events-")]]
      engines = [Expected ("inferenceengine/" <> need <> "/" <> suffix) (Just kind) suffix (Just "amoebius-inference") activation "ServerSideApply" need
        | (suffix, kind, activation) <- [("config", "ConfigMap", "Immediate"), ("service", "Service", "AfterBootstrapAddonCutover"), ("member-0", engineKind, "AfterBootstrapAddonCutover")]]
      plans = [Expected ("extension/" <> need <> "/" <> identifier <> "/plan") (Just "ConfigMap")
        (identifier <> "-" <> Text.take 12 (Text.drop 2 (attestedScopeLabel "extension/infernix" app need)))
        (Just "amoebius-inference") "Immediate" "ServerSideApply" ("extension/" <> identifier) | identifier <- linkedIds]
      wanted = chainOrder (expectedObjects params <> peers <> engines <> plans)
      objects = manifestObjects manifest
      identity = annotationText "amoebius.io/object-identity"
      matches expected actual = identity actual == Just (expectedIdentity expected)
        && Just (mKind actual) == expectedKind expected && mName actual == expectedName expected
        && mNamespace actual == expectedNamespace expected && mApiVersion actual == apiVersionOf (mKind actual)
        && annotationText "amoebius.io/render-activation" actual == Just (expectedActivation expected)
        && annotationText "amoebius.io/reconcile-mode" actual == Just (expectedReconcile expected)
        && Map.lookup "amoebius.io/owner" (mLabels actual) == Just (expectedOwner expected)
        && Map.lookup "amoebius.io/epoch" (mLabels actual) == Just "generation-1"
        && Map.lookup "app.kubernetes.io/managed-by" (mLabels actual) == Just "amoebius"
      scope expected actual = let (issuer, ownerNeed) = authority nonce (expectedIdentity expected) in
        Map.lookup "amoebius.io/scope" (mLabels actual) == Just (attestedScopeLabel issuer app ownerNeed)
        && Map.lookup "amoebius.io/scope-issuer" (mAnnotations actual) == Just issuer
        && Map.lookup "amoebius.io/scope-application" (mAnnotations actual) == Just app
        && Map.lookup "amoebius.io/scope-need" (mAnnotations actual) == Just ownerNeed
      complete = length objects == 26 && length (maybe [] splitPayloads manifest) == 26
      find objectId = one [value | value <- objects, identity value == Just objectId]
      config objectId = find objectId >>= configuration
      fields = planFields nonce cuda
      output identifier = lookup identifier fields >>= lookup "output"
      exactPlans = all (\(identifier, values) -> config ("extension/" <> need <> "/" <> identifier <> "/plan") == Just (Map.fromList values)) fields
      engineConfiguration = config ("inferenceengine/" <> need <> "/config") == Just (Map.fromList
        ([("kind", "ConfigMap"), ("role", "provider-config"), ("cache-budget", "8192"),
          ("engine-runtime", if cuda then "Cuda" else "LinuxCpu"), ("engine-family", "llama.cpp")]
         <> [(key, value) | (key, Just value) <- [("jit-build", output "jit-build"), ("infernix-output", output "infernix")]]))
      workflowKeys identifier arms =
        [("workflow." <> need <> ".application", app), ("workflow." <> need <> ".need", need), ("workflow." <> need <> ".issuer", "extension/infernix")]
        <> [("extension." <> need <> "." <> identifier <> ".declaration.workflow.field." <> Text.pack (show index), value)
           | (index, value) <- zip [1 :: Int ..] (["ledger", "arms", Text.pack (show (length arms))] <> arms <> ["provisioned", "0", "released", "0"])]
      workflowPairs = [(key, value) | [key, value] <- maybe [] id workflows]
      exactWorkflow = all (\(key, value) -> [observed | (actual, observed) <- workflowPairs, actual == key] == [value])
        (concat [workflowKeys identifier arms | (identifier, arms) <- declarationWorkflows])
      expectedController = "inferenceengine/" <> need <> "/member-0:" <>
        if cuda then "DaemonSetBody [\"kind-host-1\"] DaemonSetOnDelete" else "DeploymentBody 1 RecreateRollout"
      controller = maybe False (elem ["bound.service." <> need <> ".controllers", expectedController]) lowered
      topology = all (\(key, value) -> maybe False (elem ["topology.node.kind-host-1." <> key, value]) lowered)
        [("architecture", architecture), ("substrate", if cuda then "linux-cuda" else "linux-cpu"),
         ("lanes", Text.intercalate "," ([cpuLane] <> [cudaLane | cuda]))]
      row family suffix passed = check (family <> "." <> name <> "." <> suffix) passed "runtime, identity, scope or dependency projection differs from the independent contract"
  pure ([row "runtime" "complete-manifest" (complete && and (zipWith matches wanted objects)),
         row "scope" "every-object" (complete && and (zipWith scope wanted objects)),
         row "runtime" "inference-pod" ((find ("inferenceengine/" <> need <> "/member-0") >>= pod) == Just (enginePod cuda)),
         row "runtime" "runtime-controller" controller,
         row "runtime" "supplied-lanes" topology,
         row "workflow" "consumed" (exactPlans && engineConfiguration && exactWorkflow),
         row "runtime" "fake-applied" (manifest /= Nothing && manifest == appliedManifest)]
    <> [appDeploymentRow ("runtime." <> name <> ".application-pod") params objects,
        appSmallRow ("runtime." <> name <> ".application-endpoints") params objects,
        chainRow ("workflow." <> name <> ".chain") wanted plan,
        chainManifestRow ("workflow." <> name <> ".manifest-order") wanted (maybe [] splitPayloads manifest) objects,
        dryRunRow ("workflow." <> name <> ".dry-run") wanted (maybe [] splitPayloads manifest) dry] <> fake <> recipes)

provider :: Text -> Text -> Text -> [Expected]
provider slug need namespace =
  [Expected (slug <> "/" <> need <> "/" <> suffix) (Just kind) name (Just namespace) activation "ServerSideApply" need
    | (suffix, kind, name, activation) <-
      [("config", "ConfigMap", "config", "Immediate"), ("service", "Service", "service", "AfterBootstrapAddonCutover"),
       ("member-0", "StatefulSet", "member-0", "AfterBootstrapAddonCutover"),
       ("member-0/pvc", "PersistentVolumeClaim", "data-member-0-0", "AfterBootstrapAddonCutover")]]

authority :: Text -> Text -> (Text, Text)
authority nonce identity
  | "inferenceengine/" `Text.isPrefixOf` identity || "extension/" `Text.isPrefixOf` identity = ("extension/infernix", "engine-" <> nonce)
  | "registry/" `Text.isPrefixOf` identity = ("core/Registry", "images-" <> nonce)
  | "messagebus/" `Text.isPrefixOf` identity = ("core/MessageBus", "events-" <> nonce)
  | otherwise = ("core/ObjectStore", "assets-" <> nonce)

planFields :: Text -> Bool -> [(Text, [(Text, Text)])]
planFields nonce cuda = [coordination, build, inference, training]
 where
  label = attestedScopeLabel "extension/infernix" ("notes-" <> nonce) ("engine-" <> nonce)
  make name fields = (name, ("output", "plan-" <> sha256Hex (frame
    (["extension-plan/v1", name, expectedDeclaration name, label] <> concat [[key, value] | (key, value) <- fields]))) : fields)
  output (_, fields) = maybe "missing-independent-output" id (lookup "output" fields)
  coordination = make "coordination" [("message-bus", "events-" <> nonce)]
  build = make "jit-build" [("cache-budget", "4096"), ("cache-temporary", "1024"), ("cache-concurrency", "3"), ("object-store", "assets-" <> nonce), ("registry", "images-" <> nonce)]
  inference = make "infernix" [("jit-build", output build), ("cache-budget", "8192"), ("engine-runtime", if cuda then "Cuda" else "LinuxCpu"), ("engine-family", "llama.cpp")]
  training = make "jitml" [("jit-build", output build), ("coordination", output coordination), ("infernix", output inference), ("training-store", "assets-" <> nonce)]

configuration :: Manifested -> Maybe (Map.Map Text Text)
configuration value = case mSpec value of
  Object spec | KeyMap.lookup "tag" spec == Just (String "ConfigurationSpec"),
                Just (Object fields) <- KeyMap.lookup "contents" spec ->
    Map.fromList <$> traverse (\(key, entry) -> case entry of String text -> Just (Key.toText key, text); _ -> Nothing) (KeyMap.toList fields)
  _ -> Nothing

pod :: Manifested -> Maybe Value
pod value = case mSpec value of
  Object spec -> KeyMap.lookup "contents" spec
  _ -> Nothing

enginePod :: Bool -> Value
enginePod cuda = toArray [String (if cuda then "DaemonSetWorkload" else "DeploymentWorkload"), object
  ["podAcceleratorClaim" .= (if cuda then Just (1 :: Int) else Nothing),
   "podImage" .= ("registry.amoebius.invalid/member-0@sha256:provisioned" :: Text), "podNodeName" .= ("kind-host-1" :: Text),
   "podReplicas" .= Null, "podResources" .= object ["resourceRequests" .= vector, "resourceLimits" .= vector],
   "podSchedulerName" .= ("amoebius-capacity" :: Text), "podSecurityContext" .= object
     ["securityAllowPrivilegeEscalation" .= False, "securityReadOnlyRootFilesystem" .= True, "securityRunAsNonRoot" .= True],
   "podVolumesBounded" .= True]]
 where
  vector = object ["resourceCpu" .= (4 :: Int), "resourceMemory" .= (8 :: Int), "resourceEphemeralStorage" .= (16 :: Int), "resourcePodSlots" .= (1 :: Int)]
  toArray = toJSON
