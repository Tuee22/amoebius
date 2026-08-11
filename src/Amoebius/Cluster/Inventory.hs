{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Cluster.Inventory
  ( ObservedInventory (..)
  , ObservedPodCommitment (..)
  , ObservedContainerCommitment (..)
  , ObservedBackingIdentity (..)
  , InventoryError (..)
  , DeclaredTarget (..)
  , observeInventory
  , validateDeclaredTarget
  , defaultDeclaredTarget
  ) where

import Amoebius.Cluster.Kind (KindFilesystemLayout (..), nodeContainerName)
import Amoebius.Host.Context
import Amoebius.Host.Ensure
import Data.Aeson
import Data.ByteString.Lazy qualified as ByteString
import Data.ByteString.Lazy.Char8 qualified as ByteString.Char8
import Data.Foldable (traverse_)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Word (Word64)
import GHC.Generics (Generic)
import System.Exit (ExitCode (..))
import Text.Read (readMaybe)

data ObservedInventory = ObservedInventory
  { inventoryNodeName :: Text
  , inventoryNodeUid :: Text
  , inventoryCpuMillis :: Word64
  , inventoryMemoryBytes :: Word64
  , inventoryEphemeralBytes :: Word64
  , inventoryPodSlots :: Word64
  , inventoryCurrentPods :: Word64
  , inventoryPodCidr :: Text
  , inventoryRemainingCniSlots :: Word64
  , inventoryCsiAttachmentLimits :: Map Text Word64
  , inventoryCurrentUniquePvcs :: Word64
  , inventoryFilesystemLayout :: Text
  , inventoryNodefsIdentity :: Text
  , inventoryContainerdRoots :: Text
  , inventoryImagePullPolicy :: Text
  , inventoryResidentImages :: [Text]
  , inventoryResidentContentDigests :: [Text]
  , inventoryResidentSnapshots :: [Text]
  , inventoryAddonPods :: [Text]
  , inventoryPodCommitments :: [ObservedPodCommitment]
  , inventoryMappedFileEntries :: [Text]
  , inventoryMappedFileCurrentBytes :: Word64
  , inventoryMappedFileTransitionBytes :: Word64
  , inventoryMappedFileMounts :: [Text]
  , inventoryNodefsCommittedBytes :: Word64
  , inventoryBackingIdentities :: [ObservedBackingIdentity]
  , inventoryHostRuntime :: Text
  , inventoryHostRuntimeImages :: [Text]
  , inventoryHostRuntimeContainers :: [Text]
  , inventoryHostRuntimeStorage :: [Text]
  , inventoryCsiCurrentAttachments :: Map Text Word64
  , inventoryDurableBackingPools :: [Text]
  , inventoryNativeHostCachePools :: [Text]
  , inventoryAcceleratorOffering :: Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

data ObservedContainerCommitment = ObservedContainerCommitment
  { commitmentContainer :: Text
  , commitmentImage :: Text
  , commitmentCpuRequest :: Text
  , commitmentCpuLimit :: Text
  , commitmentMemoryRequest :: Text
  , commitmentMemoryLimit :: Text
  , commitmentEphemeralRequest :: Text
  , commitmentEphemeralLimit :: Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

data ObservedPodCommitment = ObservedPodCommitment
  { commitmentPodIdentity :: Text
  , commitmentPodUid :: Text
  , commitmentOwner :: Text
  , commitmentRestartPolicy :: Text
  , commitmentHostNetwork :: Bool
  , commitmentContainers :: [ObservedContainerCommitment]
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

data ObservedBackingIdentity = ObservedBackingIdentity
  { backingRole :: Text
  , backingPath :: Text
  , backingFilesystem :: Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

data DeclaredTarget = DeclaredTarget
  { declaredCpuMillis :: Word64
  , declaredMemoryBytes :: Word64
  , declaredEphemeralBytes :: Word64
  , declaredPodSlots :: Word64
  , declaredCsiAttachments :: Map Text Word64
  , declaredAcceleratorOffering :: Text
  , declaredFilesystemLayout :: Text
  , declaredImagePullPolicy :: Text
  }
  deriving stock (Eq, Show)

data InventoryError
  = InventoryCommandFailed Text
  | InventoryDecodeFailed Text
  | DeclaredCpuExceedsObserved
  | DeclaredMemoryExceedsObserved
  | DeclaredEphemeralExceedsObserved
  | DeclaredPodSlotsExceedObserved
  | DeclaredCsiAttachExceedsObserved
  | DeclaredAcceleratorMismatch
  | DeclaredFilesystemLayoutMismatch
  | DeclaredImagePullPolicyMismatch
  | UnknownCommitment Text
  | MappedFileDemandExceedsNodefs Word64 Word64
  | AcceleratorLeakIntoLinuxCpu Text
  deriving stock (Eq, Show)

newtype NodeList = NodeList [Node]
instance FromJSON NodeList where parseJSON = withObject "NodeList" $ \o -> NodeList <$> o .: "items"
data Node = Node {metadata :: Metadata, spec :: NodeSpec, status :: NodeStatus}
instance FromJSON Node where parseJSON = withObject "Node" $ \o -> Node <$> o .: "metadata" <*> o .: "spec" <*> o .: "status"
data Metadata = Metadata {name :: Text, uid :: Text}
instance FromJSON Metadata where parseJSON = withObject "Metadata" $ \o -> Metadata <$> o .: "name" <*> o .: "uid"
newtype NodeSpec = NodeSpec {podCidr :: Maybe Text}
instance FromJSON NodeSpec where parseJSON = withObject "NodeSpec" $ \o -> NodeSpec <$> o .:? "podCIDR"
data NodeStatus = NodeStatus {allocatable :: Map Text Text, images :: Maybe [NodeImage]}
instance FromJSON NodeStatus where parseJSON = withObject "NodeStatus" $ \o -> NodeStatus <$> o .: "allocatable" <*> o .:? "images"
data NodeImage = NodeImage {names :: [Text]}
instance FromJSON NodeImage where parseJSON = withObject "NodeImage" $ \o -> NodeImage <$> o .: "names"
newtype PodList = PodList [Pod]
instance FromJSON PodList where parseJSON = withObject "PodList" $ \o -> PodList <$> o .: "items"
data Pod = Pod PodMetadata PodSpec
instance FromJSON Pod where parseJSON = withObject "Pod" $ \o -> Pod <$> o .: "metadata" <*> o .: "spec"
data PodMetadata = PodMetadata Text Text Text [OwnerReference]
instance FromJSON PodMetadata where parseJSON = withObject "PodMetadata" $ \o -> PodMetadata <$> o .: "name" <*> o .:? "namespace" .!= "default" <*> o .: "uid" <*> o .:? "ownerReferences" .!= []
data OwnerReference = OwnerReference Text Text
instance FromJSON OwnerReference where parseJSON = withObject "OwnerReference" $ \o -> OwnerReference <$> o .: "kind" <*> o .: "name"
data PodSpec = PodSpec Bool [PodVolume] [PodContainer] Text
instance FromJSON PodSpec where parseJSON = withObject "PodSpec" $ \o -> PodSpec <$> o .:? "hostNetwork" .!= False <*> o .:? "volumes" .!= [] <*> o .: "containers" <*> o .:? "restartPolicy" .!= "Always"
data PodContainer = PodContainer Text Text ContainerResources
instance FromJSON PodContainer where parseJSON = withObject "PodContainer" $ \o -> PodContainer <$> o .: "name" <*> o .: "image" <*> o .:? "resources" .!= ContainerResources mempty mempty
data ContainerResources = ContainerResources (Map Text Text) (Map Text Text)
instance FromJSON ContainerResources where parseJSON = withObject "ContainerResources" $ \o -> ContainerResources <$> o .:? "requests" .!= mempty <*> o .:? "limits" .!= mempty
newtype PodVolume = PodVolume (Maybe Text)
instance FromJSON PodVolume where
  parseJSON = withObject "PodVolume" $ \o -> do
    claim <- o .:? "persistentVolumeClaim"
    pure (PodVolume (pvcClaimName <$> claim))
newtype PvcSource = PvcSource {pvcClaimName :: Text}
instance FromJSON PvcSource where parseJSON = withObject "PvcSource" $ \o -> PvcSource <$> o .: "claimName"
newtype CsiNodeList = CsiNodeList [CsiNode]
instance FromJSON CsiNodeList where parseJSON = withObject "CsiNodeList" $ \o -> CsiNodeList <$> o .: "items"
newtype CsiNode = CsiNode [CsiDriver]
instance FromJSON CsiNode where
  parseJSON = withObject "CsiNode" $ \o -> do
    nodeSpec <- o .: "spec"
    CsiNode <$> nodeSpec .:? "drivers" .!= []
data CsiDriver = CsiDriver {csiDriverName :: Text, csiDriverCount :: Maybe Word64}
instance FromJSON CsiDriver where
  parseJSON = withObject "CsiDriver" $ \o -> do
    driverName <- o .: "name"
    driverAllocatable <- o .:? "allocatable"
    pure (CsiDriver driverName (csiCount <$> driverAllocatable))
newtype CsiAllocatable = CsiAllocatable {csiCount :: Word64}
instance FromJSON CsiAllocatable where parseJSON = withObject "CsiAllocatable" $ \o -> CsiAllocatable <$> o .: "count"
newtype VolumeAttachmentList = VolumeAttachmentList [VolumeAttachment]
instance FromJSON VolumeAttachmentList where parseJSON = withObject "VolumeAttachmentList" $ \o -> VolumeAttachmentList <$> o .: "items"
newtype VolumeAttachment = VolumeAttachment Text
instance FromJSON VolumeAttachment where
  parseJSON = withObject "VolumeAttachment" $ \o -> do
    attachmentSpec <- o .: "spec"
    VolumeAttachment <$> attachmentSpec .: "attacher"

defaultDeclaredTarget :: DeclaredTarget
defaultDeclaredTarget = DeclaredTarget 1000 (1024 * 1024 * 1024) (1024 * 1024 * 1024) 16 Map.empty "none" "Unified" "Serial"

observeInventory :: BinaryContext -> KindFilesystemLayout -> IO (Either InventoryError ObservedInventory)
observeInventory context expectedLayout = do
  nodeResult <- runTool (contextKubectl context) ["--kubeconfig", contextKubeconfig context, "get", "nodes", "-o", "json"]
  podResult <- runTool (contextKubectl context) ["--kubeconfig", contextKubeconfig context, "get", "pods", "-A", "-o", "json"]
  csiResult <- runTool (contextKubectl context) ["--kubeconfig", contextKubeconfig context, "get", "csinodes.storage.k8s.io", "-o", "json"]
  attachmentResult <- runTool (contextKubectl context) ["--kubeconfig", contextKubeconfig context, "get", "volumeattachments.storage.k8s.io", "-o", "json"]
  rootsResult <- runTool (contextDocker context) ["exec", nodeContainerName, "containerd", "config", "dump"]
  contentResult <- runTool (contextDocker context) ["exec", nodeContainerName, "/usr/local/bin/ctr", "--namespace", "k8s.io", "content", "list", "--quiet"]
  snapshotsResult <- runTool (contextDocker context) ["exec", nodeContainerName, "/usr/local/bin/ctr", "--namespace", "k8s.io", "snapshots", "list"]
  hostRuntimeResult <- runTool (contextDocker context) ["info", "--format", "{{.ServerVersion}} {{.Driver}} {{.DockerRootDir}}"]
  hostImagesResult <- runTool (contextDocker context) ["image", "ls", "--no-trunc", "--digests", "--format", "{{.ID}}\t{{.Digest}}\t{{.Repository}}:{{.Tag}}\t{{.Size}}"]
  hostContainersResult <- runTool (contextDocker context) ["ps", "-a", "--no-trunc", "--size", "--format", "{{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Size}}"]
  hostStorageResult <- runTool (contextDocker context) ["system", "df", "-v"]
  hostMountsResult <- runTool (contextDocker context) ["inspect", "--format", "{{range .Mounts}}{{.Source}}=>{{.Destination}};{{end}}", nodeContainerName]
  acceleratorResult <- runTool (contextDocker context) ["inspect", "--format", "{{json .HostConfig.DeviceRequests}}|{{json .HostConfig.Devices}}", nodeContainerName]
  nodefsResult <- runTool (contextDocker context) ["exec", nodeContainerName, "stat", "-f", "-c", "%i:%S:%b", "/var/lib/kubelet"]
  imagefsResult <- runTool (contextDocker context) ["exec", nodeContainerName, "stat", "-f", "-c", "%i:%S:%b", "/var/lib/containerd"]
  snapshotfsResult <- runTool (contextDocker context) ["exec", nodeContainerName, "stat", "-f", "-c", "%i:%S:%b", "/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs"]
  nodefsBackingResult <- runTool (contextDocker context) ["exec", nodeContainerName, "findmnt", "-bno", "SOURCE,FSTYPE,SIZE,AVAIL,TARGET", "-T", "/var/lib/kubelet"]
  imagefsBackingResult <- runTool (contextDocker context) ["exec", nodeContainerName, "findmnt", "-bno", "SOURCE,FSTYPE,SIZE,AVAIL,TARGET", "-T", "/var/lib/containerd"]
  snapshotBackingResult <- runTool (contextDocker context) ["exec", nodeContainerName, "findmnt", "-bno", "SOURCE,FSTYPE,SIZE,AVAIL,TARGET", "-T", "/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs"]
  mappedFilesResult <- runTool (contextDocker context)
    [ "exec", nodeContainerName, "/usr/bin/find", "/var/lib/kubelet/pods"
    , "(", "-type", "f", "-o", "-type", "l", ")"
    , "-path", "*/volumes/kubernetes.io~*/*", "-printf", "%y\t%p\t%s\n"
    ]
  mappedMountsResult <- runTool (contextDocker context) ["exec", nodeContainerName, "findmnt", "-bno", "SOURCE,FSTYPE,SIZE,AVAIL,TARGET"]
  nodefsUsageResult <- runTool (contextDocker context) ["exec", nodeContainerName, "du", "-sb", "/var/lib/kubelet"]
  pure $ do
    requireSuccess "nodes" nodeResult
    requireSuccess "pods" podResult
    requireSuccess "csinodes" csiResult
    requireSuccess "volumeattachments" attachmentResult
    requireSuccess "containerd-config" rootsResult
    requireSuccess "containerd-content" contentResult
    requireSuccess "containerd-snapshots" snapshotsResult
    requireSuccess "host-runtime" hostRuntimeResult
    requireSuccess "host-runtime-images" hostImagesResult
    requireSuccess "host-runtime-containers" hostContainersResult
    requireSuccess "host-runtime-storage" hostStorageResult
    requireSuccess "host-runtime-mounts" hostMountsResult
    requireSuccess "accelerator-boundary" acceleratorResult
    requireSuccess "nodefs-mount" nodefsResult
    requireSuccess "imagefs-mount" imagefsResult
    requireSuccess "snapshotfs-mount" snapshotfsResult
    requireSuccess "nodefs-backing" nodefsBackingResult
    requireSuccess "imagefs-backing" imagefsBackingResult
    requireSuccess "snapshotfs-backing" snapshotBackingResult
    requireSuccess "mapped-files" mappedFilesResult
    requireSuccess "mapped-mounts" mappedMountsResult
    requireSuccess "nodefs-usage" nodefsUsageResult
    NodeList nodes <- decodeResult "nodes" (toolStdout nodeResult)
    PodList pods <- decodeResult "pods" (toolStdout podResult)
    CsiNodeList csiNodes <- decodeResult "csinodes" (toolStdout csiResult)
    VolumeAttachmentList attachments <- decodeResult "volumeattachments" (toolStdout attachmentResult)
    node <- case nodes of
      [one] -> Right one
      _ -> Left (InventoryDecodeFailed "expected-exactly-one-node")
    cpu <- quantityCpu (lookupQuantity "cpu" node)
    memory <- quantityBytes (lookupQuantity "memory" node)
    ephemeral <- quantityBytes (lookupQuantity "ephemeral-storage" node)
    slots <- quantityNatural (lookupQuantity "pods" node)
    cidr <- maybe (Left (InventoryDecodeFailed "missing-pod-cidr")) Right (podCidr (spec node))
    cniAddresses <- cidrAddressCount cidr
    csiLimits <- csiLimitMap csiNodes
    let current = fromIntegral (length pods)
        podRemaining = if slots >= current then slots - current else 0
        cniConsumers = fromIntegral (length [() | Pod _ (PodSpec hostNetwork _ _ _) <- pods, not hostNetwork])
        usableCniAddresses = if cniAddresses >= 2 then cniAddresses - 2 else 0
        cniRemaining = if usableCniAddresses >= cniConsumers then usableCniAddresses - cniConsumers else 0
        remaining = min podRemaining cniRemaining
        imageNames = concatMap names (maybe [] id (images (status node)))
        addons = [namespace <> "/" <> pod | Pod (PodMetadata pod namespace _ _) _ <- pods]
        pvcClaims = Set.fromList
          [ namespace <> "/" <> claim
          | Pod (PodMetadata _ namespace _ _) (PodSpec _ volumes _ _) <- pods
          , PodVolume (Just claim) <- volumes
          ]
        attachmentCounts = Map.fromListWith (+) [(attacher, 1) | VolumeAttachment attacher <- attachments]
        podCommitments = map renderPodCommitment pods
        contents = filter (not . Text.null) (Text.lines (Text.strip (decodeUtf8Lazy (toolStdout contentResult))))
        snapshots = drop 1 (filter (not . Text.null) (Text.lines (Text.strip (decodeUtf8Lazy (toolStdout snapshotsResult)))))
        nodefsIdentity = Text.strip (decodeUtf8Lazy (toolStdout nodefsResult))
        imagefsIdentity = Text.strip (decodeUtf8Lazy (toolStdout imagefsResult))
        snapshotfsIdentity = Text.strip (decodeUtf8Lazy (toolStdout snapshotfsResult))
        observedLayout = if nodefsIdentity == imagefsIdentity then "Unified" else "SplitRuntime"
        expectedLayoutText = case expectedLayout of
          KindUnified -> "Unified"
          KindSplitRuntime -> "SplitRuntime"
          KindSplitImage -> "SplitImage"
        mappedEntries = filter (not . Text.null) (Text.lines (Text.strip (decodeUtf8Lazy (toolStdout mappedFilesResult))))
        mappedCurrent = sum (map mappedEntryBytes mappedEntries)
        mappedTransition = sum (map mappedTransitionEntryBytes mappedEntries)
        mappedMounts = filter (Text.isInfixOf "/var/lib/kubelet/pods") (Text.lines (decodeUtf8Lazy (toolStdout mappedMountsResult)))
        nodefsCommitted = firstNumericField (decodeUtf8Lazy (toolStdout nodefsUsageResult))
        deviceProjection = Text.strip (decodeUtf8Lazy (toolStdout acceleratorResult))
        hostMountProjection = Text.strip (decodeUtf8Lazy (toolStdout hostMountsResult))
        hostRuntime = Text.intercalate ";" [Text.strip (decodeUtf8Lazy (toolStdout hostRuntimeResult)), "mounts=" <> hostMountProjection]
        backingIdentities =
          [ ObservedBackingIdentity "nodefs" "/var/lib/kubelet" (Text.strip (decodeUtf8Lazy (toolStdout nodefsBackingResult)))
          , ObservedBackingIdentity "image-content" "/var/lib/containerd" (Text.strip (decodeUtf8Lazy (toolStdout imagefsBackingResult)))
          , ObservedBackingIdentity "image-snapshots" "/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs" (Text.strip (decodeUtf8Lazy (toolStdout snapshotBackingResult)))
          ]
    traverse_ validatePodCommitment podCommitments
    if nodefsCommitted < mappedTransition
      then Left (MappedFileDemandExceedsNodefs mappedTransition nodefsCommitted)
      else Right ()
    if deviceProjection `elem` ["null|[]", "[]|[]", "null|null"]
      then Right ()
      else Left (AcceleratorLeakIntoLinuxCpu deviceProjection)
    if observedLayout /= expectedLayoutText
      then Left (DeclaredFilesystemLayoutMismatch)
      else Right ()
    Right ObservedInventory
      { inventoryNodeName = name (metadata node)
      , inventoryNodeUid = uid (metadata node)
      , inventoryCpuMillis = cpu
      , inventoryMemoryBytes = memory
      , inventoryEphemeralBytes = ephemeral
      , inventoryPodSlots = slots
      , inventoryCurrentPods = current
      , inventoryPodCidr = cidr
      , inventoryRemainingCniSlots = remaining
      , inventoryCsiAttachmentLimits = csiLimits
      , inventoryCurrentUniquePvcs = fromIntegral (Set.size pvcClaims)
      , inventoryFilesystemLayout = observedLayout
      , inventoryNodefsIdentity = Text.intercalate ";" ["nodefs=" <> nodefsIdentity, "imagefs=" <> imagefsIdentity, "snapshotfs=" <> snapshotfsIdentity]
      , inventoryContainerdRoots = Text.strip (decodeUtf8Lazy (toolStdout rootsResult))
      , inventoryImagePullPolicy = "Serial"
      , inventoryResidentImages = imageNames
      , inventoryResidentContentDigests = contents
      , inventoryResidentSnapshots = snapshots
      , inventoryAddonPods = addons
      , inventoryPodCommitments = podCommitments
      , inventoryMappedFileEntries = mappedEntries
      , inventoryMappedFileCurrentBytes = mappedCurrent
      , inventoryMappedFileTransitionBytes = mappedTransition
      , inventoryMappedFileMounts = mappedMounts
      , inventoryNodefsCommittedBytes = nodefsCommitted
      , inventoryBackingIdentities = backingIdentities
      , inventoryHostRuntime = hostRuntime
      , inventoryHostRuntimeImages = nonEmptyLines hostImagesResult
      , inventoryHostRuntimeContainers = nonEmptyLines hostContainersResult
      , inventoryHostRuntimeStorage = nonEmptyLines hostStorageResult
      , inventoryCsiCurrentAttachments = attachmentCounts
      , inventoryDurableBackingPools = []
      , inventoryNativeHostCachePools = []
      , inventoryAcceleratorOffering = "none"
      }
 where
 lookupQuantity key node = maybe (Left (InventoryDecodeFailed ("missing-" <> key))) Right (Map.lookup key (allocatable (status node)))

renderPodCommitment :: Pod -> ObservedPodCommitment
renderPodCommitment (Pod (PodMetadata pod namespace podUid owners) (PodSpec hostNetwork _ containers restartPolicy)) =
  ObservedPodCommitment
    { commitmentPodIdentity = namespace <> "/" <> pod
    , commitmentPodUid = podUid
    , commitmentOwner = case owners of
        [] -> "static-or-unowned"
        values -> Text.intercalate "," [ownerKind <> "/" <> ownerName | OwnerReference ownerKind ownerName <- values]
    , commitmentRestartPolicy = restartPolicy
    , commitmentHostNetwork = hostNetwork
    , commitmentContainers = map renderContainer containers
    }
 where
  renderContainer (PodContainer container image (ContainerResources requests limits)) =
    ObservedContainerCommitment
      { commitmentContainer = container
      , commitmentImage = image
      , commitmentCpuRequest = resource "cpu" requests
      , commitmentCpuLimit = resource "cpu" limits
      , commitmentMemoryRequest = resource "memory" requests
      , commitmentMemoryLimit = resource "memory" limits
      , commitmentEphemeralRequest = resource "ephemeral-storage" requests
      , commitmentEphemeralLimit = resource "ephemeral-storage" limits
      }
  resource key values = Map.findWithDefault "" key values

validatePodCommitment :: ObservedPodCommitment -> Either InventoryError ()
validatePodCommitment pod
  | null (commitmentContainers pod) = Left (UnknownCommitment (commitmentPodIdentity pod <> ":no-containers"))
  | otherwise = traverse_ validateContainer (commitmentContainers pod)
 where
  validateContainer container
    | any Text.null
        [ commitmentImage container
        , commitmentCpuRequest container
        , commitmentCpuLimit container
        , commitmentMemoryRequest container
        , commitmentMemoryLimit container
        , commitmentEphemeralRequest container
        , commitmentEphemeralLimit container
        ] = Left (UnknownCommitment (commitmentPodIdentity pod <> "/" <> commitmentContainer container))
    | otherwise = Right ()

nonEmptyLines :: ToolResult -> [Text]
nonEmptyLines = filter (not . Text.null) . Text.lines . Text.strip . decodeUtf8Lazy . toolStdout

mappedEntryBytes :: Text -> Word64
mappedEntryBytes row = case Text.splitOn "\t" row of
  [_kind, _path, bytes] -> either (const 0) id (parseWord bytes)
  _ -> 0

mappedTransitionEntryBytes :: Text -> Word64
mappedTransitionEntryBytes row = case Text.splitOn "\t" row of
  [kind, _path, bytes] ->
    let observed = either (const 0) id (parseWord bytes)
    in if kind == "f" then observed * 2 else observed
  _ -> 0

firstNumericField :: Text -> Word64
firstNumericField source = case Text.words source of
  value : _ -> either (const 0) id (parseWord value)
  [] -> 0

requireSuccess :: Text -> ToolResult -> Either InventoryError ()
requireSuccess label result = case toolExitCode result of
  ExitSuccess -> Right ()
  ExitFailure _ -> Left (InventoryCommandFailed label)

decodeResult :: FromJSON value => Text -> ByteString.ByteString -> Either InventoryError value
decodeResult label source = case eitherDecode source of
  Left problem -> Left (InventoryDecodeFailed (label <> ":" <> Text.pack problem))
  Right value -> Right value

decodeUtf8Lazy :: ByteString.ByteString -> Text
decodeUtf8Lazy = Text.pack . ByteString.Char8.unpack

quantityCpu :: Either InventoryError Text -> Either InventoryError Word64
quantityCpu source = do
  value <- source
  if "m" `Text.isSuffixOf` value
    then parseWord (Text.dropEnd 1 value)
    else (* 1000) <$> parseWord value

quantityBytes :: Either InventoryError Text -> Either InventoryError Word64
quantityBytes source = do
  value <- source
  let units = [("Ki", 1024), ("Mi", 1024 ^ (2 :: Int)), ("Gi", 1024 ^ (3 :: Int)), ("Ti", 1024 ^ (4 :: Int))]
  case [(Text.dropEnd (Text.length suffix) value, multiplier) | (suffix, multiplier) <- units, suffix `Text.isSuffixOf` value] of
    (number, multiplier) : _ -> (* multiplier) <$> parseWord number
    [] -> parseWord value

quantityNatural :: Either InventoryError Text -> Either InventoryError Word64
quantityNatural source = source >>= parseWord

parseWord :: Text -> Either InventoryError Word64
parseWord value = maybe (Left (InventoryDecodeFailed ("quantity:" <> value))) Right (readMaybe (Text.unpack value))

cidrAddressCount :: Text -> Either InventoryError Word64
cidrAddressCount cidr = case Text.splitOn "/" cidr of
  [_address, prefixText] -> do
    prefix <- parseWord prefixText
    if prefix > 32
      then Left (InventoryDecodeFailed ("unsupported-pod-cidr:" <> cidr))
      else Right (2 ^ (32 - prefix))
  _ -> Left (InventoryDecodeFailed ("pod-cidr:" <> cidr))

csiLimitMap :: [CsiNode] -> Either InventoryError (Map Text Word64)
csiLimitMap nodes = Map.fromList <$> traverse requireCount [driver | CsiNode drivers <- nodes, driver <- drivers]
 where
  requireCount driver = case csiDriverCount driver of
    Nothing -> Left (InventoryDecodeFailed ("unknown-csi-attachment-limit:" <> csiDriverName driver))
    Just count -> Right (csiDriverName driver, count)

validateDeclaredTarget :: DeclaredTarget -> ObservedInventory -> Either InventoryError ()
validateDeclaredTarget declared observed
  | declaredCpuMillis declared > inventoryCpuMillis observed = Left DeclaredCpuExceedsObserved
  | declaredMemoryBytes declared > inventoryMemoryBytes observed = Left DeclaredMemoryExceedsObserved
  | declaredEphemeralBytes declared > inventoryEphemeralBytes observed = Left DeclaredEphemeralExceedsObserved
  | declaredPodSlots declared > inventoryRemainingCniSlots observed = Left DeclaredPodSlotsExceedObserved
  | any exceedsCsi (Map.toList (declaredCsiAttachments declared)) = Left DeclaredCsiAttachExceedsObserved
  | declaredAcceleratorOffering declared /= inventoryAcceleratorOffering observed = Left DeclaredAcceleratorMismatch
  | declaredFilesystemLayout declared /= inventoryFilesystemLayout observed = Left DeclaredFilesystemLayoutMismatch
  | declaredImagePullPolicy declared /= inventoryImagePullPolicy observed = Left DeclaredImagePullPolicyMismatch
  | otherwise = Right ()
 where
  exceedsCsi (driver, required) = required > Map.findWithDefault 0 driver (inventoryCsiAttachmentLimits observed)
