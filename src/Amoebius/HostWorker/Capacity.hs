{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.HostWorker.Capacity
  ( AppleHostSupply (..)
  , MetalOwnerDemand (..)
  , AppleHostDemand (..)
  , ProvisionedMetalOwnerDemand
  , ProvisionedAppleHostPlan
  , AppleProvisionError (..)
  , provisionAppleHost
  , provisionedDisk
  , provisionedMetalEpochPeak
  , provisionedHostMemoryDebit
  , provisionedHostDiskDebit
  ) where

import Amoebius.Host.Substrate (Substrate (..))
import Amoebius.Substrate.Lima
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Word (Word64)

data AppleHostSupply = AppleHostSupply
  { supplySubstrate :: Substrate
  , supplyArchitecture :: Text
  , supplyCpuCores :: Word64
  , supplyUnifiedMemoryBytes :: Word64
  , supplyDiskBytes :: Word64
  , supplyMetalProfile :: Text
  }
  deriving stock (Eq, Show)

data MetalOwnerDemand = MetalOwnerDemand
  { metalProfile :: Text
  , metalSourceBytes :: Map Text Word64
  , metalWorkloadBytes :: Map Text Word64
  , metalResidentClassBounds :: Map Text Word64
  , metalRunningClassBounds :: Map Text Word64
  , metalCoexistenceEpochs :: [[Text]]
  }
  deriving stock (Eq, Show)

data AppleHostDemand = AppleHostDemand
  { demandVmCpuCores :: Word64
  , demandVmMemoryBytes :: Word64
  , demandSystemHeadroomBytes :: Word64
  , demandWorkerCpuCores :: Word64
  , demandWorkerRuntimeBytes :: Word64
  , demandVmDisk :: VmDiskCarve
  , demandDurableBackingBytes :: Word64
  , demandHostCacheBytes :: Word64
  , demandMetalOwner :: MetalOwnerDemand
  }
  deriving stock (Eq, Show)

newtype ProvisionedMetalOwnerDemand = ProvisionedMetalOwnerDemand Word64
  deriving stock (Eq, Show)

data ProvisionedAppleHostPlan = ProvisionedAppleHostPlan
  { internalDisk :: ProvisionedVmDiskCarve
  , internalMetal :: ProvisionedMetalOwnerDemand
  , internalMemoryDebit :: Word64
  , internalDiskDebit :: Word64
  }
  deriving stock (Eq, Show)

data AppleProvisionError
  = AppleSubstrateRequired
  | AppleArm64Required
  | MissingCapabilityAppleMetal
  | MetalProfileMismatch
  | MetalKeyDomainMismatch
  | MetalPolicyDomainMismatch
  | MetalEpochDomainMismatch
  | HostCpuShort
  | HostMemoryShort
  | HostDiskShort
  | VmDiskProvisionError VmDiskError
  | CapacityArithmeticOverflow
  deriving stock (Eq, Show)

provisionAppleHost :: AppleHostSupply -> AppleHostDemand -> Either AppleProvisionError ProvisionedAppleHostPlan
provisionAppleHost supply demand = do
  if supplySubstrate supply == Apple then Right () else Left AppleSubstrateRequired
  if supplyArchitecture supply == "arm64" then Right () else Left AppleArm64Required
  if supplyMetalProfile supply == "" then Left MissingCapabilityAppleMetal else Right ()
  let metal = demandMetalOwner demand
  if supplyMetalProfile supply == metalProfile metal then Right () else Left MetalProfileMismatch
  let sourceKeys = Map.keysSet (metalSourceBytes metal)
#ifdef APPLE_METAL_HOST_DAEMON_OMIT_METAL_WORK_ITEM_MUTANT
      workloadKeys = Set.delete "jit" (Map.keysSet (metalWorkloadBytes metal))
#else
      workloadKeys = Map.keysSet (metalWorkloadBytes metal)
#endif
  if sourceKeys == workloadKeys then Right () else Left MetalKeyDomainMismatch
  if Map.keysSet (metalResidentClassBounds metal) == sourceKeys
      && Map.keysSet (metalRunningClassBounds metal) == sourceKeys
    then Right () else Left MetalPolicyDomainMismatch
  if all (\epoch -> not (null epoch) && Set.fromList epoch `Set.isSubsetOf` sourceKeys)
      (metalCoexistenceEpochs metal)
      && Set.unions (fmap Set.fromList (metalCoexistenceEpochs metal)) == sourceKeys
    then Right () else Left MetalEpochDomainMismatch
  disk <- either (Left . VmDiskProvisionError) Right (provisionVmDisk (demandVmDisk demand))
  cpuDebit <- checkedSum [demandVmCpuCores demand, demandWorkerCpuCores demand]
  if cpuDebit <= supplyCpuCores supply then Right () else Left HostCpuShort
  epochPeak <- metalEpochPeak metal
  memoryDebit <- hostMemoryDebit demand epochPeak
  if memoryDebit <= supplyUnifiedMemoryBytes supply then Right () else Left HostMemoryShort
  diskDebit <- checkedSum [provisionedBytes disk, demandDurableBackingBytes demand, demandHostCacheBytes demand]
  if diskDebit <= supplyDiskBytes supply then Right () else Left HostDiskShort
  Right (ProvisionedAppleHostPlan disk (ProvisionedMetalOwnerDemand epochPeak) memoryDebit diskDebit)

metalEpochPeak :: MetalOwnerDemand -> Either AppleProvisionError Word64
metalEpochPeak demand = do
  values <- traverse epochBytes (metalCoexistenceEpochs demand)
  case values of
    [] -> Left MetalEpochDomainMismatch
#ifdef APPLE_METAL_HOST_DAEMON_FAVORABLE_METAL_EPOCH_MUTANT
    _ -> Right (minimum values)
#else
    _ -> Right (maximum values)
#endif
 where
  epochBytes classes = do
    classBytes <- traverse
      (\key -> checkedSum
        [ Map.findWithDefault 0 key (metalSourceBytes demand)
        , Map.findWithDefault 0 key (metalWorkloadBytes demand)
        ])
      (Set.toList (Set.fromList classes))
    checkedSum classBytes

hostMemoryDebit :: AppleHostDemand -> Word64 -> Either AppleProvisionError Word64
hostMemoryDebit demand epochPeak = checkedSum
#ifdef APPLE_METAL_HOST_DAEMON_DROP_METAL_OVERLAP_DEBIT_MUTANT
  [demandVmMemoryBytes demand, demandSystemHeadroomBytes demand, demandWorkerRuntimeBytes demand]
#else
  [demandVmMemoryBytes demand, demandSystemHeadroomBytes demand, demandWorkerRuntimeBytes demand, epochPeak]
#endif

checkedSum :: [Word64] -> Either AppleProvisionError Word64
checkedSum = foldl step (Right 0)
 where
  step current next = do
    value <- current
    if maxBound - value < next then Left CapacityArithmeticOverflow else Right (value + next)

provisionedDisk :: ProvisionedAppleHostPlan -> ProvisionedVmDiskCarve
provisionedDisk = internalDisk

provisionedMetalEpochPeak :: ProvisionedAppleHostPlan -> Word64
provisionedMetalEpochPeak plan = case internalMetal plan of ProvisionedMetalOwnerDemand value -> value

provisionedHostMemoryDebit :: ProvisionedAppleHostPlan -> Word64
provisionedHostMemoryDebit = internalMemoryDebit

provisionedHostDiskDebit :: ProvisionedAppleHostPlan -> Word64
provisionedHostDiskDebit = internalDiskDebit
