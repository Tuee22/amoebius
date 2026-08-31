{-# LANGUAGE OverloadedStrings #-}

-- | How much of the declared mutation corpus can actually be executed.
--
-- A mutation macro that no suite drives is not a test. Setting its flag changes
-- production, nothing observes the change, and the macro still appears in every
-- inventory that counts declarations. A corpus counted that way reports
-- coverage it does not carry, which is the exact failure
-- @DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md@ records as @LTD-VAL-002@.
--
-- The kernel declares thousands of mutation loci and, until the two dead
-- selector drivers were given suites, could execute 151 of them. This module
-- states the corpus and the suites that drive it as typed values and refuses
-- the difference, so the gap is a standing refusal attributed to an owner
-- rather than a silent absence.
--
-- Both numbers are authored here and independently restated by
-- @test/validation-kernel/MutationCoverageOracle.hs@. Neither side derives the
-- other, and neither reads @amoebius.cabal@: parsing the build description is
-- a separate capability whose own parser is not yet validated, so consuming it
-- here would rest this count on an unvalidated subject.
module Amoebius.Validation.MutationCoverage
  ( DrivenSuite (..)
  , SelectionMode (..)
  , declaredMutationLoci
  , drivenSuites
  , milestoneCapabilities
  , mutationCoverageCheck
  , mutationPolicyCheck
  , mutationSelectionMode
  , unwiredMutationLoci
  ) where

import Amoebius.Validation.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.Types (CheckResult (..), finding, observation)
import Data.List (nub, sort)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

-- | One selector suite that can execute a named part of the corpus.
data DrivenSuite = DrivenSuite
  { drivenSuiteName :: Text
  -- ^ The Cabal test-suite that owns the driver.
  , drivenSuiteFamily :: Text
  -- ^ The macro prefix whose loci the suite can reach.
  , drivenSuiteOwnerCapability :: Text
  -- ^ The plan capability that owns closing this family's gap.
  , drivenSuiteLoci :: Int
  -- ^ Loci the suite can select, each with an intent and an impact row.
  }
  deriving (Eq, Show)

-- | Mutation loci the validation kernel declares across every family.
--
-- Authored, not counted from the build description. It changes only when a
-- production module gains or loses a guarded locus, which is exactly when a
-- human should have to restate it.
declaredMutationLoci :: Int
declaredMutationLoci = 5712

-- | The suites that can execute part of the corpus.
--
-- The first four existed. The last two are the drivers that were written,
-- exported, and never called from any @Main.hs@: a 659-locus registry and a
-- 374-locus registry that no Cabal stanza could reach.
drivenSuites :: [DrivenSuite]
drivenSuites =
  [ DrivenSuite "validation-source-debt-internal-component" "VALIDATION_SOURCE_DEBT" "documentation_suite" 73
  , DrivenSuite "validation-compiler-source-graph-acquired-component" "VALIDATION_COMPILER_GRAPH" "documentation_suite" 70
  , DrivenSuite "validation-phase-contract-component" "VALIDATION_PHASE_CONTRACT" "documentation_suite" 8
  , DrivenSuite "validation-compiler-component-plan-component" "VALIDATION_COMPILER_PLAN" "documentation_suite" 659
  , DrivenSuite "validation-pb-bootstrap-grammar-component" "VALIDATION_PB_GRAMMAR" "documentation_suite" 374
  ]

-- | Declared loci that no suite can select.
unwiredMutationLoci :: Int
unwiredMutationLoci = declaredMutationLoci - sum (map drivenSuiteLoci drivenSuites)

-- | The standing count, attributed to the capability that owns each gap.
mutationCoverageCheck :: CheckResult
mutationCoverageCheck =
  CheckResult
    { checkName = "mutation-coverage"
    , checkObservations =
        [ observation "mutation.declared-loci" (showText declaredMutationLoci)
        , observation "mutation.driven-loci" (showText drivenLoci)
        , observation "mutation.unwired-loci" (showText unwiredMutationLoci)
        , observation "mutation.driving-suite-count" (showText (length drivenSuites))
        ]
          <> [ observation
                 ("mutation.suite." <> drivenSuiteFamily suite)
                 (drivenSuiteName suite <> "=" <> showText (drivenSuiteLoci suite))
             | suite <- drivenSuites
             ]
    , checkFindings = integrityFindings <> unwiredFindings
    }
 where
  drivenLoci = sum (map drivenSuiteLoci drivenSuites)

  integrityFindings =
    [ finding
        "MUTANT-COVERAGE-INTEGRITY"
        "amoebius.cabal"
        "the driven locus total exceeds the declared corpus, so one of the two authored counts is wrong"
    | drivenLoci > declaredMutationLoci
    ]
      <> [ finding
             "MUTANT-COVERAGE-INTEGRITY"
             "amoebius.cabal"
             ("a driving suite declares a non-positive locus count: " <> drivenSuiteName suite)
         | suite <- drivenSuites
         , drivenSuiteLoci suite <= 0
         ]

  -- An unwired locus is reported against the capability that owns it, so the
  -- count is a per-phase obligation rather than one corpus-wide number nobody
  -- owns. Every family resolves to the kernel's own capability today because
  -- the kernel is that capability's deliverable; a family owned elsewhere would
  -- carry its own owner here without changing the shape of the refusal.
  unwiredFindings =
    [ finding
        "MUTANT-UNWIRED"
        "src/validation-kernel/"
        ( "capability="
            <> owner
            <> " has "
            <> showText unwiredMutationLoci
            <> " declared mutation loci that no selector suite can execute; each changes production"
            <> " under its flag while nothing observes the change, so it counts as coverage without"
            <> " carrying any. Driving them requires an exact case that observes the changed locus,"
            <> " an intent row, and an impact row, none of which a flag declaration supplies."
        )
    | unwiredMutationLoci > 0
    , owner <- ["documentation_suite"]
    ]

-- | How much of the corpus a gate runs.
--
-- Mutation effort is bounded by what a gate claims. Running the whole corpus at
-- every gate is what made the corpus unbounded in the first place: an atomic
-- selector per acceptance conjunct, demanded everywhere, produces thousands of
-- loci nobody drives, which is the 'unwiredMutationLoci' number above.
data SelectionMode
  = -- | The complete selector corpus. Reserved for a milestone.
    MatrixAll
  | -- | Exactly the selectors whose impact set meets the phase's own contract
    -- rows. Every other gate.
    Impacted
  deriving (Eq, Show)

-- | The capabilities whose gates run the complete corpus.
--
-- Named as capabilities and resolved through the identity table, never as
-- ordinal literals: a rebalance moves ordinals, and a milestone list written in
-- ordinals would keep pointing at whatever phase inherited the number. A split
-- must hand the milestone to a named successor, which is a visible edit here
-- rather than a silent drift.
--
-- Each entry closes a band or a role boundary, so it is the point at which a
-- regression anywhere beneath it must still be caught.
milestoneCapabilities :: [Text]
milestoneCapabilities =
  -- role boundaries
  [ "self_referential_gates"
  , "host_assert_cli"
  , "host_ensure_kernel"
  , "linux_engine_bringup"
  -- band closures
  , "repository_layout_conformance"
  , "calculus_composition"
  , "compile_fail_harness"
  , "conformance_gate_generator"
  , "chain_kernel_boundary"
  , "test_workflow_algebra"
  -- live closures
  , "live_dsl_deploy"
  , "determinism_jitcache"
  , "test_topology_live"
  ]

-- | The selection mode a capability's gate runs under.
mutationSelectionMode :: Text -> SelectionMode
mutationSelectionMode capability
  | capability `elem` milestoneCapabilities = MatrixAll
  | otherwise = Impacted

-- | The rulebook states the same milestone set in prose. Haskell owns the
-- value; this checks that the prose says what the value says, in both
-- directions, which is a correspondence obligation rather than a semantic
-- derivation from prose.
mutationPolicyCheck :: [(FilePath, Text)] -> CheckResult
mutationPolicyCheck supplied =
  CheckResult
    { checkName = "mutation-policy"
    , checkObservations =
        [ observation "mutation.milestone-count" (showText (length milestoneCapabilities))
        , observation "mutation.ordinary-gate-count" (showText ordinaryCount)
        , observation "mutation.policy-section-found" (showText (not (Text.null policySection)))
        ]
    , checkFindings = duplicateFindings <> unresolvedFindings <> correspondenceFindings
    }
 where
  ordinaryCount = length PhaseIdentity.allPhaseIdentities - length milestoneCapabilities

  duplicateFindings =
    [ finding
        "MUTANT-POLICY-DUPLICATE"
        "Amoebius.Validation.MutationCoverage.milestoneCapabilities"
        ("a milestone capability is named more than once: " <> capability)
    | capability <- nub milestoneCapabilities
    , length (filter (== capability) milestoneCapabilities) > 1
    ]

  -- A milestone naming a capability no phase carries is the exact rot the
  -- capability indirection exists to prevent, so it refuses rather than being
  -- silently skipped.
  unresolvedFindings =
    [ finding
        "MUTANT-POLICY-UNRESOLVED"
        "Amoebius.Validation.MutationCoverage.milestoneCapabilities"
        ("a milestone names a capability no phase provides: " <> capability)
    | capability <- milestoneCapabilities
    , PhaseIdentity.lookupCapabilityOrdinal capability == Nothing
    ]

  knownCapabilities =
    Set.fromList (map PhaseIdentity.phaseIdentityCapability PhaseIdentity.allPhaseIdentities)

  policySection = sectionBody "### M.3 " gateIntegrityText
  gateIntegrityText =
    Text.concat
      [ contents
      | (path, contents) <- supplied
      , normaliseSlashes path == "DEVELOPMENT_PLAN/development_plan_gate_integrity.md"
      ]

  prosed =
    Set.fromList
      [ token
      | token <- codeSpans policySection
      , Set.member token knownCapabilities
      ]
  declared = Set.fromList milestoneCapabilities

  correspondenceFindings =
    [ finding
        "MUTANT-POLICY-PROSE-MISSING"
        "DEVELOPMENT_PLAN/development_plan_gate_integrity.md"
        ("section M.3 does not name the milestone capability: " <> capability)
    | not (Text.null policySection)
    , capability <- sort (Set.toList (Set.difference declared prosed))
    ]
      <> [ finding
             "MUTANT-POLICY-PROSE-EXTRA"
             "DEVELOPMENT_PLAN/development_plan_gate_integrity.md"
             ("section M.3 names a capability that is not a declared milestone: " <> capability)
         | not (Text.null policySection)
         , capability <- sort (Set.toList (Set.difference prosed declared))
         ]
      <> [ finding
             "MUTANT-POLICY-PROSE-ABSENT"
             "DEVELOPMENT_PLAN/development_plan_gate_integrity.md"
             "section M.3 is absent from the supplied corpus, so the milestone set has no prose correspondence"
         | Text.null policySection
         ]

normaliseSlashes :: FilePath -> Text
normaliseSlashes = Text.replace "\\" "/" . Text.pack

-- | The body of a heading, up to the next heading of the same depth.
sectionBody :: Text -> Text -> Text
sectionBody heading source = case Text.breakOn heading source of
  (_, rest)
    | Text.null rest -> ""
    | otherwise ->
        let body = Text.drop (Text.length heading) rest
         in fst (Text.breakOn "\n### " body)

-- | Backticked tokens, which is where a capability name appears in prose.
codeSpans :: Text -> [Text]
codeSpans source = go source
 where
  go remaining = case Text.breakOn "`" remaining of
    (_, rest)
      | Text.null rest -> []
      | otherwise ->
          let body = Text.drop 1 rest
              (token, after) = Text.breakOn "`" body
           in [token | not (Text.null token)] <> go (Text.drop 1 after)


showText :: Show value => value -> Text
showText = Text.pack . show
