{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Node-local OCI/image and physical-disk accounting.  Logical roles are
-- resolved through one closed filesystem layout and grouped by concrete
-- backing identity before capacity is checked.
module Amoebius.Capacity.NodeLocalStorage
  ( LocalBacking (..)
  , ContainerRuntimeModel (..)
  , KubeletFilesystemLayout (..)
  , NodeStorageRole (..)
  , NodeStorageComponent (..)
  , ImageArtifactRequirement (..)
  , ImageMetadataCatalog (..)
  , NodeImageStorageDemand (..)
  , ProvisionedNodeImageStorageDemand (..)
  , ProvisionedNodeLocalStorage (..)
  , DiskExtentKind (..)
  , NamedDiskCarve (..)
  , VmDiskCarve (..)
  , ProvisionedVmDiskCarve (..)
  , PhysicalDiskPartition (..)
  , ProvisionedPhysicalDiskPartition (..)
  , NodeLocalStorageError (..)
  , provisionNodeImageStorage
  , fitLayoutComponents
  , validateFilesystemLayoutObservation
  , provisionPhysicalDiskPartition
  ) where

import Amoebius.Capacity.Storage
  ( BackingAllocationPolicy
  , FilesystemPresentation
  , presentBytes
  , roundAllocation
  )
import Control.DeepSeq (NFData)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data LocalBacking = LocalBacking
  { localBackingId :: Text
  , localBackingCapacityBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ContainerRuntimeModel = ContainerdV1 | ContainerdV2
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data KubeletFilesystemLayout
  = Unified LocalBacking
  | SplitRuntime LocalBacking LocalBacking
  | SplitImage ContainerRuntimeModel LocalBacking LocalBacking
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data NodeStorageRole = KubeletNodefs | CriRuntimeRoot | ImageStorage
  deriving stock (Eq, Enum, Generic, Ord, Show)
  deriving anyclass (NFData)

data NodeStorageComponent = NodeStorageComponent
  { nodeStorageComponentId :: Text
  , nodeStorageComponentRole :: NodeStorageRole
  , nodeStorageComponentBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ImageArtifactRequirement = ImageArtifactRequirement
  { imageArtifactId :: Text
  , imageTargetPlatform :: Text
  , imageIndexDigest :: Text
  , imageManifestDigest :: Text
  , imageConfigDigest :: Text
  , imageLayerDigests :: [Text]
  , imageSnapshotChains :: [Text]
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ImageMetadataCatalog = ImageMetadataCatalog
  { imageStoredObjects :: Map Text Natural
  , imagePlatformManifests :: Map (Text, Text) Text
  , imageManifestConfigs :: Map Text Text
  , imageManifestLayers :: Map Text [Text]
  , imageSnapshotBytes :: Map Text Natural
  , imageStorageModels :: Set Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data NodeImageStorageDemand = NodeImageStorageDemand
  { nodeImageStorageModel :: Text
  , nodeImageArtifacts :: [ImageArtifactRequirement]
  , nodeResidentImages :: Set Text
  , nodePullConcurrency :: Natural
  , nodePullWorkspaceBytes :: Map Text Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedNodeImageStorageDemand = ProvisionedNodeImageStorageDemand
  { provisionedImageContent :: Map Text Natural
  , provisionedImageSnapshots :: Map Text Natural
  , provisionedImageWorkspaceBytes :: Natural
  , provisionedImageComponents :: [NodeStorageComponent]
  , provisionedImagePeakBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedNodeLocalStorage = ProvisionedNodeLocalStorage
  { provisionedBackingDebits :: Map Text Natural
  , provisionedBackingResiduals :: Map Text Natural
  , provisionedComponentBacking :: Map Text Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data DiskExtentKind = PhysicalRawExtent | VmGuestUsableExtent Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data NamedDiskCarve = NamedDiskCarve
  { namedDiskCarveId :: Text
  , namedDiskCarveKind :: DiskExtentKind
  , namedDiskCarveUsableBytes :: Natural
  , namedDiskCarvePresentation :: FilesystemPresentation
  , namedDiskCarveAllocation :: BackingAllocationPolicy
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data VmDiskCarve = VmDiskCarve
  { vmDiskCarveId :: Text
  , vmGuestSystemBytes :: Natural
  , vmDiskPresentation :: FilesystemPresentation
  , vmDiskAllocation :: BackingAllocationPolicy
  , vmGuestCarves :: [NamedDiskCarve]
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedVmDiskCarve = ProvisionedVmDiskCarve
  { provisionedVmDiskId :: Text
  , provisionedVmRequiredUsableBytes :: Natural
  , provisionedVmBytes :: Natural
  , provisionedVmChildDebits :: Map Text Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PhysicalDiskPartition = PhysicalDiskPartition
  { physicalDiskPartitionId :: Text
  , physicalDiskAllocatableRawBytes :: Natural
  , physicalDiskSystemReserveRawBytes :: Natural
  , physicalDiskVms :: [VmDiskCarve]
  , physicalDiskRawCarves :: [NamedDiskCarve]
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedPhysicalDiskPartition = ProvisionedPhysicalDiskPartition
  { provisionedPhysicalDiskId :: Text
  , provisionedPhysicalDiskRequiredBytes :: Natural
  , provisionedPhysicalDiskResidualBytes :: Natural
  , provisionedPhysicalVms :: Map Text ProvisionedVmDiskCarve
  , provisionedPhysicalRawChildren :: Map Text Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data NodeLocalStorageError
  = FilesystemLayoutMismatch Text
  | ImageMetadataMissing Text
  | ImageMetadataConflict Text
  | SplitImageUnsupported ContainerRuntimeModel
  | NodeLocalStorageOverBacking Text Natural Natural
  | NodeStorageComponentDuplicate Text
  | DiskBackingAlias Text
  | DiskExtentUnitMismatch Text DiskExtentKind
  | VmGuestStorageOvercommit Text Natural Natural
  | PhysicalDiskOvercommit Text Natural Natural
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

provisionNodeImageStorage
  :: ImageMetadataCatalog
  -> NodeImageStorageDemand
  -> Either NodeLocalStorageError ProvisionedNodeImageStorageDemand
provisionNodeImageStorage catalog demand
  | nodeImageStorageModel demand `Set.notMember` imageStorageModels catalog =
      Left (ImageMetadataMissing (nodeImageStorageModel demand))
  | otherwise = do
      objectIds <- fmap concat (mapM (validateArtifact catalog) (nodeImageArtifacts demand))
      content <- exactExtents (imageStoredObjects catalog) objectIds
      let snapshotIds = concatMap imageSnapshotChains (nodeImageArtifacts demand)
      snapshots <- exactExtents (imageSnapshotBytes catalog) snapshotIds
      let missingImages =
            [ imageArtifactId artifact
            | artifact <- nodeImageArtifacts demand
            , imageArtifactId artifact `Set.notMember` nodeResidentImages demand
            ]
          workspaces =
            reverse
              ( sortOn id
                  [ Map.findWithDefault 0 imageId (nodePullWorkspaceBytes demand)
                  | imageId <- missingImages
                  ]
              )
          workspace = sum (takeNatural (nodePullConcurrency demand) workspaces)
          contentBytes = sum (Map.elems content)
          snapshotBytes = sum (Map.elems snapshots)
          components =
            [ NodeStorageComponent ("image-object:" <> identity) ImageStorage bytes
            | (identity, bytes) <- Map.toList content
            ]
              <> [ NodeStorageComponent ("snapshot:" <> identity) ImageStorage bytes
                 | (identity, bytes) <- Map.toList snapshots
                 ]
              <> [NodeStorageComponent "image-pull-workspace" ImageStorage workspace]
      pure
        ProvisionedNodeImageStorageDemand
          { provisionedImageContent = content
          , provisionedImageSnapshots = snapshots
          , provisionedImageWorkspaceBytes = workspace
          , provisionedImageComponents = components
          , provisionedImagePeakBytes = contentBytes + snapshotBytes + workspace
          }

fitLayoutComponents
  :: KubeletFilesystemLayout
  -> [NodeStorageComponent]
  -> Either NodeLocalStorageError ProvisionedNodeLocalStorage
fitLayoutComponents layout components = do
  validateLayout layout
  componentMap <- uniqueComponents components
  routed <- mapM (routeComponent layout) (Map.elems componentMap)
  let debit = Map.fromListWith (+) [(localBackingId backing, nodeStorageComponentBytes component) | (component, backing) <- routed]
      capacities = Map.fromList [(localBackingId backing, localBackingCapacityBytes backing) | backing <- layoutBackings layout]
      assignments = Map.fromList [(nodeStorageComponentId component, localBackingId backing) | (component, backing) <- routed]
  mapM_ (fitDebit capacities) (Map.toList debit)
  pure
    ProvisionedNodeLocalStorage
      { provisionedBackingDebits = debit
      , provisionedBackingResiduals = Map.mapWithKey (residual debit) capacities
      , provisionedComponentBacking = assignments
      }

validateFilesystemLayoutObservation
  :: KubeletFilesystemLayout
  -> KubeletFilesystemLayout
  -> Either NodeLocalStorageError ()
validateFilesystemLayoutObservation declared observed = do
  validateLayout declared
  validateLayout observed
  if fmap localBackingId (layoutBackings declared) == fmap localBackingId (layoutBackings observed)
    then Right ()
    else Left (FilesystemLayoutMismatch "observed filesystem roles differ from the declared layout")

provisionPhysicalDiskPartition
  :: PhysicalDiskPartition
  -> Either NodeLocalStorageError ProvisionedPhysicalDiskPartition
provisionPhysicalDiskPartition partition = do
  ensureUniqueCarves partition
  provisionedVms <- mapM provisionVm (physicalDiskVms partition)
  rawChildren <- mapM provisionRaw (physicalDiskRawCarves partition)
  let vmMap = Map.fromList [(provisionedVmDiskId vm, vm) | vm <- provisionedVms]
      rawMap = Map.fromList rawChildren
      required =
        physicalDiskSystemReserveRawBytes partition
          + sum (fmap provisionedVmBytes provisionedVms)
          + sum (Map.elems rawMap)
      available = physicalDiskAllocatableRawBytes partition
  if required > available
    then Left (PhysicalDiskOvercommit (physicalDiskPartitionId partition) required available)
    else
      Right
        ProvisionedPhysicalDiskPartition
          { provisionedPhysicalDiskId = physicalDiskPartitionId partition
          , provisionedPhysicalDiskRequiredBytes = required
          , provisionedPhysicalDiskResidualBytes = available - required
          , provisionedPhysicalVms = vmMap
          , provisionedPhysicalRawChildren = rawMap
          }

validateArtifact :: ImageMetadataCatalog -> ImageArtifactRequirement -> Either NodeLocalStorageError [Text]
validateArtifact catalog artifact = do
  let joinKey = (imageIndexDigest artifact, imageTargetPlatform artifact)
  manifest <- requireMap (imagePlatformManifests catalog) joinKey (imageArtifactId artifact <> ":platform-manifest")
  if manifest /= imageManifestDigest artifact
    then Left (ImageMetadataConflict (imageArtifactId artifact <> ":manifest"))
    else Right ()
  config <- requireMap (imageManifestConfigs catalog) manifest (imageArtifactId artifact <> ":config")
  if config /= imageConfigDigest artifact
    then Left (ImageMetadataConflict (imageArtifactId artifact <> ":config"))
    else Right ()
  layers <- requireMap (imageManifestLayers catalog) manifest (imageArtifactId artifact <> ":layers")
  if layers /= imageLayerDigests artifact
    then Left (ImageMetadataConflict (imageArtifactId artifact <> ":layers"))
    else Right ()
  pure (imageIndexDigest artifact : manifest : config : layers)

requireMap :: Ord key => Map key value -> key -> Text -> Either NodeLocalStorageError value
requireMap values key label = case Map.lookup key values of
  Nothing -> Left (ImageMetadataMissing label)
  Just value -> Right value

exactExtents :: Map Text Natural -> [Text] -> Either NodeLocalStorageError (Map Text Natural)
exactExtents catalog identities = go Map.empty identities
 where
  go result remaining = case remaining of
    [] -> Right result
    identity : rest -> case Map.lookup identity catalog of
      Nothing -> Left (ImageMetadataMissing identity)
      Just bytes -> case Map.lookup identity result of
        Nothing -> go (Map.insert identity bytes result) rest
        Just prior
          | prior == bytes -> go result rest
          | otherwise -> Left (ImageMetadataConflict identity)

validateLayout :: KubeletFilesystemLayout -> Either NodeLocalStorageError ()
validateLayout layout = case layout of
  Unified _ -> Right ()
  SplitRuntime nodefs runtime
    | localBackingId nodefs == localBackingId runtime -> Left (FilesystemLayoutMismatch "SplitRuntime aliases nodefs and runtime")
    | otherwise -> Right ()
  SplitImage model nodefs imagefs
    | model == ContainerdV1 -> Left (SplitImageUnsupported model)
    | localBackingId nodefs == localBackingId imagefs -> Left (FilesystemLayoutMismatch "SplitImage aliases nodefs and imagefs")
    | otherwise -> Right ()

uniqueComponents :: [NodeStorageComponent] -> Either NodeLocalStorageError (Map Text NodeStorageComponent)
uniqueComponents components = go Map.empty (sortOn nodeStorageComponentId components)
 where
  go result remaining = case remaining of
    [] -> Right result
    component : rest
      | Map.member (nodeStorageComponentId component) result -> Left (NodeStorageComponentDuplicate (nodeStorageComponentId component))
      | otherwise -> go (Map.insert (nodeStorageComponentId component) component result) rest

routeComponent
  :: KubeletFilesystemLayout
  -> NodeStorageComponent
  -> Either NodeLocalStorageError (NodeStorageComponent, LocalBacking)
routeComponent layout component = Right (component, routeRole layout (nodeStorageComponentRole component))

routeRole :: KubeletFilesystemLayout -> NodeStorageRole -> LocalBacking
routeRole layout role = case layout of
  Unified nodefs -> nodefs
  SplitRuntime nodefs runtime -> case role of
    KubeletNodefs -> nodefs
    CriRuntimeRoot -> runtime
    ImageStorage -> runtime
  SplitImage _ nodefs imagefs -> case role of
    KubeletNodefs -> nodefs
    CriRuntimeRoot -> nodefs
    ImageStorage -> imagefs

layoutBackings :: KubeletFilesystemLayout -> [LocalBacking]
layoutBackings layout = case layout of
  Unified nodefs -> [nodefs]
  SplitRuntime nodefs runtime -> [nodefs, runtime]
  SplitImage _ nodefs imagefs -> [nodefs, imagefs]

fitDebit :: Map Text Natural -> (Text, Natural) -> Either NodeLocalStorageError ()
fitDebit capacities (identity, required) =
  let available = Map.findWithDefault 0 identity capacities
   in if required <= available
        then Right ()
        else Left (NodeLocalStorageOverBacking identity required available)

residual :: Map Text Natural -> Text -> Natural -> Natural
residual debit identity capacity = capacity - Map.findWithDefault 0 identity debit

ensureUniqueCarves :: PhysicalDiskPartition -> Either NodeLocalStorageError ()
ensureUniqueCarves partition = go Set.empty identities
 where
  identities =
    fmap namedDiskCarveId (physicalDiskRawCarves partition)
      <> concatMap (fmap namedDiskCarveId . vmGuestCarves) (physicalDiskVms partition)
      <> fmap vmDiskCarveId (physicalDiskVms partition)
  go seen remaining = case remaining of
    [] -> Right ()
    identity : rest
      | identity `Set.member` seen -> Left (DiskBackingAlias identity)
      | otherwise -> go (Set.insert identity seen) rest

provisionVm :: VmDiskCarve -> Either NodeLocalStorageError ProvisionedVmDiskCarve
provisionVm vm = do
  children <- mapM provisionGuest (vmGuestCarves vm)
  let childMap = Map.fromList children
      required = vmGuestSystemBytes vm + sum (Map.elems childMap)
      presented = presentBytes (vmDiskPresentation vm) required
      provisioned = roundAllocation (vmDiskAllocation vm) presented
  pure
    ProvisionedVmDiskCarve
      { provisionedVmDiskId = vmDiskCarveId vm
      , provisionedVmRequiredUsableBytes = required
      , provisionedVmBytes = provisioned
      , provisionedVmChildDebits = childMap
      }
 where
  provisionGuest carve = case namedDiskCarveKind carve of
    VmGuestUsableExtent vmId
      | vmId == vmDiskCarveId vm -> Right (namedDiskCarveId carve, namedDiskCarveUsableBytes carve)
      | otherwise -> Left (DiskExtentUnitMismatch (namedDiskCarveId carve) (namedDiskCarveKind carve))
    PhysicalRawExtent -> Left (DiskExtentUnitMismatch (namedDiskCarveId carve) PhysicalRawExtent)

provisionRaw :: NamedDiskCarve -> Either NodeLocalStorageError (Text, Natural)
provisionRaw carve = case namedDiskCarveKind carve of
  PhysicalRawExtent ->
    Right
      ( namedDiskCarveId carve
      , roundAllocation
          (namedDiskCarveAllocation carve)
          (presentBytes (namedDiskCarvePresentation carve) (namedDiskCarveUsableBytes carve))
      )
  kind -> Left (DiskExtentUnitMismatch (namedDiskCarveId carve) kind)

takeNatural :: Natural -> [a] -> [a]
takeNatural count values
  | count == 0 = []
  | otherwise = case values of
      [] -> []
      value : rest -> value : takeNatural (count - 1) rest
