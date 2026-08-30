{-# LANGUAGE OverloadedStrings #-}

-- | Independent expectations for the mutation-coverage count.
--
-- The numbers here are restated from the corpus, not read back from the
-- module. The kernel declares 5,712 guarded mutation loci; five selector
-- suites between them can execute 1,184; the remaining 4,528 change production
-- under a flag with nothing observing the change.
--
-- Two of the five suites are new. Before they existed the drivers for a
-- 659-locus registry and a 374-locus registry were exported and never called,
-- so the executable corpus was 151 loci and every inventory that counted flag
-- declarations reported thousands.
module MutationCoverageOracle
  ( runMutationCoverageOracle
  ) where

import Amoebius.Validation.MutationCoverage (mutationCoverageCheck)
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text

runMutationCoverageOracle :: IO ()
runMutationCoverageOracle = do
  let problems = observationProblems <> findingProblems
  unless (null problems) $
    fail (unlines ("MutationCoverageOracle component diagnostics failed:" : map ("  " <>) problems))
  putStrLn
    ( "MutationCoverageOracle: the declared mutation corpus, the five driving suites, and the "
        <> "unwired remainder agree with an independently stated count. A standing gap, not a gate result."
    )

-- | Restated from the corpus. 73 + 70 + 8 + 659 + 374 = 1,184 driven;
-- 5,712 - 1,184 = 4,528 unwired.
expectedObservations :: [(Text, Text)]
expectedObservations =
  [ ("mutation.declared-loci", "5712")
  , ("mutation.driven-loci", "1184")
  , ("mutation.unwired-loci", "4528")
  , ("mutation.driving-suite-count", "5")
  , ("mutation.suite.VALIDATION_SOURCE_DEBT", "validation-source-debt-internal-component=73")
  , ("mutation.suite.VALIDATION_COMPILER_GRAPH", "validation-compiler-source-graph-acquired-component=70")
  , ("mutation.suite.VALIDATION_PHASE_CONTRACT", "validation-phase-contract-component=8")
  , ("mutation.suite.VALIDATION_COMPILER_PLAN", "validation-compiler-component-plan-component=659")
  , ("mutation.suite.VALIDATION_PB_GRAMMAR", "validation-pb-bootstrap-grammar-component=374")
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
    [(observationKey item, observationValue item) | item <- checkObservations mutationCoverageCheck]

-- | Exactly one standing refusal, against the capability that owns the kernel.
-- An integrity code here would mean the two authored counts disagree.
findingProblems :: [String]
findingProblems =
  [ "expected the unwired-mutant refusal alone, observed "
      <> show (map (Text.unpack . findingCode) findings)
  | sort (map findingCode findings) /= ["MUTANT-UNWIRED"]
  ]
    <> [ "the unwired refusal must name its owning capability and the locus count"
       | finding <- findings
       , findingCode finding == "MUTANT-UNWIRED"
       , not ("capability=documentation_suite" `Text.isInfixOf` findingDetail finding)
           || not ("4528" `Text.isInfixOf` findingDetail finding)
       ]
 where
  findings = checkFindings mutationCoverageCheck
