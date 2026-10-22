{-# LANGUAGE OverloadedStrings #-}

-- | The closed legacy-identity inventory and its owner map, by capability.
--
-- The reader-facing explanation lives in @DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md@;
-- this module is the executable identity: which identifiers exist and which phase
-- capability owns each closure. An owner is a capability, never an ordinal, so a
-- re-sequence cannot silently move it.
module Amoebius.Plan.Legacy
  ( LegacyId (..)
  , LegacyOwner (..)
  , LegacyLifecycle
  , LegacyScope
  , LegacyAnalyzerKey
  , LegacyCaseKey
  , LegacyRequirement
  , allLegacyIds
  , legacyRequirements
  , legacyRequirement
  , legacyBootstrapSourceRequirement
  , legacyRequirementId
  , legacyRequirementOwner
  , legacyRequirementLifecycle
  , legacyRequirementRetired
  , legacyRequirementScope
  , legacyRequirementAnalyzer
  , legacyRequirementCases
  , renderLegacyLifecycle
  , renderLegacyScope
  , renderLegacyAnalyzerKey
  , renderLegacyCaseKey
  , legacyOwner
  , legacyOwnerOrdinal
  , legacyOwnerProblems
  , legacyIdsOwnedBy
  , parseLegacyId
  , renderLegacyId
  ) where

import Amoebius.Plan.PhaseIdentity (lookupCapabilityOrdinal)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)

data LegacyId
  = LtdSrc000
  | LtdSrc001
  | LtdSrc002
  | LtdSrc003
  | LtdSrc004
  | LtdSrc005
  | LtdSrc006
  | LtdSrc007
  | LtdSrc008
  | LtdSrc009
  | LtdMeta001
  | LtdVal001
  | LtdVal002
  | LtdVal003
  | LtdVal004
  | LtdVal005
  | LtdVal006
  | LtdVal007
  | LtdVal008
  | LtdDoc001
  | LtdName001
  | LtdHost001
  | LtdHost002
  | LtdImg001
  | LtdRun001
  | LtdSeed001
  | LtdSeed002
  | LtdBoot001
  | LtdKrn001
  | LtdKrn002
  | LtdKrn003
  | LtdDsl001
  | LtdDsl002
  | LtdDsl003
  | LtdDsl004
  | LtdDsl005
  | LtdDsl006
  | LtdDsl007
  | LtdDsl008
  | LtdDsl009
  | LtdLib001
  | LtdLib002
  | LtdUi001
  | LtdHelper001
  deriving (Bounded, Enum, Eq, Ord, Show)

allLegacyIds :: [LegacyId]
allLegacyIds = [minBound .. maxBound]

-- These are declarations, never observations or closure evidence. Constructors
-- remain private, including the case/key wrappers, so a consumer cannot invent
-- a requirement, replace its cases by record update, or introduce a retired row.
-- Retirement records a completed owning gate; it grants no current-run authority.
-- The runner still requires exact-source qualification and a full predecessor pass.
data LegacyLifecycle = LegacyActive | LegacyRetired deriving (Eq, Ord, Show)
data LegacyScope = LegacySnapshot | LegacyCapturedBootstrap deriving (Eq, Ord, Show)
newtype LegacyAnalyzerKey = LegacyAnalyzerKey Text deriving (Eq, Ord, Show)
newtype LegacyCaseKey = LegacyCaseKey Text deriving (Eq, Ord, Show)
data LegacyRequirement = LegacyRequirement LegacyId LegacyLifecycle LegacyScope LegacyAnalyzerKey (NonEmpty LegacyCaseKey)
  deriving (Eq, Show)

legacyRequirementId :: LegacyRequirement -> LegacyId
legacyRequirementId (LegacyRequirement identifier _ _ _ _) = identifier
legacyRequirementOwner :: LegacyRequirement -> LegacyOwner
legacyRequirementOwner = legacyOwner . legacyRequirementId
legacyRequirementLifecycle :: LegacyRequirement -> LegacyLifecycle
legacyRequirementLifecycle (LegacyRequirement _ lifecycle _ _ _) = lifecycle
legacyRequirementRetired :: LegacyRequirement -> Bool
legacyRequirementRetired requirement = legacyRequirementLifecycle requirement == LegacyRetired
legacyRequirementScope :: LegacyRequirement -> LegacyScope
legacyRequirementScope (LegacyRequirement _ _ scope _ _) = scope
legacyRequirementAnalyzer :: LegacyRequirement -> LegacyAnalyzerKey
legacyRequirementAnalyzer (LegacyRequirement _ _ _ analyzer _) = analyzer
legacyRequirementCases :: LegacyRequirement -> NonEmpty LegacyCaseKey
legacyRequirementCases (LegacyRequirement _ _ _ _ cases) = cases
renderLegacyLifecycle :: LegacyLifecycle -> Text
renderLegacyLifecycle LegacyActive = "active"
renderLegacyLifecycle LegacyRetired = "retired"
renderLegacyScope :: LegacyScope -> Text
renderLegacyScope LegacySnapshot = "snapshot"
renderLegacyScope LegacyCapturedBootstrap = "captured-bootstrap"
renderLegacyAnalyzerKey :: LegacyAnalyzerKey -> Text
renderLegacyAnalyzerKey (LegacyAnalyzerKey key) = key
renderLegacyCaseKey :: LegacyCaseKey -> Text
renderLegacyCaseKey (LegacyCaseKey key) = key

-- One total declaration per identity. Later-owned declarations authorize no
-- implementation, execution, deferral-as-closure, or hardware observation.
legacyRequirements :: [LegacyRequirement]
legacyRequirements = map legacyRequirement allLegacyIds

-- Total lookup returns only the canonical declaration for a closed identity.
legacyRequirement :: LegacyId -> LegacyRequirement
legacyRequirement identifier =
  let (analyzer, cases) = requiredBinding identifier
      lifecycle = if identifier `elem` [LtdVal001, LtdVal002, LtdVal003, LtdVal004, LtdVal006, LtdKrn001, LtdKrn002, LtdKrn003, LtdBoot001, LtdSrc007, LtdSrc009] then LegacyRetired else LegacyActive
  in LegacyRequirement identifier lifecycle LegacySnapshot analyzer cases

-- The genesis source check supplies no whole-snapshot zero and cannot retire
-- the later-owned bootstrap binding or establish runtime handoff behavior.
legacyBootstrapSourceRequirement :: LegacyRequirement
legacyBootstrapSourceRequirement = LegacyRequirement LtdSrc008 LegacyActive LegacyCapturedBootstrap
  (LegacyAnalyzerKey "bootstrap-structure")
  (LegacyCaseKey "dynamic-import" :| map LegacyCaseKey ["undeclared-effect", "command-dispatch", "argv-rewritten", "unscanned-syntax"])

requiredBinding :: LegacyId -> (LegacyAnalyzerKey, NonEmpty LegacyCaseKey)
requiredBinding identifier = case identifier of
  LtdSrc000 -> binding "source-graph" "path-omitted" ["mode-changed", "bytes-changed", "foreign-behavior-disguised", "effect-unattributed"]
  LtdSrc001 -> binding "tool-source" "tracked-python-gate" ["renamed-tool-root"]
  LtdSrc002 -> binding "dhall-source" "tracked-dhall" ["tracked-dhall-registry", "roundtrip-changed"]
  LtdSrc003 -> binding "wire-schema" "tracked-proto" ["field-number-changed", "vendor-attribution-duplicated"]
  LtdSrc004 -> binding "ui-source" "tracked-purescript" ["tracked-javascript", "root-package-manifest"]
  LtdSrc005 -> binding "pulumi-source" "tracked-pulumi-yaml" ["renamed-pulumi-program"]
  LtdSrc006 -> binding "test-source" "tracked-test-script" ["tracked-test-table", "tracked-expected-output", "tracked-patch", "tracked-mutant-body"]
  LtdSrc007 -> binding "probe-source" "foreign-probe-script" ["foreign-probe-fixture", "probe-case-omitted"]
  LtdSrc008 -> binding "bootstrap-source" "bootstrap-byte-changed" ["bootstrap-extra-role", "bootstrap-argv-rewritten"]
  LtdSrc009 -> binding "vendor-source" "top-level-vendor" ["mutable-reference", "tracked-vendor-proto", "tracked-foreign-package", "tracked-patch-program"]
  LtdMeta001 -> binding "ignore-context" "retired-generated-root" ["undeclared-state-root"]
  LtdVal001 -> binding "runner-authority" "noop-subject" ["constant-success-checker", "forged-exit", "omitted-discovery", "unavailable-boundary"]
  LtdVal002 -> binding "contract-correspondence" "gate-spec-mismatch" ["phase-role-swap", "byte-copy-equivalence", "subject-not-shipped", "retired-domain-literal"]
  LtdVal003 -> binding "receipt-custody" "generation-one-receipt" ["verifier-diverged", "predecessor-closure-edited"]
  LtdVal004 -> binding "status-authority" "status-surface-dirty" ["status-without-receipt", "predecessor-not-reproduced", "status-edit-without-receipt"]
  LtdVal005 -> binding "spine-handoffs" "hand-built-stage" ["noop-stage", "render-omitted", "executed-argv-diverged"]
  LtdVal006 -> binding "fresh-inputs" "stale-run" ["ignored-input", "authored-output", "ambient-temp", "replayed-input", "empty-discovery"]
  LtdVal007 -> binding "bounded-supervisor" "wrong-length-entropy" ["endless-entropy", "missing-limit", "deadline-exceeded", "memory-pressure", "forced-cleanup"]
  LtdVal008 -> binding "child-environment" "path-absent" ["ambient-path", "foreign-executable", "precedence-reordered", "undeclared-variable"]
  LtdDoc001 -> binding "semantic-inputs" "markdown-behavior-consumer" ["serialized-registry-consumer"]
  LtdName001 -> binding "runtime-identity" "stale-ordinal" ["copied-ordinal", "phase-named-runtime"]
  LtdHost001 -> binding "host-ensure" "ensure-caller-bypassed" ["install-result-ignored", "idempotency-broken"]
  LtdHost002 -> binding "owned-executables" "bare-name" ["foreign-root", "ambient-resolution", "changed-owner", "production-overlap"]
  LtdImg001 -> binding "natural-image" "cross-architecture" ["emulator-used", "index-join"]
  LtdRun001 -> binding "product-identity" "identity-by-executable" ["phase-runtime-path", "second-product-stanza"]
  LtdSeed001 -> binding "infernix-independence" "seed-fetch" ["upstream-namespace", "copied-hash", "captured-output"]
  LtdSeed002 -> binding "jitml-independence" "seed-fetch" ["missing-module", "copied-output", "silent-cpu-fallback"]
  LtdBoot001 -> binding "native-tool-versions" "missing-tool" ["failed-command", "malformed-version", "unsupported-version"]
  LtdKrn001 -> binding "kernel-shape" "per-phase-run-module" ["phase-number-literal", "kernel-over-ratchet"]
  LtdKrn002 -> binding "mutation-source" "authored-mutant-symbol" ["authored-mutant-flag", "authored-mutant-selector"]
  LtdKrn003 -> binding "solver-demotion" "fake-inductive" ["fake-proved"]
  LtdDsl001 -> binding "decoded-lowering" "lowering-bypassed" ["nonce-discarded"]
  LtdDsl002 -> binding "typed-root" "two-server-quorum" ["empty-needs", "text-tree-authority"]
  LtdDsl003 -> binding "witness-rendering" "placement-ignored" ["requests-changed", "claim-bytes-changed"]
  LtdDsl004 -> binding "substrate-recipes" "two-server-rke2" ["duplicate-host", "tainted-only-host", "unrequired-lane", "digest-bearing-channel", "architecture-mismatch"]
  LtdDsl005 -> binding "linked-extensions" "unlinked-extension" ["consumed-calculus-removed"]
  LtdDsl006 -> binding "ui-program" "guard-gap" ["type-mismatch", "unbound-port", "requirement-without-port"]
  LtdDsl007 -> binding "extension-ast" "qualified-forbidden-name" ["forbidden-reexport", "template-haskell-splice", "cpp-definition", "foreign-import", "string-built-name", "comment-split-token", "raw-io", "unsafe-call", "orphan-instance", "unsanctioned-import"]
  LtdDsl008 -> binding "attested-scope" "text-minted-scope" ["claimed-identity", "scope-coercion", "foreign-tenant-reentry", "missing-scope-label"]
  LtdDsl009 -> binding "endpoint-consumption" "constant-demand" ["noop-renderer"]
  LtdLib001 -> binding "parked-calculi" "unconsumed-calculus" ["undecided-library"]
  LtdLib002 -> binding "proof-track" "interpreter-error-erased" ["parameter-state-precedence", "raw-line-equation-selection", "fake-solver-authority"]
  LtdUi001 -> binding "ui-projection" "phantom-route" ["placeholder-bundle", "unchecked-program"]
  LtdHelper001 -> binding "runtime-handoff" "python-runtime-helper" ["foreign-deploy-command"]
 where
  binding analyzer first rest = (LegacyAnalyzerKey analyzer, LegacyCaseKey first :| map LegacyCaseKey rest)

-- | Who closes an identifier: a numbered phase named by capability, or the
-- later-phases proof-assistant track, which has no ordinal until it is promoted.
data LegacyOwner
  = PhaseOwner Text
  | LaterPhasesTrack
  deriving (Eq, Ord, Show)

renderLegacyId :: LegacyId -> Text
renderLegacyId identifier = case identifier of
  LtdSrc000 -> "LTD-SRC-000"
  LtdSrc001 -> "LTD-SRC-001"
  LtdSrc002 -> "LTD-SRC-002"
  LtdSrc003 -> "LTD-SRC-003"
  LtdSrc004 -> "LTD-SRC-004"
  LtdSrc005 -> "LTD-SRC-005"
  LtdSrc006 -> "LTD-SRC-006"
  LtdSrc007 -> "LTD-SRC-007"
  LtdSrc008 -> "LTD-SRC-008"
  LtdSrc009 -> "LTD-SRC-009"
  LtdMeta001 -> "LTD-META-001"
  LtdVal001 -> "LTD-VAL-001"
  LtdVal002 -> "LTD-VAL-002"
  LtdVal003 -> "LTD-VAL-003"
  LtdVal004 -> "LTD-VAL-004"
  LtdVal005 -> "LTD-VAL-005"
  LtdVal006 -> "LTD-VAL-006"
  LtdVal007 -> "LTD-VAL-007"
  LtdVal008 -> "LTD-VAL-008"
  LtdDoc001 -> "LTD-DOC-001"
  LtdName001 -> "LTD-NAME-001"
  LtdHost001 -> "LTD-HOST-001"
  LtdHost002 -> "LTD-HOST-002"
  LtdImg001 -> "LTD-IMG-001"
  LtdRun001 -> "LTD-RUN-001"
  LtdSeed001 -> "LTD-SEED-001"
  LtdSeed002 -> "LTD-SEED-002"
  LtdBoot001 -> "LTD-BOOT-001"
  LtdKrn001 -> "LTD-KRN-001"
  LtdKrn002 -> "LTD-KRN-002"
  LtdKrn003 -> "LTD-KRN-003"
  LtdDsl001 -> "LTD-DSL-001"
  LtdDsl002 -> "LTD-DSL-002"
  LtdDsl003 -> "LTD-DSL-003"
  LtdDsl004 -> "LTD-DSL-004"
  LtdDsl005 -> "LTD-DSL-005"
  LtdDsl006 -> "LTD-DSL-006"
  LtdDsl007 -> "LTD-DSL-007"
  LtdDsl008 -> "LTD-DSL-008"
  LtdDsl009 -> "LTD-DSL-009"
  LtdLib001 -> "LTD-LIB-001"
  LtdLib002 -> "LTD-LIB-002"
  LtdUi001 -> "LTD-UI-001"
  LtdHelper001 -> "LTD-HELPER-001"

parseLegacyId :: Text -> Maybe LegacyId
parseLegacyId rendered =
  case [identifier | identifier <- allLegacyIds, renderLegacyId identifier == rendered] of
    [identifier] -> Just identifier
    _ -> Nothing

-- | The owner map. The capability names the phase whose gate closes the identifier;
-- the reader-facing register explains the shares other phases carry in prose.
legacyOwner :: LegacyId -> LegacyOwner
legacyOwner identifier = case identifier of
  LtdSrc000 -> PhaseOwner "repository_layout_conformance"
  LtdSrc001 -> PhaseOwner "repository_layout_conformance"
  LtdSrc002 -> PhaseOwner "typed_spine"
  LtdSrc003 -> PhaseOwner "typed_spine"
  LtdSrc004 -> PhaseOwner "ui_program_language_binding"
  LtdSrc005 -> PhaseOwner "repository_layout_conformance"
  LtdSrc006 -> PhaseOwner "repository_layout_conformance"
  LtdSrc007 -> PhaseOwner "toolchain_spike"
  LtdSrc008 -> PhaseOwner "repository_layout_conformance"
  LtdSrc009 -> PhaseOwner "toolchain_spike"
  LtdMeta001 -> PhaseOwner "repository_layout_conformance"
  LtdVal001 -> PhaseOwner "documentation_suite"
  LtdVal002 -> PhaseOwner "documentation_suite"
  LtdVal003 -> PhaseOwner "documentation_suite"
  LtdVal004 -> PhaseOwner "documentation_suite"
  LtdVal005 -> PhaseOwner "typed_spine"
  LtdVal006 -> PhaseOwner "documentation_suite"
  LtdVal007 -> PhaseOwner "host_assert_cli"
  LtdVal008 -> PhaseOwner "host_assert_cli"
  LtdDoc001 -> PhaseOwner "typed_spine"
  LtdName001 -> PhaseOwner "repository_layout_conformance"
  LtdHost001 -> PhaseOwner "host_ensure_kernel"
  LtdHost002 -> PhaseOwner "host_ensure_kernel"
  LtdImg001 -> PhaseOwner "base_image_registry"
  LtdRun001 -> PhaseOwner "bootstrap_coordinator_kind"
  LtdSeed001 -> PhaseOwner "infernix_rederivation"
  LtdSeed002 -> PhaseOwner "jitml_rederivation"
  LtdBoot001 -> PhaseOwner "toolchain_spike"
  LtdKrn001 -> PhaseOwner "documentation_suite"
  LtdKrn002 -> PhaseOwner "documentation_suite"
  LtdKrn003 -> PhaseOwner "documentation_suite"
  LtdDsl001 -> PhaseOwner "typed_spine"
  LtdDsl002 -> PhaseOwner "typed_spine"
  LtdDsl003 -> PhaseOwner "witness_manifests_capacity_storage"
  LtdDsl004 -> PhaseOwner "substrates_lanes_image_recipe"
  LtdDsl005 -> PhaseOwner "extension_admission_attested_scope"
  LtdDsl006 -> PhaseOwner "ui_program_language_binding"
  LtdDsl007 -> PhaseOwner "extension_admission_attested_scope"
  LtdDsl008 -> PhaseOwner "extension_admission_attested_scope"
  LtdDsl009 -> PhaseOwner "typed_spine"
  LtdLib001 -> PhaseOwner "dsl_barrier"
  LtdLib002 -> LaterPhasesTrack
  LtdUi001 -> PhaseOwner "ui_program_release"
  LtdHelper001 -> PhaseOwner "host_assert_cli"

legacyOwnerOrdinal :: LegacyId -> Maybe Int
legacyOwnerOrdinal identifier = case legacyOwner identifier of
  PhaseOwner capability -> lookupCapabilityOrdinal capability
  LaterPhasesTrack -> Nothing

legacyIdsOwnedBy :: Int -> [LegacyId]
legacyIdsOwnedBy ordinal =
  [identifier | identifier <- allLegacyIds, legacyOwnerOrdinal identifier == Just ordinal]

-- | Every phase-owned identifier must name a capability a phase provides.
legacyOwnerProblems :: [Text]
legacyOwnerProblems =
  [ "legacy owner capability is not provided by any phase: " <> renderLegacyId identifier <> "=" <> capability
  | identifier <- allLegacyIds
  , PhaseOwner capability <- [legacyOwner identifier]
  , lookupCapabilityOrdinal capability == Nothing
  ]
