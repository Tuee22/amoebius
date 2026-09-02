{-# LANGUAGE OverloadedStrings #-}

-- | Independent expectations for the mutation-coverage inventory.
--
-- This oracle asserts properties authored from the requirement, never a corpus
-- cardinality restated from the subject.  A restated total is a change
-- tripwire rather than an expectation, and because the coverage check runs
-- inside the documentation-suite gate — which every later phase re-derives — a
-- total here would redden Phase 0 for work Phase 0 does not own.
--
-- It also does not call the subject's decision function.  M.2 forbids an
-- oracle importing or calling the decision it checks, so the milestone
-- classification is compared against an authored literal through the
-- observation the policy check publishes.
module MutationCoverageOracle
  ( runMutationCoverageOracle
  ) where

import Amoebius.Validation.MutationCoverage
  ( DrivenSuite (..)
  , mutationCoverageCheck
  , mutationCoverageCheckFor
  , mutationPolicyCheck
  )
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Data.Text (Text)
import Data.Text qualified as Text

runMutationCoverageOracle :: IO ()
runMutationCoverageOracle = do
  let problems = inventoryProblems <> findingProblems <> policyProblems
  unless (null problems) $
    fail (unlines ("MutationCoverageOracle component diagnostics failed:" : map ("  " <>) problems))
  putStrLn
    ( "MutationCoverageOracle: the selector inventory is well formed, each malformation is refused at its "
        <> "exact code, and the published milestone set agrees with an independently authored list. An inventory "
        <> "check, not a mutation matrix or gate result; family cardinality is owed by each owning capability."
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
  [ "published milestone set does not match the independently authored list, observed "
      <> show (Text.unpack observedMilestones)
  | observedMilestones /= Text.intercalate "," expectedMilestones
  ]
    <> [ "an ordinary capability was published as a milestone: " <> Text.unpack capability
       | capability <- expectedOrdinary
       , capability `elem` Text.splitOn "," observedMilestones
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
  observedMilestones =
    head
      ( [ observationValue item
        | item <- checkObservations (mutationPolicyCheck syntheticRulebook)
        , observationKey item == "mutation.milestone-capabilities"
        ]
          <> ["<absent>"]
      )


-- | A well-formed two-row inventory, authored here rather than taken from the
-- subject, and the minimally different malformations of it.
--
-- Each negative differs from 'wellFormedInventory' in exactly one dimension and
-- must be refused with one exact code, which is what separates a refusal that
-- names a defect from one that merely fails.
wellFormedInventory :: [DrivenSuite]
wellFormedInventory =
  [ DrivenSuite "alpha-selector-component" "ORACLE_FAMILY_ALPHA" "documentation_suite" 3
  , DrivenSuite "beta-selector-component" "ORACLE_FAMILY_BETA" "documentation_suite" 5
  ]

inventoryProblems :: [String]
inventoryProblems =
  [ "a well-formed inventory must produce no coverage refusal, observed " <> show (codesFor wellFormedInventory)
  | not (null (codesFor wellFormedInventory))
  ]
    <> exactly "an empty inventory" [] ["MUTANT-COVERAGE-INVENTORY-EMPTY"]
    <> exactly
      "a duplicated driving suite"
      [head wellFormedInventory, head wellFormedInventory]
      ["MUTANT-COVERAGE-DUPLICATE-SUITE", "MUTANT-COVERAGE-DUPLICATE-FAMILY"]
    <> exactly
      "two drivers for one family"
      [ head wellFormedInventory
      , (wellFormedInventory !! 1) {drivenSuiteFamily = "ORACLE_FAMILY_ALPHA"}
      ]
      ["MUTANT-COVERAGE-DUPLICATE-FAMILY"]
    <> exactly
      "a non-positive locus count"
      [head wellFormedInventory, (wellFormedInventory !! 1) {drivenSuiteLoci = 0}]
      ["MUTANT-COVERAGE-INTEGRITY"]
    <> exactly
      "an owner outside the phase-identity table"
      [head wellFormedInventory, (wellFormedInventory !! 1) {drivenSuiteOwnerCapability = "no_such_capability"}]
      ["MUTANT-COVERAGE-OWNER-UNKNOWN"]
 where
  codesFor suites = map findingCode (checkFindings (mutationCoverageCheckFor suites))
  exactly label suites expected =
    [ label <> " must be refused with exactly " <> show (map Text.unpack expected) <> ", observed " <> show (map Text.unpack (codesFor suites))
    | codesFor suites /= expected
    ]

-- | The live inventory must be well formed.  Its cardinality is not asserted:
-- each family's count and unwired remainder are owed by the capability named in
-- its owner field, in that phase's own residue.
findingProblems :: [String]
findingProblems =
  [ "expected no mutation-coverage refusal for the live inventory, observed "
      <> show (map (Text.unpack . findingCode) findings)
  | not (null findings)
  ]
    <> [ "the live inventory published no per-owner total"
       | not (any (Text.isPrefixOf "mutation.owner." . observationKey) (checkObservations mutationCoverageCheck))
       ]
 where
  findings = checkFindings mutationCoverageCheck
