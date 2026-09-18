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
  , allLegacyIds
  , legacyOwner
  , legacyOwnerOrdinal
  , legacyOwnerProblems
  , legacyIdsOwnedBy
  , parseLegacyId
  , renderLegacyId
  ) where

import Amoebius.Plan.PhaseIdentity (lookupCapabilityOrdinal)
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
  LtdDsl004 -> PhaseOwner "typed_spine"
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
