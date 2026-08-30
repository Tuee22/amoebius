{-# LANGUAGE OverloadedStrings #-}

-- | Independent expectations for the dormant plan revision.
--
-- The counts below are derived from the ledger, not read back from the module:
-- ninety-six old phases become ninety-one through eight splits and ten merged
-- capabilities, and the nine bands must each occupy one contiguous range. The
-- one expected finding is the proposal-only refusal, so any integrity violation
-- in the revised table shows up here as an unexpected code.
module PlanRevisionOracle
  ( runPlanRevisionOracle
  ) where

import Amoebius.Validation.PlanRevision (planRevisionDiagnostic)
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text

runPlanRevisionOracle :: IO ()
runPlanRevisionOracle = do
  let problems = observationProblems <> findingProblems
  unless (null problems) $
    fail (unlines ("PlanRevisionOracle component diagnostics failed:" : map ("  " <>) problems))
  putStrLn
    ( "PlanRevisionOracle: the revised ninety-one-phase table and its complete old-to-new audit map are "
        <> "internally consistent, and the four role-bearing phases stay consecutive and in role order. "
        <> "A checked proposal, not an identity table."
    )

expectedObservations :: [(Text, Text)]
expectedObservations =
  [ ("revision.phase-count", "91")
  , ("revision.old-phase-count", "96")
  , ("revision.split-count", "8")
  , ("revision.merge-count", "10")
  -- The splits before the cuts and the merges after them cancel exactly, so the
  -- four semantic cuts do not move under this revision.
  , ("revision.role-ordinals", "self_referential_gates=49,host_assert_cli=50,host_ensure_kernel=51,linux_engine_bringup=52")
  -- Sufficiency is a property of each parent-and-capability component, not of
  -- one parent against the capabilities it becomes: the tool-and-mutant phase
  -- shares a component with the UI-contract phase it merges with, and the pair
  -- supplies two sprints to two capabilities. Every component is feasible, so
  -- all 270 sprints redistribute with no new sprint body authored.
  , ("revision.sprint-deficit-count", "0")
  -- Every capability takes a contiguous run of its parent's linear sprint
  -- chain, so no split puts a dependency edge in both directions.
  , ("revision.split-discontiguous-count", "0")
  , ("revision.band", "Foundations=9")
  , ("revision.band", "Algebra=4")
  , ("revision.band", "ProofStack=9")
  , ("revision.band", "ExtensionContract=2")
  , ("revision.band", "GenerativeSurface=24")
  , ("revision.band", "TestAsWorkflow=2")
  , ("revision.band", "PreBinaryAndHost=8")
  , ("revision.band", "LivePlatform=30")
  , ("revision.band", "DomainInstances=3")
  ]

observationProblems :: [String]
observationProblems =
  [ "missing or wrong observation: " <> Text.unpack key <> "=" <> Text.unpack value
  | (key, value) <- expectedObservations
  , (key, value) `notElem` observed
  ]
    <> [ "unexpected observation count: expected "
           <> show (length expectedObservations)
           <> ", observed "
           <> show (length observed)
       | length observed /= length expectedObservations
       ]
 where
  observed =
    [(observationKey item, observationValue item) | item <- checkObservations planRevisionDiagnostic]

findingProblems :: [String]
findingProblems =
  [ "expected the proposal-only refusal alone, observed "
      <> show (map (Text.unpack . findingCode) findings)
  | sort (map findingCode findings) /= ["REVISION-PROPOSAL-ONLY"]
  ]
 where
  findings = checkFindings planRevisionDiagnostic
