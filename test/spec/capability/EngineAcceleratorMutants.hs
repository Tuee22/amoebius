{-# LANGUAGE OverloadedStrings #-}

module EngineAcceleratorMutants
  ( engineAcceleratorMutants
  , runEngineAcceleratorMutant
  ) where

import Amoebius.Capacity.Accelerator
  ( AcceleratorResidencyDemand (acceleratorResidencyBytes, acceleratorResidencyPlacement)
  , ResidencyPlacement (Unsharded)
  )
import Amoebius.Capability.Engine
  ( CudaOwnerDemand (..)
  , EngineCoexistencePolicy (..)
  , EngineFamily (LlamaFamily)
  , EngineOwnerDemand (CudaEngineOwner)
  , EngineProvisionError
  , ProvisionedEngineAccelerator
  , engineProvisionErrorTag
  , provisionEngineOwner
  )
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import EngineAcceleratorFixtures
  ( baseCudaOwner
  , coexistenceOvercommitCudaOwner
  , cudaOffering
  , invalidShardCudaOwner
  , policyMismatchCudaOwner
  , sourceMismatchCudaOwner
  )

engineAcceleratorMutants :: [Text]
engineAcceleratorMutants =
  [ "mutant_drop_accelerator_work_item"
  , "mutant_accept_accelerator_domain_mismatch"
  , "mutant_select_favorable_accelerator_epoch"
  , "mutant_drop_accelerator_overlap_debit"
  , "mutant_skip_accelerator_shard_validation"
  ]

runEngineAcceleratorMutant :: Text -> IO Bool
runEngineAcceleratorMutant mutant = pure $ case mutant of
  "mutant_drop_accelerator_work_item" ->
    hasTag "EngineSourceWorkloadMismatch" (provisionCuda sourceMismatchCudaOwner)
      && not (Map.null (cudaOwnerSources baseCudaOwner))
      && Map.null (cudaOwnerSources droppedOwner)
      && isRight (provisionCuda droppedOwner)
  "mutant_accept_accelerator_domain_mismatch" ->
    hasTag "EnginePolicyDomainMismatch" (provisionCuda policyMismatchCudaOwner)
      && isRight (provisionCuda policyDefaultedOwner)
  "mutant_select_favorable_accelerator_epoch" ->
    hasTag "AcceleratorCoexistenceOvercommit" (provisionCuda coexistenceOvercommitCudaOwner)
      && isRight (provisionCuda favorableEpochOnlyOwner)
  "mutant_drop_accelerator_overlap_debit" ->
    hasTag "AcceleratorCoexistenceOvercommit" (provisionCuda coexistenceOvercommitCudaOwner)
      && isRight (provisionCuda overlapDebitDroppedOwner)
  "mutant_skip_accelerator_shard_validation" ->
    hasTag "EngineResidencyPlacementInvalid" (provisionCuda invalidShardCudaOwner)
      && isRight (provisionCuda shardValidationSkippedOwner)
  _ -> False

provisionCuda :: CudaOwnerDemand -> Either EngineProvisionError ProvisionedEngineAccelerator
provisionCuda = provisionEngineOwner cudaOffering LlamaFamily . CudaEngineOwner

droppedOwner :: CudaOwnerDemand
droppedOwner =
  baseCudaOwner
    { cudaOwnerSources = Map.empty
    , cudaOwnerWorkloads = Map.empty
    , cudaOwnerPolicy = EngineCoexistencePolicy Map.empty Map.empty Map.empty
    }

policyDefaultedOwner :: CudaOwnerDemand
policyDefaultedOwner = policyMismatchCudaOwner {cudaOwnerPolicy = cudaOwnerPolicy baseCudaOwner}

favorableEpochOnlyOwner :: CudaOwnerDemand
favorableEpochOnlyOwner =
  (replaceEpochs (Map.singleton "favorable" (Set.singleton "left")))
    { cudaOwnerSources = Map.delete "right" (cudaOwnerSources coexistenceOvercommitCudaOwner)
    , cudaOwnerWorkloads = Map.delete "right" (cudaOwnerWorkloads coexistenceOvercommitCudaOwner)
    }

overlapDebitDroppedOwner :: CudaOwnerDemand
overlapDebitDroppedOwner =
  coexistenceOvercommitCudaOwner
    { cudaOwnerWorkloads =
        Map.adjust
          (\residency -> residency {acceleratorResidencyBytes = 0})
          "right"
          (cudaOwnerWorkloads coexistenceOvercommitCudaOwner)
    }

replaceEpochs :: Map.Map Text (Set.Set Text) -> CudaOwnerDemand
replaceEpochs epochs =
  let EngineCoexistencePolicy resident running _ = cudaOwnerPolicy coexistenceOvercommitCudaOwner
   in coexistenceOvercommitCudaOwner
        { cudaOwnerPolicy = EngineCoexistencePolicy resident running epochs
        }

shardValidationSkippedOwner :: CudaOwnerDemand
shardValidationSkippedOwner =
  invalidShardCudaOwner
    { cudaOwnerWorkloads =
        Map.map
          (\residency -> residency {acceleratorResidencyPlacement = Unsharded})
          (cudaOwnerWorkloads invalidShardCudaOwner)
    }

hasTag :: Text -> Either EngineProvisionError value -> Bool
hasTag expected outcome = case outcome of
  Left problem -> engineProvisionErrorTag problem == expected
  Right _ -> False

isRight :: Either left right -> Bool
isRight outcome = case outcome of
  Left _ -> False
  Right _ -> True
