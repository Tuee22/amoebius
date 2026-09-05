{-# LANGUAGE OverloadedStrings #-}

module EngineAcceleratorOracle
  ( MutantOracle (..)
  , expectedOfferings
  , expectedFamilies
  , expectedCoexistence
  , expectedNegatives
  , expectedLocusEntries
  , expectedCalculusProjection
  , expectedMutants
  ) where

import Data.Text (Text)

data MutantOracle = MutantOracle
  { oracleMutantName :: Text
  , oracleMutantFlag :: Text
  , oracleProductionLocus :: Text
  , oracleExpectedFailure :: Text
  }
  deriving stock (Eq, Show)

expectedOfferings :: [(Text, Text)]
expectedOfferings =
  [ ("apple", "AppleMetalLane")
  , ("linux-cpu", "LinuxCpuLane")
  , ("linux-cuda", "CudaLane")
  , ("windows", "CudaLane")
  ]

expectedFamilies :: [(Text, Text, Text)]
expectedFamilies =
  [ ("LlamaFamily", "AppleMetalLane", "available")
  , ("LlamaFamily", "CudaLane", "available")
  , ("LlamaFamily", "LinuxCpuLane", "available")
  , ("VllmFamily", "AppleMetalLane", "unavailable")
  , ("VllmFamily", "CudaLane", "available")
  , ("VllmFamily", "LinuxCpuLane", "unavailable")
  , ("DiffusionFamily", "AppleMetalLane", "available")
  , ("DiffusionFamily", "CudaLane", "available")
  , ("DiffusionFamily", "LinuxCpuLane", "unavailable")
  , ("OnnxFamily", "AppleMetalLane", "unavailable")
  , ("OnnxFamily", "CudaLane", "available")
  , ("OnnxFamily", "LinuxCpuLane", "available")
  ]

expectedCoexistence :: [(Text, Text, Text)]
expectedCoexistence = [("all-classes", "cuda-a", "15")]

expectedNegatives :: [(Text, Text, Text, Text)]
expectedNegatives =
  [ ("illegal_engine_by_url", "Url", "legal_inference_cuda", "Gate-1")
  , ("illegal_engine_family_unavailable_on_lane", "EngineFamilyUnavailable", "legal_engine_family_available_on_lane", "provision-seal")
  , ("illegal_cuda_on_cpu_target", "MissingCapability", "legal_cuda_on_cuda_target", "provision-seal")
  , ("illegal_accelerator_count_shortage", "AcceleratorCountShortage", "legal_accelerator_count_exact", "provision-seal")
  , ("illegal_accelerator_vram_shortage", "VramOvercommit", "legal_accelerator_vram_exact", "provision-seal")
  , ("illegal_accelerator_source_workload_mismatch", "EngineSourceWorkloadMismatch", "legal_accelerator_source_workload_equal", "provision-seal")
  , ("illegal_accelerator_policy_domain_mismatch", "EnginePolicyDomainMismatch", "legal_accelerator_policy_domain_equal", "provision-seal")
  , ("illegal_accelerator_residency_placement", "EngineResidencyPlacementInvalid", "legal_accelerator_residency_placement", "provision-seal")
  , ("illegal_accelerator_coexistence_overcommit", "AcceleratorCoexistenceOvercommit", "legal_accelerator_coexistence_exact", "provision-seal")
  ]

expectedMutants :: [MutantOracle]
expectedMutants =
  [ MutantOracle "drop-accelerator-work-item" "inference-accelerator-drop-work-item-mutant" "checkedDemand" "SourceWorkloadMismatch"
  , MutantOracle "accept-accelerator-domain-mismatch" "inference-accelerator-accept-domain-mismatch-mutant" "checkedDemand" "illegal engine case accepted: illegal_accelerator_policy_domain_mismatch"
  , MutantOracle "select-favorable-accelerator-epoch" "inference-accelerator-select-favorable-epoch-mutant" "checkedDemand" "wrong engine provision tag"
  , MutantOracle "drop-accelerator-overlap-debit" "inference-accelerator-drop-overlap-debit-mutant" "epochFor" "AcceleratorDomainMismatch"
  , MutantOracle "skip-accelerator-shard-validation" "inference-accelerator-skip-shard-validation-mutant" "validateWorkload" "wrong engine provision tag"
  ]

expectedLocusEntries :: [Text]
expectedLocusEntries =
  [ "legal_inference_singlenode", "legal_inference_distributed", "legal_inference_cuda"
  , "illegal_engine_by_url", "illegal_engine_family_unavailable_on_lane", "illegal_cuda_on_cpu_target"
  , "illegal_accelerator_count_shortage", "illegal_accelerator_vram_shortage"
  , "illegal_accelerator_source_workload_mismatch", "illegal_accelerator_policy_domain_mismatch"
  , "illegal_accelerator_residency_placement", "illegal_accelerator_coexistence_overcommit"
  , "drop-accelerator-work-item", "accept-accelerator-domain-mismatch"
  , "select-favorable-accelerator-epoch", "drop-accelerator-overlap-debit"
  , "skip-accelerator-shard-validation"
  ]

expectedCalculusProjection :: [(Text, Text)]
expectedCalculusProjection =
  [ ("calculus-kinds", "artifact,budget,lift,workflow,evidence")
  , ("component-names", "inference-positives,availability-cells,boundary-negatives,accelerator-property,mutant-evidence")
  , ("projection-counts", "3,16,9,1,5")
  , ("resource-vector", "5,34,0,0")
  ]
