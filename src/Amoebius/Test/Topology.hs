{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Test.Topology
  ( TestSubstrate (..)
  , ResourceVector (..)
  , AcceleratorRequirement (..)
  , Allocation (..)
  , Fault (..)
  , Expectation (..)
  , TestTopology (..)
  , ProvisionedTestTopology
  , ProvisionError (..)
  , provisionTestTopology
  , provisionedTopology
  ) where

import Amoebius.Test.Credentials
import Data.Text (Text)
import Data.Word (Word64)

data TestSubstrate = TestLinuxCpu | TestLinuxCuda | TestApple | TestWindows
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data ResourceVector = ResourceVector
  { resourceCpuMillis :: Word64
  , resourceMemoryBytes :: Word64
  , resourceEphemeralBytes :: Word64
  , resourceDurableBytes :: Word64
  , resourceCacheBytes :: Word64
  , resourcePodSlots :: Word64
  , resourceIpSlots :: Word64
  , resourceCsiSlots :: Word64
  , resourceProviderQuota :: Word64
  }
  deriving stock (Eq, Show)

data AcceleratorRequirement = NoAccelerator | Accelerator Text
  deriving stock (Eq, Show)

data Allocation = Allocation
  { allocationId :: Text
  , allocationTestOwned :: Bool
  , allocationDurableBytes :: Word64
  }
  deriving stock (Eq, Ord, Show)

data Fault = KillWorker
  { faultTarget :: Text
  , faultSubscription :: Text
  }
  deriving stock (Eq, Ord, Show)

data Expectation = Expectation
  { expectationInvariant :: Text
  , expectationWitness :: Maybe Text
  }
  deriving stock (Eq, Ord, Show)

data TestTopology = TestTopology
  { topologySubstrate :: TestSubstrate
  , topologyCredential :: TestCredential
  , topologyAllocations :: [Allocation]
  , topologyFaults :: [Fault]
  , topologyExpectations :: [Expectation]
  , topologyTeardownRequired :: Bool
  , topologySupply :: ResourceVector
  , topologyDemand :: ResourceVector
  , topologyAcceleratorRequirement :: AcceleratorRequirement
  , topologyAcceleratorOffering :: Maybe Text
  }
  deriving stock (Eq, Show)

newtype ProvisionedTestTopology = ProvisionedTestTopology TestTopology
  deriving stock (Eq, Show)

data ProvisionError
  = TeardownRequired
  | FlaggedCredentialRequired
  | EmptyAllocationInventory
  | AllocationIdEmpty
  | TestOwnedTagRequired
  | CpuShort
  | MemoryShort
  | EphemeralShort
  | DurableShort
  | CacheShort
  | PodSlotsShort
  | IpSlotsShort
  | CsiSlotsShort
  | ProviderQuotaShort
  | MissingAcceleratorCapability
  | AcceleratorCapabilityMismatch
  | DelegatedFailoverRequired
  deriving stock (Eq, Show)

provisionTestTopology :: TestTopology -> Either ProvisionError ProvisionedTestTopology
provisionTestTopology topology = do
  if topologyTeardownRequired topology then Right () else Left TeardownRequired
  if credentialIsTestSimulation (topologyCredential topology) then Right () else Left FlaggedCredentialRequired
  if null (topologyAllocations topology) then Left EmptyAllocationInventory else Right ()
  if any ((== "") . allocationId) (topologyAllocations topology) then Left AllocationIdEmpty else Right ()
  if all allocationTestOwned (topologyAllocations topology) then Right () else Left TestOwnedTagRequired
  let supply = topologySupply topology
      demand = topologyDemand topology
  fit CpuShort resourceCpuMillis supply demand
  fit MemoryShort resourceMemoryBytes supply demand
  fit EphemeralShort resourceEphemeralBytes supply demand
  fit DurableShort resourceDurableBytes supply demand
  fit CacheShort resourceCacheBytes supply demand
  fit PodSlotsShort resourcePodSlots supply demand
  fit IpSlotsShort resourceIpSlots supply demand
  fit CsiSlotsShort resourceCsiSlots supply demand
  fit ProviderQuotaShort resourceProviderQuota supply demand
  case (topologyAcceleratorRequirement topology, topologyAcceleratorOffering topology) of
    (NoAccelerator, _) -> Right ()
    (Accelerator _, Nothing) -> Left MissingAcceleratorCapability
    (Accelerator expected, Just observed)
      | expected == observed -> Right ()
      | otherwise -> Left AcceleratorCapabilityMismatch
  let validFault (KillWorker _ subscription) =
#ifdef TEST_TOPOLOGY_DSL_WRONG_SUBSCRIPTION_MUTANT
        subscription == "wrong-subscription"
#else
        subscription == "test-topology-dsl-failover"
#endif
  if not (null (topologyFaults topology)) && all validFault (topologyFaults topology)
    then Right (ProvisionedTestTopology topology)
    else Left DelegatedFailoverRequired
 where
  fit failure axis supply demand
    | axis demand <= axis supply = Right ()
    | otherwise = Left failure

provisionedTopology :: ProvisionedTestTopology -> TestTopology
provisionedTopology (ProvisionedTestTopology topology) = topology
