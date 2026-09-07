{-# LANGUAGE OverloadedStrings #-}

-- | Independently authored Phase-49 expectations. This module deliberately
-- imports no production, fixture, or case module.
module DslBarrierOracle
  ( OracleStage (..)
  , expectedFakeArgv
  , expectedMutantLabels
  , expectedNegativeLabels
  , expectedStageDigests
  , expectedStages
  ) where

import Data.Text (Text)

data OracleStage
  = OracleDecode
  | OracleLegality
  | OracleBindExpand
  | OraclePlanResolve
  | OracleProvision
  | OracleRenderAll
  | OraclePlan
  | OracleDryRun
  | OracleFakeApply
  deriving stock (Bounded, Enum, Eq, Ord, Show)

expectedStages :: [OracleStage]
expectedStages = [minBound .. maxBound]

expectedStageDigests :: [Text]
expectedStageDigests =
  [ "0000000000000000000000000000000000000000000000000000000000000001"
  , "0000000000000000000000000000000000000000000000000000000000000002"
  , "0000000000000000000000000000000000000000000000000000000000000003"
  , "0000000000000000000000000000000000000000000000000000000000000004"
  , "0000000000000000000000000000000000000000000000000000000000000005"
  , "0000000000000000000000000000000000000000000000000000000000000006"
  , "0000000000000000000000000000000000000000000000000000000000000007"
  , "0000000000000000000000000000000000000000000000000000000000000008"
  , "0000000000000000000000000000000000000000000000000000000000000009"
  ]

expectedFakeArgv :: [Text]
expectedFakeArgv = ["apply", "--server-side=true", "-f", "-"]

expectedNegativeLabels :: [Text]
expectedNegativeLabels =
  [ "decode-failure", "stage-inventory", "demand-digest", "provision-identity"
  , "fake-argv", "fake-request", "challenge", "dry-run-effect", "self-observer"
  , "teardown", "workflow-evidence", "workflow-balance"
  ]

expectedMutantLabels :: [Text]
expectedMutantLabels =
  [ "decoder-widening", "legality-drop", "bind-arm-swap", "demand-omission"
  , "provision-identity-collapse", "render-omission", "plan-reorder"
  , "dry-run-execution", "fake-call-bypass", "workflow-observation-skip"
  , "teardown-leak", "skip-mutant"
  ]
