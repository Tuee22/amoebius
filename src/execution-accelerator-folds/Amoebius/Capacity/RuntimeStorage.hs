{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Structural kubelet/CRI metadata accounting for planned execution slots
-- and authenticated observed Pod UIDs.  The two identity domains are never
-- interchangeable.
module Amoebius.Capacity.RuntimeStorage
  ( RuntimeAccountingId (..)
  , RuntimeAccountingScope (..)
  , PodRuntimeMetadataSource (..)
  , KubeletRuntimeMetadataModel (..)
  , KubeletRuntimeMetadataDemand (..)
  , ProvisionedKubeletRuntimeMetadataDemand (..)
  , ProvisionedNodeRuntimeStorageAccounting (..)
  , RuntimeStorageError (..)
  , provisionKubeletRuntimeMetadata
  , provisionNodeRuntimeStorageAccounting
  ) where

import Amoebius.Capacity.NodeLocalStorage
  ( KubeletFilesystemLayout
  , NodeLocalStorageError (..)
  , NodeStorageComponent (..)
  , NodeStorageRole (..)
  , ProvisionedNodeImageStorageDemand (..)
  , ProvisionedNodeLocalStorage
  , fitLayoutComponents
  )
import Amoebius.Capacity.Phase29Mutation (phase29MutationTargets)
import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data RuntimeAccountingId
  = PlannedExecutionSlotId Text
  | ObservedPodUid Text Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data RuntimeAccountingScope
  = PlannedEpochScope Text (Set Text)
  | ObservedInventoryScope Text (Set Text)
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PodRuntimeMetadataSource = PodRuntimeMetadataSource
  { runtimeContainerIds :: Set Text
  , runtimeVolumeIds :: Set Text
  , runtimeMounts :: Set (Text, Text)
  , runtimeNetworkAttachments :: Set Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data KubeletRuntimeMetadataModel = KubeletRuntimeMetadataModel
  { metadataSandboxBytes :: Natural
  , metadataPodDirectoryBytes :: Natural
  , metadataRuntimeBytesPerContainer :: Natural
  , metadataKubeletBytesPerContainer :: Natural
  , metadataCniBytesPerAttachment :: Natural
  , metadataVolumeBytesPerVolume :: Natural
  , metadataMountBytesPerMount :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data KubeletRuntimeMetadataDemand = KubeletRuntimeMetadataDemand
  { runtimeAccountingId :: RuntimeAccountingId
  , runtimeMetadataModelVersion :: Text
  , runtimeMetadataSource :: PodRuntimeMetadataSource
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedKubeletRuntimeMetadataDemand = ProvisionedKubeletRuntimeMetadataDemand
  { provisionedRuntimeAccountingId :: RuntimeAccountingId
  , provisionedRuntimeModelVersion :: Text
  , provisionedRuntimeComponents :: [NodeStorageComponent]
  , provisionedRuntimeRoleSums :: Map NodeStorageRole Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedNodeRuntimeStorageAccounting = ProvisionedNodeRuntimeStorageAccounting
  { provisionedRuntimeScope :: RuntimeAccountingScope
  , provisionedRuntimeRows :: Map Text ProvisionedKubeletRuntimeMetadataDemand
  , provisionedRuntimeAndImageComponents :: [NodeStorageComponent]
  , provisionedRuntimeLayout :: ProvisionedNodeLocalStorage
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RuntimeStorageError
  = RuntimeMetadataModelMissing Text
  | RuntimeMetadataSourceInvalid Text
  | RuntimeAccountingDomainMismatch (Set Text) (Set Text)
  | RuntimeAccountingScopeMismatch RuntimeAccountingId
  | RuntimeComponentOwnershipMismatch Text
  | RuntimeNodeLocalError NodeLocalStorageError
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

provisionKubeletRuntimeMetadata
  :: Map Text KubeletRuntimeMetadataModel
  -> KubeletRuntimeMetadataDemand
  -> Either RuntimeStorageError ProvisionedKubeletRuntimeMetadataDemand
provisionKubeletRuntimeMetadata models demand = do
  model <- case Map.lookup (runtimeMetadataModelVersion demand) models of
    Nothing -> Left (RuntimeMetadataModelMissing (runtimeMetadataModelVersion demand))
    Just found -> Right found
  validateSource (runtimeMetadataSource demand)
  let prefix = accountingKey (runtimeAccountingId demand)
      source = runtimeMetadataSource demand
      components =
        [ component prefix "sandbox" CriRuntimeRoot (metadataSandboxBytes model)
        , component prefix "pod-directory" KubeletNodefs (metadataPodDirectoryBytes model)
        , component prefix "runtime-containers" CriRuntimeRoot (count (runtimeContainerIds source) * metadataRuntimeBytesPerContainer model)
        , component prefix "kubelet-containers" KubeletNodefs (count (runtimeContainerIds source) * metadataKubeletBytesPerContainer model)
        , component prefix "cni" KubeletNodefs (count (runtimeNetworkAttachments source) * metadataCniBytesPerAttachment model)
        , component prefix "volumes" KubeletNodefs (count (runtimeVolumeIds source) * metadataVolumeBytesPerVolume model)
        , component prefix "mounts" KubeletNodefs (count (runtimeMounts source) * metadataMountBytesPerMount model)
        ]
      roleSums = Map.fromListWith (+) [(nodeStorageComponentRole row, nodeStorageComponentBytes row) | row <- components]
  pure
    ProvisionedKubeletRuntimeMetadataDemand
      { provisionedRuntimeAccountingId = runtimeAccountingId demand
      , provisionedRuntimeModelVersion = runtimeMetadataModelVersion demand
      , provisionedRuntimeComponents = components
      , provisionedRuntimeRoleSums = roleSums
      }

provisionNodeRuntimeStorageAccounting
  :: Map Text KubeletRuntimeMetadataModel
  -> RuntimeAccountingScope
  -> KubeletFilesystemLayout
  -> [KubeletRuntimeMetadataDemand]
  -> ProvisionedNodeImageStorageDemand
  -> Either RuntimeStorageError ProvisionedNodeRuntimeStorageAccounting
provisionNodeRuntimeStorageAccounting models scope layout demands imageDemand = mutateRuntimeResult $ do
  let expected = scopeDomain scope
      observed = Set.fromList (fmap (accountingKey . runtimeAccountingId) demands)
  if expected /= observed
    then Left (RuntimeAccountingDomainMismatch expected observed)
    else Right ()
  mapM_ (validateScope scope . runtimeAccountingId) demands
  provisioned <- mapM (provisionKubeletRuntimeMetadata models) demands
  let rows = Map.fromList [(accountingKey (provisionedRuntimeAccountingId row), row) | row <- provisioned]
      runtimeComponents = concatMap provisionedRuntimeComponents provisioned
      imageComponents = provisionedImageComponents imageDemand
      allComponents = runtimeComponents <> imageComponents
  validateOwnership runtimeComponents imageComponents
  provisionedLayout <- mapNodeLocal (fitLayoutComponents layout allComponents)
  pure
    ProvisionedNodeRuntimeStorageAccounting
      { provisionedRuntimeScope = scope
      , provisionedRuntimeRows = rows
      , provisionedRuntimeAndImageComponents = allComponents
      , provisionedRuntimeLayout = provisionedLayout
      }

mutateRuntimeResult
  :: Either RuntimeStorageError ProvisionedNodeRuntimeStorageAccounting
  -> Either RuntimeStorageError ProvisionedNodeRuntimeStorageAccounting
mutateRuntimeResult outcome = case outcome of
  Left (RuntimeNodeLocalError (NodeLocalStorageOverBacking "nodefs" _ _))
    | phase29MutationTargets "runtime-nodefs" -> changed
  Left (RuntimeNodeLocalError (NodeLocalStorageOverBacking "runtime" _ _))
    | phase29MutationTargets "runtime-imagefs" -> changed
  Left RuntimeMetadataModelMissing {}
    | phase29MutationTargets "runtime-model" -> changed
  Left RuntimeAccountingDomainMismatch {}
    | phase29MutationTargets "runtime-scope-domain" -> changed
  _ -> outcome
 where
  changed = Left (RuntimeMetadataSourceInvalid "phase-29 changed-production runtime mutation")

validateSource :: PodRuntimeMetadataSource -> Either RuntimeStorageError ()
validateSource source
  | Set.null (runtimeContainerIds source) = Left (RuntimeMetadataSourceInvalid "container inventory is empty")
  | Set.null (runtimeNetworkAttachments source) = Left (RuntimeMetadataSourceInvalid "network attachment inventory is empty")
  | not (all mountResolves (Set.toList (runtimeMounts source))) = Left (RuntimeMetadataSourceInvalid "mount inventory has an unresolved endpoint")
  | otherwise = Right ()
 where
  mountResolves (container, volume) =
    container `Set.member` runtimeContainerIds source
      && volume `Set.member` runtimeVolumeIds source

validateScope :: RuntimeAccountingScope -> RuntimeAccountingId -> Either RuntimeStorageError ()
validateScope scope identity = case (scope, identity) of
  (PlannedEpochScope {}, PlannedExecutionSlotId _) -> Right ()
  (ObservedInventoryScope {}, ObservedPodUid _ witness)
    | not (Text.null witness) -> Right ()
    | otherwise -> Left (RuntimeAccountingScopeMismatch identity)
  _ -> Left (RuntimeAccountingScopeMismatch identity)

validateOwnership :: [NodeStorageComponent] -> [NodeStorageComponent] -> Either RuntimeStorageError ()
validateOwnership runtimeComponents imageComponents =
  let runtimeKeys = Set.fromList (fmap nodeStorageComponentId runtimeComponents)
      imageKeys = Set.fromList (fmap nodeStorageComponentId imageComponents)
   in if Set.null (Set.intersection runtimeKeys imageKeys)
        then Right ()
        else Left (RuntimeComponentOwnershipMismatch "runtime and image component domains overlap")

component :: Text -> Text -> NodeStorageRole -> Natural -> NodeStorageComponent
component prefix suffix role bytes = NodeStorageComponent (prefix <> ":" <> suffix) role bytes

scopeDomain :: RuntimeAccountingScope -> Set Text
scopeDomain scope = case scope of
  PlannedEpochScope _ identities -> identities
  ObservedInventoryScope _ identities -> identities

accountingKey :: RuntimeAccountingId -> Text
accountingKey identity = case identity of
  PlannedExecutionSlotId slot -> "planned:" <> slot
  ObservedPodUid uid _ -> "observed:" <> uid

count :: Set a -> Natural
count = fromIntegral . Set.size

mapNodeLocal :: Either NodeLocalStorageError value -> Either RuntimeStorageError value
mapNodeLocal outcome = case outcome of
  Left problem -> Left (RuntimeNodeLocalError problem)
  Right value -> Right value
