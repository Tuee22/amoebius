{-# LANGUAGE OverloadedStrings #-}

module PolicyContractOracle
  ( policyContractSelectorAssignments
  , policyContractSelectorNames
  , runPolicyContractOracle
  , runPolicyContractSelectorOracle
  , runPolicyContractUnaffectedControl
  ) where

-- Hardware-free component diagnostics only.  The selector registry, exact
-- ordered result, and serialized wire below are oracle-owned literals.  This
-- module imports only the refusal-only public facade.  It performs no ambient
-- I/O and cannot pass or validate a phase.

import Amoebius.Validation.PolicyContract (policyContractDiagnostic)
import Amoebius.Validation.Types (CheckResult (..), Finding (..), Observation (..))
import Control.Monad (unless)
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as ByteString8
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

policyContractSelectorIntents :: [(String, String, String)]
policyContractSelectorIntents =
  [ ( "VALIDATION_POLICY_ALTERNATE_REGISTRY_MUTANT"
    , "closed constructor universe: registry provider"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_CONTRACT_GENERATION_FIELD_MUTANT"
    , "exact PolicyContract component comparison: generation"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_CONTRACT_ORDERING_FIELD_MUTANT"
    , "exact PolicyContract component comparison: ordering"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_CONTRACT_PB_FIELD_MUTANT"
    , "exact PolicyContract component comparison: pb"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_CONTRACT_GATE_COMPLETION_FIELD_MUTANT"
    , "exact PolicyContract component comparison: gate completion"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_CONTRACT_REGISTER_FIELD_MUTANT"
    , "exact PolicyContract component comparison: register"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_CONTRACT_REGISTRY_FIELD_MUTANT"
    , "exact PolicyContract component comparison: registry"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_CONTRACT_SOURCE_FIELD_MUTANT"
    , "exact PolicyContract component comparison: source"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_CONTRACT_STATUS_RESET_FIELD_MUTANT"
    , "exact PolicyContract component comparison: status reset"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_DIGEST_BINDING_MUTANT"
    , "contract digest binds the exact serialized policy wire"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_FINDING_ORDER_MUTANT"
    , "public diagnostic finding order"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_ACTIVE_REGISTER_DROP_MUTANT"
    , "public diagnostic observation retention: active register"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_CONTRACT_SHA256_DROP_MUTANT"
    , "public diagnostic observation retention: contract sha256"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_DIAGNOSTIC_STATUS_DROP_MUTANT"
    , "public diagnostic observation retention: diagnostic status"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_DSL_BARRIER_SOURCE_CLOSURE_DROP_MUTANT"
    , "public diagnostic observation retention: dsl barrier source closure"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_GENERATION_ROOT_DROP_MUTANT"
    , "public diagnostic observation retention: generation root"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_ORDER_MUTANT"
    , "public diagnostic observation order"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_OWNER_COUNT_DROP_MUTANT"
    , "public diagnostic observation retention: owner count"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_PB_OPERATIONS_DROP_MUTANT"
    , "public diagnostic observation retention: pb operations"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_PB_ROOT_DROP_MUTANT"
    , "public diagnostic observation retention: pb root"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_PB_SOURCE_LANGUAGE_DROP_MUTANT"
    , "public diagnostic observation retention: pb source language"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_PB_TRANSPORT_DROP_MUTANT"
    , "public diagnostic observation retention: pb transport"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_PHASE_ROLES_DROP_MUTANT"
    , "public diagnostic observation retention: phase roles"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_PHASE_ZERO_STATUS_DROP_MUTANT"
    , "public diagnostic observation retention: phase zero status"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_GATE_PASS_RULE_DROP_MUTANT"
    , "public diagnostic observation retention: gate-pass result"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_REGISTRY_PROVIDER_DROP_MUTANT"
    , "public diagnostic observation retention: registry provider"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OBSERVATION_SOURCE_LANGUAGE_DROP_MUTANT"
    , "public diagnostic observation retention: source language"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_ACTIVE_LEGACY_REGISTER_ANCHOR_MUTANT"
    , "canonical owner binding: active legacy register anchor"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_ACTIVE_LEGACY_REGISTER_MATCH_MUTANT"
    , "canonical owner binding: active legacy register match"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_ACTIVE_LEGACY_REGISTER_PATH_MUTANT"
    , "canonical owner binding: active legacy register path"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_ACTIVE_LEGACY_REGISTER_SECTION_MUTANT"
    , "canonical owner binding: active legacy register section"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PLACEMENT_ANCHOR_MUTANT"
    , "canonical owner binding: cluster registry placement anchor"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PLACEMENT_MATCH_MUTANT"
    , "canonical owner binding: cluster registry placement match"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PLACEMENT_PATH_MUTANT"
    , "canonical owner binding: cluster registry placement path"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PLACEMENT_SECTION_MUTANT"
    , "canonical owner binding: cluster registry placement section"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PROVIDER_ANCHOR_MUTANT"
    , "canonical owner binding: cluster registry provider anchor"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PROVIDER_MATCH_MUTANT"
    , "canonical owner binding: cluster registry provider match"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PROVIDER_PATH_MUTANT"
    , "canonical owner binding: cluster registry provider path"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PROVIDER_SECTION_MUTANT"
    , "canonical owner binding: cluster registry provider section"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_DSL_BARRIER_SOURCE_CLOSURE_ANCHOR_MUTANT"
    , "canonical owner binding: dsl barrier source closure anchor"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_DSL_BARRIER_SOURCE_CLOSURE_MATCH_MUTANT"
    , "canonical owner binding: dsl barrier source closure match"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_DSL_BARRIER_SOURCE_CLOSURE_PATH_MUTANT"
    , "canonical owner binding: dsl barrier source closure path"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_DSL_BARRIER_SOURCE_CLOSURE_SECTION_MUTANT"
    , "canonical owner binding: dsl barrier source closure section"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_INVENTORY_PREDICATE_MUTANT"
    , "closed owner inventory predicate"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_LAZY_BUILD_GENERATION_ANCHOR_MUTANT"
    , "canonical owner binding: lazy build generation anchor"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_LAZY_BUILD_GENERATION_MATCH_MUTANT"
    , "canonical owner binding: lazy build generation match"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_LAZY_BUILD_GENERATION_PATH_MUTANT"
    , "canonical owner binding: lazy build generation path"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_LAZY_BUILD_GENERATION_SECTION_MUTANT"
    , "canonical owner binding: lazy build generation section"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_MAP_MUTANT"
    , "canonical registry-provider owner row remains independently bound"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_NUMERIC_PHASE_ORDER_ANCHOR_MUTANT"
    , "canonical owner binding: numeric phase order anchor"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_NUMERIC_PHASE_ORDER_MATCH_MUTANT"
    , "canonical owner binding: numeric phase order match"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_NUMERIC_PHASE_ORDER_PATH_MUTANT"
    , "canonical owner binding: numeric phase order path"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_NUMERIC_PHASE_ORDER_SECTION_MUTANT"
    , "canonical owner binding: numeric phase order section"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_PB_BOOTSTRAP_ANCHOR_MUTANT"
    , "canonical owner binding: pb bootstrap anchor"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_PB_BOOTSTRAP_MATCH_MUTANT"
    , "canonical owner binding: pb bootstrap match"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_PB_BOOTSTRAP_PATH_MUTANT"
    , "canonical owner binding: pb bootstrap path"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_PB_BOOTSTRAP_SECTION_MUTANT"
    , "canonical owner binding: pb bootstrap section"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_PREHARDWARE_GATE_BARRIER_ANCHOR_MUTANT"
    , "canonical owner binding: prehardware gate barrier anchor"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_PREHARDWARE_GATE_BARRIER_MATCH_MUTANT"
    , "canonical owner binding: prehardware gate barrier match"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_PREHARDWARE_GATE_BARRIER_PATH_MUTANT"
    , "canonical owner binding: prehardware gate barrier path"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_PREHARDWARE_GATE_BARRIER_SECTION_MUTANT"
    , "canonical owner binding: prehardware gate barrier section"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_GATE_PASS_RULE_ANCHOR_MUTANT"
    , "canonical owner binding: gate-pass result anchor"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_GATE_PASS_RULE_MATCH_MUTANT"
    , "canonical owner binding: gate-pass result match"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_GATE_PASS_RULE_PATH_MUTANT"
    , "canonical owner binding: gate-pass result path"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_GATE_PASS_RULE_SECTION_MUTANT"
    , "canonical owner binding: gate-pass result section"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_TRACKED_SOURCE_ANCHOR_MUTANT"
    , "canonical owner binding: tracked source anchor"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_TRACKED_SOURCE_MATCH_MUTANT"
    , "canonical owner binding: tracked source match"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_TRACKED_SOURCE_PATH_MUTANT"
    , "canonical owner binding: tracked source path"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_TRACKED_SOURCE_SECTION_MUTANT"
    , "canonical owner binding: tracked source section"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_VALIDATION_STATUS_RESET_ANCHOR_MUTANT"
    , "canonical owner binding: validation status reset anchor"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_VALIDATION_STATUS_RESET_MATCH_MUTANT"
    , "canonical owner binding: validation status reset match"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_VALIDATION_STATUS_RESET_PATH_MUTANT"
    , "canonical owner binding: validation status reset path"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_OWNER_VALIDATION_STATUS_RESET_SECTION_MUTANT"
    , "canonical owner binding: validation status reset section"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_PB_TRANSPORT_MUTANT"
    , "closed constructor universe: pb transport rule"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_REGISTRY_PLACEMENT_PREDICATE_MUTANT"
    , "registry contract predicate: placement"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_REGISTRY_REFERENCE_PREDICATE_MUTANT"
    , "registry contract predicate: reference"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_REGISTRY_SELECTION_PREDICATE_MUTANT"
    , "registry contract predicate: selection"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_DIAGNOSTIC_ONLY_CODE_MUTANT"
    , "permanent refusal residue: diagnostic only code"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_DIAGNOSTIC_ONLY_DETAIL_MUTANT"
    , "permanent refusal residue: diagnostic only detail"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_DIAGNOSTIC_ONLY_DROP_MUTANT"
    , "permanent refusal residue: diagnostic only drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_DIAGNOSTIC_ONLY_SUBJECT_MUTANT"
    , "permanent refusal residue: diagnostic only subject"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_DOCUMENTATION_CORRESPONDENCE_CODE_MUTANT"
    , "permanent refusal residue: documentation correspondence check code"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_DOCUMENTATION_CORRESPONDENCE_DETAIL_MUTANT"
    , "permanent refusal residue: documentation correspondence check detail"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_DOCUMENTATION_CORRESPONDENCE_DROP_MUTANT"
    , "permanent refusal residue: documentation correspondence check drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_DOCUMENTATION_CORRESPONDENCE_SUBJECT_MUTANT"
    , "permanent refusal residue: documentation correspondence check subject"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_QUALIFICATION_CODE_MUTANT"
    , "permanent refusal residue: qualification code"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_QUALIFICATION_DETAIL_MUTANT"
    , "permanent refusal residue: qualification detail"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_QUALIFICATION_DROP_MUTANT"
    , "permanent refusal residue: qualification drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_QUALIFICATION_SUBJECT_MUTANT"
    , "permanent refusal residue: qualification subject"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_SOURCE_BINDING_CODE_MUTANT"
    , "permanent refusal residue: source binding code"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_SOURCE_BINDING_DETAIL_MUTANT"
    , "permanent refusal residue: source binding detail"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_SOURCE_BINDING_DROP_MUTANT"
    , "permanent refusal residue: source binding drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESIDUE_SOURCE_BINDING_SUBJECT_MUTANT"
    , "permanent refusal residue: source binding subject"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_RESULT_NAME_MUTANT"
    , "public diagnostic result name"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_GENERATION_ROOT_DROP_MUTANT"
    , "serialized policy wire: generation root drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_GENERATION_TIMING_DROP_MUTANT"
    , "serialized policy wire: generation timing drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_GENERATION_TRACKED_ARTIFACT_DROP_MUTANT"
    , "serialized policy wire: generation tracked artifact drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_HEADER_DROP_MUTANT"
    , "serialized policy wire: header drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_LEGACY_ACTIVE_REGISTER_CARDINALITY_DROP_MUTANT"
    , "serialized policy wire: legacy active register cardinality drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_LEGACY_ACTIVE_REGISTER_DROP_MUTANT"
    , "serialized policy wire: legacy active register drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_LEGACY_ARCHIVE_RULE_DROP_MUTANT"
    , "serialized policy wire: legacy archive rule drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_LEGACY_FORBIDDEN_ARCHIVE_DROP_MUTANT"
    , "serialized policy wire: legacy forbidden archive drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_LEGACY_HISTORY_DROP_MUTANT"
    , "serialized policy wire: legacy history drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_LEGACY_PREDICATE_AUTHORITY_DROP_MUTANT"
    , "serialized policy wire: legacy predicate authority drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_ORDERING_DOMAIN_DROP_MUTANT"
    , "serialized policy wire: ordering domain drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_ORDERING_DSL_BARRIER_SOURCE_CLOSURE_DROP_MUTANT"
    , "serialized policy wire: ordering dsl barrier source closure drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_ORDERING_PB_TRANSPORT_DROP_MUTANT"
    , "serialized policy wire: ordering pb transport drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_ORDERING_PHASE50_MIGRATION_DROP_MUTANT"
    , "serialized policy wire: ordering phase50 migration drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_ORDERING_PREDECESSOR_DROP_MUTANT"
    , "serialized policy wire: ordering predecessor drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_ORDERING_PREHARDWARE_DROP_MUTANT"
    , "serialized policy wire: ordering prehardware drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_ORDERING_ROLES_DROP_MUTANT"
    , "serialized policy wire: ordering roles drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_ORDER_MUTANT"
    , "serialized policy wire: order"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_OWNER_ACTIVE_LEGACY_REGISTER_DROP_MUTANT"
    , "serialized policy wire: owner active legacy register drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_OWNER_CLUSTER_REGISTRY_PLACEMENT_DROP_MUTANT"
    , "serialized policy wire: owner cluster registry placement drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_OWNER_CLUSTER_REGISTRY_PROVIDER_DROP_MUTANT"
    , "serialized policy wire: owner cluster registry provider drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_OWNER_DSL_BARRIER_SOURCE_CLOSURE_DROP_MUTANT"
    , "serialized policy wire: owner dsl barrier source closure drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_OWNER_LAZY_BUILD_GENERATION_DROP_MUTANT"
    , "serialized policy wire: owner lazy build generation drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_OWNER_NUMERIC_PHASE_ORDER_DROP_MUTANT"
    , "serialized policy wire: owner numeric phase order drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_OWNER_PB_BOOTSTRAP_DROP_MUTANT"
    , "serialized policy wire: owner pb bootstrap drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_OWNER_PREHARDWARE_GATE_BARRIER_DROP_MUTANT"
    , "serialized policy wire: owner prehardware gate barrier drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_OWNER_GATE_PASS_RULE_DROP_MUTANT"
    , "serialized policy wire: owner gate-pass result drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_OWNER_TRACKED_SOURCE_DROP_MUTANT"
    , "serialized policy wire: owner tracked source drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_OWNER_VALIDATION_STATUS_RESET_DROP_MUTANT"
    , "serialized policy wire: owner validation status reset drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_PB_ADMISSION_DROP_MUTANT"
    , "serialized policy wire: pb admission drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_PB_OPERATIONS_DROP_MUTANT"
    , "serialized policy wire: pb operations drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_PB_ROOT_DROP_MUTANT"
    , "serialized policy wire: pb root drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_PB_SOURCE_LANGUAGE_DROP_MUTANT"
    , "serialized policy wire: pb source language drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_GATE_PASS_RULE_DROP_MUTANT"
    , "serialized policy wire: gate-pass result drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_GATE_COMPLETION_AUTOMATION_ROLE_DROP_MUTANT"
    , "serialized policy wire: gate-completion automation role drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_GATE_COMPLETION_STATUS_TRANSITION_DROP_MUTANT"
    , "serialized policy wire: gate-completion status transition drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_REGISTRY_PLACEMENT_DROP_MUTANT"
    , "serialized policy wire: registry placement drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_REGISTRY_PROVIDER_DROP_MUTANT"
    , "serialized policy wire: registry provider drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_SOURCE_BEHAVIORAL_LANGUAGE_DROP_MUTANT"
    , "serialized policy wire: source behavioral language drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_SOURCE_CLASSIFICATION_DROP_MUTANT"
    , "serialized policy wire: source classification drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_SOURCE_PUBLIC_BEHAVIOR_AUTHORITY_DROP_MUTANT"
    , "serialized policy wire: source public behavior authority drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_STATUS_HISTORICAL_EVIDENCE_DROP_MUTANT"
    , "serialized policy wire: status historical evidence drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_STATUS_PHASES_01_95_DROP_MUTANT"
    , "serialized policy wire: status phases 01 95 drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_STATUS_PHASE_00_DROP_MUTANT"
    , "serialized policy wire: status phase 00 drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_STATUS_SPRINTS_DROP_MUTANT"
    , "serialized policy wire: status sprints drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_TRAILING_NEWLINE_MUTANT"
    , "serialized policy wire: trailing newline"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_ARCHIVE_REGISTER_RULE_DROP_MUTANT"
    , "serialized policy wire: universe archive register rule drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_AUTOMATION_ROLE_DROP_MUTANT"
    , "serialized policy wire: universe automation role drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_BEHAVIORAL_LANGUAGE_DROP_MUTANT"
    , "serialized policy wire: universe behavioral language drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_BOOTSTRAP_OPERATION_DROP_MUTANT"
    , "serialized policy wire: universe bootstrap operation drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_DSL_BARRIER_SOURCE_CLOSURE_DROP_MUTANT"
    , "serialized policy wire: universe dsl barrier source closure drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_GENERATION_ROOT_DROP_MUTANT"
    , "serialized policy wire: universe generation root drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_GENERATION_TIMING_DROP_MUTANT"
    , "serialized policy wire: universe generation timing drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_HISTORICAL_EVIDENCE_RULE_DROP_MUTANT"
    , "serialized policy wire: universe historical evidence rule drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_PB_ADMISSION_DROP_MUTANT"
    , "serialized policy wire: universe pb admission drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_PB_SOURCE_LANGUAGE_DROP_MUTANT"
    , "serialized policy wire: universe pb source language drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_PB_TRANSPORT_RULE_DROP_MUTANT"
    , "serialized policy wire: universe pb transport rule drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_PHASE50_MIGRATION_RULE_DROP_MUTANT"
    , "serialized policy wire: universe phase50 migration rule drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_PHASE_ROLE_DROP_MUTANT"
    , "serialized policy wire: universe phase role drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_POLICY_ID_DROP_MUTANT"
    , "serialized policy wire: universe policy id drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_PREDECESSOR_RULE_DROP_MUTANT"
    , "serialized policy wire: universe predecessor rule drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_PREHARDWARE_RULE_DROP_MUTANT"
    , "serialized policy wire: universe prehardware rule drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_GATE_PASS_RULE_DROP_MUTANT"
    , "serialized policy wire: universe gate-pass result drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_PUBLIC_BEHAVIOR_AUTHORITY_DROP_MUTANT"
    , "serialized policy wire: universe public behavior authority drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_REGISTER_CARDINALITY_DROP_MUTANT"
    , "serialized policy wire: universe register cardinality drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_REGISTER_HISTORY_DROP_MUTANT"
    , "serialized policy wire: universe register history drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_REGISTER_PREDICATE_AUTHORITY_DROP_MUTANT"
    , "serialized policy wire: universe register predicate authority drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_REGISTRY_PLACEMENT_DROP_MUTANT"
    , "serialized policy wire: universe registry placement drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_REGISTRY_PROVIDER_DROP_MUTANT"
    , "serialized policy wire: universe registry provider drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_RESET_PHASE_STATUS_DROP_MUTANT"
    , "serialized policy wire: universe reset phase status drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_SOURCE_CLASSIFICATION_DROP_MUTANT"
    , "serialized policy wire: universe source classification drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_SPRINT_RESET_RULE_DROP_MUTANT"
    , "serialized policy wire: universe sprint reset rule drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_STATUS_TRANSITION_RULE_DROP_MUTANT"
    , "serialized policy wire: universe status transition rule drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_SERIALIZER_UNIVERSE_TRACKED_GENERATED_ARTIFACT_DROP_MUTANT"
    , "serialized policy wire: universe tracked generated artifact drop"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_ARCHIVE_REGISTER_RULE_MUTANT"
    , "closed constructor universe: archive register rule"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_AUTOMATION_ROLE_MUTANT"
    , "closed constructor universe: automation role"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_BEHAVIORAL_LANGUAGE_MUTANT"
    , "closed constructor universe: behavioral language"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_BOOTSTRAP_OPERATION_MUTANT"
    , "closed constructor universe: bootstrap operation"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_DSL_BARRIER_SOURCE_CLOSURE_MUTANT"
    , "closed constructor universe: dsl barrier source closure"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_GENERATION_ROOT_MUTANT"
    , "closed constructor universe: generation root"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_GENERATION_TIMING_MUTANT"
    , "closed constructor universe: generation timing"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_HISTORICAL_EVIDENCE_RULE_MUTANT"
    , "closed constructor universe: historical evidence rule"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_PB_ADMISSION_MUTANT"
    , "closed constructor universe: pb admission"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_PB_SOURCE_LANGUAGE_MUTANT"
    , "closed constructor universe: pb source language"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_PHASE50_MIGRATION_RULE_MUTANT"
    , "closed constructor universe: phase50 migration rule"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_PHASE_ROLE_MUTANT"
    , "closed constructor universe: phase role"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_POLICY_ID_MUTANT"
    , "closed constructor universe: policy id"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_PREDECESSOR_RULE_MUTANT"
    , "closed constructor universe: predecessor rule"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_PREHARDWARE_RULE_MUTANT"
    , "closed constructor universe: prehardware rule"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_GATE_PASS_RULE_MUTANT"
    , "closed constructor universe: gate-pass result"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_PUBLIC_BEHAVIOR_AUTHORITY_MUTANT"
    , "closed constructor universe: public behavior authority"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_REGISTER_CARDINALITY_MUTANT"
    , "closed constructor universe: register cardinality"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_REGISTER_HISTORY_MUTANT"
    , "closed constructor universe: register history"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_REGISTER_PREDICATE_AUTHORITY_MUTANT"
    , "closed constructor universe: register predicate authority"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_REGISTRY_PLACEMENT_MUTANT"
    , "closed constructor universe: registry placement"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_RESET_PHASE_STATUS_MUTANT"
    , "closed constructor universe: reset phase status"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_SOURCE_CLASSIFICATION_MUTANT"
    , "closed constructor universe: source classification"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_SPRINT_RESET_RULE_MUTANT"
    , "closed constructor universe: sprint reset rule"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_STATUS_TRANSITION_RULE_MUTANT"
    , "closed constructor universe: status transition rule"
    , "canonical policy diagnostic"
    )
  , ( "VALIDATION_POLICY_UNIVERSE_TRACKED_GENERATED_ARTIFACT_MUTANT"
    , "closed constructor universe: tracked generated artifact"
    , "canonical policy diagnostic"
    )
  ]

policyContractSelectorNames :: [String]
policyContractSelectorNames =
  [selector | (selector, _, _) <- policyContractSelectorIntents]

policyContractSelectorAssignments :: [(String, String)]
policyContractSelectorAssignments =
  [(selector, target) | (selector, _, target) <- policyContractSelectorIntents]

runPolicyContractOracle :: IO ()
runPolicyContractOracle =
  finishDiagnostics
    "PolicyContractOracle"
    (policyLiteralIntegrityProblems <> exactPolicyProblems)

runPolicyContractSelectorOracle :: String -> IO ()
runPolicyContractSelectorOracle selector =
  finishDiagnostics
    "PolicyContractOracle selector"
    ( policyLiteralIntegrityProblems
        <> case
          [target | (candidate, _, target) <- policyContractSelectorIntents, candidate == selector] of
          ["canonical policy diagnostic"] -> exactPolicyProblems
          targets ->
            [ "selector intent is not exactly resolvable: selector="
                <> selector
                <> "; exact-case-count="
                <> show (length targets)
            ]
    )

runPolicyContractUnaffectedControl :: IO ()
runPolicyContractUnaffectedControl =
  unless
    ( sha256Hex (ByteString8.pack "policy-oracle-independent-control-v1")
        == "0608bebf9a0946a1f3334c7beb7d1e477f3e38acb6217b5c3a2618b3069e2e3b"
    )
    (fail "PolicyContractOracle independent SHA-256 control changed")

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics label problems =
  unless (null problems)
    (fail (unlines (label <> " component diagnostics failed:" : map ("  " <>) problems)))

exactPolicyProblems :: [String]
exactPolicyProblems =
  [ "canonical policy diagnostic changed:\nexpected="
      <> show expectedPolicyResult
      <> "\nactual="
      <> show policyContractDiagnostic
  | policyContractDiagnostic /= expectedPolicyResult
  ]

expectedPolicyResult :: CheckResult
expectedPolicyResult =
  CheckResult
    { checkName = "policy-contract-diagnostic"
    , checkObservations =
        [ Observation "policy.source-language" "haskell-.hs-only"
        , Observation "policy.pb-root" "pb"
        , Observation "policy.pb-source-language" "python"
        , Observation "policy.pb-operations" "minimal-platform-distinction,contained-toolchain-establishment,source-bound-haskell-build,opaque-argument-preserving-exec"
        , Observation "policy.generation-root" ".build/**"
        , Observation "policy.registry-provider" "registry:2"
        , Observation "policy.active-register" "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
        , Observation "policy.phase-zero-status" "active-not-validated"
        , Observation "policy.phase-roles" "hardware-free-dsl-barrier=49,bounded-pb-handoff-validation=50,haskell-host-ensure=51,first-hardware-validation=52"
        , Observation "policy.dsl-barrier-source-closure" "all-ltd-src-queries-zero-before-phase-49"
        , Observation "policy.pb-transport" "direct-haskell-through-49;observed-pb-at-50;phase-50-gate-pass-bound-pb-after-50"
        , Observation "policy.gate-pass-rule" "qualified-gate-pass"
        , Observation "policy.owner-count" "11"
        , Observation "policy.contract-sha256" expectedPolicyDigest
        , Observation "policy.diagnostic-status" "refused"
        ]
    , checkFindings =
        [ Finding "POLICY-DIAGNOSTIC-ONLY"
            "Amoebius.Validation.PolicyContract.policyContractDiagnostic"
            ("the public standard-value facade cannot mint candidate evidence" <> commitmentDetail)
        , Finding "POLICY-SOURCE-BINDING-UNAVAILABLE"
            "Amoebius.Validation.PolicyContract.Internal"
            ("the canonical policy value is not exact source binding capture evidence" <> commitmentDetail)
        , Finding "POLICY-QUALIFICATION-UNAVAILABLE"
            "policy-contract-changed-subject-matrix"
            ("component diagnostics cannot qualify a complete atomic changed-production corpus for this exact subject" <> commitmentDetail)
        , Finding "POLICY-DOCUMENTATION-CORRESPONDENCE-UNAVAILABLE"
            "DEVELOPMENT_PLAN/phase_00_documentation_suite.md"
            ("policy-to-prose correspondence requires the documentation gate" <> commitmentDetail)
        ]
    }
 where
  commitmentDetail = "; policy-contract-sha256=" <> expectedPolicyDigest

expectedPolicyDigest :: Text
expectedPolicyDigest = "c53ae80762bc0aa9fc5ee4f0193c4bd68d2ff3405a58870c77db4f4a30feb244"

literalPolicyLines :: [Text]
literalPolicyLines =
  [ "amoebius-policy-contract-v4"
  , "universe.policy-id=tracked-source-boundary,pb-bootstrap-boundary,lazy-build-generation,cluster-registry-provider,cluster-registry-placement,active-legacy-register,validation-status-reset,numeric-phase-order,dsl-barrier-source-closure,prehardware-gate-barrier,gate-pass-rule"
  , "universe.behavioral-language=haskell-.hs-only"
  , "universe.source-classification=semantic-closed-world"
  , "universe.public-behavior-authority=haskell-binary-only"
  , "universe.pb-source-language=python"
  , "universe.bootstrap-operation=minimal-platform-distinction,contained-toolchain-establishment,source-bound-haskell-build,opaque-argument-preserving-exec"
  , "universe.pb-admission=deny-by-default-static-ast-import-call-control-flow-potential-effect"
  , "universe.generation-timing=lazy-at-consumption"
  , "universe.generation-root=.build/**"
  , "universe.tracked-generated-artifact=forbidden"
  , "universe.registry-provider=registry:2"
  , "universe.registry-placement=separately-pinned-and-preloaded"
  , "universe.register-cardinality=exactly-one-active-register"
  , "universe.archive-register-rule=forbidden"
  , "universe.register-history=git-history-only"
  , "universe.register-predicate-authority=haskell-predicate-only"
  , "universe.reset-phase-status=active-not-validated,blocked-not-validated"
  , "universe.sprint-reset-rule=every-sprint-not-validated"
  , "universe.historical-evidence-rule=prior-validation-permanently-invalid"
  , "universe.predecessor-rule=immediate-numeric-predecessor"
  , "universe.phase-role=hardware-free-dsl-barrier,bounded-pb-handoff-validation,haskell-host-ensure,first-hardware-validation"
  , "universe.phase50-migration-rule=no-source-migration"
  , "universe.dsl-barrier-source-closure=all-ltd-src-queries-zero-before-phase-49"
  , "universe.prehardware-rule=no-hardware-through-phase-51"
  , "universe.pb-transport-rule=direct-haskell-through-49;observed-pb-at-50;phase-50-gate-pass-bound-pb-after-50"
  , "universe.gate-pass-rule=qualified-gate-pass"
  , "universe.automation-role=candidate-evidence-and-gate-pass"
  , "universe.status-transition-rule=passing-gate"
  , "source.behavioral-language=haskell-.hs-only"
  , "source.classification=semantic-closed-world"
  , "source.public-behavior-authority=haskell-binary-only"
  , "pb.root=pb"
  , "pb.source-language=python"
  , "pb.operations=minimal-platform-distinction,contained-toolchain-establishment,source-bound-haskell-build,opaque-argument-preserving-exec"
  , "pb.admission=deny-by-default-static-ast-import-call-control-flow-potential-effect"
  , "generation.timing=lazy-at-consumption"
  , "generation.root=.build/**"
  , "generation.tracked-artifact=forbidden"
  , "registry.provider=registry:2"
  , "registry.placement=separately-pinned-and-preloaded"
  , "legacy.active-register=DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
  , "legacy.active-register-cardinality=exactly-one-active-register"
  , "legacy.forbidden-archive=DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md"
  , "legacy.archive-rule=forbidden"
  , "legacy.history=git-history-only"
  , "legacy.predicate-authority=haskell-predicate-only"
  , "status.phase-00=active-not-validated"
  , "status.phases-01-95=blocked-not-validated"
  , "status.sprints=every-sprint-not-validated"
  , "status.historical-evidence=prior-validation-permanently-invalid"
  , "ordering.domain=00..95"
  , "ordering.predecessor=immediate-numeric-predecessor"
  , "ordering.roles=hardware-free-dsl-barrier=49,bounded-pb-handoff-validation=50,haskell-host-ensure=51,first-hardware-validation=52"
  , "ordering.phase50-migration=no-source-migration"
  , "ordering.dsl-barrier-source-closure=all-ltd-src-queries-zero-before-phase-49"
  , "ordering.prehardware=no-hardware-through-phase-51"
  , "ordering.pb-transport=direct-haskell-through-49;observed-pb-at-50;phase-50-gate-pass-bound-pb-after-50"
  , "gate-completion.rule=qualified-gate-pass"
  , "gate-completion.automation-role=candidate-evidence-and-gate-pass"
  , "gate-completion.status-transition=passing-gate"
  , "owner.tracked-source-boundary=documents/engineering/repository_layout_doctrine.md#1-classification-rule|1. Classification rule"
  , "owner.pb-bootstrap-boundary=documents/engineering/substrate_doctrine.md#6-the-pre-binary-handoff-contract|6. The pre-binary handoff contract"
  , "owner.lazy-build-generation=documents/engineering/generated_artifacts_doctrine.md#3-the-rule|3. The rule"
  , "owner.cluster-registry-provider=documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific|3. Canonical providers; extension is capability-specific"
  , "owner.cluster-registry-placement=documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster|2. The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster"
  , "owner.active-legacy-register=DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md#1-register-contract|1. Register contract"
  , "owner.validation-status-reset=DEVELOPMENT_PLAN/phase_00_documentation_suite.md#phase-status|Phase Status"
  , "owner.numeric-phase-order=DEVELOPMENT_PLAN/development_plan_phase_model.md#e-one-canonical-phase-model|E. One canonical phase model"
  , "owner.dsl-barrier-source-closure=DEVELOPMENT_PLAN/development_plan_phase_model.md#e-one-canonical-phase-model|E. One canonical phase model"
  , "owner.prehardware-gate-barrier=DEVELOPMENT_PLAN/development_plan_phase_model.md#l-one-substrate-discipline|L. One-substrate discipline"
  , "owner.gate-pass-rule=DEVELOPMENT_PLAN/development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass|M.6 Candidate evidence and gate pass"
  ]

literalPolicyWire :: ByteString
literalPolicyWire = TextEncoding.encodeUtf8 (Text.unlines literalPolicyLines)

policyLiteralIntegrityProblems :: [String]
policyLiteralIntegrityProblems =
  [ "selector intent cardinality changed: expected=194; observed="
      <> show (length policyContractSelectorIntents)
  | length policyContractSelectorIntents /= 194
  ]
    <> ["duplicate selector intent: " <> value | value <- duplicateStrings policyContractSelectorNames]
    <> ["duplicate atomic requirement: " <> value | value <- duplicateStrings requirements]
    <> ["duplicate exact-case label: " <> value | value <- duplicateStrings exactCaseLabels]
    <> [ "selector target must occur exactly once: selector="
           <> selector
           <> "; target="
           <> target
           <> "; observed="
           <> show (occurrenceCount target exactCaseLabels)
       | (selector, _, target) <- policyContractSelectorIntents
       , occurrenceCount target exactCaseLabels /= 1
       ]
    <> [ "literal serialized line cardinality changed: expected=72; observed="
           <> show (length literalPolicyLines)
       | length literalPolicyLines /= 72
       ]
    <> [ "literal serialized wire digest changed: expected="
           <> Text.unpack expectedPolicyDigest
           <> "; observed="
           <> Text.unpack (sha256Hex literalPolicyWire)
       | sha256Hex literalPolicyWire /= expectedPolicyDigest
       ]
 where
  requirements = [requirement | (_, requirement, _) <- policyContractSelectorIntents]
  exactCaseLabels = ["canonical policy diagnostic"]

duplicateStrings :: [String] -> [String]
duplicateStrings = Set.toAscList . snd . foldl remember (Set.empty, Set.empty)
 where
  remember :: (Set String, Set String) -> String -> (Set String, Set String)
  remember (seen, repeated) value
    | Set.member value seen = (seen, Set.insert value repeated)
    | otherwise = (Set.insert value seen, repeated)

occurrenceCount :: String -> [String] -> Int
occurrenceCount wanted = go 0
 where
  go count values = case values of
    [] -> count
    value : rest -> go (if value == wanted then count + 1 else count) rest

sha256Hex :: ByteString -> Text
sha256Hex = Text.pack . show . Crypto.hashWith Crypto.SHA256
