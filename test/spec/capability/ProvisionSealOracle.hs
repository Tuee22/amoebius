{-# LANGUAGE OverloadedStrings #-}

module ProvisionSealOracle
  ( NegativeOracle (..)
  , MutantOracle (..)
  , expectedNegatives
  , expectedActivations
  , expectedMutants
  , expectedCalculusProjection
  , expectedLocusEntries
  ) where

import Data.Text (Text)

data NegativeOracle = NegativeOracle
  { oracleNegativeName :: Text
  , oracleNegativeTag :: Text
  , oraclePositiveTwin :: Text
  }
  deriving stock (Eq, Show)

data MutantOracle = MutantOracle
  { oracleMutantName :: Text
  , oracleMutantFlag :: Text
  , oracleProductionLocus :: Text
  , oracleExpectedFailure :: Text
  }
  deriving stock (Eq, Show)

expectedNegatives :: [NegativeOracle]
expectedNegatives =
  [ NegativeOracle "illegal_post_bind_expansion_overcommit" "PostBindExpansionOvercommit" "legal_post_bind_expansion_exact"
  , NegativeOracle "illegal_monitoring_work_over_budget" "MonitoringBudgetExceeded" "legal_monitoring_work_exact"
  , NegativeOracle "illegal_accelerator_vram_shortage" "VramOvercommit" "legal_accelerator_vram_exact"
  , NegativeOracle "illegal_cuda_on_cpu_target" "MissingCapability" "legal_cuda_on_cuda_target"
  , NegativeOracle "illegal_controller_child_unbounded" "UnknownCommitment" "legal_controller_child_bounded"
  , NegativeOracle "illegal_elastic_per_node_expansion_overcommit" "ElasticPerNodeExpansionOvercommit" "legal_elastic_per_node_expansion_exact"
  , NegativeOracle "illegal_prior_provision_ref_missing" "MissingPriorProvisionRef" "legal_prior_provision_ref_present"
  , NegativeOracle "illegal_prior_provision_ref_stale" "StalePriorProvisionRef" "legal_prior_provision_ref_fresh"
  , NegativeOracle "illegal_prior_provision_ref_wrong_generation" "WrongGenerationPriorProvisionRef" "legal_prior_provision_ref_generation"
  , NegativeOracle "illegal_prior_provision_ref_wrong_arm" "WrongArmPriorProvisionRef" "legal_prior_provision_ref_arm"
  ]

expectedActivations :: [(Text, Text)]
expectedActivations =
  [ ("NamespacePart", "Immediate")
  , ("CapacitySchedulerPart", "BootstrapSchedulerStage")
  , ("BootstrapAddonCutoverPart", "AfterBootstrapAddonCutover")
  , ("ManagedCapacityAdmissionPart", "AfterManagedCapacityReady")
  ]

expectedMutants :: [MutantOracle]
expectedMutants =
  [ MutantOracle "accept-plan-replay" "provision-seal-accept-plan-replay-mutant" "validateInfrastructurePlan" "expected provision failure: InfrastructurePlanReplay"
  , MutantOracle "accept-missing-readback" "provision-seal-accept-missing-readback-mutant" "enactInfrastructurePlan" "expected provision failure: PromisedIdentityNotObserved"
  , MutantOracle "drop-execution-replica" "provision-seal-drop-execution-replica-mutant" "provision" "desired execution expansion differs from the controller oracle"
  , MutantOracle "drop-runtime-row" "provision-seal-drop-runtime-row-mutant" "provisionRuntime" "RuntimeStorageProvisionFailure"
  ]

expectedCalculusProjection :: [(Text, Text)]
expectedCalculusProjection =
  [ ("calculus-kinds", "artifact,budget,lift,workflow,evidence")
  , ("component-names", "inherited-positives,planner-paths,specific-negatives,provision-properties,mutant-evidence")
  , ("projection-counts", "18,2,10,2,4")
  , ("resource-vector", "5,36,0,0")
  ]

expectedLocusEntries :: [Text]
expectedLocusEntries =
  [ "legal_objectstore_singlenode", "legal_objectstore_distributed"
  , "legal_secretstore_singlenode", "legal_secretstore_distributed"
  , "legal_messagebus_singlenode", "legal_messagebus_distributed"
  , "legal_sql_singlenode", "legal_sql_distributed"
  , "legal_identity_singlenode", "legal_identity_distributed"
  , "legal_observability_singlenode", "legal_observability_distributed"
  , "legal_registry_singlenode", "legal_registry_distributed"
  , "legal_edge_singlenode", "legal_edge_distributed"
  , "legal_inferenceengine_singlenode", "legal_inferenceengine_distributed"
  , "planner_preexisting", "planner_creation"
  , "illegal_post_bind_expansion_overcommit"
  , "illegal_monitoring_work_over_budget"
  , "illegal_accelerator_vram_shortage"
  , "illegal_cuda_on_cpu_target"
  , "illegal_controller_child_unbounded"
  , "illegal_elastic_per_node_expansion_overcommit"
  , "illegal_prior_provision_ref_missing"
  , "illegal_prior_provision_ref_stale"
  , "illegal_prior_provision_ref_wrong_generation"
  , "illegal_prior_provision_ref_wrong_arm"
  , "accept-plan-replay"
  , "accept-missing-readback"
  , "drop-execution-replica"
  , "drop-runtime-row"
  ]
