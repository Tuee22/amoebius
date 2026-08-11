{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Capacity.NodeLocalStorage
import Amoebius.Capacity.RuntimeStorage
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import System.Exit (die)

main :: IO ()
main = do
  _ <- requireRight (provisionNodeRuntimeStorageAccounting models plannedScope exactLayout [plannedDemand] imageDemand)
  _ <- requireRight (provisionNodeRuntimeStorageAccounting models observedScope exactLayout [observedDemand] imageDemand)
  assertLeft "planned/observed scope mismatch"
    (provisionNodeRuntimeStorageAccounting models observedScope exactLayout [plannedDemand] imageDemand)
  assertLeft "domain mismatch"
    (provisionNodeRuntimeStorageAccounting models (PlannedEpochScope "epoch" Set.empty) exactLayout [plannedDemand] imageDemand)
  assertLeft "missing observed owner witness"
    (provisionNodeRuntimeStorageAccounting models observedScope exactLayout [observedDemand {runtimeAccountingId = ObservedPodUid "pod-a" ""}] imageDemand)
  assertLeft "nodefs one short"
    (provisionNodeRuntimeStorageAccounting models plannedScope (SplitRuntime (LocalBacking "nodefs" 4) (LocalBacking "runtime" 12)) [plannedDemand] imageDemand)
  assertLeft "runtime one short"
    (provisionNodeRuntimeStorageAccounting models plannedScope (SplitRuntime (LocalBacking "nodefs" 5) (LocalBacking "runtime" 11)) [plannedDemand] imageDemand)
  assertLeft "role ownership overlap"
    (provisionNodeRuntimeStorageAccounting models plannedScope exactLayout [plannedDemand] overlapImageDemand)
  assertLeft "backing alias"
    (provisionNodeRuntimeStorageAccounting models plannedScope (SplitRuntime (LocalBacking "same" 100) (LocalBacking "same" 100)) [plannedDemand] imageDemand)
  assertLeft "pinned model mismatch"
    (provisionNodeRuntimeStorageAccounting models plannedScope exactLayout [plannedDemand {runtimeMetadataModelVersion = "other"}] imageDemand)
  putStrLn "phase33-runtime-storage-spec: PASS (scope domains, role ownership, SplitRuntime exact fit, pinned model)"

models :: Map.Map Text.Text KubeletRuntimeMetadataModel
models = Map.singleton "model-v1" (KubeletRuntimeMetadataModel 1 1 1 1 1 1 1)

source :: PodRuntimeMetadataSource
source = PodRuntimeMetadataSource
  { runtimeContainerIds = Set.singleton "singleton"
  , runtimeVolumeIds = Set.singleton "projected-token"
  , runtimeMounts = Set.singleton ("singleton", "projected-token")
  , runtimeNetworkAttachments = Set.singleton "eth0"
  }

plannedDemand :: KubeletRuntimeMetadataDemand
plannedDemand = KubeletRuntimeMetadataDemand (PlannedExecutionSlotId "singleton-0") "model-v1" source

observedDemand :: KubeletRuntimeMetadataDemand
observedDemand = KubeletRuntimeMetadataDemand (ObservedPodUid "pod-a" "Deployment/phase33-system/amoebius-control-plane") "model-v1" source

plannedScope :: RuntimeAccountingScope
plannedScope = PlannedEpochScope "epoch" (Set.singleton "planned:singleton-0")

observedScope :: RuntimeAccountingScope
observedScope = ObservedInventoryScope "inventory" (Set.singleton "observed:pod-a")

exactLayout :: KubeletFilesystemLayout
exactLayout = SplitRuntime (LocalBacking "nodefs" 5) (LocalBacking "runtime" 12)

imageDemand :: ProvisionedNodeImageStorageDemand
imageDemand = ProvisionedNodeImageStorageDemand Map.empty Map.empty 0 [NodeStorageComponent "image:singleton" ImageStorage 10] 10

overlapImageDemand :: ProvisionedNodeImageStorageDemand
overlapImageDemand = ProvisionedNodeImageStorageDemand Map.empty Map.empty 0 [NodeStorageComponent "planned:singleton-0:sandbox" ImageStorage 10] 10

requireRight :: Show problem => Either problem value -> IO value
requireRight = either (die . show) pure

assertLeft :: (Show problem, Show value) => String -> Either problem value -> IO ()
assertLeft label result = case result of
  Left _ -> pure ()
  Right value -> die (label <> ": unexpectedly accepted " <> show value)
