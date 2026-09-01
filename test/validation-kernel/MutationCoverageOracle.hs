{-# LANGUAGE OverloadedStrings #-}

-- | Independent expectations for the mutation-coverage count.
--
-- The numbers here are restated from the corpus, not read back from the
-- module. The kernel declares 5,844 Cabal mutation flags; twenty selector
-- suites between them can execute all 5,844 declared loci; no declared flag remains
-- unwired and no guarded selector identity is absent from the Cabal corpus.
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
import Data.Text (Text)
import Data.Text qualified as Text

runMutationCoverageOracle :: IO ()
runMutationCoverageOracle = do
  let problems = observationProblems <> findingProblems <> policyProblems
  unless (null problems) $
    fail (unlines ("MutationCoverageOracle component diagnostics failed:" : map ("  " <>) problems))
  putStrLn
    ( "MutationCoverageOracle: the declared mutation corpus, the twenty driving suites, the "
        <> "unwired remainder, and the selector-only residue agree with independently stated counts; the milestone set and its "
        <> "selection modes agree with an independently restated list. An inventory check, not a mutation matrix or gate result."
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


-- | Restated from the corpus. The twenty independently named executable
-- suites drive all 5,844 declared loci.
expectedObservations :: [(Text, Text)]
expectedObservations =
  [ ("mutation.declared-loci", "5844")
  , ("mutation.driven-loci", "5844")
  , ("mutation.unwired-loci", "0")
  , ("mutation.selector-only-loci", "0")
  , ("mutation.driving-suite-count", "20")
  , ("mutation.suite.VALIDATION_SOURCE_DEBT_PUBLIC", "validation-source-debt-selector-component=188")
  , ("mutation.suite.VALIDATION_SOURCE_DEBT_INTERNAL", "validation-source-debt-internal-component=73")
  , ("mutation.suite.VALIDATION_COMPILER_GRAPH_PUBLIC", "validation-compiler-source-graph-selector-component=275")
  , ("mutation.suite.VALIDATION_COMPILER_GRAPH_ACQUIRED", "validation-compiler-source-graph-acquired-component=70")
  , ("mutation.suite.VALIDATION_PHASE_CONTRACT_PUBLIC", "validation-phase-contract-component=134")
  , ("mutation.suite.VALIDATION_PHASE_CONTRACT_INTERNAL", "validation-phase-contract-internal-component=8")
  , ("mutation.suite.VALIDATION_COMPILER_PLAN", "validation-compiler-component-plan-component=659")
  , ("mutation.suite.VALIDATION_PB_GRAMMAR", "validation-pb-bootstrap-grammar-component=374")
  , ("mutation.suite.VALIDATION_POLICY", "validation-policy-contract-selector-component=194")
  , ("mutation.suite.VALIDATION_LEGACY", "validation-legacy-selector-component=1320")
  , ("mutation.suite.VALIDATION_PHASE_SEMANTIC", "validation-phase-semantic-selector-component=36")
  , ("mutation.suite.VALIDATION_QUALIFICATION", "validation-qualification-selector-component=1")
  , ("mutation.suite.VALIDATION_SOURCE_CLOSURE", "validation-source-closure-selector-component=607")
  , ("mutation.suite.VALIDATION_SOURCE_CONSUMER_PUBLIC", "validation-source-consumer-selector-component=476")
  , ("mutation.suite.VALIDATION_SOURCE_CONSUMER_INTERNAL", "validation-source-consumer-internal-selector-component=292")
  , ("mutation.suite.VALIDATION_DOCUMENTATION", "validation-documentation-selector-component=64")
  , ("mutation.suite.VALIDATION_DOCUMENTATION_INTERNAL", "validation-documentation-internal-selector-component=91")
  , ("mutation.suite.VALIDATION_DISPATCH", "validation-dispatch-selector-component=26")
  , ("mutation.suite.VALIDATION_COMPILER_BUILDINFO", "validation-compiler-buildinfo-selector-component=614")
  , ("mutation.suite.VALIDATION_COMPILER_ELABORATED", "validation-compiler-elaborated-plan-selector-component=342")
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

-- | Complete selector wiring produces no coverage refusal.
findingProblems :: [String]
findingProblems =
  [ "expected no mutation-coverage refusal, observed "
      <> show (map (Text.unpack . findingCode) findings)
  | not (null findings)
  ]
 where
  findings = checkFindings mutationCoverageCheck
