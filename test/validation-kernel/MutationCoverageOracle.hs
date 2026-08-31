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

import Amoebius.Validation.MutationCoverage
  ( SelectionMode (..)
  , mutationCoverageCheck
  , mutationPolicyCheck
  , mutationSelectionMode
  )
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text

runMutationCoverageOracle :: IO ()
runMutationCoverageOracle = do
  let problems = observationProblems <> findingProblems <> policyProblems
  unless (null problems) $
    fail (unlines ("MutationCoverageOracle component diagnostics failed:" : map ("  " <>) problems))
  putStrLn
    ( "MutationCoverageOracle: the declared mutation corpus, the five driving suites, and the "
        <> "unwired remainder agree with an independently stated count; the milestone set and its "
        <> "selection modes agree with an independently restated list. A standing gap, not a gate result."
    )

-- | The thirteen capabilities whose gates run the complete corpus, restated
-- here from the rulebook rather than read back from the module. Every other
-- gate runs only the selectors its own contract rows reach.
--
-- The list is authored as a literal precisely so that changing production's
-- milestone set without changing the rulebook, or the reverse, fails here.
expectedMilestones :: [Text]
expectedMilestones =
  [ "calculus_composition"
  , "chain_kernel_boundary"
  , "compile_fail_harness"
  , "conformance_gate_generator"
  , "determinism_jitcache"
  , "host_assert_cli"
  , "host_ensure_kernel"
  , "linux_engine_bringup"
  , "live_dsl_deploy"
  , "repository_layout_conformance"
  , "self_referential_gates"
  , "test_topology_live"
  , "test_workflow_algebra"
  ]

-- | A capability that is deliberately not a milestone. An ordinary gate runs
-- the impacted selection, not the matrix.
expectedOrdinary :: [Text]
expectedOrdinary =
  [ "artifact_calculus"
  , "app_tenancy"
  , "documentation_suite"
  , "provision_seal"
  , "vault_pki"
  ]

-- | A minimal section-M.3 body naming exactly the expected milestones, authored
-- here rather than read from the rulebook, so the correspondence check is
-- exercised against a corpus this oracle controls.
syntheticRulebook :: [(FilePath, Text)]
syntheticRulebook =
  [ ( "DEVELOPMENT_PLAN/development_plan_gate_integrity.md"
    , Text.unlines
        ( ["### M.3 Mutants must prove that they changed the subject", "", "The milestones are:", ""]
            <> ["- `" <> capability <> "`;" | capability <- expectedMilestones]
            <> ["", "### M.4 Harness qualification precedes every candidate", "", "Unrelated."]
        )
    )
  ]

policyProblems :: [String]
policyProblems =
  [ "selection mode for milestone " <> Text.unpack capability <> " must be MatrixAll"
  | capability <- expectedMilestones
  , mutationSelectionMode capability /= MatrixAll
  ]
    <> [ "selection mode for ordinary gate " <> Text.unpack capability <> " must be Impacted"
       | capability <- expectedOrdinary
       , mutationSelectionMode capability /= Impacted
       ]
    <> [ "against a rulebook naming exactly the expected milestones the policy check must be clean, observed "
           <> show (map (Text.unpack . findingCode) (checkFindings (mutationPolicyCheck syntheticRulebook)))
       | not (null (checkFindings (mutationPolicyCheck syntheticRulebook)))
       ]
    <> [ "a rulebook omitting a milestone must be reported missing, observed " <> show observedOmitted
       | observedOmitted /= ["MUTANT-POLICY-PROSE-MISSING"]
       ]
    <> [ "a rulebook naming a non-milestone capability must be reported extra, observed " <> show observedExtra
       | observedExtra /= ["MUTANT-POLICY-PROSE-EXTRA"]
       ]
    <> [ "an absent section M.3 must refuse, observed " <> show observedAbsent
       | observedAbsent /= ["MUTANT-POLICY-PROSE-ABSENT"]
       ]
 where
  observedOmitted =
    map (Text.unpack . findingCode) (checkFindings (mutationPolicyCheck (mutate (Text.replace "- `test_topology_live`;" ""))))
  observedExtra =
    map (Text.unpack . findingCode) (checkFindings (mutationPolicyCheck (mutate (Text.replace "- `live_dsl_deploy`;" "- `live_dsl_deploy`;\n- `app_tenancy`;"))))
  observedAbsent = map (Text.unpack . findingCode) (checkFindings (mutationPolicyCheck []))
  mutate transform = [(path, transform contents) | (path, contents) <- syntheticRulebook]


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
