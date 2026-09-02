{-# LANGUAGE OverloadedStrings #-}

-- | How much of the declared mutation corpus can actually be executed.
--
-- A mutation macro that no suite drives is not a test. Setting its flag changes
-- production, nothing observes the change, and the macro still appears in every
-- inventory that counts declarations. A corpus counted that way reports
-- coverage it does not carry, which is the exact failure
-- @DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md@ records as @LTD-VAL-002@.
--
-- The kernel declares thousands of mutation loci and, until the exported
-- selector registries were given suites, could execute only a small fraction
-- of them. This module states the corpus and the suites that drive it as typed
-- values and refuses the difference, so the gap is a standing refusal
-- attributed to an owner rather than a silent absence.
--
-- Both numbers are authored here and independently restated by
-- @test/validation-kernel/MutationCoverageOracle.hs@. Neither side derives the
-- other, and neither reads @amoebius.cabal@: parsing the build description is
-- a separate capability whose own parser is not yet validated, so consuming it
-- here would rest this count on an unvalidated subject.
module Amoebius.Validation.MutationCoverage
  ( DrivenSuite (..)
  , SelectionMode (..)
  , drivenSuites
  , milestoneCapabilities
  , mutationCoverageCheck
  , mutationCoverageCheckFor
  , mutationPolicyCheck
  , mutationSelectionMode
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

-- | Corpus cardinality is deliberately not declared here.
--
-- A corpus-wide total in this module was Phase-0 subject, because
-- 'mutationCoverageCheck' is part of the documentation-suite run and
-- @Dispatch.checkAcquiredPhaseChain@ re-derives gate 0 inside every later
-- phase's gate.  A total therefore changed whenever any later phase added or
-- retired a selector, reddening a phase that owns none of that work and
-- forcing it to be reopened after closing.
--
-- The total was also unknowable here.  This module cannot see the selector
-- registries, which live beside the oracles in @test/@, and it must not consume
-- the build description, whose parser is a separate unvalidated capability.  A
-- declared total could only ever be a restated literal, and a literal compared
-- against another literal authored to agree with it refuses nothing.
--
-- What this module owns instead is inventory well-formedness, which does not
-- move when a corpus grows.  Each family's cardinality and its unwired
-- remainder are owed by the capability named in 'drivenSuiteOwnerCapability',
-- and belong in that phase's own @Residue@ row.
-- | The suites that can execute part of the corpus.
--
-- Every row names a Cabal component with a real @Main.hs@ that reaches the
-- oracle-owned selector registry. A registry exported only from an oracle does
-- not belong here: without this executable component it remains unwired.
drivenSuites :: [DrivenSuite]
drivenSuites =
  [ DrivenSuite "validation-source-debt-selector-component" "VALIDATION_SOURCE_DEBT_PUBLIC" "documentation_suite" 188
  , DrivenSuite "validation-source-debt-internal-component" "VALIDATION_SOURCE_DEBT_INTERNAL" "documentation_suite" 73
  , DrivenSuite "validation-compiler-source-graph-selector-component" "VALIDATION_COMPILER_GRAPH_PUBLIC" "documentation_suite" 275
  , DrivenSuite "validation-compiler-source-graph-acquired-component" "VALIDATION_COMPILER_GRAPH_ACQUIRED" "documentation_suite" 70
  , DrivenSuite "validation-phase-contract-component" "VALIDATION_PHASE_CONTRACT_PUBLIC" "documentation_suite" 134
  , DrivenSuite "validation-phase-contract-internal-component" "VALIDATION_PHASE_CONTRACT_INTERNAL" "documentation_suite" 8
  , DrivenSuite "validation-compiler-component-plan-component" "VALIDATION_COMPILER_PLAN" "documentation_suite" 659
  , DrivenSuite "validation-pb-bootstrap-grammar-component" "VALIDATION_PB_GRAMMAR" "documentation_suite" 374
  , DrivenSuite "validation-policy-contract-selector-component" "VALIDATION_POLICY" "documentation_suite" 194
  , DrivenSuite "validation-legacy-selector-component" "VALIDATION_LEGACY" "documentation_suite" 1320
  , DrivenSuite "validation-phase-semantic-selector-component" "VALIDATION_PHASE_SEMANTIC" "documentation_suite" 36
  , DrivenSuite "validation-qualification-selector-component" "VALIDATION_QUALIFICATION" "documentation_suite" 1
  , DrivenSuite "validation-source-closure-selector-component" "VALIDATION_SOURCE_CLOSURE" "documentation_suite" 607
  , DrivenSuite "validation-source-consumer-selector-component" "VALIDATION_SOURCE_CONSUMER_PUBLIC" "documentation_suite" 476
  , DrivenSuite "validation-source-consumer-internal-selector-component" "VALIDATION_SOURCE_CONSUMER_INTERNAL" "documentation_suite" 292
  , DrivenSuite "validation-documentation-selector-component" "VALIDATION_DOCUMENTATION" "documentation_suite" 64
  , DrivenSuite "validation-documentation-internal-selector-component" "VALIDATION_DOCUMENTATION_INTERNAL" "documentation_suite" 91
  , DrivenSuite "validation-dispatch-selector-component" "VALIDATION_DISPATCH" "documentation_suite" 26
  , DrivenSuite "validation-compiler-buildinfo-selector-component" "VALIDATION_COMPILER_BUILDINFO" "documentation_suite" 614
  , DrivenSuite "validation-compiler-elaborated-plan-selector-component" "VALIDATION_COMPILER_ELABORATED" "documentation_suite" 342
  ]


-- | Inventory well-formedness for the selector corpus.
--
-- Every finding below can actually fire on a malformed inventory, which the
-- previous corpus-wide comparison could not: it compared one authored literal
-- against a second authored literal chosen to equal it, so its difference was
-- zero by construction and the refusals it guarded were unreachable.
mutationCoverageCheck :: CheckResult
mutationCoverageCheck = mutationCoverageCheckFor drivenSuites

-- | The same check over a supplied inventory.
--
-- An independently authored oracle needs this seam to assert an exact refusal
-- at an exact locus for each malformed inventory, which it cannot do against a
-- constant.  It decides nothing a caller can use to mint a pass: the result is
-- an ordinary 'CheckResult'.
mutationCoverageCheckFor :: [DrivenSuite] -> CheckResult
mutationCoverageCheckFor suites =
  CheckResult
    { checkName = "mutation-coverage"
    , checkObservations =
        [ observation "mutation.driving-suite-count" (showText (length suites))
        , observation "mutation.driven-loci" (showText (sum (map drivenSuiteLoci suites)))
        ]
          <> [ observation ("mutation.owner." <> owner) (showText total)
             | (owner, total) <- ownerTotals
             ]
          <> [ observation
                 ("mutation.suite." <> drivenSuiteFamily suite)
                 (drivenSuiteName suite <> "=" <> showText (drivenSuiteLoci suite))
             | suite <- suites
             ]
    , checkFindings =
        emptyInventoryFindings
          <> duplicateSuiteFindings
          <> duplicateFamilyFindings
          <> nonPositiveFindings
          <> unknownOwnerFindings
    }
 where
  owners = nub (map drivenSuiteOwnerCapability suites)
  ownerTotals =
    [ (owner, sum [drivenSuiteLoci suite | suite <- suites, drivenSuiteOwnerCapability suite == owner])
    | owner <- sort owners
    ]

  emptyInventoryFindings =
    [ finding
        "MUTANT-COVERAGE-INVENTORY-EMPTY"
        "src/validation-kernel/Amoebius/Validation/MutationCoverage.hs"
        "no driving suite is declared, so no declared locus can be executed"
    | null suites
    ]

  duplicateSuiteFindings =
    [ finding
        "MUTANT-COVERAGE-DUPLICATE-SUITE"
        "amoebius.cabal"
        ("a driving suite is declared more than once: " <> name)
    | name <- repeated (map drivenSuiteName suites)
    ]

  duplicateFamilyFindings =
    [ finding
        "MUTANT-COVERAGE-DUPLICATE-FAMILY"
        "amoebius.cabal"
        ("a macro family names more than one driver, so a red result cannot be attributed: " <> family)
    | family <- repeated (map drivenSuiteFamily suites)
    ]

  nonPositiveFindings =
    [ finding
        "MUTANT-COVERAGE-INTEGRITY"
        "amoebius.cabal"
        ("a driving suite declares a non-positive locus count: " <> drivenSuiteName suite)
    | suite <- suites
    , drivenSuiteLoci suite <= 0
    ]

  -- An owner outside the compiled phase-identity table cannot carry the
  -- family's cardinality or its unwired remainder in any @Residue@ row, so the
  -- obligation would be owed by nobody.
  unknownOwnerFindings =
    [ finding
        "MUTANT-COVERAGE-OWNER-UNKNOWN"
        "DEVELOPMENT_PLAN/README.md"
        ( "a driving suite names an owner capability absent from the phase-identity table: "
            <> drivenSuiteOwnerCapability suite
        )
    | suite <- suites
    , PhaseIdentity.lookupCapabilityOrdinal (drivenSuiteOwnerCapability suite) == Nothing
    ]

-- | Values occurring more than once, each reported once, in order.
repeated :: Ord value => [value] -> [value]
repeated values = nub [value | (value, count) <- counts, count > (1 :: Int)]
 where
  counts = [(value, length (filter (== value) values)) | value <- nub values]

-- | How much of the corpus a gate runs.
--
-- Mutation effort is bounded by what a gate claims. Running the whole corpus at
-- every gate is what made the corpus unbounded in the first place: an atomic
-- selector per acceptance conjunct, demanded everywhere, produces thousands of
-- loci nobody drives, which is a remainder each owning capability carries.
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
        [ observation "mutation.milestone-capabilities" (Text.intercalate "," (sort milestoneCapabilities))
        , observation "mutation.milestone-count" (showText (length milestoneCapabilities))
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
