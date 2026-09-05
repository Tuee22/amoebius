{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Whole-device accelerator ownership and per-coexistence-epoch residency
-- placement against net allocatable VRAM.
module Amoebius.Capacity.Accelerator
  ( AcceleratorFamily (..)
  , InterconnectRequirement (..)
  , AcceleratorDevice (..)
  , AcceleratorOffering (..)
  , VramShardAssignment (..)
  , ResidencyPlacement (..)
  , AcceleratorResidencyDemand (..)
  , AcceleratorCoexistenceEpoch (..)
  , AcceleratorDemand (..)
  , ProvisionedAcceleratorEpoch (..)
  , ProvisionedAccelerator (..)
  , AcceleratorError (..)
  , provisionAccelerator
  , validateExclusiveAcceleratorOwners
  ) where

import Amoebius.Capacity.Phase29Mutation (phase29MutationTargets)
import Control.DeepSeq (NFData)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data AcceleratorFamily = CudaFamily | AppleMetalFamily
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data InterconnectRequirement = NoPeerRequirement | FullyConnectedPeerAccess | FullyConnectedNvLink
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data AcceleratorDevice = AcceleratorDevice
  { acceleratorDeviceId :: Text
  , acceleratorDeviceFamily :: AcceleratorFamily
  , acceleratorDeviceProfile :: Text
  , acceleratorRawVramBytes :: Natural
  , acceleratorDriverRuntimeReserveBytes :: Natural
  , acceleratorAllocatableVramBytes :: Natural
  , acceleratorPeerDevices :: Set Text
  , acceleratorNvLinkDevices :: Set Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype AcceleratorOffering = AcceleratorOffering
  { acceleratorOfferingDevices :: Map Text AcceleratorDevice
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data VramShardAssignment = VramShardAssignment
  { vramShardId :: Text
  , vramShardDevice :: Text
  , vramShardBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ResidencyPlacement
  = Unsharded
  | ReplicatedPerDevice
  | Sharded [VramShardAssignment]
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data AcceleratorResidencyDemand = AcceleratorResidencyDemand
  { acceleratorResidencyId :: Text
  , acceleratorResidencySource :: Text
  , acceleratorResidencyWorkloadClass :: Text
  , acceleratorResidencyBytes :: Natural
  , acceleratorResidencyPlacement :: ResidencyPlacement
  , acceleratorResidencyInterconnect :: InterconnectRequirement
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data AcceleratorCoexistenceEpoch = AcceleratorCoexistenceEpoch
  { acceleratorEpochId :: Text
  , acceleratorEpochResidencies :: [AcceleratorResidencyDemand]
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data AcceleratorDemand
  = NoAcceleratorDemand
  | AcceleratorDemand
      { acceleratorDemandOwner :: Text
      , acceleratorDemandFamily :: AcceleratorFamily
      , acceleratorDemandProfile :: Text
      , acceleratorDemandDeviceIds :: Set Text
      , acceleratorDemandDeviceCount :: Natural
      , acceleratorDemandSources :: Set Text
      , acceleratorDemandWorkloadClasses :: Set Text
      , acceleratorDemandEpochs :: [AcceleratorCoexistenceEpoch]
      }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedAcceleratorEpoch = ProvisionedAcceleratorEpoch
  { provisionedAcceleratorEpochId :: Text
  , provisionedVramByDevice :: Map Text Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedAccelerator = ProvisionedAccelerator
  { provisionedAcceleratorOwner :: Text
  , provisionedAcceleratorDevices :: Set Text
  , provisionedAcceleratorEpochs :: [ProvisionedAcceleratorEpoch]
  , provisionedAcceleratorPeakByDevice :: Map Text Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data AcceleratorError
  = AcceleratorFamilyAbsent AcceleratorFamily
  | AcceleratorDeviceCountShortage Natural Natural
  | AcceleratorResidencyFit Text Natural Natural
  | AcceleratorNetAllocatableViolation Text Natural Natural Natural
  | AcceleratorProfileMismatch Text Text
  | AcceleratorSharedDevice Text Text Text
  | AcceleratorDomainMismatch Text (Set Text) (Set Text)
  | AcceleratorShardInvalid Text
  | AcceleratorInterconnectMissing Text Text
  | AcceleratorDeviceMissing Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

provisionAccelerator
  :: AcceleratorOffering
  -> AcceleratorDemand
  -> Either AcceleratorError ProvisionedAccelerator
provisionAccelerator _ NoAcceleratorDemand =
  Right (ProvisionedAccelerator "none" Set.empty [] Map.empty)
provisionAccelerator offering demand@AcceleratorDemand {} = mutateAcceleratorResult $ do
  devices <- selectedDevices offering (acceleratorDemandDeviceIds demand)
  validateDevices demand devices
  validateDomains demand
  epochs <- mapM (placeEpoch devices) (acceleratorDemandEpochs demand)
  let peak = foldl maxPerDevice Map.empty (fmap provisionedVramByDevice epochs)
  pure
    ProvisionedAccelerator
      { provisionedAcceleratorOwner = acceleratorDemandOwner demand
      , provisionedAcceleratorDevices = acceleratorDemandDeviceIds demand
      , provisionedAcceleratorEpochs = epochs
      , provisionedAcceleratorPeakByDevice = peak
      }

validateExclusiveAcceleratorOwners :: [(Text, Set Text)] -> Either AcceleratorError ()
validateExclusiveAcceleratorOwners allocations = mutateOwnerResult (go Map.empty (sortOn fst allocations))
 where
  go owners remaining = case remaining of
    [] -> Right ()
    (owner, devices) : rest -> do
      updated <- foldDevices owner owners (Set.toList devices)
      go updated rest
  foldDevices owner owners remaining = case remaining of
    [] -> Right owners
    device : rest -> case Map.lookup device owners of
      Nothing -> foldDevices owner (Map.insert device owner owners) rest
      Just prior
        | prior == owner -> foldDevices owner owners rest
        | otherwise -> Left (AcceleratorSharedDevice device prior owner)

mutateAcceleratorResult
  :: Either AcceleratorError ProvisionedAccelerator
  -> Either AcceleratorError ProvisionedAccelerator
mutateAcceleratorResult outcome = case outcome of
  Left AcceleratorFamilyAbsent {}
    | phase29MutationTargets "cuda-family-absent" -> changed
  Left AcceleratorDeviceCountShortage {}
    | phase29MutationTargets "cuda-device-count" -> changed
  Left AcceleratorResidencyFit {}
    | phase29MutationTargets "cuda-unsharded-fragmentation" -> changed
  Left AcceleratorShardInvalid {}
    | phase29MutationTargets "cuda-shard-byte-sum" -> changed
  Left AcceleratorNetAllocatableViolation {}
    | phase29MutationTargets "cuda-vram-reserve" -> changed
  Left AcceleratorProfileMismatch {}
    | phase29MutationTargets "metal-profile" -> changed
  Left AcceleratorInterconnectMissing {}
    | phase29MutationTargets "accelerator-peer-graph" -> changed
  _ -> outcome
 where
  changed = Left (AcceleratorDeviceMissing "phase-29 changed-production accelerator mutation")

mutateOwnerResult :: Either AcceleratorError () -> Either AcceleratorError ()
mutateOwnerResult outcome = case outcome of
  Left AcceleratorSharedDevice {}
    | phase29MutationTargets "accelerator-shared-owner" ->
        Left (AcceleratorDeviceMissing "phase-29 changed-production owner mutation")
  _ -> outcome

selectedDevices :: AcceleratorOffering -> Set Text -> Either AcceleratorError (Map Text AcceleratorDevice)
selectedDevices offering identities = go Map.empty (Set.toList identities)
 where
  go result remaining = case remaining of
    [] -> Right result
    identity : rest -> case Map.lookup identity (acceleratorOfferingDevices offering) of
      Nothing -> Left (AcceleratorDeviceMissing identity)
      Just device -> go (Map.insert identity device result) rest

validateDevices :: AcceleratorDemand -> Map Text AcceleratorDevice -> Either AcceleratorError ()
validateDevices NoAcceleratorDemand _ = Right ()
validateDevices demand@AcceleratorDemand {} devices = do
  let familyMatches = [device | device <- Map.elems devices, acceleratorDeviceFamily device == acceleratorDemandFamily demand]
      requested = acceleratorDemandDeviceCount demand
      available = fromIntegral (length familyMatches)
  if null familyMatches
    then Left (AcceleratorFamilyAbsent (acceleratorDemandFamily demand))
    else Right ()
  if available < requested || fromIntegral (Map.size devices) /= requested
    then Left (AcceleratorDeviceCountShortage requested available)
    else Right ()
  mapM_ validateDevice (Map.elems devices)
 where
  validateDevice device
    | acceleratorDeviceFamily device /= acceleratorDemandFamily demand = Left (AcceleratorFamilyAbsent (acceleratorDemandFamily demand))
    | acceleratorDeviceProfile device /= acceleratorDemandProfile demand =
        Left (AcceleratorProfileMismatch (acceleratorDemandProfile demand) (acceleratorDeviceProfile device))
    | acceleratorDriverRuntimeReserveBytes device + acceleratorAllocatableVramBytes device > acceleratorRawVramBytes device =
        Left
          ( AcceleratorNetAllocatableViolation
              (acceleratorDeviceId device)
              (acceleratorRawVramBytes device)
              (acceleratorDriverRuntimeReserveBytes device)
              (acceleratorAllocatableVramBytes device)
          )
    | otherwise = Right ()

validateDomains :: AcceleratorDemand -> Either AcceleratorError ()
validateDomains NoAcceleratorDemand = Right ()
validateDomains demand@AcceleratorDemand {} = do
  let residencies = concatMap acceleratorEpochResidencies (acceleratorDemandEpochs demand)
      sources = Set.fromList (fmap acceleratorResidencySource residencies)
      workloads = Set.fromList (fmap acceleratorResidencyWorkloadClass residencies)
  if sources /= acceleratorDemandSources demand
    then Left (AcceleratorDomainMismatch "source" (acceleratorDemandSources demand) sources)
    else Right ()
  if workloads /= acceleratorDemandWorkloadClasses demand
    then Left (AcceleratorDomainMismatch "workload-class" (acceleratorDemandWorkloadClasses demand) workloads)
    else Right ()

placeEpoch :: Map Text AcceleratorDevice -> AcceleratorCoexistenceEpoch -> Either AcceleratorError ProvisionedAcceleratorEpoch
placeEpoch devices epoch = do
  debit <- placeResidencies devices Map.empty (acceleratorEpochResidencies epoch)
  mapM_ (fitDevice devices) (Map.toList debit)
  pure (ProvisionedAcceleratorEpoch (acceleratorEpochId epoch) debit)

placeResidencies
  :: Map Text AcceleratorDevice
  -> Map Text Natural
  -> [AcceleratorResidencyDemand]
  -> Either AcceleratorError (Map Text Natural)
placeResidencies devices debit remaining = case remaining of
  [] -> Right debit
  residency : rest -> do
    validateInterconnect devices residency
    updated <- case acceleratorResidencyPlacement residency of
      Unsharded -> placeUnsharded devices debit residency
      ReplicatedPerDevice ->
        Right
          ( foldl
              (\current identity -> Map.insertWith (+) identity (acceleratorResidencyBytes residency) current)
              debit
              (Map.keys devices)
          )
      Sharded shards -> placeShards devices debit residency shards
    placeResidencies devices updated rest

placeUnsharded
  :: Map Text AcceleratorDevice
  -> Map Text Natural
  -> AcceleratorResidencyDemand
  -> Either AcceleratorError (Map Text Natural)
placeUnsharded devices debit residency = case fitting of
  [] ->
    Left
      ( AcceleratorResidencyFit
          (acceleratorResidencyId residency)
          (acceleratorResidencyBytes residency)
          (maximumTotal (fmap remaining (Map.elems devices)))
      )
  identity : _ -> Right (Map.insertWith (+) identity (acceleratorResidencyBytes residency) debit)
 where
  remaining device = acceleratorAllocatableVramBytes device - min (acceleratorAllocatableVramBytes device) (Map.findWithDefault 0 (acceleratorDeviceId device) debit)
  fitting =
    [ acceleratorDeviceId device
    | device <- sortOn acceleratorDeviceId (Map.elems devices)
    , acceleratorResidencyBytes residency <= remaining device
    ]

placeShards
  :: Map Text AcceleratorDevice
  -> Map Text Natural
  -> AcceleratorResidencyDemand
  -> [VramShardAssignment]
  -> Either AcceleratorError (Map Text Natural)
placeShards devices debit residency shards
  | Set.size (Set.fromList (fmap vramShardId shards)) /= length shards = Left (AcceleratorShardInvalid (acceleratorResidencyId residency <> ":duplicate-shard"))
  | sum (fmap vramShardBytes shards) /= acceleratorResidencyBytes residency = Left (AcceleratorShardInvalid (acceleratorResidencyId residency <> ":byte-sum"))
  | any (\shard -> Map.notMember (vramShardDevice shard) devices) shards = Left (AcceleratorShardInvalid (acceleratorResidencyId residency <> ":device"))
  | otherwise =
      Right
        ( foldl
            (\current shard -> Map.insertWith (+) (vramShardDevice shard) (vramShardBytes shard) current)
            debit
            shards
        )

validateInterconnect :: Map Text AcceleratorDevice -> AcceleratorResidencyDemand -> Either AcceleratorError ()
validateInterconnect devices residency = case acceleratorResidencyInterconnect residency of
  NoPeerRequirement -> Right ()
  FullyConnectedPeerAccess -> fullyConnected acceleratorPeerDevices
  FullyConnectedNvLink -> fullyConnected acceleratorNvLinkDevices
 where
  identities = Map.keysSet devices
  fullyConnected project = mapM_ check (Map.elems devices)
   where
    check device =
      let required = Set.delete (acceleratorDeviceId device) identities
       in case Set.lookupMin (required `Set.difference` project device) of
            Nothing -> Right ()
            Just missing -> Left (AcceleratorInterconnectMissing (acceleratorDeviceId device) missing)

fitDevice :: Map Text AcceleratorDevice -> (Text, Natural) -> Either AcceleratorError ()
fitDevice devices (identity, required) = case Map.lookup identity devices of
  Nothing -> Left (AcceleratorDeviceMissing identity)
  Just device
    | required <= acceleratorAllocatableVramBytes device -> Right ()
    | otherwise -> Left (AcceleratorResidencyFit identity required (acceleratorAllocatableVramBytes device))

maxPerDevice :: Map Text Natural -> Map Text Natural -> Map Text Natural
maxPerDevice = Map.unionWith max

maximumTotal :: [Natural] -> Natural
maximumTotal values = foldl max 0 values
