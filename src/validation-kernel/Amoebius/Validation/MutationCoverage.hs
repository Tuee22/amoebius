{-# LANGUAGE OverloadedStrings #-}

-- | Which capability owns making each mutation family executable.
--
-- A mutation macro that no suite drives is not a test. Setting its flag changes
-- production, nothing observes the change, and the macro still appears in every
-- inventory that counts declarations. A corpus counted that way reports
-- coverage it does not carry, which is the exact failure
-- @DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md@ records as @LTD-VAL-002@.
--
-- The kernel declares thousands of mutation loci spanning several capability
-- phases. This module names each family, its diagnostic driver, and the
-- capability that must acquire and reconcile its exact selector and execution
-- sets. It deliberately does not claim a corpus or family cardinality.
--
-- Ownership is independently restated by
-- @test/validation-kernel/MutationCoverageOracle.hs@. Neither side reads
-- @amoebius.cabal@: parsing and validating the execution mapping belongs to
-- the owning capability rather than to this Phase-0 inventory seam.
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

-- | One selector family and the capability that owes its executable proof.
data DrivenSuite = DrivenSuite
  { drivenSuiteName :: Text
  -- ^ The Cabal test-suite that owns the driver.
  , drivenSuiteFamily :: Text
  -- ^ The macro prefix whose loci the suite can reach.
  , drivenSuiteOwnerCapability :: Text
  -- ^ The plan capability that owns this family's cardinality, executable
  -- mapping, applied-change witnesses, and any unwired residue.
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
-- What this module owns instead is inventory well-formedness and explicit
-- ownership, neither of which requires a selector count.  Each family's exact
-- selector set, cardinality, executable mapping, and unwired remainder are
-- acquired and checked by the capability named in
-- 'drivenSuiteOwnerCapability', and belong in that phase's own evidence and
-- @Residue@ row.
-- | The suites that can execute part of the corpus.
--
-- Every row names a Cabal component with a real @Main.hs@ that reaches the
-- oracle-owned selector registry. The row does not claim that every selector
-- has an acquired execution mapping or applied-change witness; its owner must
-- establish those in the owner's gate.
drivenSuites :: [DrivenSuite]
drivenSuites =
  [ DrivenSuite "validation-source-debt-selector-component" "VALIDATION_SOURCE_DEBT_PUBLIC" "repository_layout_conformance"
  , DrivenSuite "validation-source-debt-internal-component" "VALIDATION_SOURCE_DEBT_INTERNAL" "repository_layout_conformance"
  , DrivenSuite "validation-compiler-source-graph-selector-component" "VALIDATION_COMPILER_GRAPH_PUBLIC" "toolchain_spike"
  , DrivenSuite "validation-compiler-source-graph-acquired-component" "VALIDATION_COMPILER_GRAPH_ACQUIRED" "toolchain_spike"
  , DrivenSuite "validation-phase-contract-component" "VALIDATION_PHASE_CONTRACT_PUBLIC" "self_referential_gates"
  , DrivenSuite "validation-phase-contract-internal-component" "VALIDATION_PHASE_CONTRACT_INTERNAL" "self_referential_gates"
  , DrivenSuite "validation-compiler-component-plan-component" "VALIDATION_COMPILER_PLAN" "toolchain_spike"
  , DrivenSuite "validation-pb-bootstrap-grammar-component" "VALIDATION_PB_GRAMMAR" "repository_layout_conformance"
  , DrivenSuite "validation-policy-contract-selector-component" "VALIDATION_POLICY" "self_referential_gates"
  , DrivenSuite "validation-legacy-selector-component" "VALIDATION_LEGACY" "self_referential_gates"
  , DrivenSuite "validation-phase-semantic-selector-component" "VALIDATION_PHASE_SEMANTIC" "self_referential_gates"
  , DrivenSuite "validation-qualification-selector-component" "VALIDATION_QUALIFICATION" "self_referential_gates"
  , DrivenSuite "validation-source-closure-selector-component" "VALIDATION_SOURCE_CLOSURE" "repository_layout_conformance"
  , DrivenSuite "validation-source-consumer-selector-component" "VALIDATION_SOURCE_CONSUMER_PUBLIC" "repository_layout_conformance"
  , DrivenSuite "validation-source-consumer-internal-selector-component" "VALIDATION_SOURCE_CONSUMER_INTERNAL" "repository_layout_conformance"
  , DrivenSuite "validation-documentation-selector-component" "VALIDATION_DOCUMENTATION" "self_referential_gates"
  , DrivenSuite "validation-documentation-internal-selector-component" "VALIDATION_DOCUMENTATION_INTERNAL" "self_referential_gates"
  , DrivenSuite "validation-dispatch-selector-component" "VALIDATION_DISPATCH" "self_referential_gates"
  , DrivenSuite "validation-compiler-buildinfo-selector-component" "VALIDATION_COMPILER_BUILDINFO" "toolchain_spike"
  , DrivenSuite "validation-compiler-elaborated-plan-selector-component" "VALIDATION_COMPILER_ELABORATED" "toolchain_spike"
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
        [ observation
            ("mutation.suite." <> drivenSuiteFamily suite)
            (drivenSuiteName suite)
        | suite <- suites
        ]
          <> [ observation
                ("mutation.owner." <> drivenSuiteFamily suite)
                (drivenSuiteOwnerCapability suite)
             | suite <- suites
             ]
    , checkFindings =
        emptyInventoryFindings
          <> duplicateSuiteFindings
          <> duplicateFamilyFindings
          <> unknownOwnerFindings
    }
 where
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
