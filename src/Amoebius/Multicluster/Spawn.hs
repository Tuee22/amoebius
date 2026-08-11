{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Multicluster.Spawn
  ( ForestDemand (..)
  , ForestCapacity (..)
  , ForestProvisionError (..)
  , ValidatedForestSpawn
  , SpawnAuthority
  , SpawnAuthorizationError (..)
  , SpawnAction (..)
  , ChildObservation (..)
  , representativeForestDemand
  , forestDemandJson
  , validateForestSpawn
  , freshSpawnAuthority
  , authorizeSpawn
  , reconcileForest
  ) where

import Amoebius.Pulumi.Engine
import Data.Aeson (Value, object, (.=))
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)

data ForestDemand = ForestDemand
  { forestCpuMilli :: Integer
  , forestMemoryBytes :: Integer
  , forestVmDiskBytes :: Integer
  , forestPodEphemeralBytes :: Integer
  , forestPluginCacheBytes :: Integer
  , forestWorkspaceBytes :: Integer
  , forestCheckpointBytes :: Integer
  , forestExecutorLiveSet :: Int
  , forestHostProcessSlots :: Integer
  }
  deriving stock (Eq, Show)

data ForestCapacity = ForestCapacity
  { capacityCpuMilli :: Integer
  , capacityMemoryBytes :: Integer
  , capacityVmDiskBytes :: Integer
  , capacityPodEphemeralBytes :: Integer
  , capacityPluginCacheBytes :: Integer
  , capacityWorkspaceBytes :: Integer
  , capacityCheckpointBytes :: Integer
  , capacityExecutorLiveSet :: Int
  , capacityHostProcessSlots :: Integer
  }
  deriving stock (Eq, Show)

data ForestProvisionError
  = ForestCpuShort
  | ForestMemoryShort
  | ForestVmDiskShort
  | ForestPodEphemeralShort
  | PulumiPluginCacheShort
  | PulumiWorkspaceShort
  | PulumiCheckpointShort
  | PulumiExecutorLiveSetShort
  | ForestHostProcessSlotsShort
  deriving stock (Eq, Show)

data ValidatedForestSpawn = ValidatedForestSpawn Text ForestDemand

data SpawnAuthority
  = FreshSpawnAuthority Text ForestDemand
  | ConsumedSpawnAuthority
  deriving stock (Eq)

data SpawnAuthorizationError
  = MissingSpawnAuthority
  | SharedSupplySnapshotChanged
  | SpawnAuthorityAlreadyConsumed
  deriving stock (Eq, Show)

data SpawnAction
  = WriteEncryptedCheckpoint Text
  | RunPulumiExecutor Text
  | CreateKindChild Text
  deriving stock (Eq, Show)

newtype ChildObservation = ChildObservation (Set Text)
  deriving stock (Eq, Show)

representativeForestDemand :: ForestDemand
representativeForestDemand =
  let executor = PulumiExecutorDemand
        { executorCpuMilli = 250
        , executorMemoryBytes = 268435456
        , executorPodEphemeralBytes = 67108864
        , executorPluginCacheBytes = 33554432
        , executorWorkspaceBytes = 67108864
        }
#ifdef PHASE42_DROP_PARALLEL_EXECUTOR_MUTANT
      parallelLimit = 1
#else
      parallelLimit = 2
#endif
      execution = case boundedExecutionDemand parallelLimit [executor, executor] of
        Left failure -> error (show failure)
        Right value -> value
   in ForestDemand
        { forestCpuMilli = 2700 + executionCpuMilli execution
        , forestMemoryBytes = 2214592512 + executionMemoryBytes execution
        , forestVmDiskBytes = 4294967296
        , forestPodEphemeralBytes = 1107296256 + executionPodEphemeralBytes execution
        , forestPluginCacheBytes = executionPluginCacheBytes execution
        , forestWorkspaceBytes = executionWorkspaceBytes execution
        , forestCheckpointBytes = 49152
        , forestExecutorLiveSet = executionLiveSet execution
        , forestHostProcessSlots = 2 + fromIntegral (executionLiveSet execution)
        }

forestDemandJson :: ForestDemand -> Value
forestDemandJson demand = object
  [ "checkpointBytes" .= forestCheckpointBytes demand
  , "cpuMilli" .= forestCpuMilli demand
  , "executorLiveSet" .= forestExecutorLiveSet demand
  , "hostProcessSlots" .= forestHostProcessSlots demand
  , "memoryBytes" .= forestMemoryBytes demand
  , "pluginCacheBytes" .= forestPluginCacheBytes demand
  , "podEphemeralBytes" .= forestPodEphemeralBytes demand
  , "vmDiskBytes" .= forestVmDiskBytes demand
  , "workspaceBytes" .= forestWorkspaceBytes demand
  ]

validateForestSpawn
  :: Text
  -> ForestCapacity
  -> ForestDemand
  -> Either ForestProvisionError ValidatedForestSpawn
validateForestSpawn snapshot capacity demand
  | capacityCpuMilli capacity < forestCpuMilli demand = Left ForestCpuShort
  | capacityMemoryBytes capacity < forestMemoryBytes demand = Left ForestMemoryShort
  | capacityVmDiskBytes capacity < forestVmDiskBytes demand = Left ForestVmDiskShort
  | capacityPodEphemeralBytes capacity < forestPodEphemeralBytes demand = Left ForestPodEphemeralShort
  | capacityPluginCacheBytes capacity < forestPluginCacheBytes demand = Left PulumiPluginCacheShort
  | capacityWorkspaceBytes capacity < forestWorkspaceBytes demand = Left PulumiWorkspaceShort
  | capacityCheckpointBytes capacity < forestCheckpointBytes demand = Left PulumiCheckpointShort
  | capacityExecutorLiveSet capacity < forestExecutorLiveSet demand = Left PulumiExecutorLiveSetShort
  | capacityHostProcessSlots capacity < forestHostProcessSlots demand = Left ForestHostProcessSlotsShort
  | otherwise = Right (ValidatedForestSpawn snapshot demand)

freshSpawnAuthority :: ValidatedForestSpawn -> SpawnAuthority
freshSpawnAuthority (ValidatedForestSpawn snapshot demand) = FreshSpawnAuthority snapshot demand

authorizeSpawn
  :: Text
  -> Maybe SpawnAuthority
  -> Either SpawnAuthorizationError SpawnAuthority
authorizeSpawn _ Nothing = Left MissingSpawnAuthority
authorizeSpawn _ (Just ConsumedSpawnAuthority) = Left SpawnAuthorityAlreadyConsumed
authorizeSpawn current (Just (FreshSpawnAuthority observed _))
  | current /= observed = Left SharedSupplySnapshotChanged
  | otherwise = Right ConsumedSpawnAuthority

reconcileForest :: ChildObservation -> ValidatedForestSpawn -> [SpawnAction]
reconcileForest (ChildObservation observed) _ = concatMap actionsFor ["amoebius-p42-a", "amoebius-p42-b"]
 where
  actionsFor child
    | child `Set.member` observed = []
    | otherwise =
        [ WriteEncryptedCheckpoint child
        , RunPulumiExecutor child
        , CreateKindChild child
        ]
