{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.PhaseSemanticContract
  ( phaseSemanticContractCheck
  , phaseSemanticContractDiagnostic
  , phaseStructuralProjectionCheck
  , phaseStructuralProjectionCheckAtFrontier
  , phaseStructuralProjectionCheckForPhase
  , phaseStructuralProjectionDiagnostic
  ) where

import Amoebius.Validation.Legacy.Internal qualified as Legacy
import Amoebius.Validation.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.StatusFrontier qualified as Status
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Data.List (group, sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text

-- This module is the compiled semantic registry.  Markdown is deliberately
-- absent from its construction.  The only public views are refusal-bearing
-- CheckResults; no caller can obtain a PhaseSemanticContract or a successful
-- slot value from this pre-authority seam.

data Substrate
  = NoSubstrate
  | LinuxCpu
  | Apple
  | Windows
  | LinuxCuda
  deriving (Eq, Ord, Show)

data Lane
  = NoLane
  | LinuxCpuAmd64
  | LinuxCpuArm64
  | Provider
  | Metal
  | Cuda
  deriving (Eq, Ord, Show)

data ValidationRegister
  = NoRegister
  | Register1
  | Register2
  | Register3
  deriving (Eq, Ord, Show)

data ExecutionStage
  = DirectSourceBoundHaskell
  | PbChildUnderDirectHaskellSupervisor
  | GatePassBoundHaskellFakeBoundary
  | GatePassBoundHardware
  deriving (Eq, Ord, Show)

data Predecessor
  = Genesis
  | ImmediatePredecessor Int
  deriving (Eq, Ord, Show)

data GateCategory
  = Claim
  | Subject
  | Command
  | Oracle
  | PositiveControls
  | PairedNegatives
  | Mutants
  | Discovery
  | Challenge
  | Observer
  | AuthorityBypass
  | Freshness
  | Qualification
  | Cleanroom
  | LegacyClosure
  | PredecessorCategory
  | Residue
  | PassCriterion
  deriving (Bounded, Enum, Eq, Ord, Show)

data GapId = GapId Int GateCategory
  deriving (Eq, Ord, Show)

-- | A compiled contract payload. The requirement constructor carries the
-- semantic obligation; ordinal/category fields bind that obligation to one
-- exact registry slot. This is deliberately not derived from Markdown.
data GateSpecification = GateSpecification Int GateCategory GateRequirement
  deriving (Eq, Ord, Show)

data GateRequirement
  = RequireGovernedCorpusAndSourcePolicyClosure
  | RequireExactSourceBoundPhaseZeroDispatcher
  | RequireDirectPinnedOfflineHaskellInvocation
  | RequireIndependentPhaseZeroOracleSet
  | RequireClosedPhaseZeroPositiveCorpus
  | RequireMinimallyDifferentPhaseZeroNegatives
  | RequireFiniteBootstrapChangedProductionMatrix
  | RequireCompleteRuntimeDiscoveryEquality
  | RequireFreshnessAndIndependentChallenge
  | RequireRawIndependentObservation
  | RequireAuthorityAndBypassRejection
  | RequireStartEndSourceAndRunFreshness
  | RequireFiniteBootstrapQualificationSequence
  | RequireRunScopedCleanroomAndResidueContainment
  | RequireStructuralLegacyInventoryWithNoPhaseZeroOwner
  | RequireGenesisPredecessor
  | RequireNoPhaseZeroResidueAndTypedForwardDeferrals
  | RequireQualifiedGatePass
  deriving (Eq, Ord, Show)

-- | A gate-table slot is exactly @Bound specification@ or @ContractGap@
-- (development_plan_gate_integrity.md section M.6).  The former three-state
-- encoding could not represent a bound contract without tripping the registry
-- integrity rules, so no slot was reachable from a gap.
data ContractSlot a
  = ContractGap GapId
  | BoundSpecification a
  deriving (Eq, Ord, Show)

data Phase49Requirement
  = RequireAllSourceMigrationQueriesZero
  | RequireAllOwnersAtOrBefore49Zero
  deriving (Eq, Show)

data Phase50Requirement
  = RequireNoSourceMigrationOwnership
  | RequirePassedPhase49SourceSnapshot
  | RequireDirectHaskellSupervisorWithPbChild
  | RequireIdentityArgvExecHandoff
  | RequirePublicTargetNotSelfSupervising
  deriving (Eq, Show)

data Phase51Requirement
  = RequireHardwareFreeExecution
  | RequireHaskellFakeBoundariesOnly
  deriving (Eq, Show)

data Phase52Requirement
  = RequireFirstHardwareValidation
  deriving (Eq, Show)

data RegistryExclusivityRequirement
  = RequireDistributionRegistry2Only
  deriving (Eq, Show)

data CriticalGuard
  = Phase49SourceBarrier [Phase49Requirement]
  | Phase50HandoffBoundary [Phase50Requirement]
  | Phase51FakeBoundary [Phase51Requirement]
  | Phase52HardwareBoundary [Phase52Requirement]
  | Phase56RegistryBoundary
      { distributionRegistryContract :: Policy.RegistryContract
      , distributionRegistryReference :: Text
      , registryExclusivityRequirement :: RegistryExclusivityRequirement
      }
  deriving (Eq, Show)

data PhaseSemanticContract = PhaseSemanticContract
  { semanticOrdinal :: Int
  , semanticCapabilityId :: Text
  , semanticPath :: FilePath
  , semanticTitle :: Text
  , semanticSubstrate :: Substrate
  , semanticLane :: Lane
  , semanticRegister :: ValidationRegister
  , semanticExecutionStage :: ExecutionStage
  , semanticPredecessor :: Predecessor
  , semanticResourceProvision :: PhaseIdentity.ResourceProvisionRequirement
  , semanticLegacyIds :: [Legacy.LegacyId]
  , semanticGateSlots :: Map GateCategory (ContractSlot GateSpecification)
  , semanticCriticalGuards :: [CriticalGuard]
  }
  deriving (Eq, Show)

gateCategories :: [GateCategory]
gateCategories = [minBound .. maxBound]

-- | The nullary registry view.  It names no phase under validation, so it
-- can report the registry's shape but can never decide one, and it retains an
-- exact permanent refusal.  The gate uses 'phaseSemanticContractCheck'.
phaseSemanticContractDiagnostic :: CheckResult
phaseSemanticContractDiagnostic = semanticRegistryCheck Nothing

-- | The phase-scoped registry check.  A 'ContractGap' at a phase at or below
-- the phase under validation is fatal; a gap at a strictly later phase is an
-- explicit deferred-gap observation, because a later phase's contract is not
-- an input to this phase's claim.
phaseSemanticContractCheck :: Int -> CheckResult
phaseSemanticContractCheck = semanticRegistryCheck . Just

semanticRegistryCheck :: Maybe Int -> CheckResult
semanticRegistryCheck target =
  CheckResult
    { checkName = "phase-semantic-contract-diagnostic"
    , checkObservations =
        [ observation "semantic.phase-count" (showText (length canonicalPhaseRegistry))
        , observation "semantic.slot-count" (showText (length allSlots))
        , observation "semantic.gap-count" (showText gapCount)
        , observation "semantic.bound-count" (showText boundCount)
        , observation "semantic.target-phase" (maybe "none" renderOrdinal target)
        , observation "semantic.deferred-gap-count" (showText deferredGapCount)
        , observation "semantic.legacy-count" (showText (length allSemanticLegacyIds))
        ]
          <> map (observation "semantic.phase" . renderPhaseProjection) canonicalPhaseRegistry
          <> [ observation "semantic.bound-slot" (renderGateDraft draft)
             | contract <- canonicalPhaseRegistry
             , BoundSpecification draft <- Map.elems (semanticGateSlots contract)
             ]
    , checkFindings =
        registryIntegrityFindings
          <> concatMap (slotFindings target) canonicalPhaseRegistry
          <> diagnosticSeamRefusal target
    }
 where
  allSlots = concatMap (Map.elems . semanticGateSlots) canonicalPhaseRegistry
  gapCount = length [() | ContractGap _ <- allSlots]
  boundCount = length [() | BoundSpecification _ <- allSlots]
  deferredGapCount =
    length
      [ ()
      | contract <- canonicalPhaseRegistry
      , ContractGap _ <- Map.elems (semanticGateSlots contract)
      , slotIsDeferred target (semanticOrdinal contract)
      ]
  allSemanticLegacyIds = concatMap semanticLegacyIds canonicalPhaseRegistry

-- | A gap is deferred exactly when a phase under validation is named and that
-- gap belongs to a strictly later phase.
slotIsDeferred :: Maybe Int -> Int -> Bool
slotIsDeferred target ordinal = case target of
  Nothing -> False
  Just phaseUnderValidation -> ordinal > phaseUnderValidation

-- | Retained only for the nullary seam, which decides no phase.
diagnosticSeamRefusal :: Maybe Int -> [Finding]
diagnosticSeamRefusal target =
  [ finding
      "PLAN-SEMANTIC-DIAGNOSTIC-ONLY"
      "DEVELOPMENT_PLAN/"
      "the nullary registry view names no phase under validation and cannot pass a phase"
  | target == Nothing
  ]

slotFindings :: Maybe Int -> PhaseSemanticContract -> [Finding]
slotFindings target contract = concatMap findingFor gateCategories
 where
  deferred = slotIsDeferred target (semanticOrdinal contract)
  findingFor category = case Map.lookup category (semanticGateSlots contract) of
    Nothing ->
      [ semanticFinding
          "PLAN-SEMANTIC-SLOT-MISSING"
          contract
          category
          "the canonical eighteen-category map has no slot"
      ]
    Just (ContractGap gapIdentifier)
      | deferred -> []
      | otherwise ->
          [ semanticFinding
              "PLAN-SEMANTIC-CONTRACT-GAP"
              contract
              category
              ("gap=" <> renderGapId gapIdentifier)
          ]
    Just (BoundSpecification _) -> []

semanticFinding :: Text -> PhaseSemanticContract -> GateCategory -> Text -> Finding
semanticFinding code contract category detail =
  finding
    code
    (semanticPath contract)
    ( "phase="
        <> renderOrdinal (semanticOrdinal contract)
        <> " category="
        <> renderGateCategory category
        <> " "
        <> detail
    )

registryIntegrityFindings :: [Finding]
registryIntegrityFindings =
  concat
    [ integrityFinding
        (length canonicalPhaseRegistry == 96)
        "phase cardinality must be exactly 96"
    , integrityFinding
        (map semanticOrdinal canonicalPhaseRegistry == [0 .. 95])
        "phase ordinals must be exactly 0 through 95 in order"
    , integrityFinding
        (allUnique (map semanticCapabilityId canonicalPhaseRegistry))
        "capability identifiers must be unique"
    , integrityFinding
        (allUnique (map semanticPath canonicalPhaseRegistry))
        "phase paths must be unique"
    , integrityFinding
        (all pathMatchesCapability canonicalPhaseRegistry)
        "every path must be the exact phase ordinal and capability identifier projection"
    , integrityFinding
        (all ((== gateCategories) . Map.keys . semanticGateSlots) canonicalPhaseRegistry)
        "every phase must contain exactly the closed eighteen gate categories"
    , integrityFinding
        (all semanticSlotIdentitiesAreExact canonicalPhaseRegistry)
        "every semantic slot must retain its exact phase/category identity and reset state"
    , integrityFinding
        (length allSlots == 1728)
        "the 96-phase registry must contain exactly 1,728 slots"
    , identityIntegrityFindings
    , integrityFinding
        (all phaseIdentityProjectionIsExact canonicalPhaseRegistry)
        "every semantic row must retain the shared ordinal/capability/path/resource identity"
    , integrityFinding
        phaseMetadataIdentityJoinIsExact
        "phase metadata rows must remain in exact shared-identity order"
    , integrityFinding
        (all stageMatchesOrdinal canonicalPhaseRegistry)
        "execution stages must preserve the Phase-49/50/51/52 ordering boundary"
    , integrityFinding
        (all predecessorMatchesOrdinal canonicalPhaseRegistry)
        "every phase must bind genesis or its exact immediate numeric predecessor"
    , integrityFinding
        legacyReverseMapIsExact
        "the semantic reverse legacy map must contain every canonical LegacyId exactly once at its typed owner"
    , integrityFinding
        (all registryRowLegacyOwnersAreExact canonicalPhaseRegistry)
        "every semantic phase row must contain exactly the LegacyIds whose typed owner is that row ordinal"
    , integrityFinding
        criticalGuardsAreExact
        "the complete Phase-49/50/51/52/56 critical-guard relation must remain exact and exclusive"
    , integrityFinding
        criticalBoundaryTuplesAreExact
        "the Phase-49/50/51/52 stage/substrate/lane/register/predecessor/resource/guard tuples must remain exact"
    ]
 where
  allSlots = concatMap (Map.elems . semanticGateSlots) canonicalPhaseRegistry

integrityFinding :: Bool -> Text -> [Finding]
integrityFinding condition detail =
  [finding "PLAN-SEMANTIC-REGISTRY-INTEGRITY" "DEVELOPMENT_PLAN/" detail | not condition]

identityIntegrityFindings :: [Finding]
identityIntegrityFindings =
  [ finding
      "PLAN-SEMANTIC-REGISTRY-INTEGRITY"
      "DEVELOPMENT_PLAN/"
      ("shared phase identity refused: " <> detail)
  | detail <- PhaseIdentity.phaseIdentityIntegrityProblems
  ]

canonicalPhaseRegistry :: [PhaseSemanticContract]
canonicalPhaseRegistry =
  applyRegistryMutants (zipWith makePhase PhaseIdentity.allPhaseIdentities phaseMetadata)

applyRegistryMutants :: [PhaseSemanticContract] -> [PhaseSemanticContract]
applyRegistryMutants contracts =
  omissionMutation (map swapMutation (map hardwareMetadataMutation contracts))
 where
#ifdef VALIDATION_PHASE_SEMANTIC_OMISSION_MUTANT
  omissionMutation = filter ((/= 48) . semanticOrdinal)
#else
  omissionMutation = id
#endif
#ifdef VALIDATION_PHASE_SEMANTIC_SWAP_MUTANT
  swapMutation contract
    | semanticOrdinal contract == 48 = copyIdentity 49 contract
    | semanticOrdinal contract == 49 = copyIdentity 48 contract
    | otherwise = contract
  copyIdentity sourceOrdinal target =
    case lookupPhase sourceOrdinal (zipWith makePhase PhaseIdentity.allPhaseIdentities phaseMetadata) of
      Nothing -> target
      Just source ->
        target
          { semanticCapabilityId = semanticCapabilityId source
          , semanticPath = phaseFile (semanticOrdinal target) (semanticCapabilityId source)
          , semanticTitle = semanticTitle source
          }
#else
  swapMutation = id
#endif
#ifdef VALIDATION_PHASE_SEMANTIC_HARDWARE_METADATA_SWAP_MUTANT
  hardwareMetadataMutation contract
    | semanticOrdinal contract == 51 =
        contract
          { semanticSubstrate = LinuxCpu
          , semanticLane = LinuxCpuAmd64
          , semanticRegister = Register3
          }
    | semanticOrdinal contract == 52 =
        contract
          { semanticSubstrate = NoSubstrate
          , semanticLane = NoLane
          , semanticRegister = Register2
          }
    | otherwise = contract
#else
  hardwareMetadataMutation = id
#endif

makePhase :: PhaseIdentity.PhaseIdentity -> PhaseMetadata -> PhaseSemanticContract
makePhase identityRow metadataRow =
  PhaseSemanticContract
    { semanticOrdinal = ordinal
    , semanticCapabilityId = PhaseIdentity.phaseIdentityCapability identityRow
    , semanticPath = PhaseIdentity.phaseIdentityPath identityRow
    , semanticTitle = metadataTitle metadataRow
    , semanticSubstrate = metadataSubstrate metadataRow
    , semanticLane = metadataLane metadataRow
    , semanticRegister = metadataRegister metadataRow
    , semanticExecutionStage = executionStageFor ordinal
    , semanticPredecessor = predecessorFor ordinal
    , semanticResourceProvision = PhaseIdentity.phaseIdentityResourceProvision identityRow
    , semanticLegacyIds = legacyIdsForPhase ordinal
    , semanticGateSlots = gateSlotsFor ordinal
    , semanticCriticalGuards = guardsFor ordinal
    }
 where
  ordinal = PhaseIdentity.phaseIdentityOrdinal identityRow

data PhaseMetadata = PhaseMetadata
  { metadataCapabilityWitness :: Text
  , metadataTitle :: Text
  , metadataSubstrate :: Substrate
  , metadataLane :: Lane
  , metadataRegister :: ValidationRegister
  }

metadata :: Text -> Text -> Substrate -> Lane -> ValidationRegister -> PhaseMetadata
metadata = PhaseMetadata

-- The capability text in each metadata row is a checked positional witness,
-- not a second identity source.  makePhase always consumes the capability and
-- path from PhaseIdentity.
phaseMetadataIdentityJoinIsExact :: Bool
phaseMetadataIdentityJoinIsExact =
  length phaseMetadata == length PhaseIdentity.allPhaseIdentities
    && and
      [ metadataCapabilityWitness metadataRow
          == PhaseIdentity.phaseIdentityCapability identityRow
      | (identityRow, metadataRow) <- zip PhaseIdentity.allPhaseIdentities phaseMetadata
      ]

phaseMetadata :: [PhaseMetadata]
phaseMetadata =
  [ metadata "documentation_suite" "Documentation, source policy, and validation baseline" NoSubstrate NoLane NoRegister
  , metadata "toolchain_spike" "Haskell toolchain and probe-source closure" NoSubstrate NoLane Register1
  , metadata "repository_layout_conformance" "Repository layout conformance and de-phased naming" NoSubstrate NoLane Register1
  , metadata "artifact_calculus" "The artifact calculus" NoSubstrate NoLane Register1
  , metadata "budget_calculus" "The budget calculus" NoSubstrate NoLane Register1
  , metadata "lift_calculus" "The lift calculus" NoSubstrate NoLane Register1
  , metadata "workflow_calculus" "The workflow calculus" NoSubstrate NoLane Register1
  , metadata "evidence_calculus" "The evidence calculus" NoSubstrate NoLane Register1
  , metadata "scope_index" "Scoped identity kernel" NoSubstrate NoLane Register1
  , metadata "resource_index" "Capacity core fold + topology relation" NoSubstrate NoLane Register1
  , metadata "calculus_composition" "Composition across the five calculi" NoSubstrate NoLane Register1
  , metadata "formal_model_kernel" "Formal-model EDSL (`Model`/`interpret`/`emitTLA`)" NoSubstrate NoLane Register1
  , metadata "explicit_state_checker" "The amoebius explicit-state checker" NoSubstrate NoLane Register1
  , metadata "symbolic_checker" "The amoebius symbolic checker" NoSubstrate NoLane Register1
  , metadata "refinement_checker" "The amoebius refinement checker" NoSubstrate NoLane Register1
  , metadata "compile_fail_harness" "The compile-fail fixture harness" NoSubstrate NoLane Register1
  , metadata "deterministic_sim_substrate" "Deterministic-simulation substrate" NoSubstrate NoLane Register2
  , metadata "gateway_migration_model" "Gateway-migration model (both branches)" NoSubstrate NoLane Register1
  , metadata "dsl_formal_model" "DSL formal model" NoSubstrate NoLane Register1
  , metadata "reconcile_core_simulation" "Reconcile decision core under deterministic simulation" NoSubstrate NoLane Register2
  , metadata "extension_declaration" "The extension declaration" NoSubstrate NoLane Register1
  , metadata "extension_laws_per_extension" "The per-extension laws L1-L5" NoSubstrate NoLane Register1
  , metadata "extension_laws_compositional" "The compositional laws C1-C7" NoSubstrate NoLane Register1
  , metadata "extension_security_laws" "The security laws S1-S6" NoSubstrate NoLane Register1
  , metadata "conformance_gate_generator" "The generated conformance gate" NoSubstrate NoLane Register1
  , metadata "dhall_schema_generation" "Haskell-derived Dhall projection and smart-constructor prelude" NoSubstrate NoLane Register1
  , metadata "gadt_decode_ir" "Haskell protocol declarations, GADT-indexed IR, and total decoder" NoSubstrate NoLane Register1
  , metadata "illegal_state_covering" "Illegal-state corpus + validation-locus ledger" NoSubstrate NoLane Register1
  , metadata "storage_geometry_folds" "Logical→physical storage geometry folds" NoSubstrate NoLane Register1
  , metadata "execution_accelerator_folds" "Execution-epoch + scheduler + accelerator + provider-root folds" NoSubstrate NoLane Register1
  , metadata "capability_bind" "Capability union + representational bind" NoSubstrate NoLane Register1
  , metadata "provision_seal" "Whole-deployment provision seal + expansion" NoSubstrate NoLane Register1
  , metadata "inference_accelerator_provision" "InferenceEngine capability + accelerator provision" NoSubstrate NoLane Register1
  , metadata "render_manifest_oracles" "Pure `renderAll` + rendered-artifact oracles" NoSubstrate NoLane Register1
  , metadata "chain_kernel_boundary" "chain/Step kernel + `--dry-run` + boundary fake-tool harness + extension-astcheck AST checker" NoSubstrate NoLane Register2
  , metadata "image_recipe_generation" "The amoebius image recipe" NoSubstrate NoLane Register1
  , metadata "transaction_vocabulary" "The closed transaction vocabulary" NoSubstrate NoLane Register1
  , metadata "ui_program_schema" "Bounded UI-program schema" NoSubstrate NoLane Register1
  , metadata "ui_authorization_kernel" "UI authorization kernel" NoSubstrate NoLane Register1
  , metadata "ui_effect_binding" "UI effect binding" NoSubstrate NoLane Register1
  , metadata "ui_plan_compiler" "UI plan compiler" NoSubstrate NoLane Register1
  , metadata "offline_language_plan" "Offline language and paired plans" NoSubstrate NoLane Register1
  , metadata "ui_browser_interpreter" "Haskell browser-interpreter semantics and projection" NoSubstrate NoLane Register1
  , metadata "ui_server_boundary" "Haskell UI-server boundary" NoSubstrate NoLane Register2
  , metadata "ui_local_composition" "Hardware-free Haskell UI composition" NoSubstrate NoLane Register2
  , metadata "encrypted_browser_runtime" "Haskell offline-state semantics and runtime projection" NoSubstrate NoLane Register1
  , metadata "ui_contract_generation" "Haskell-generated browser contracts and bundle" NoSubstrate NoLane Register1
  , metadata "tool_and_mutant_generation" "Foreign-source generator closure, checking tools, and mutants" NoSubstrate NoLane Register1
  , metadata "test_workflow_algebra" "The test-workflow algebra" NoSubstrate NoLane Register1
  , metadata "self_referential_gates" "No-hardware DSL gate barrier + self-referential gate suite" NoSubstrate NoLane Register2
  , metadata "host_assert_cli" "Validate the bounded `pb` → Haskell handoff" NoSubstrate NoLane Register2
  , metadata "host_ensure_kernel" "The host-ensure kernel" NoSubstrate NoLane Register2
  , metadata "linux_engine_bringup" "Linux: sudoless Docker and the native image" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "apple_engine_bringup" "Apple: Homebrew, Colima, and the native image" Apple LinuxCpuArm64 Register3
  , metadata "windows_engine_bringup" "Windows: WSL2 and the lifted Linux engine" Windows LinuxCpuAmd64 Register3
  , metadata "bootstrap_coordinator_kind" "Haskell substrate coordinator + single kind cluster" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "base_image_registry" "The base image, the jit-build resolver, and the in-cluster registry" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "complementary_arch_child" "The complementary-architecture base image" Apple LinuxCpuArm64 Register3
  , metadata "object_reconciler" "Typed renderer + object reconciler" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "capacity_scheduler" "amoebius-capacity scheduler + bootstrap cutover" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "retained_storage" "No-provisioner retained storage + lossless rebind" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "vault_pki" "Root Vault + PKI + built-in Haskell Vault client" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "platform_backbone" "Platform backbone (MetalLB + MinIO + Pulsar HA)" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "platform_services_2" "Platform services-2 (Redis/Sentinel + Percona/Patroni + pgAdmin + observability + readiness-DAG)" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "keycloak_ingress" "Keycloak-owned ingress" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "live_dsl_deploy" "Live DSL deploy via the replicas=1 control-plane daemon" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "app_tenancy" "Tenant/provider provisioning" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "pulsar_client" "Native Pulsar client (CBOR)" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "user_tenant_isolation_live" "Live subject/tenant isolation" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "content_store_workflow" "Content store + workflow runtime (Pulsar-Failover single-writer)" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "ui_projection_runtime" "Owner-scoped UI projection runtime" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "release_lifecycle" "Release lifecycle" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "ui_program_release" "Atomic immutable UI-program release" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "network_fabric_wireguard" "WireGuard network fabric" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "multicluster_spawn_georepl" "Multi-cluster spawn + geo-replication" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "gateway_migration_drills" "Gateway-migration drills + model-correspondence" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "provider_deploy_checkpoint" "Haskell-derived provider Pulumi program and enveloped checkpoint" LinuxCpu Provider Register3
  , metadata "provider_child_bringup" "Hostless provider child + convergence + Lease handoff" LinuxCpu Provider Register3
  , metadata "provider_ebs_credential" "Per-PV EBS decoupling + create-vs-delete credential" LinuxCpu Provider Register3
  , metadata "provider_dynamic_nodes" "Dynamic node provisioning by signal + leak-free provider gate" LinuxCpu Provider Register3
  , metadata "determinism_jitcache" "Determinism kernel + jit-build CacheBudget cache" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "ui_single_tenant_live" "Single-tenant low-code UI live path" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "ui_multi_tenant_live" "Multi-tenant low-code UI isolation" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "ui_rollout_reconnect" "UI rollout, projection catch-up, and reconnect" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "ui_ha_multizone" "Initial online UI multi-zone high availability" LinuxCpu Provider Register3
  , metadata "offline_replay_receipts" "Offline replay and durable receipts" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "offline_blobs_isolation" "Offline blobs and partition isolation" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "offline_release_evolution" "Offline release and schema evolution" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "offline_multizone_continuity" "Offline multi-zone continuity" LinuxCpu Provider Register3
  , metadata "apple_metal_host_daemon" "Apple-Metal host compute daemon" Apple Metal Register3
  , metadata "test_topology_live" "The live test topology and elevated harness" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "infernix_rederivation" "The infernix inference core, re-derived" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "infernix_ui_rederivation" "The infernix workflow and artifact contracts, re-derived" LinuxCpu LinuxCpuAmd64 Register3
  , metadata "jitml_rederivation" "The jitML numerical core, re-derived" LinuxCuda Cuda Register3
  , metadata "jitml_ui_rederivation" "The jitML training and checkpoint contracts, re-derived" LinuxCuda Cuda Register3
  , metadata "webapp_rederivation" "The multi-tenant web application re-derived" LinuxCpu LinuxCpuAmd64 Register3
  ]

-- | The semantic cuts are read from the typed policy contract by role, never
-- from an ordinal literal, so a reorder that moves a role moves every consumer
-- with it. The ordinals themselves stay in one place:
-- @PolicyContract.expectedOrderingContract@.
roleOrdinal :: Policy.PhaseRole -> Int
roleOrdinal =
  Policy.phaseOrdinalNumber
    . Policy.phaseRoleOrdinal (Policy.orderingContract Policy.canonicalPolicyContract)

barrierOrdinal, handoffOrdinal, hostEnsureOrdinal, firstHardwareOrdinal, registryOrdinal :: Int
barrierOrdinal = roleOrdinal Policy.HardwareFreeDslBarrier
handoffOrdinal = roleOrdinal Policy.BoundedPbHandoffValidation
hostEnsureOrdinal = roleOrdinal Policy.HaskellHostEnsure
firstHardwareOrdinal = roleOrdinal Policy.FirstHardwareValidation
registryOrdinal = roleOrdinal Policy.RegistryBoundary

executionStageFor :: Int -> ExecutionStage
executionStageFor ordinal
  | ordinal <= barrierOrdinal = DirectSourceBoundHaskell
  | ordinal == handoffOrdinal = PbChildUnderDirectHaskellSupervisor
#ifdef VALIDATION_PHASE_SEMANTIC_STAGE_MUTANT
  | ordinal == hostEnsureOrdinal = GatePassBoundHardware
#else
  | ordinal == hostEnsureOrdinal = GatePassBoundHaskellFakeBoundary
#endif
  | otherwise = GatePassBoundHardware

predecessorFor :: Int -> Predecessor
predecessorFor 0 = Genesis
#ifdef VALIDATION_PHASE_SEMANTIC_PREDECESSOR_MUTANT
predecessorFor 52 = ImmediatePredecessor 50
#endif
predecessorFor ordinal = ImmediatePredecessor (ordinal - 1)

slotFor :: Int -> GateCategory -> ContractSlot GateSpecification
slotFor 0 category =
  BoundSpecification (GateSpecification 0 category (phaseZeroRequirement category))
#ifdef VALIDATION_PHASE_SEMANTIC_GAP_ACCEPTANCE_MUTANT
slotFor 1 Subject =
  BoundSpecification (GateSpecification 1 Subject RequireExactSourceBoundPhaseZeroDispatcher)
#endif
slotFor ordinal category = ContractGap (GapId ordinal category)

phaseZeroRequirement :: GateCategory -> GateRequirement
phaseZeroRequirement category = case category of
  Claim -> RequireGovernedCorpusAndSourcePolicyClosure
  Subject -> RequireExactSourceBoundPhaseZeroDispatcher
  Command -> RequireDirectPinnedOfflineHaskellInvocation
  Oracle -> RequireIndependentPhaseZeroOracleSet
  PositiveControls -> RequireClosedPhaseZeroPositiveCorpus
  PairedNegatives -> RequireMinimallyDifferentPhaseZeroNegatives
  Mutants -> RequireFiniteBootstrapChangedProductionMatrix
  Discovery -> RequireCompleteRuntimeDiscoveryEquality
  Challenge -> RequireFreshnessAndIndependentChallenge
  Observer -> RequireRawIndependentObservation
  AuthorityBypass -> RequireAuthorityAndBypassRejection
  Freshness -> RequireStartEndSourceAndRunFreshness
  Qualification -> RequireFiniteBootstrapQualificationSequence
  Cleanroom -> RequireRunScopedCleanroomAndResidueContainment
  LegacyClosure -> RequireStructuralLegacyInventoryWithNoPhaseZeroOwner
  PredecessorCategory -> RequireGenesisPredecessor
  Residue -> RequireNoPhaseZeroResidueAndTypedForwardDeferrals
  PassCriterion -> RequireQualifiedGatePass

gateSlotsFor :: Int -> Map GateCategory (ContractSlot GateSpecification)
gateSlotsFor ordinal = slotOmissionMutation canonicalSlots
 where
  canonicalSlots = Map.fromList [(category, slotFor ordinal category) | category <- gateCategories]
#ifdef VALIDATION_PHASE_SEMANTIC_SLOT_OMISSION_MUTANT
  slotOmissionMutation
    | ordinal == 1 = Map.delete Subject
    | otherwise = id
#else
  slotOmissionMutation = id
#endif

legacyIdsForPhase :: Int -> [Legacy.LegacyId]
legacyIdsForPhase ordinal =
  legacyRowMutation
    ordinal
    [ identifier
    | (owner, identifier) <- semanticLegacyReverseMap
    , owner == ordinal
    ]
 where
#ifdef VALIDATION_PHASE_SEMANTIC_LEGACY_ROW_SWAP_MUTANT
  legacyRowMutation 0 = map replacePhaseZero
  legacyRowMutation 1 = map replacePhaseOne
  legacyRowMutation _ = id
  replacePhaseZero identifier
    | identifier == Legacy.LtdSrc000 = Legacy.LtdSrc007
    | otherwise = identifier
  replacePhaseOne identifier
    | identifier == Legacy.LtdSrc007 = Legacy.LtdSrc000
    | otherwise = identifier
#else
  legacyRowMutation _ = id
#endif

semanticLegacyReverseMap :: [(Int, Legacy.LegacyId)]
semanticLegacyReverseMap =
  [ (semanticLegacyOwner identifier, identifier)
  | identifier <- Legacy.allLegacyIds
  ]

semanticLegacyOwner :: Legacy.LegacyId -> Int
#ifdef VALIDATION_PHASE_SEMANTIC_LEGACY_MUTANT
semanticLegacyOwner Legacy.LtdImg001 = 55
#endif
semanticLegacyOwner identifier =
  Policy.phaseOrdinalNumber (Legacy.legacyIdOwner identifier)

-- Independently stated requirement literals.  These strings are comparison
-- values only; Legacy owns the constructor universe, rendering, and owner
-- function used to build the semantic phase projection above.
expectedLegacyOwnerRelation :: [(Text, Int)]
expectedLegacyOwnerRelation =
  [ ("LTD-SRC-000", 2)
  , ("LTD-SRC-001", 47)
  , ("LTD-SRC-002", 25)
  , ("LTD-SRC-003", 26)
  , ("LTD-SRC-004", 46)
  , ("LTD-SRC-005", 47)
  , ("LTD-SRC-006", 47)
  , ("LTD-SRC-007", 1)
  , ("LTD-SRC-008", 2)
  , ("LTD-SRC-009", 1)
  , ("LTD-META-001", 2)
  , ("LTD-VAL-001", 49)
  , ("LTD-VAL-002", 49)
  , ("LTD-VAL-003", 49)
  , ("LTD-VAL-004", 49)
  , ("LTD-VAL-005", 49)
  , ("LTD-VAL-006", 49)
  , ("LTD-DOC-001", 27)
  , ("LTD-NAME-001", 2)
  , ("LTD-HOST-001", 51)
  , ("LTD-HOST-002", 51)
  , ("LTD-IMG-001", 56)
  , ("LTD-RUN-001", 55)
  , ("LTD-SEED-001", 91)
  , ("LTD-SEED-002", 93)
  , ("LTD-BOOT-001", 1)
  ]

guardsFor :: Int -> [CriticalGuard]
guardsFor ordinal
#ifdef VALIDATION_PHASE_SEMANTIC_UNEXPECTED_CRITICAL_GUARD_MUTANT
  | ordinal == barrierOrdinal - 1 = [Phase49SourceBarrier canonicalPhase49Requirements]
#endif
#ifdef VALIDATION_PHASE_SEMANTIC_PHASE49_SOURCE_GUARD_MUTANT
  | ordinal == barrierOrdinal = [Phase49SourceBarrier [RequireAllSourceMigrationQueriesZero]]
#else
  | ordinal == barrierOrdinal = [Phase49SourceBarrier canonicalPhase49Requirements]
#endif
#ifdef VALIDATION_PHASE_SEMANTIC_PHASE50_HANDOFF_GUARD_MUTANT
  | ordinal == handoffOrdinal =
      [ Phase50HandoffBoundary
          [ RequireNoSourceMigrationOwnership
          , RequirePassedPhase49SourceSnapshot
          , RequireIdentityArgvExecHandoff
          , RequirePublicTargetNotSelfSupervising
          ]
      ]
#else
  | ordinal == handoffOrdinal = [Phase50HandoffBoundary canonicalPhase50Requirements]
#endif
#ifdef VALIDATION_PHASE_SEMANTIC_PHASE51_FAKE_GUARD_MUTANT
  | ordinal == hostEnsureOrdinal = [Phase51FakeBoundary [RequireHaskellFakeBoundariesOnly]]
#else
  | ordinal == hostEnsureOrdinal = [Phase51FakeBoundary canonicalPhase51Requirements]
#endif
#ifdef VALIDATION_PHASE_SEMANTIC_PHASE52_HARDWARE_GUARD_MUTANT
  | ordinal == firstHardwareOrdinal = [Phase52HardwareBoundary []]
#else
  | ordinal == firstHardwareOrdinal = [Phase52HardwareBoundary canonicalPhase52Requirements]
#endif
  | ordinal == registryOrdinal =
  [ Phase56RegistryBoundary
      (Policy.registryContract Policy.canonicalPolicyContract)
#ifdef VALIDATION_PHASE_SEMANTIC_PROVIDER_MUTANT
      "mutation-only-alternate-registry"
#else
      (Policy.registryImageReference (Policy.registryProvider (Policy.registryContract Policy.canonicalPolicyContract)))
#endif
      RequireDistributionRegistry2Only
  ]
  | otherwise = []

canonicalPhase49Requirements :: [Phase49Requirement]
canonicalPhase49Requirements =
  [ RequireAllSourceMigrationQueriesZero
  , RequireAllOwnersAtOrBefore49Zero
  ]

canonicalPhase50Requirements :: [Phase50Requirement]
canonicalPhase50Requirements =
  [ RequireNoSourceMigrationOwnership
  , RequirePassedPhase49SourceSnapshot
  , RequireDirectHaskellSupervisorWithPbChild
  , RequireIdentityArgvExecHandoff
  , RequirePublicTargetNotSelfSupervising
  ]

canonicalPhase51Requirements :: [Phase51Requirement]
canonicalPhase51Requirements =
  [ RequireHardwareFreeExecution
  , RequireHaskellFakeBoundariesOnly
  ]

canonicalPhase52Requirements :: [Phase52Requirement]
canonicalPhase52Requirements = [RequireFirstHardwareValidation]

stageMatchesOrdinal :: PhaseSemanticContract -> Bool
stageMatchesOrdinal contract
  | semanticOrdinal contract <= barrierOrdinal = semanticExecutionStage contract == DirectSourceBoundHaskell
  | semanticOrdinal contract == handoffOrdinal = semanticExecutionStage contract == PbChildUnderDirectHaskellSupervisor
  | semanticOrdinal contract == hostEnsureOrdinal = semanticExecutionStage contract == GatePassBoundHaskellFakeBoundary
  | otherwise = semanticExecutionStage contract == GatePassBoundHardware

predecessorMatchesOrdinal :: PhaseSemanticContract -> Bool
predecessorMatchesOrdinal contract =
  semanticPredecessor contract
    == if semanticOrdinal contract == 0
      then Genesis
      else ImmediatePredecessor (semanticOrdinal contract - 1)

legacyReverseMapIsExact :: Bool
legacyReverseMapIsExact =
  actualLegacyOwnerRelation == expectedLegacyOwnerRelation
    && sort mappedIds == sort Legacy.allLegacyIds
    && length mappedIds == 26
    && length Legacy.allLegacyIds == 26
    && allUnique (map fst actualLegacyOwnerRelation)
 where
  mappedIds = concatMap semanticLegacyIds canonicalPhaseRegistry
  actualLegacyOwnerRelation =
    [ (Legacy.renderLegacyId identifier, owner)
    | (owner, identifier) <- semanticLegacyReverseMap
    ]

registryRowLegacyOwnersAreExact :: PhaseSemanticContract -> Bool
registryRowLegacyOwnersAreExact contract =
  all
    (\identifier -> Policy.phaseOrdinalNumber (Legacy.legacyIdOwner identifier) == semanticOrdinal contract)
    (semanticLegacyIds contract)

phaseIdentityProjectionIsExact :: PhaseSemanticContract -> Bool
phaseIdentityProjectionIsExact contract =
  case PhaseIdentity.lookupPhaseIdentity (semanticOrdinal contract) of
    Nothing -> False
    Just identityRow ->
      semanticCapabilityId contract == PhaseIdentity.phaseIdentityCapability identityRow
        && semanticPath contract == PhaseIdentity.phaseIdentityPath identityRow
        && semanticResourceProvision contract
          == PhaseIdentity.phaseIdentityResourceProvision identityRow

criticalGuardsAreExact :: Bool
criticalGuardsAreExact =
  actualGuardRelation == expectedGuardRelation
    && phase56GuardIsExact (guards 56)
    && null (legacy 50)
 where
  guards ordinal = maybe [] semanticCriticalGuards (lookupPhase ordinal canonicalPhaseRegistry)
  legacy ordinal = maybe [] semanticLegacyIds (lookupPhase ordinal canonicalPhaseRegistry)
  actualGuardRelation =
    [ (semanticOrdinal contract, semanticCriticalGuards contract)
    | contract <- canonicalPhaseRegistry
    , not (null (semanticCriticalGuards contract))
    ]
  expectedGuardRelation =
    [ (49, [Phase49SourceBarrier canonicalPhase49Requirements])
    , (50, [Phase50HandoffBoundary canonicalPhase50Requirements])
    , (51, [Phase51FakeBoundary canonicalPhase51Requirements])
    , (52, [Phase52HardwareBoundary canonicalPhase52Requirements])
    , ( 56
      , [ Phase56RegistryBoundary
            (Policy.registryContract Policy.canonicalPolicyContract)
            "registry:2"
            RequireDistributionRegistry2Only
        ]
      )
    ]

phase56GuardIsExact :: [CriticalGuard] -> Bool
phase56GuardIsExact guards = case guards of
  [Phase56RegistryBoundary contract reference exclusivityRequirement] ->
    Policy.registryProvider contract == Policy.DistributionRegistry2
      && reference == "registry:2"
      && Policy.registryImageReference (Policy.registryProvider contract) == "registry:2"
      && exclusivityRequirement == RequireDistributionRegistry2Only
  _ -> False

data CriticalBoundaryTuple = CriticalBoundaryTuple
  Int
  Substrate
  Lane
  ValidationRegister
  ExecutionStage
  Predecessor
  PhaseIdentity.ResourceProvisionRequirement
  [CriticalGuard]
  deriving (Eq, Show)

criticalBoundaryTuplesAreExact :: Bool
criticalBoundaryTuplesAreExact =
  actualBoundaryTuples == expectedBoundaryTuples
 where
  actualBoundaryTuples =
    [ criticalBoundaryTuple contract
    | contract <- canonicalPhaseRegistry
    , semanticOrdinal contract >= 49
    , semanticOrdinal contract <= 52
    ]
  expectedBoundaryTuples =
    [ CriticalBoundaryTuple
        49
        NoSubstrate
        NoLane
        Register2
        DirectSourceBoundHaskell
        (ImmediatePredecessor 48)
        PhaseIdentity.ResourceProvisionRequired
        [Phase49SourceBarrier canonicalPhase49Requirements]
    , CriticalBoundaryTuple
        50
        NoSubstrate
        NoLane
        Register2
        PbChildUnderDirectHaskellSupervisor
        (ImmediatePredecessor 49)
        PhaseIdentity.ResourceProvisionRequired
        [Phase50HandoffBoundary canonicalPhase50Requirements]
    , CriticalBoundaryTuple
        51
        NoSubstrate
        NoLane
        Register2
        GatePassBoundHaskellFakeBoundary
        (ImmediatePredecessor 50)
        PhaseIdentity.ResourceProvisionRequired
        [Phase51FakeBoundary canonicalPhase51Requirements]
    , CriticalBoundaryTuple
        52
        LinuxCpu
        LinuxCpuAmd64
        Register3
        GatePassBoundHardware
        (ImmediatePredecessor 51)
        PhaseIdentity.ResourceProvisionRequired
        [Phase52HardwareBoundary canonicalPhase52Requirements]
    ]

criticalBoundaryTuple :: PhaseSemanticContract -> CriticalBoundaryTuple
criticalBoundaryTuple contract =
  CriticalBoundaryTuple
    (semanticOrdinal contract)
    (semanticSubstrate contract)
    (semanticLane contract)
    (semanticRegister contract)
    (semanticExecutionStage contract)
    (semanticPredecessor contract)
    (semanticResourceProvision contract)
    (semanticCriticalGuards contract)

semanticSlotIdentitiesAreExact :: PhaseSemanticContract -> Bool
semanticSlotIdentitiesAreExact contract =
  all slotMatches gateCategories
 where
  ordinal = semanticOrdinal contract
  slotMatches category = case Map.lookup category (semanticGateSlots contract) of
    Nothing -> False
    Just (ContractGap (GapId slotOrdinal slotCategory)) ->
      slotOrdinal == ordinal && slotCategory == category
    Just (BoundSpecification (GateSpecification slotOrdinal slotCategory requirement)) ->
      slotOrdinal == ordinal
        && slotCategory == category
        && requirementCategory requirement == category

requirementCategory :: GateRequirement -> GateCategory
requirementCategory requirement = case requirement of
  RequireGovernedCorpusAndSourcePolicyClosure -> Claim
  RequireExactSourceBoundPhaseZeroDispatcher -> Subject
  RequireDirectPinnedOfflineHaskellInvocation -> Command
  RequireIndependentPhaseZeroOracleSet -> Oracle
  RequireClosedPhaseZeroPositiveCorpus -> PositiveControls
  RequireMinimallyDifferentPhaseZeroNegatives -> PairedNegatives
  RequireFiniteBootstrapChangedProductionMatrix -> Mutants
  RequireCompleteRuntimeDiscoveryEquality -> Discovery
  RequireFreshnessAndIndependentChallenge -> Challenge
  RequireRawIndependentObservation -> Observer
  RequireAuthorityAndBypassRejection -> AuthorityBypass
  RequireStartEndSourceAndRunFreshness -> Freshness
  RequireFiniteBootstrapQualificationSequence -> Qualification
  RequireRunScopedCleanroomAndResidueContainment -> Cleanroom
  RequireStructuralLegacyInventoryWithNoPhaseZeroOwner -> LegacyClosure
  RequireGenesisPredecessor -> PredecessorCategory
  RequireNoPhaseZeroResidueAndTypedForwardDeferrals -> Residue
  RequireQualifiedGatePass -> PassCriterion

pathMatchesCapability :: PhaseSemanticContract -> Bool
pathMatchesCapability contract =
  semanticPath contract == phaseFile (semanticOrdinal contract) (semanticCapabilityId contract)

lookupPhase :: Int -> [PhaseSemanticContract] -> Maybe PhaseSemanticContract
lookupPhase ordinal = lookup ordinal . map (\contract -> (semanticOrdinal contract, contract))

phaseFile :: Int -> Text -> FilePath
phaseFile ordinal capability =
  "DEVELOPMENT_PLAN/phase_"
    <> Text.unpack (renderOrdinal ordinal)
    <> "_"
    <> Text.unpack capability
    <> ".md"

renderPhaseProjection :: PhaseSemanticContract -> Text
renderPhaseProjection contract =
  Text.intercalate
    "|"
    [ renderOrdinal (semanticOrdinal contract)
    , semanticCapabilityId contract
    , Text.pack (semanticPath contract)
    , semanticTitle contract
    , renderSubstrate (semanticSubstrate contract)
    , renderLane (semanticLane contract)
    , renderRegister (semanticRegister contract)
    , renderExecutionStage (semanticExecutionStage contract)
    , renderPredecessor (semanticPredecessor contract)
    , Text.intercalate "," (map renderSemanticLegacyId (semanticLegacyIds contract))
    , Text.concat
        [ maybe "M" renderSlot (Map.lookup category (semanticGateSlots contract))
        | category <- gateCategories
        ]
    , Text.intercalate "," (map renderCriticalGuard (semanticCriticalGuards contract))
    ]

renderSlot :: ContractSlot GateSpecification -> Text
renderSlot slot = case slot of
  ContractGap _ -> "G"
  BoundSpecification _ -> "B"

renderGapId :: GapId -> Text
renderGapId (GapId ordinal category) =
  "phase-" <> renderOrdinal ordinal <> "-" <> categorySlug category

renderGateDraft :: GateSpecification -> Text
renderGateDraft (GateSpecification ordinal category requirement) =
  "phase-"
    <> renderOrdinal ordinal
    <> "-"
    <> categorySlug category
    <> "="
    <> gateRequirementSlug requirement

gateRequirementSlug :: GateRequirement -> Text
gateRequirementSlug requirement = case requirement of
  RequireGovernedCorpusAndSourcePolicyClosure -> "governed-corpus-and-source-policy-closure"
  RequireExactSourceBoundPhaseZeroDispatcher -> "exact-source-bound-phase-zero-dispatcher"
  RequireDirectPinnedOfflineHaskellInvocation -> "direct-pinned-offline-haskell-invocation"
  RequireIndependentPhaseZeroOracleSet -> "independent-phase-zero-oracle-set"
  RequireClosedPhaseZeroPositiveCorpus -> "closed-phase-zero-positive-corpus"
  RequireMinimallyDifferentPhaseZeroNegatives -> "minimally-different-phase-zero-negatives"
  RequireFiniteBootstrapChangedProductionMatrix -> "finite-bootstrap-changed-production-matrix"
  RequireCompleteRuntimeDiscoveryEquality -> "complete-runtime-discovery-equality"
  RequireFreshnessAndIndependentChallenge -> "freshness-and-independent-challenge"
  RequireRawIndependentObservation -> "raw-independent-observation"
  RequireAuthorityAndBypassRejection -> "authority-and-bypass-rejection"
  RequireStartEndSourceAndRunFreshness -> "start-end-source-and-run-freshness"
  RequireFiniteBootstrapQualificationSequence -> "finite-bootstrap-qualification-sequence"
  RequireRunScopedCleanroomAndResidueContainment -> "run-scoped-cleanroom-and-residue-containment"
  RequireStructuralLegacyInventoryWithNoPhaseZeroOwner -> "structural-legacy-inventory-with-no-phase-zero-owner"
  RequireGenesisPredecessor -> "genesis-predecessor"
  RequireNoPhaseZeroResidueAndTypedForwardDeferrals -> "no-phase-zero-residue-and-typed-forward-deferrals"
  RequireQualifiedGatePass -> "qualified-gate-pass"

renderGateCategory :: GateCategory -> Text
renderGateCategory category = case category of
  Claim -> "Claim"
  Subject -> "Subject"
  Command -> "Command"
  Oracle -> "Oracle"
  PositiveControls -> "Positive controls"
  PairedNegatives -> "Paired negatives"
  Mutants -> "Mutants"
  Discovery -> "Discovery"
  Challenge -> "Challenge"
  Observer -> "Observer"
  AuthorityBypass -> "Authority/bypass"
  Freshness -> "Freshness"
  Qualification -> "Qualification"
  Cleanroom -> "Cleanroom"
  LegacyClosure -> "Legacy closure"
  PredecessorCategory -> "Predecessor"
  Residue -> "Residue"
  PassCriterion -> "Pass criterion"

categorySlug :: GateCategory -> Text
categorySlug = Text.map replace . Text.toLower . renderGateCategory
 where
  replace character
    | character == ' ' || character == '/' = '-'
    | otherwise = character

renderSubstrate :: Substrate -> Text
renderSubstrate substrate = case substrate of
  NoSubstrate -> "none"
  LinuxCpu -> "linux-cpu"
  Apple -> "apple"
  Windows -> "windows"
  LinuxCuda -> "linux-cuda"

renderLane :: Lane -> Text
renderLane lane = case lane of
  NoLane -> "none"
  LinuxCpuAmd64 -> "linux-cpu/amd64"
  LinuxCpuArm64 -> "linux-cpu/arm64"
  Provider -> "provider"
  Metal -> "metal"
  Cuda -> "cuda"

renderRegister :: ValidationRegister -> Text
renderRegister validationRegister = case validationRegister of
  NoRegister -> "—"
  Register1 -> "1"
  Register2 -> "2"
  Register3 -> "3"

renderExecutionStage :: ExecutionStage -> Text
renderExecutionStage executionStage = case executionStage of
  DirectSourceBoundHaskell -> "DirectSourceBoundHaskell"
  PbChildUnderDirectHaskellSupervisor -> "PbChildUnderDirectHaskellSupervisor"
  GatePassBoundHaskellFakeBoundary -> "GatePassBoundHaskellFakeBoundary"
  GatePassBoundHardware -> "GatePassBoundHardware"

renderPredecessor :: Predecessor -> Text
renderPredecessor predecessor = case predecessor of
  Genesis -> "genesis"
  ImmediatePredecessor ordinal -> "phase-" <> renderOrdinal ordinal

renderSemanticLegacyId :: Legacy.LegacyId -> Text
renderSemanticLegacyId = Legacy.renderLegacyId

renderCriticalGuard :: CriticalGuard -> Text
renderCriticalGuard criticalGuard = case criticalGuard of
  Phase49SourceBarrier requirements ->
    "phase49:requires=" <> Text.intercalate "," (map renderPhase49Requirement requirements)
  Phase50HandoffBoundary requirements ->
    "phase50:requires=" <> Text.intercalate "," (map renderPhase50Requirement requirements)
  Phase51FakeBoundary requirements ->
    "phase51:requires=" <> Text.intercalate "," (map renderPhase51Requirement requirements)
  Phase52HardwareBoundary requirements ->
    "phase52:requires=" <> Text.intercalate "," (map renderPhase52Requirement requirements)
  Phase56RegistryBoundary contract reference exclusivityRequirement ->
    "phase56:provider="
      <> Text.pack (show (Policy.registryProvider contract))
      <> ";image="
      <> reference
      <> ";requires="
      <> renderRegistryExclusivityRequirement exclusivityRequirement

renderPhase49Requirement :: Phase49Requirement -> Text
renderPhase49Requirement requirement = case requirement of
  RequireAllSourceMigrationQueriesZero -> "all-source-migration-queries-zero"
  RequireAllOwnersAtOrBefore49Zero -> "all-owners-at-or-before-49-zero"

renderPhase50Requirement :: Phase50Requirement -> Text
renderPhase50Requirement requirement = case requirement of
  RequireNoSourceMigrationOwnership -> "no-source-migration-ownership"
  RequirePassedPhase49SourceSnapshot -> "phase49-gate-pass-source-snapshot"
  RequireDirectHaskellSupervisorWithPbChild -> "direct-haskell-supervisor-with-pb-child"
  RequireIdentityArgvExecHandoff -> "identity-argv-exec-handoff"
  RequirePublicTargetNotSelfSupervising -> "public-target-not-self-supervising"

renderPhase51Requirement :: Phase51Requirement -> Text
renderPhase51Requirement requirement = case requirement of
  RequireHardwareFreeExecution -> "hardware-free-execution"
  RequireHaskellFakeBoundariesOnly -> "haskell-fake-boundaries-only"

renderPhase52Requirement :: Phase52Requirement -> Text
renderPhase52Requirement RequireFirstHardwareValidation = "first-hardware-validation"

renderRegistryExclusivityRequirement :: RegistryExclusivityRequirement -> Text
renderRegistryExclusivityRequirement RequireDistributionRegistry2Only = "distribution-registry2-only"

renderOrdinal :: Int -> Text
renderOrdinal ordinal = Text.justifyRight 2 '0' (showText ordinal)

showText :: Show value => value -> Text
showText = Text.pack . show

allUnique :: Ord value => [value] -> Bool
allUnique values = all ((== 1) . length) (group (sort values))

-- The structural join accepts only a deliberately narrow projection produced
-- by PhaseSemanticJoin.  Each tuple contains ordinal, path, H1 title, ordered
-- six-field labels, substrate token, lane token, register token, predecessor
-- link token, future command, current status, ordered gate-row labels, unresolved
-- row labels, and the exact tracker-row projection.  It never receives Claim,
-- Subject, Oracle, provider, module, count, Legacy-ID, or other prose.
phaseStructuralProjectionDiagnostic
  :: [ ( Int
       , FilePath
       , Text
       , [Text]
       , Text
       , Text
       , Text
       , Text
       , Text
       , Text
       , [Text]
       , [Text]
       , Text
       )
     ]
  -> CheckResult
phaseStructuralProjectionDiagnostic =
  phaseStructuralProjectionWithAuthority False Status.initialFrontier

-- | Integrated correspondence check. The caller-authored projection still
-- cannot populate a typed slot, but the gate may compare it with the compiled
-- registry without retaining the public diagnostic seam's permanent refusal.
phaseStructuralProjectionCheck
  :: [ ( Int
       , FilePath
       , Text
       , [Text]
       , Text
       , Text
       , Text
       , Text
       , Text
       , Text
       , [Text]
       , [Text]
       , Text
       )
     ]
  -> CheckResult
phaseStructuralProjectionCheck = phaseStructuralProjectionCheckForPhase 0

-- | Integrated correspondence check at the exact numerical validation
-- frontier. Earlier phases must already be Done, this phase must be Active,
-- and later phases must remain Blocked.
phaseStructuralProjectionCheckForPhase
  :: Int
  -> [ ( Int
       , FilePath
       , Text
       , [Text]
       , Text
       , Text
       , Text
       , Text
       , Text
       , Text
       , [Text]
       , [Text]
       , Text
       )
     ]
  -> CheckResult
phaseStructuralProjectionCheckForPhase phaseUnderValidation supplied =
  case Status.frontierForGate phaseUnderValidation of
    Nothing ->
      CheckResult
        { checkName = "phase-semantic-structural-projection"
        , checkObservations = [observation "semantic.status-frontier" "invalid"]
        , checkFindings =
            [ finding
                "PHASE-SEMANTIC-STATUS-FRONTIER"
                "DEVELOPMENT_PLAN/"
                "the requested phase is outside the canonical status-frontier domain"
            ]
        }
    Just frontier -> phaseStructuralProjectionCheckAtFrontier frontier supplied

phaseStructuralProjectionCheckAtFrontier
  :: Status.StatusFrontier
  -> [ ( Int
       , FilePath
       , Text
       , [Text]
       , Text
       , Text
       , Text
       , Text
       , Text
       , Text
       , [Text]
       , [Text]
       , Text
       )
     ]
  -> CheckResult
phaseStructuralProjectionCheckAtFrontier =
  phaseStructuralProjectionWithAuthority True

phaseStructuralProjectionWithAuthority
  :: Bool
  -> Status.StatusFrontier
  -> [ ( Int
       , FilePath
       , Text
       , [Text]
       , Text
       , Text
       , Text
       , Text
       , Text
       , Text
       , [Text]
       , [Text]
       , Text
       )
     ]
  -> CheckResult
phaseStructuralProjectionWithAuthority integrated frontier supplied =
  CheckResult
    { checkName = "phase-semantic-structural-projection-diagnostic"
    , checkObservations =
        [ observation "semantic.join.phase-count" (showText (length supplied))
        , observation "semantic.join.distinct-ordinal-count" (showText (Map.size grouped))
        ]
    , checkFindings =
        cardinalityFindings
          <> duplicateFindings
          <> missingFindings
          <> extraFindings
          <> concatMap (compareProjection frontier) supplied
          <> [item | item <- structuralDiagnosticRefusal, not integrated]
    }
 where
  grouped = Map.fromListWith (<>) [(ordinalOf row, [row]) | row <- supplied]
  cardinalityFindings =
    [ finding
        "PLAN-SEMANTIC-JOIN-CARDINALITY"
        "DEVELOPMENT_PLAN/"
        ("expected exactly 96 phase projections; observed " <> showText (length supplied))
    | length supplied /= 96
    ]
  duplicateFindings =
    [ finding
        "PLAN-SEMANTIC-JOIN-DUPLICATE"
        "DEVELOPMENT_PLAN/"
        ("phase=" <> renderOrdinal ordinal <> " has " <> showText (length rows) <> " projections")
    | (ordinal, rows) <- Map.toAscList grouped
    , length rows /= 1
    ]
  expectedOrdinals = map semanticOrdinal canonicalPhaseRegistry
  missingFindings =
    [ finding
        "PLAN-SEMANTIC-JOIN-MISSING"
        (semanticPath expected)
        ("phase=" <> renderOrdinal ordinal <> " structural projection is absent")
    | ordinal <- expectedOrdinals
    , Map.notMember ordinal grouped
    , Just expected <- [lookupPhase ordinal canonicalPhaseRegistry]
    ]
  extraFindings =
    [ finding
        "PLAN-SEMANTIC-JOIN-EXTRA"
        (pathOf row)
        ("phase=" <> showText (ordinalOf row) <> " lies outside the canonical registry")
    | row <- supplied
    , lookupPhase (ordinalOf row) canonicalPhaseRegistry == Nothing
    ]

structuralDiagnosticRefusal :: [Finding]
#ifdef VALIDATION_PHASE_SEMANTIC_DIAGNOSTIC_RESIDUE_REMOVAL_MUTANT
structuralDiagnosticRefusal = []
#else
structuralDiagnosticRefusal =
  [ finding
      "PLAN-SEMANTIC-JOIN-DIAGNOSTIC-ONLY"
      "DEVELOPMENT_PLAN/"
      "caller-supplied structural projections cannot populate or pass a semantic contract slot"
  ]
#endif

compareProjection
  :: Status.StatusFrontier
  -> ( Int
     , FilePath
     , Text
     , [Text]
     , Text
     , Text
     , Text
     , Text
     , Text
     , Text
     , [Text]
     , [Text]
     , Text
     )
  -> [Finding]
compareProjection frontier row = case lookupPhase (ordinalOf row) canonicalPhaseRegistry of
  Nothing -> []
  Just expected ->
    concat
      [ mismatch expected "path" (Text.pack (semanticPath expected)) (Text.pack (pathOf row))
      , mismatch expected "title" (semanticTitle expected) (titleOf row)
      , mismatch expected "summary-field-order" expectedSummaryFields (summaryFieldsOf row)
      , mismatch expected "substrate" (renderSubstrate (semanticSubstrate expected)) (substrateOf row)
      , mismatch expected "lane" (renderLane (semanticLane expected)) (laneOf row)
      , mismatch expected "register" (renderRegister (semanticRegister expected)) (registerOf row)
      , mismatch expected "predecessor-link" (expectedPredecessorLink expected) (predecessorLinkOf row)
      , mismatch expected "future-command" (expectedFutureCommand expected) (futureCommandOf row)
      , mismatch expected "current-status" (expectedCurrentStatus frontier expected) (resetStatusOf row)
      , mismatch expected "gate-row-order" (map renderGateCategory gateCategories) (gateRowsOf row)
      , mismatch expected "unresolved-shape" (expectedUnresolvedRows expected) (unresolvedRowsOf row)
      , mismatch expected "tracker-row" (expectedTrackerProjection frontier expected) (trackerProjectionOf row)
      ]

mismatch :: (Eq value, Show value) => PhaseSemanticContract -> Text -> value -> value -> [Finding]
mismatch expected fieldName wanted observed =
  [ finding
      "PLAN-SEMANTIC-JOIN-MISMATCH"
      (semanticPath expected)
      ( "phase="
          <> renderOrdinal (semanticOrdinal expected)
          <> " field="
          <> fieldName
          <> " expected="
          <> showText wanted
          <> " actual="
          <> showText observed
      )
  | wanted /= observed
  ]

expectedSummaryFields :: [Text]
expectedSummaryFields = ["Phase scope", "Substrate", "Lane", "Register", "Depends on", "Gate"]

expectedPredecessorLink :: PhaseSemanticContract -> Text
expectedPredecessorLink expected = case semanticPredecessor expected of
  Genesis -> "genesis"
  ImmediatePredecessor ordinal ->
    case lookupPhase ordinal canonicalPhaseRegistry of
      Nothing -> "missing-predecessor"
      Just predecessor ->
        "Phase " <> showText ordinal <> "|" <> Text.pack (semanticPath predecessor)

expectedFutureCommand :: PhaseSemanticContract -> Text
expectedFutureCommand expected =
  "pb validate phase " <> renderOrdinal (semanticOrdinal expected)

expectedCurrentStatus :: Status.StatusFrontier -> PhaseSemanticContract -> Text
expectedCurrentStatus frontier expected =
  Status.renderTrackerStatus
    (Status.phaseStatusAt frontier (semanticOrdinal expected))

expectedUnresolvedRows :: PhaseSemanticContract -> [Text]
expectedUnresolvedRows expected =
  map renderGateCategory
    [ category
    | category <- gateCategories
    , Just (ContractGap _) <- [Map.lookup category (semanticGateSlots expected)]
    ]

expectedTrackerProjection :: Status.StatusFrontier -> PhaseSemanticContract -> Text
expectedTrackerProjection frontier expected =
  Text.intercalate
    "|"
    [ semanticTitle expected
    , renderSubstrate (semanticSubstrate expected)
    , renderLane (semanticLane expected)
    , renderRegister (semanticRegister expected)
    , expectedCurrentStatus frontier expected
    , Text.pack (semanticPath expected)
    ]

ordinalOf
  :: (Int, FilePath, Text, [Text], Text, Text, Text, Text, Text, Text, [Text], [Text], Text)
  -> Int
ordinalOf (value, _, _, _, _, _, _, _, _, _, _, _, _) = value

pathOf
  :: (Int, FilePath, Text, [Text], Text, Text, Text, Text, Text, Text, [Text], [Text], Text)
  -> FilePath
pathOf (_, value, _, _, _, _, _, _, _, _, _, _, _) = value

titleOf, substrateOf, laneOf, registerOf, predecessorLinkOf, futureCommandOf, resetStatusOf, trackerProjectionOf
  :: (Int, FilePath, Text, [Text], Text, Text, Text, Text, Text, Text, [Text], [Text], Text)
  -> Text
titleOf (_, _, value, _, _, _, _, _, _, _, _, _, _) = value
substrateOf (_, _, _, _, value, _, _, _, _, _, _, _, _) = value
laneOf (_, _, _, _, _, value, _, _, _, _, _, _, _) = value
registerOf (_, _, _, _, _, _, value, _, _, _, _, _, _) = value
predecessorLinkOf (_, _, _, _, _, _, _, value, _, _, _, _, _) = value
futureCommandOf (_, _, _, _, _, _, _, _, value, _, _, _, _) = value
resetStatusOf (_, _, _, _, _, _, _, _, _, value, _, _, _) = value
trackerProjectionOf (_, _, _, _, _, _, _, _, _, _, _, _, value) = value

summaryFieldsOf, gateRowsOf, unresolvedRowsOf
  :: (Int, FilePath, Text, [Text], Text, Text, Text, Text, Text, Text, [Text], [Text], Text)
  -> [Text]
summaryFieldsOf (_, _, _, value, _, _, _, _, _, _, _, _, _) = value
gateRowsOf (_, _, _, _, _, _, _, _, _, _, value, _, _) = value
unresolvedRowsOf (_, _, _, _, _, _, _, _, _, _, _, value, _) = value
