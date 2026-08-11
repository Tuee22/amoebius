{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Pure host-only compute derivations for builds, named engine reserves,
-- monitoring work, and Pulumi executors.
module Amoebius.Capacity.PulumiExecution
  ( BuildStageDemand (..)
  , BuildExecutionEnvelope (..)
  , ProvisionedBuildExecution (..)
  , EngineProcessDemand (..)
  , EngineSystemReserve (..)
  , MonitoringWorkBudget (..)
  , ProvisionedMonitoringWork (..)
  , PulumiExecutionDemand (..)
  , ProvisionedPulumiExecutionDemand (..)
  , HostComputeError (..)
  , provisionBuildExecution
  , provisionEngineSystemReserve
  , provisionMonitoringWork
  , provisionPulumiExecution
  ) where

import Amoebius.Capacity.Types (ResourceVector (..), addResources, zeroResources)
import Control.DeepSeq (NFData)
import Data.List (sortOn)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data BuildStageDemand = BuildStageDemand
  { buildStageId :: Text
  , buildStageResources :: ResourceVector
  , buildStageScratchBytes :: Natural
  , buildStageCacheWriteBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data BuildExecutionEnvelope = BuildExecutionEnvelope
  { buildStages :: [BuildStageDemand]
  , buildArchitectureConcurrency :: Natural
  , buildStageConcurrency :: Natural
  , buildObservedCacheResidentBytes :: Natural
  , buildCacheBudgetBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedBuildExecution = ProvisionedBuildExecution
  { provisionedBuildComputePeak :: ResourceVector
  , provisionedBuildScratchPeakBytes :: Natural
  , provisionedBuildCachePeakBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data EngineProcessDemand = EngineProcessDemand
  { engineProcessId :: Text
  , engineProcessResources :: ResourceVector
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data EngineSystemReserve = EngineSystemReserve
  { engineRole :: Text
  , engineProcesses :: [EngineProcessDemand]
  , engineStorageRequiredBytes :: Natural
  , engineStorageAvailableBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data MonitoringWorkBudget = MonitoringWorkBudget
  { monitoringWorkflows :: Natural
  , monitoringRules :: Natural
  , monitoringSeries :: Natural
  , monitoringSamplesPerSecond :: Natural
  , monitoringConcurrentQueries :: Natural
  , monitoringSeriesPerQuery :: Natural
  , monitoringSamplesPerQuery :: Natural
  , monitoringProxyCpuPerQuery :: Natural
  , monitoringMemoryPerSeries :: Natural
  , monitoringTsdbResidentBytes :: Natural
  , monitoringTsdbTemporaryBytes :: Natural
  , monitoringVolumeBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedMonitoringWork = ProvisionedMonitoringWork
  { provisionedMonitoringResources :: ResourceVector
  , provisionedMonitoringStorageBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data PulumiExecutionDemand = PulumiExecutionDemand
  { pulumiDeployResources :: ResourceVector
  , pulumiPluginResources :: [ResourceVector]
  , pulumiExecutorConcurrency :: Natural
  , pulumiWorkspaceBytesPerExecutor :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ProvisionedPulumiExecutionDemand = ProvisionedPulumiExecutionDemand
  { provisionedPulumiResources :: ResourceVector
  , provisionedPulumiWorkspaceBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data HostComputeError
  = BuildStageAlias Text
  | BuildConcurrencyZero
  | BuildCacheOvercommit Natural Natural
  | EngineProcessAlias Text
  | EngineProcessInventoryEmpty
  | EngineStorageOvercommit Natural Natural
  | MonitoringStorageOvercommit Natural Natural
  | PulumiConcurrencyZero
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

provisionBuildExecution :: BuildExecutionEnvelope -> Either HostComputeError ProvisionedBuildExecution
provisionBuildExecution envelope
  | buildArchitectureConcurrency envelope == 0 || buildStageConcurrency envelope == 0 = Left BuildConcurrencyZero
  | length stages /= Set.size (Set.fromList (fmap buildStageId stages)) = Left (BuildStageAlias (duplicateStage stages))
  | cachePeak > buildCacheBudgetBytes envelope = Left (BuildCacheOvercommit cachePeak (buildCacheBudgetBytes envelope))
  | otherwise =
      Right
        ProvisionedBuildExecution
          { provisionedBuildComputePeak = scaleResources concurrency (resourcePeak (fmap buildStageResources stages))
          , provisionedBuildScratchPeakBytes = concurrency * maximumTotal (fmap buildStageScratchBytes stages)
          , provisionedBuildCachePeakBytes = cachePeak
          }
 where
  stages = buildStages envelope
  concurrency = buildArchitectureConcurrency envelope * buildStageConcurrency envelope
  cachePeak = buildObservedCacheResidentBytes envelope + concurrency * maximumTotal (fmap buildStageCacheWriteBytes stages)

provisionEngineSystemReserve :: EngineSystemReserve -> Either HostComputeError ResourceVector
provisionEngineSystemReserve reserve
  | null processes = Left EngineProcessInventoryEmpty
  | length processes /= Set.size (Set.fromList (fmap engineProcessId processes)) = Left (EngineProcessAlias (duplicateProcess processes))
  | engineStorageRequiredBytes reserve > engineStorageAvailableBytes reserve =
      Left (EngineStorageOvercommit (engineStorageRequiredBytes reserve) (engineStorageAvailableBytes reserve))
  | otherwise = Right (foldl addResources zeroResources (fmap engineProcessResources processes))
 where
  processes = engineProcesses reserve

provisionMonitoringWork :: MonitoringWorkBudget -> Either HostComputeError ProvisionedMonitoringWork
provisionMonitoringWork budget
  | storage > monitoringVolumeBytes budget = Left (MonitoringStorageOvercommit storage (monitoringVolumeBytes budget))
  | otherwise = Right (ProvisionedMonitoringWork compute storage)
 where
  evaluationCpu = monitoringWorkflows budget + monitoringRules budget + monitoringSamplesPerSecond budget
  queryCpu = monitoringConcurrentQueries budget * (monitoringSeriesPerQuery budget + monitoringProxyCpuPerQuery budget)
  memory = monitoringSeries budget * monitoringMemoryPerSeries budget + monitoringConcurrentQueries budget * monitoringSamplesPerQuery budget
  compute = ResourceVector (evaluationCpu + queryCpu) memory 0 1
  storage = monitoringTsdbResidentBytes budget + monitoringTsdbTemporaryBytes budget

provisionPulumiExecution :: PulumiExecutionDemand -> Either HostComputeError ProvisionedPulumiExecutionDemand
provisionPulumiExecution demand
  | pulumiExecutorConcurrency demand == 0 = Left PulumiConcurrencyZero
  | otherwise =
      Right
        ProvisionedPulumiExecutionDemand
          { provisionedPulumiResources = scaleResources (pulumiExecutorConcurrency demand) joined
          , provisionedPulumiWorkspaceBytes = pulumiExecutorConcurrency demand * pulumiWorkspaceBytesPerExecutor demand
          }
 where
  joined = foldl addResources (pulumiDeployResources demand) (pulumiPluginResources demand)

scaleResources :: Natural -> ResourceVector -> ResourceVector
scaleResources amount resources =
  ResourceVector
    { resourceCpu = amount * resourceCpu resources
    , resourceMemory = amount * resourceMemory resources
    , resourceEphemeralStorage = amount * resourceEphemeralStorage resources
    , resourcePodSlots = amount * resourcePodSlots resources
    }

resourcePeak :: [ResourceVector] -> ResourceVector
resourcePeak rows = foldl maxResources zeroResources rows

maxResources :: ResourceVector -> ResourceVector -> ResourceVector
maxResources left right =
  ResourceVector
    { resourceCpu = max (resourceCpu left) (resourceCpu right)
    , resourceMemory = max (resourceMemory left) (resourceMemory right)
    , resourceEphemeralStorage = max (resourceEphemeralStorage left) (resourceEphemeralStorage right)
    , resourcePodSlots = max (resourcePodSlots left) (resourcePodSlots right)
    }

maximumTotal :: [Natural] -> Natural
maximumTotal = foldl max 0

duplicateStage :: [BuildStageDemand] -> Text
duplicateStage = duplicateBy buildStageId . sortOn buildStageId

duplicateProcess :: [EngineProcessDemand] -> Text
duplicateProcess = duplicateBy engineProcessId . sortOn engineProcessId

duplicateBy :: (value -> Text) -> [value] -> Text
duplicateBy project values = go values
 where
  go remaining = case remaining of
    first : second : rest
      | project first == project second -> project first
      | otherwise -> go (second : rest)
    _ -> "duplicate"
