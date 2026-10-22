{-# LANGUAGE OverloadedStrings #-}

-- | The hardware-free compile boundary supplies small fake devices explicitly.
-- Their 64/8/56-byte capacity model is not a hardware observation. Eligibility
-- comes from the operator's supplied topology; the provision fold still checks
-- exact service/target identity, lane, family and device capacity.
module Amoebius.Dsl.TargetModel (fakeEngineOfferings, targetModelDump) where

import Amoebius.Capacity.Accelerator (AcceleratorDevice (..), AcceleratorFamily (..))
import Amoebius.Capacity.Types (Node (..))
import Amoebius.Capability.Engine (TargetOffering (..))
import Amoebius.Capability.Types
import Amoebius.Dsl.Dump (rows, row)
import Amoebius.Dsl.Topology (Topology, NodeSupply (..), topologySupply)
import Amoebius.Vocabulary (Lane (..), detectedArchitecture, lanesOf)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

fakeEngineOfferings :: Topology -> BoundDeployment -> Map.Map Text TargetOffering
fakeEngineOfferings topology deployment = Map.fromList
  [(capabilityResourceName (boundCapabilityNeed service), offering runtime node)
   | service <- Map.elems (boundDeploymentServices deployment),
     InferenceEngineCapabilityNeed inference <- [boundCapabilityNeed service],
     let runtime = inferenceRuntime inference,
     node <- take 1 [candidate | candidate <- nodes, Set.null (nodeTaints candidate), lane runtime candidate `elem` lanesOf (nodeDetected candidate)]]
 where
  nodes = case topologySupply topology of FixedSupply values -> NonEmpty.toList values; ElasticSupply {} -> []
  lane runtime node = case runtime of CpuRuntime -> LinuxCpuAt (detectedArchitecture (nodeDetected node)); Cuda -> LinuxCudaAt (detectedArchitecture (nodeDetected node)); AppleMetal -> AppleMetalOnHost
  offering runtime node = case runtime of
    CpuRuntime -> LinuxCpuOffering (nodeId node)
    Cuda -> LinuxCudaOffering (nodeId node) (devices CudaFamily node)
    AppleMetal -> AppleOffering (nodeId node) (devices AppleMetalFamily node)
  devices family node = let identity = "fake/" <> nodeId node <> "/device-0" in Map.singleton identity
    (AcceleratorDevice identity family "fake-model" 64 8 56 Set.empty Set.empty)

targetModelDump :: Map.Map Text TargetOffering -> Text
targetModelDump offerings = rows
  (row "boundary" "HaskellFakeBoundaries" : [row ("offering." <> name) (Text.pack (show offering)) | (name, offering) <- Map.toList offerings])
