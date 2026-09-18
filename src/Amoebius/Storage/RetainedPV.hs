{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Storage.RetainedPV
  ( VolumeAttachment (..)
  , DeclaredRetainedVolume (..)
  , RetainedPV (..)
  , RetainedClaimRef (..)
  , UniformClaimPlan (..)
  , RetainedInventoryError (..)
  , retainedLogicalIdentity
  , retainedMetadataName
  , retainedPvcName
  , planRetainedInventory
  , sanitizeClaimRefForRebind
  , retainedInventoryErrorReason
  ) where

import Amoebius.Capacity.Storage
import Amoebius.Capacity.StorageGeometry
import Control.DeepSeq (NFData)
import Data.Foldable (traverse_)
import Data.List (foldl')
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data VolumeAttachment = NodeLocal Text | Csi Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data DeclaredRetainedVolume = DeclaredRetainedVolume
  { retainedNamespace :: Text
  , retainedDemand :: DeclaredVolumeDemand
  , retainedAttachment :: VolumeAttachment
  , retainedPresentation :: FilesystemPresentation
  , retainedAllocation :: BackingAllocationPolicy
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data RetainedClaimRef = RetainedClaimRef
  { retainedClaimNamespace :: Text
  , retainedClaimName :: Text
  , retainedClaimUid :: Maybe Text
  , retainedClaimResourceVersion :: Maybe Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data RetainedPV = RetainedPV
  { retainedPvName :: Text
  , retainedPvLogicalIdentity :: Text
  , retainedPvClaimRef :: RetainedClaimRef
  , retainedPvCapacityBytes :: Natural
  , retainedPvRequiredUsableBytes :: Natural
  , retainedPvBacking :: BackingId
  , retainedPvAttachment :: VolumeAttachment
  , retainedPvPresentation :: FilesystemPresentation
  , retainedPvAllocation :: BackingAllocationPolicy
  , retainedPvReclaimPolicy :: Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data UniformClaimPlan = UniformClaimPlan
  { uniformRetainedPvs :: Map Text RetainedPV
  , uniformCapacityByTemplate :: Map (Text, Text, Text) Natural
  , uniformDebitByBacking :: Map BackingId Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RetainedInventoryError
  = InvalidRetainedIdentity Text
  | ConflictingRetainedIdentity Text
  | IncompatibleUniformClaimTemplate Text Text
  | DurableDemandExceedsBacking BackingId Natural Natural
  | RetainedProvisionError StorageError
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

retainedLogicalIdentity :: Text -> Text -> Natural -> Text
retainedLogicalIdentity namespace statefulSet ordinal = namespace <> "/" <> statefulSet <> "/pv_" <> decimal ordinal

retainedMetadataName :: Text -> Text -> Natural -> Text
retainedMetadataName namespace statefulSet ordinal = namespace <> "." <> statefulSet <> ".pv-" <> decimal ordinal

retainedPvcName :: StatefulSetClaimSlot -> Text
retainedPvcName claim = claimTemplate claim <> "-" <> claimStatefulSet claim <> "-" <> decimal (claimOrdinal claim)

planRetainedInventory
  :: Map BackingId Natural
  -> [DeclaredRetainedVolume]
  -> [DeclaredRetainedVolume]
  -> Either RetainedInventoryError UniformClaimPlan
planRetainedInventory observedBackings existing proposed = do
  indexed <- foldl' insertOne (Right Map.empty) (existing <> proposed)
  provisioned <- traverse provisionOne indexed
  let groups = Map.fromListWith (<>) [(groupKey row, [row]) | row <- Map.elems provisioned]
  traverse_ validateGroup groups
  let capacityByGroup = fmap groupCapacity groups
      debit = foldl' (debitGroup capacityByGroup) Map.empty (Map.elems provisioned)
  validateDebits observedBackings debit
  pvs <- traverse (renderOne capacityByGroup) provisioned
  pure (UniformClaimPlan pvs capacityByGroup debit)
 where
  insertOne accumulated row = do
    current <- accumulated
    identity <- identityOf row
    case Map.lookup identity current of
      Nothing -> Right (Map.insert identity row current)
      Just prior
        | prior == row -> Right current
        | otherwise -> Left (ConflictingRetainedIdentity identity)

data ProvisionedRetained = ProvisionedRetained
  { declaredRetained :: DeclaredRetainedVolume
  , provisionedRetained :: ProvisionedVolumeDemand
  }

provisionOne :: DeclaredRetainedVolume -> Either RetainedInventoryError ProvisionedRetained
provisionOne row = do
  provisioned <- either (Left . RetainedProvisionError) Right (provisionVolume (retainedDemand row))
  pure (ProvisionedRetained row provisioned)

identityOf :: DeclaredRetainedVolume -> Either RetainedInventoryError Text
identityOf row =
  let claim = volumeClaim (retainedDemand row)
      namespace = retainedNamespace row
      statefulSet = claimStatefulSet claim
      invalid = any Text.null [namespace, statefulSet, claimTemplate claim] || any (Text.any (`elem` ("/_" :: String))) [namespace, statefulSet]
   in if invalid
        then Left (InvalidRetainedIdentity (retainedLogicalIdentity namespace statefulSet (claimOrdinal claim)))
        else Right (retainedLogicalIdentity namespace statefulSet (claimOrdinal claim))

groupKey :: ProvisionedRetained -> (Text, Text, Text)
groupKey row =
  let claim = volumeClaim (retainedDemand (declaredRetained row))
   in (retainedNamespace (declaredRetained row), claimStatefulSet claim, claimTemplate claim)

validateGroup :: [ProvisionedRetained] -> Either RetainedInventoryError ()
validateGroup rows = case rows of
  [] -> Right ()
  first : rest ->
    let template = claimTemplate (volumeClaim (retainedDemand (declaredRetained first)))
        compatible row =
          retainedPresentation (declaredRetained row) == retainedPresentation (declaredRetained first)
            && retainedAllocation (declaredRetained row) == retainedAllocation (declaredRetained first)
     in if all compatible rest then Right () else Left (IncompatibleUniformClaimTemplate template "presentation/allocation mismatch")

groupCapacity :: [ProvisionedRetained] -> Natural
groupCapacity rows =
  maximumOrZero [provisionedBytes (provisionedRetained row) | row <- rows]

debitGroup
  :: Map (Text, Text, Text) Natural
  -> Map BackingId Natural
  -> ProvisionedRetained
  -> Map BackingId Natural
debitGroup capacities accumulated row =
  let owner = provisionedBacking (provisionedRetained row)
      bytes = Map.findWithDefault 0 (groupKey row) capacities
   in Map.insertWith (+) owner bytes accumulated

validateDebits :: Map BackingId Natural -> Map BackingId Natural -> Either RetainedInventoryError ()
validateDebits observed debit = traverse_ validate (Map.toList debit)
 where
  validate (owner, required) =
    let available = Map.findWithDefault 0 owner observed
     in if required <= available then Right () else Left (DurableDemandExceedsBacking owner required available)

renderOne :: Map (Text, Text, Text) Natural -> ProvisionedRetained -> Either RetainedInventoryError RetainedPV
renderOne capacities row = do
  identity <- identityOf (declaredRetained row)
  let declared = declaredRetained row
      demand = retainedDemand declared
      claim = volumeClaim demand
      capacity = Map.findWithDefault 0 (groupKey row) capacities
      required = geometryPhysicalBytes (provisionedGeometryWitness (provisionedRetained row))
      reclaim =
        "Retain"
  if capacity < required
    then Left (IncompatibleUniformClaimTemplate (claimTemplate claim) "uniform capacity below required usable bytes")
    else Right RetainedPV
      { retainedPvName = retainedMetadataName (retainedNamespace declared) (claimStatefulSet claim) (claimOrdinal claim)
      , retainedPvLogicalIdentity = identity
      , retainedPvClaimRef = RetainedClaimRef (retainedNamespace declared) (retainedPvcName claim) Nothing Nothing
      , retainedPvCapacityBytes = capacity
      , retainedPvRequiredUsableBytes = required
      , retainedPvBacking = provisionedBacking (provisionedRetained row)
      , retainedPvAttachment = retainedAttachment declared
      , retainedPvPresentation = retainedPresentation declared
      , retainedPvAllocation = retainedAllocation declared
      , retainedPvReclaimPolicy = reclaim
      }

sanitizeClaimRefForRebind :: RetainedClaimRef -> RetainedClaimRef
sanitizeClaimRefForRebind reference = reference {retainedClaimUid = Nothing, retainedClaimResourceVersion = Nothing}

retainedInventoryErrorReason :: RetainedInventoryError -> Text
retainedInventoryErrorReason problem = case problem of
  InvalidRetainedIdentity {} -> "invalid-retained-identity"
  ConflictingRetainedIdentity {} -> "conflicting-retained-identity"
  IncompatibleUniformClaimTemplate {} -> "uniform-claim-template-mismatch"
  DurableDemandExceedsBacking {} -> "durable-demand-exceeds-backing"
  RetainedProvisionError (StorageOverBacking _ _ _) -> "durable-demand-exceeds-backing after presentation/allocation"
  RetainedProvisionError _ -> "retained-volume-provision-failed"

maximumOrZero :: [Natural] -> Natural
maximumOrZero values = case values of
  [] -> 0
  _ -> maximum values

decimal :: Natural -> Text
decimal = Text.pack . show
