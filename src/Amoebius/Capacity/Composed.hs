{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Composition boundary for the Phase-7 placement, Phase-8 storage
-- witnesses, and Phase-9 execution/runtime/accelerator/provider-root proofs.
-- The component folds remain the only way to obtain each retained witness.
module Amoebius.Capacity.Composed
  ( ComposedPlacementInput (..)
  , ComposedPlacementWitness (..)
  , ComposedPlacementError (..)
  , placeFullResourceVector
  ) where

import Amoebius.Capacity.Accelerator (ProvisionedAccelerator)
import Amoebius.Capacity.Execution (ProvisionedExecutionEpochs (..))
import Amoebius.Capacity.Fold (effectiveReserved, place)
import Amoebius.Capacity.ProviderRoot (ProvisionedPerInstanceDiskTemplate)
import Amoebius.Capacity.RuntimeStorage (ProvisionedNodeRuntimeStorageAccounting)
import Amoebius.Capacity.Storage (StorageWitness)
import Amoebius.Capacity.Types
  ( Axis (..)
  , Placement
  , PlacementError
  , ResourceVector (..)
  , Workload (..)
  , addResources
  , zeroResources
  )
import Amoebius.Dsl.Topology (Topology)
import Control.DeepSeq (NFData)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ComposedPlacementInput = ComposedPlacementInput
  { composedTopology :: Topology
  , composedWorkloads :: [Workload]
  , composedExecution :: ProvisionedExecutionEpochs
  , composedRuntimeStorage :: [ProvisionedNodeRuntimeStorageAccounting]
  , composedDurableAndCacheStorage :: [StorageWitness]
  , composedAccelerators :: [ProvisionedAccelerator]
  , composedProviderRoots :: [ProvisionedPerInstanceDiskTemplate]
  }
  deriving stock (Generic)
  deriving anyclass (NFData)

data ComposedPlacementWitness = ComposedPlacementWitness
  { composedBasePlacement :: Placement
  , composedRequiredResources :: ResourceVector
  , composedExecutionPeakResources :: ResourceVector
  , composedRuntimeStorageWitnesses :: [ProvisionedNodeRuntimeStorageAccounting]
  , composedStorageWitnesses :: [StorageWitness]
  , composedAcceleratorWitnesses :: [ProvisionedAccelerator]
  , composedProviderRootWitnesses :: [ProvisionedPerInstanceDiskTemplate]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ComposedPlacementError
  = ComposedBasePlacementError PlacementError
  | ComposedExecutionMismatch Axis Natural Natural
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

placeFullResourceVector :: ComposedPlacementInput -> Either ComposedPlacementError ComposedPlacementWitness
placeFullResourceVector input = do
  placement <- mapPlacement (place (composedTopology input) (composedWorkloads input))
  let required = foldl addResources zeroResources (fmap (effectiveReserved . workloadEnvelope) (composedWorkloads input))
      executionPeak = provisionedExecutionPeak (composedExecution input)
  ensurePeak required executionPeak
  pure
    ComposedPlacementWitness
      { composedBasePlacement = placement
      , composedRequiredResources = required
      , composedExecutionPeakResources = executionPeak
      , composedRuntimeStorageWitnesses = composedRuntimeStorage input
      , composedStorageWitnesses = composedDurableAndCacheStorage input
      , composedAcceleratorWitnesses = composedAccelerators input
      , composedProviderRootWitnesses = composedProviderRoots input
      }

ensurePeak :: ResourceVector -> ResourceVector -> Either ComposedPlacementError ()
ensurePeak required available
  | resourceCpu required > resourceCpu available = exceeded CpuAxis resourceCpu
  | resourceMemory required > resourceMemory available = exceeded MemoryAxis resourceMemory
  | resourceEphemeralStorage required > resourceEphemeralStorage available = exceeded EphemeralStorageAxis resourceEphemeralStorage
  | resourcePodSlots required > resourcePodSlots available = exceeded PodSlotsAxis resourcePodSlots
  | otherwise = Right ()
 where
  exceeded axis project = Left (ComposedExecutionMismatch axis (project required) (project available))

mapPlacement :: Either PlacementError value -> Either ComposedPlacementError value
mapPlacement outcome = case outcome of
  Left problem -> Left (ComposedBasePlacementError problem)
  Right value -> Right value
