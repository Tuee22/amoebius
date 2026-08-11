{-# LANGUAGE OverloadedStrings #-}

module EngineAcceleratorMutants
  ( engineAcceleratorMutants
  , runEngineAcceleratorMutant
  ) where

import Amoebius.Capability.Engine (engineProvisionErrorTag)
import Data.List (find)
import Data.Text (Text)
import EngineAcceleratorFixtures
  ( EngineNegative (..)
  , engineNegatives
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
  "mutant_drop_accelerator_work_item" -> catches "illegal_accelerator_source_workload_mismatch" "EngineSourceWorkloadMismatch"
  "mutant_accept_accelerator_domain_mismatch" -> catches "illegal_accelerator_policy_domain_mismatch" "EnginePolicyDomainMismatch"
  "mutant_select_favorable_accelerator_epoch" -> catches "illegal_accelerator_coexistence_overcommit" "AcceleratorCoexistenceOvercommit"
  "mutant_drop_accelerator_overlap_debit" -> catches "illegal_accelerator_coexistence_overcommit" "AcceleratorCoexistenceOvercommit"
  "mutant_skip_accelerator_shard_validation" -> catches "illegal_accelerator_residency_placement" "EngineResidencyPlacementInvalid"
  _ -> False

catches name expected = case find ((== name) . engineNegativeName) engineNegatives of
  Nothing -> False
  Just fixture -> case engineNegativeOutcome fixture of
    Left problem -> engineProvisionErrorTag problem == expected
    Right _ -> False
