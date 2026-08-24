{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.PolicyContract.Internal
  ( AutomationRole (..)
  , ArchiveRegisterRule (..)
  , BehavioralLanguage (..)
  , BootstrapOperation (..)
  , DslBarrierSourceClosure (..)
  , GenerationContract (..)
  , GenerationRoot (..)
  , GenerationTiming (..)
  , HistoricalEvidenceRule (..)
  , OrderingContract (..)
  , PbAdmission (..)
  , PbContract (..)
  , PbSourceLanguage (..)
  , PbTransportRule (..)
  , Phase50MigrationRule (..)
  , PhaseOrdinal
  , PhaseRole (..)
  , PolicyContract (..)
  , PolicyId (..)
  , PolicyOwnerReference (..)
  , PredecessorRule (..)
  , PrehardwareRule (..)
  , PromotionAuthority (..)
  , PromotionContract (..)
  , PublicBehaviorAuthority (..)
  , ResetPhaseStatus (..)
  , RegisterContract (..)
  , RegisterCardinality (..)
  , RegisterHistory (..)
  , RegisterPredicateAuthority (..)
  , RegistryContract (..)
  , RegistryPlacement (..)
  , RegistryProvider (..)
  , SourceClassification (..)
  , SourceContract (..)
  , SprintResetRule (..)
  , StatusResetContract (..)
  , StatusMutationAuthority (..)
  , TrackedGeneratedArtifact (..)
  , canonicalPolicyContract
  , canonicalActiveRegisterPath
  , canonicalForbiddenArchivePath
  , behavioralSourceSuffix
  , checkPolicyContract
  , generationRootPath
  , mkPhaseOrdinal
  , phaseOrdinalNumber
  , phaseRoleOrdinal
  , policyContractDigest
  , policyContractDiagnostic
  , policyOwnerReference
  , promotionAuthorityMarker
  , registryImageReference
  , renderPolicyContract
  , resetPhaseStatusText
  ) where

import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , Observation (..)
  , finding
  , observation
  )
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Word (Word8)

-- This module is executable policy. Markdown owns explanation and a human
-- correspondence review, never these values or their verdict.

data PolicyId
  = TrackedSourceBoundary
  | PbBootstrapBoundary
  | LazyBuildGeneration
  | ClusterRegistryProvider
  | ClusterRegistryPlacement
  | ActiveLegacyRegister
  | ValidationStatusReset
  | NumericPhaseOrder
  | DslBarrierSourceClosurePolicy
  | PrehardwarePromotionBarrier
  | PromotionAuthorityPolicy
#ifdef VALIDATION_POLICY_UNIVERSE_POLICY_ID_MUTANT
  | MutationOnlyPolicyId
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data PolicyOwnerReference = PolicyOwnerReference
  { policyOwnerPath :: FilePath
  , policyOwnerAnchor :: Text
  , policyOwnerSection :: Text
  }
  deriving (Eq, Ord, Show)

data BehavioralLanguage
  = HaskellDotHs
#ifdef VALIDATION_POLICY_UNIVERSE_BEHAVIORAL_LANGUAGE_MUTANT
  | MutationOnlyBehavioralLanguage
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data SourceClassification
  = SemanticClosedWorld
#ifdef VALIDATION_POLICY_UNIVERSE_SOURCE_CLASSIFICATION_MUTANT
  | MutationOnlySourceClassification
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data PublicBehaviorAuthority
  = HaskellBinaryOnly
#ifdef VALIDATION_POLICY_UNIVERSE_PUBLIC_BEHAVIOR_AUTHORITY_MUTANT
  | MutationOnlyPublicBehaviorAuthority
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data SourceContract = SourceContract
  { sourceBehavioralLanguage :: BehavioralLanguage
  , sourceClassification :: SourceClassification
  , sourcePublicBehaviorAuthority :: PublicBehaviorAuthority
  }
  deriving (Eq, Ord, Show)

behavioralSourceSuffix :: BehavioralLanguage -> FilePath
behavioralSourceSuffix language
  | language == HaskellDotHs = ".hs"
  | otherwise = ".mutation-only"

data BootstrapOperation
  = MinimalPlatformDistinction
  | ContainedToolchainEstablishment
  | SourceBoundHaskellBuild
  | OpaqueArgumentPreservingExec
#ifdef VALIDATION_POLICY_UNIVERSE_BOOTSTRAP_OPERATION_MUTANT
  | MutationOnlyBootstrapOperation
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data PbAdmission
  = DenyByDefaultStaticAstImportCallControlFlowPotentialEffect
#ifdef VALIDATION_POLICY_UNIVERSE_PB_ADMISSION_MUTANT
  | MutationOnlyPbAdmission
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data PbSourceLanguage
  = PythonSourceLanguage
#ifdef VALIDATION_POLICY_UNIVERSE_PB_SOURCE_LANGUAGE_MUTANT
  | MutationOnlyPbSourceLanguage
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data PbContract = PbContract
  { pbRoot :: FilePath
  , pbSourceLanguage :: PbSourceLanguage
  , pbOperations :: Set BootstrapOperation
  , pbAdmission :: PbAdmission
  }
  deriving (Eq, Ord, Show)

data GenerationTiming
  = LazyAtConsumption
#ifdef VALIDATION_POLICY_UNIVERSE_GENERATION_TIMING_MUTANT
  | MutationOnlyGenerationTiming
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data GenerationRoot
  = IgnoredDotBuild
#ifdef VALIDATION_POLICY_UNIVERSE_GENERATION_ROOT_MUTANT
  | MutationOnlyGenerationRoot
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data TrackedGeneratedArtifact
  = TrackedGeneratedArtifactForbidden
#ifdef VALIDATION_POLICY_UNIVERSE_TRACKED_GENERATED_ARTIFACT_MUTANT
  | MutationOnlyTrackedGeneratedArtifact
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data GenerationContract = GenerationContract
  { generationTiming :: GenerationTiming
  , generationRoot :: GenerationRoot
  , trackedGeneratedArtifact :: TrackedGeneratedArtifact
  }
  deriving (Eq, Ord, Show)

-- The normal build has exactly one constructor. The conditional constructor
-- exists only in an explicitly selected changed-production-subject build; it
-- widens the compiled universe without changing the canonical selection.
data RegistryProvider
  = DistributionRegistry2
#ifdef VALIDATION_POLICY_ALTERNATE_REGISTRY_MUTANT
  | AlternateRegistryProvider
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data RegistryPlacement
  = SeparatelyPinnedAndPreloaded
#ifdef VALIDATION_POLICY_UNIVERSE_REGISTRY_PLACEMENT_MUTANT
  | MutationOnlyRegistryPlacement
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data RegistryContract = RegistryContract
  { registryProvider :: RegistryProvider
  , registryPlacement :: RegistryPlacement
  }
  deriving (Eq, Ord, Show)

data RegisterHistory
  = GitHistoryOnly
#ifdef VALIDATION_POLICY_UNIVERSE_REGISTER_HISTORY_MUTANT
  | MutationOnlyRegisterHistory
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data RegisterPredicateAuthority
  = HaskellPredicateOnly
#ifdef VALIDATION_POLICY_UNIVERSE_REGISTER_PREDICATE_AUTHORITY_MUTANT
  | MutationOnlyRegisterPredicateAuthority
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data RegisterCardinality
  = ExactlyOneActiveRegister
#ifdef VALIDATION_POLICY_UNIVERSE_REGISTER_CARDINALITY_MUTANT
  | MutationOnlyRegisterCardinality
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data ArchiveRegisterRule
  = ArchiveRegisterForbidden
#ifdef VALIDATION_POLICY_UNIVERSE_ARCHIVE_REGISTER_RULE_MUTANT
  | MutationOnlyArchiveRegisterRule
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data RegisterContract = RegisterContract
  { activeRegisterPath :: FilePath
  , activeRegisterCardinality :: RegisterCardinality
  , forbiddenArchivePath :: FilePath
  , archiveRegisterRule :: ArchiveRegisterRule
  , registerHistory :: RegisterHistory
  , registerPredicateAuthority :: RegisterPredicateAuthority
  }
  deriving (Eq, Ord, Show)

data ResetPhaseStatus
  = ActiveNotValidated
  | BlockedNotValidated
#ifdef VALIDATION_POLICY_UNIVERSE_RESET_PHASE_STATUS_MUTANT
  | MutationOnlyResetPhaseStatus
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data SprintResetRule
  = EverySprintNotValidated
#ifdef VALIDATION_POLICY_UNIVERSE_SPRINT_RESET_RULE_MUTANT
  | MutationOnlySprintResetRule
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data HistoricalEvidenceRule
  = PriorValidationPermanentlyInvalid
#ifdef VALIDATION_POLICY_UNIVERSE_HISTORICAL_EVIDENCE_RULE_MUTANT
  | MutationOnlyHistoricalEvidenceRule
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data StatusResetContract = StatusResetContract
  { phaseZeroResetStatus :: ResetPhaseStatus
  , laterPhaseResetStatus :: ResetPhaseStatus
  , sprintResetRule :: SprintResetRule
  , historicalEvidenceRule :: HistoricalEvidenceRule
  }
  deriving (Eq, Ord, Show)

resetPhaseStatusText :: ResetPhaseStatus -> Text
resetPhaseStatusText status
  | status == ActiveNotValidated = "🔄 Active — NOT VALIDATED"
  | status == BlockedNotValidated = "⏸️ Blocked — NOT VALIDATED"
  | otherwise = "mutation-only-status"

newtype PhaseOrdinal = PhaseOrdinal Word8
  deriving (Eq, Ord, Show)

mkPhaseOrdinal :: Int -> Maybe PhaseOrdinal
mkPhaseOrdinal value
  | value >= 0 && value <= 95 = Just (PhaseOrdinal (fromIntegral value))
  | otherwise = Nothing

phaseOrdinalNumber :: PhaseOrdinal -> Int
phaseOrdinalNumber (PhaseOrdinal value) = fromIntegral value

data PredecessorRule
  = ImmediateNumericPredecessor
#ifdef VALIDATION_POLICY_UNIVERSE_PREDECESSOR_RULE_MUTANT
  | MutationOnlyPredecessorRule
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data PhaseRole
  = HardwareFreeDslBarrier
  | BoundedPbHandoffValidation
  | HaskellHostEnsure
  | FirstHardwareValidation
#ifdef VALIDATION_POLICY_UNIVERSE_PHASE_ROLE_MUTANT
  | MutationOnlyPhaseRole
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data Phase50MigrationRule
  = NoSourceMigration
#ifdef VALIDATION_POLICY_UNIVERSE_PHASE50_MIGRATION_RULE_MUTANT
  | MutationOnlyPhase50MigrationRule
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data DslBarrierSourceClosure
  = AllLtdSrcQueriesZeroBeforePhase49
#ifdef VALIDATION_POLICY_UNIVERSE_DSL_BARRIER_SOURCE_CLOSURE_MUTANT
  | MutationOnlyDslBarrierSourceClosure
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data PrehardwareRule
  = NoHardwareThroughPhase51
#ifdef VALIDATION_POLICY_UNIVERSE_PREHARDWARE_RULE_MUTANT
  | MutationOnlyPrehardwareRule
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data PbTransportRule
  = DirectHaskellThrough49ObservedPbAt50ApprovalBoundAfter50
#ifdef VALIDATION_POLICY_PB_TRANSPORT_MUTANT
  | PbAdmittedBeforePhase50
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data OrderingContract = OrderingContract
  { phaseDomainLower :: PhaseOrdinal
  , phaseDomainUpper :: PhaseOrdinal
  , predecessorRule :: PredecessorRule
  , hardwareFreeDslBarrierPhase :: PhaseOrdinal
  , boundedPbHandoffValidationPhase :: PhaseOrdinal
  , haskellHostEnsurePhase :: PhaseOrdinal
  , firstHardwareValidationPhase :: PhaseOrdinal
  , phase50MigrationRule :: Phase50MigrationRule
  , dslBarrierSourceClosure :: DslBarrierSourceClosure
  , prehardwareRule :: PrehardwareRule
  , pbTransportRule :: PbTransportRule
  }
  deriving (Eq, Show)

phaseRoleOrdinal :: OrderingContract -> PhaseRole -> PhaseOrdinal
phaseRoleOrdinal ordering role
  | role == HardwareFreeDslBarrier = hardwareFreeDslBarrierPhase ordering
  | role == BoundedPbHandoffValidation = boundedPbHandoffValidationPhase ordering
  | role == HaskellHostEnsure = haskellHostEnsurePhase ordering
  | role == FirstHardwareValidation = firstHardwareValidationPhase ordering
  | otherwise = phaseDomainLower ordering

data PromotionAuthority
  = ExternallyAnchoredHumanOnly
#ifdef VALIDATION_POLICY_UNIVERSE_PROMOTION_AUTHORITY_MUTANT
  | MutationOnlyPromotionAuthority
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data AutomationRole
  = CandidateEvidenceOnly
#ifdef VALIDATION_POLICY_UNIVERSE_AUTOMATION_ROLE_MUTANT
  | MutationOnlyAutomationRole
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data StatusMutationAuthority
  = HumanUserOnly
#ifdef VALIDATION_POLICY_UNIVERSE_STATUS_MUTATION_AUTHORITY_MUTANT
  | MutationOnlyStatusMutationAuthority
#endif
  deriving (Bounded, Enum, Eq, Ord, Show)

data PromotionContract = PromotionContract
  { promotionAuthority :: PromotionAuthority
  , automationRole :: AutomationRole
  , statusMutationAuthority :: StatusMutationAuthority
  }
  deriving (Eq, Ord, Show)

data PolicyContract = PolicyContract
  { contractOwners :: Map PolicyId PolicyOwnerReference
  , sourceContract :: SourceContract
  , pbContract :: PbContract
  , generationContract :: GenerationContract
  , registryContract :: RegistryContract
  , registerContract :: RegisterContract
  , statusResetContract :: StatusResetContract
  , orderingContract :: OrderingContract
  , promotionContract :: PromotionContract
  }
  deriving (Eq, Show)

expectedPolicyIdUniverse :: [PolicyId]
expectedPolicyIdUniverse =
  [ TrackedSourceBoundary
  , PbBootstrapBoundary
  , LazyBuildGeneration
  , ClusterRegistryProvider
  , ClusterRegistryPlacement
  , ActiveLegacyRegister
  , ValidationStatusReset
  , NumericPhaseOrder
  , DslBarrierSourceClosurePolicy
  , PrehardwarePromotionBarrier
  , PromotionAuthorityPolicy
  ]

expectedBehavioralLanguageUniverse :: [BehavioralLanguage]
expectedBehavioralLanguageUniverse = [HaskellDotHs]

expectedSourceClassificationUniverse :: [SourceClassification]
expectedSourceClassificationUniverse = [SemanticClosedWorld]

expectedPublicBehaviorAuthorityUniverse :: [PublicBehaviorAuthority]
expectedPublicBehaviorAuthorityUniverse = [HaskellBinaryOnly]

expectedPbSourceLanguageUniverse :: [PbSourceLanguage]
expectedPbSourceLanguageUniverse = [PythonSourceLanguage]

expectedBootstrapOperationUniverse :: [BootstrapOperation]
expectedBootstrapOperationUniverse =
  [ MinimalPlatformDistinction
  , ContainedToolchainEstablishment
  , SourceBoundHaskellBuild
  , OpaqueArgumentPreservingExec
  ]

expectedPbAdmissionUniverse :: [PbAdmission]
expectedPbAdmissionUniverse = [DenyByDefaultStaticAstImportCallControlFlowPotentialEffect]

expectedGenerationTimingUniverse :: [GenerationTiming]
expectedGenerationTimingUniverse = [LazyAtConsumption]

expectedGenerationRootUniverse :: [GenerationRoot]
expectedGenerationRootUniverse = [IgnoredDotBuild]

expectedTrackedGeneratedArtifactUniverse :: [TrackedGeneratedArtifact]
expectedTrackedGeneratedArtifactUniverse = [TrackedGeneratedArtifactForbidden]

expectedRegistryProviderUniverse :: [RegistryProvider]
expectedRegistryProviderUniverse = [DistributionRegistry2]

expectedRegistryPlacementUniverse :: [RegistryPlacement]
expectedRegistryPlacementUniverse = [SeparatelyPinnedAndPreloaded]

expectedRegisterCardinalityUniverse :: [RegisterCardinality]
expectedRegisterCardinalityUniverse = [ExactlyOneActiveRegister]

expectedArchiveRegisterRuleUniverse :: [ArchiveRegisterRule]
expectedArchiveRegisterRuleUniverse = [ArchiveRegisterForbidden]

expectedRegisterHistoryUniverse :: [RegisterHistory]
expectedRegisterHistoryUniverse = [GitHistoryOnly]

expectedRegisterPredicateAuthorityUniverse :: [RegisterPredicateAuthority]
expectedRegisterPredicateAuthorityUniverse = [HaskellPredicateOnly]

expectedResetPhaseStatusUniverse :: [ResetPhaseStatus]
expectedResetPhaseStatusUniverse = [ActiveNotValidated, BlockedNotValidated]

expectedSprintResetRuleUniverse :: [SprintResetRule]
expectedSprintResetRuleUniverse = [EverySprintNotValidated]

expectedHistoricalEvidenceRuleUniverse :: [HistoricalEvidenceRule]
expectedHistoricalEvidenceRuleUniverse = [PriorValidationPermanentlyInvalid]

expectedPredecessorRuleUniverse :: [PredecessorRule]
expectedPredecessorRuleUniverse = [ImmediateNumericPredecessor]

expectedPhaseRoleUniverse :: [PhaseRole]
expectedPhaseRoleUniverse =
  [ HardwareFreeDslBarrier
  , BoundedPbHandoffValidation
  , HaskellHostEnsure
  , FirstHardwareValidation
  ]

expectedPhase50MigrationRuleUniverse :: [Phase50MigrationRule]
expectedPhase50MigrationRuleUniverse = [NoSourceMigration]

expectedDslBarrierSourceClosureUniverse :: [DslBarrierSourceClosure]
expectedDslBarrierSourceClosureUniverse = [AllLtdSrcQueriesZeroBeforePhase49]

expectedPrehardwareRuleUniverse :: [PrehardwareRule]
expectedPrehardwareRuleUniverse = [NoHardwareThroughPhase51]

expectedPbTransportRuleUniverse :: [PbTransportRule]
expectedPbTransportRuleUniverse = [DirectHaskellThrough49ObservedPbAt50ApprovalBoundAfter50]

expectedPromotionAuthorityUniverse :: [PromotionAuthority]
expectedPromotionAuthorityUniverse = [ExternallyAnchoredHumanOnly]

expectedAutomationRoleUniverse :: [AutomationRole]
expectedAutomationRoleUniverse = [CandidateEvidenceOnly]

expectedStatusMutationAuthorityUniverse :: [StatusMutationAuthority]
expectedStatusMutationAuthorityUniverse = [HumanUserOnly]

canonicalPolicyContract :: PolicyContract
canonicalPolicyContract =
  PolicyContract
    { contractOwners = canonicalOwners
    , sourceContract = expectedSourceContract
    , pbContract = expectedPbContract
    , generationContract = expectedGenerationContract
    , registryContract = RegistryContract DistributionRegistry2 SeparatelyPinnedAndPreloaded
    , registerContract = expectedRegisterContract
    , statusResetContract = expectedStatusResetContract
    , orderingContract = expectedOrderingContract
    , promotionContract = expectedPromotionContract
    }

canonicalOwners :: Map PolicyId PolicyOwnerReference
#ifdef VALIDATION_POLICY_OWNER_MAP_MUTANT
canonicalOwners =
  Map.insert
    ClusterRegistryProvider
    registryPlacementOwner
    expectedOwners
#else
canonicalOwners = expectedOwners
#endif

expectedOwners :: Map PolicyId PolicyOwnerReference
expectedOwners =
  Map.fromList
    [ (TrackedSourceBoundary, trackedSourceOwner)
    , (PbBootstrapBoundary, pbBootstrapOwner)
    , (LazyBuildGeneration, lazyBuildGenerationOwner)
    , (ClusterRegistryProvider, registryProviderOwner)
    , (ClusterRegistryPlacement, registryPlacementOwner)
    , (ActiveLegacyRegister, activeLegacyRegisterOwner)
    , (ValidationStatusReset, validationStatusResetOwner)
    , (NumericPhaseOrder, numericPhaseOrderOwner)
    , (DslBarrierSourceClosurePolicy, dslBarrierSourceClosureOwner)
    , (PrehardwarePromotionBarrier, prehardwarePromotionBarrierOwner)
    , (PromotionAuthorityPolicy, promotionAuthorityOwner)
    ]

trackedSourceOwner :: PolicyOwnerReference
trackedSourceOwner =
  PolicyOwnerReference
#if defined(VALIDATION_POLICY_OWNER_TRACKED_SOURCE_PATH_MUTANT)
    "documents/engineering/repository_layout_doctrine.md.mutated"
#else
    "documents/engineering/repository_layout_doctrine.md"
#endif
#if defined(VALIDATION_POLICY_OWNER_TRACKED_SOURCE_ANCHOR_MUTANT)
    "1-classification-rule-mutated"
#else
    "1-classification-rule"
#endif
#if defined(VALIDATION_POLICY_OWNER_TRACKED_SOURCE_SECTION_MUTANT)
    "1. Classification rule (mutated)"
#else
    "1. Classification rule"
#endif

pbBootstrapOwner :: PolicyOwnerReference
pbBootstrapOwner =
  PolicyOwnerReference
#if defined(VALIDATION_POLICY_OWNER_PB_BOOTSTRAP_PATH_MUTANT)
    "documents/engineering/substrate_doctrine.md.mutated"
#else
    "documents/engineering/substrate_doctrine.md"
#endif
#if defined(VALIDATION_POLICY_OWNER_PB_BOOTSTRAP_ANCHOR_MUTANT)
    "6-the-pre-binary-handoff-contract-mutated"
#else
    "6-the-pre-binary-handoff-contract"
#endif
#if defined(VALIDATION_POLICY_OWNER_PB_BOOTSTRAP_SECTION_MUTANT)
    "6. The pre-binary handoff contract (mutated)"
#else
    "6. The pre-binary handoff contract"
#endif

lazyBuildGenerationOwner :: PolicyOwnerReference
lazyBuildGenerationOwner =
  PolicyOwnerReference
#if defined(VALIDATION_POLICY_OWNER_LAZY_BUILD_GENERATION_PATH_MUTANT)
    "documents/engineering/generated_artifacts_doctrine.md.mutated"
#else
    "documents/engineering/generated_artifacts_doctrine.md"
#endif
#if defined(VALIDATION_POLICY_OWNER_LAZY_BUILD_GENERATION_ANCHOR_MUTANT)
    "3-the-rule-mutated"
#else
    "3-the-rule"
#endif
#if defined(VALIDATION_POLICY_OWNER_LAZY_BUILD_GENERATION_SECTION_MUTANT)
    "3. The rule (mutated)"
#else
    "3. The rule"
#endif

registryProviderOwner :: PolicyOwnerReference
registryProviderOwner =
  PolicyOwnerReference
#if defined(VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PROVIDER_PATH_MUTANT)
    "documents/engineering/service_capability_doctrine.md.mutated"
#else
    "documents/engineering/service_capability_doctrine.md"
#endif
#if defined(VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PROVIDER_ANCHOR_MUTANT)
    "3-canonical-providers-extension-is-capability-specific-mutated"
#else
    "3-canonical-providers-extension-is-capability-specific"
#endif
#if defined(VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PROVIDER_SECTION_MUTANT)
    "3. Canonical providers; extension is capability-specific (mutated)"
#else
    "3. Canonical providers; extension is capability-specific"
#endif

registryPlacementOwner :: PolicyOwnerReference
registryPlacementOwner =
  PolicyOwnerReference
#if defined(VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PLACEMENT_PATH_MUTANT)
    "documents/engineering/image_build_doctrine.md.mutated"
#else
    "documents/engineering/image_build_doctrine.md"
#endif
#if defined(VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PLACEMENT_ANCHOR_MUTANT)
    "2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster-mutated"
#else
    "2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster"
#endif
#if defined(VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PLACEMENT_SECTION_MUTANT)
    "2. The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster (mutated)"
#else
    "2. The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster"
#endif

activeLegacyRegisterOwner :: PolicyOwnerReference
activeLegacyRegisterOwner =
  PolicyOwnerReference
#if defined(VALIDATION_POLICY_OWNER_ACTIVE_LEGACY_REGISTER_PATH_MUTANT)
    "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md.mutated"
#else
    "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
#endif
#if defined(VALIDATION_POLICY_OWNER_ACTIVE_LEGACY_REGISTER_ANCHOR_MUTANT)
    "1-register-contract-mutated"
#else
    "1-register-contract"
#endif
#if defined(VALIDATION_POLICY_OWNER_ACTIVE_LEGACY_REGISTER_SECTION_MUTANT)
    "1. Register contract (mutated)"
#else
    "1. Register contract"
#endif

validationStatusResetOwner :: PolicyOwnerReference
validationStatusResetOwner =
  PolicyOwnerReference
#if defined(VALIDATION_POLICY_OWNER_VALIDATION_STATUS_RESET_PATH_MUTANT)
    "DEVELOPMENT_PLAN/phase_00_documentation_suite.md.mutated"
#else
    "DEVELOPMENT_PLAN/phase_00_documentation_suite.md"
#endif
#if defined(VALIDATION_POLICY_OWNER_VALIDATION_STATUS_RESET_ANCHOR_MUTANT)
    "phase-status-mutated"
#else
    "phase-status"
#endif
#if defined(VALIDATION_POLICY_OWNER_VALIDATION_STATUS_RESET_SECTION_MUTANT)
    "Phase Status (mutated)"
#else
    "Phase Status"
#endif

numericPhaseOrderOwner :: PolicyOwnerReference
numericPhaseOrderOwner =
  PolicyOwnerReference
#if defined(VALIDATION_POLICY_OWNER_NUMERIC_PHASE_ORDER_PATH_MUTANT)
    "DEVELOPMENT_PLAN/development_plan_phase_model.md.mutated"
#else
    "DEVELOPMENT_PLAN/development_plan_phase_model.md"
#endif
#if defined(VALIDATION_POLICY_OWNER_NUMERIC_PHASE_ORDER_ANCHOR_MUTANT)
    "e-one-canonical-phase-model-mutated"
#else
    "e-one-canonical-phase-model"
#endif
#if defined(VALIDATION_POLICY_OWNER_NUMERIC_PHASE_ORDER_SECTION_MUTANT)
    "E. One canonical phase model (mutated)"
#else
    "E. One canonical phase model"
#endif

dslBarrierSourceClosureOwner :: PolicyOwnerReference
dslBarrierSourceClosureOwner =
  PolicyOwnerReference
#if defined(VALIDATION_POLICY_OWNER_DSL_BARRIER_SOURCE_CLOSURE_PATH_MUTANT)
    "DEVELOPMENT_PLAN/development_plan_phase_model.md.mutated"
#else
    "DEVELOPMENT_PLAN/development_plan_phase_model.md"
#endif
#if defined(VALIDATION_POLICY_OWNER_DSL_BARRIER_SOURCE_CLOSURE_ANCHOR_MUTANT)
    "e-one-canonical-phase-model-mutated"
#else
    "e-one-canonical-phase-model"
#endif
#if defined(VALIDATION_POLICY_OWNER_DSL_BARRIER_SOURCE_CLOSURE_SECTION_MUTANT)
    "E. One canonical phase model (mutated)"
#else
    "E. One canonical phase model"
#endif

prehardwarePromotionBarrierOwner :: PolicyOwnerReference
prehardwarePromotionBarrierOwner =
  PolicyOwnerReference
#if defined(VALIDATION_POLICY_OWNER_PREHARDWARE_PROMOTION_BARRIER_PATH_MUTANT)
    "DEVELOPMENT_PLAN/development_plan_phase_model.md.mutated"
#else
    "DEVELOPMENT_PLAN/development_plan_phase_model.md"
#endif
#if defined(VALIDATION_POLICY_OWNER_PREHARDWARE_PROMOTION_BARRIER_ANCHOR_MUTANT)
    "l-one-substrate-discipline-mutated"
#else
    "l-one-substrate-discipline"
#endif
#if defined(VALIDATION_POLICY_OWNER_PREHARDWARE_PROMOTION_BARRIER_SECTION_MUTANT)
    "L. One-substrate discipline (mutated)"
#else
    "L. One-substrate discipline"
#endif

promotionAuthorityOwner :: PolicyOwnerReference
promotionAuthorityOwner =
  PolicyOwnerReference
#if defined(VALIDATION_POLICY_OWNER_PROMOTION_AUTHORITY_PATH_MUTANT)
    "DEVELOPMENT_PLAN/development_plan_gate_integrity.md.mutated"
#else
    "DEVELOPMENT_PLAN/development_plan_gate_integrity.md"
#endif
#if defined(VALIDATION_POLICY_OWNER_PROMOTION_AUTHORITY_ANCHOR_MUTANT)
    "m6-candidate-evidence-and-human-promotion-mutated"
#else
    "m6-candidate-evidence-and-human-promotion"
#endif
#if defined(VALIDATION_POLICY_OWNER_PROMOTION_AUTHORITY_SECTION_MUTANT)
    "M.6 Candidate evidence and human promotion (mutated)"
#else
    "M.6 Candidate evidence and human promotion"
#endif

policyOwnerReference :: PolicyContract -> PolicyId -> Maybe PolicyOwnerReference
policyOwnerReference contract identifier = Map.lookup identifier (contractOwners contract)

canonicalActiveRegisterPath :: PolicyContract -> FilePath
canonicalActiveRegisterPath = activeRegisterPath . registerContract

canonicalForbiddenArchivePath :: PolicyContract -> FilePath
canonicalForbiddenArchivePath = forbiddenArchivePath . registerContract

registryImageReference :: RegistryProvider -> Text
registryImageReference provider
  | provider == DistributionRegistry2 = "registry:2"
  | otherwise = "mutation-only-alternate-registry"

generationRootPath :: GenerationRoot -> FilePath
generationRootPath root
  | root == IgnoredDotBuild = ".build"
  | otherwise = ".mutation-only"

promotionAuthorityMarker :: PromotionAuthority -> Text
promotionAuthorityMarker authority
  | authority == ExternallyAnchoredHumanOnly = "human"
  | otherwise = "mutation-only"

expectedSourceContract :: SourceContract
expectedSourceContract =
  SourceContract
    { sourceBehavioralLanguage = HaskellDotHs
    , sourceClassification = SemanticClosedWorld
    , sourcePublicBehaviorAuthority = HaskellBinaryOnly
    }

expectedPbContract :: PbContract
expectedPbContract =
  PbContract
    { pbRoot = "pb"
    , pbSourceLanguage = PythonSourceLanguage
    , pbOperations = Set.fromList expectedBootstrapOperationUniverse
    , pbAdmission = DenyByDefaultStaticAstImportCallControlFlowPotentialEffect
    }

expectedGenerationContract :: GenerationContract
expectedGenerationContract =
  GenerationContract
    { generationTiming = LazyAtConsumption
    , generationRoot = IgnoredDotBuild
    , trackedGeneratedArtifact = TrackedGeneratedArtifactForbidden
    }

expectedRegisterContract :: RegisterContract
expectedRegisterContract =
  RegisterContract
    { activeRegisterPath = "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
    , activeRegisterCardinality = ExactlyOneActiveRegister
    , forbiddenArchivePath = "DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md"
    , archiveRegisterRule = ArchiveRegisterForbidden
    , registerHistory = GitHistoryOnly
    , registerPredicateAuthority = HaskellPredicateOnly
    }

expectedStatusResetContract :: StatusResetContract
expectedStatusResetContract =
  StatusResetContract
    { phaseZeroResetStatus = ActiveNotValidated
    , laterPhaseResetStatus = BlockedNotValidated
    , sprintResetRule = EverySprintNotValidated
    , historicalEvidenceRule = PriorValidationPermanentlyInvalid
    }

expectedOrderingContract :: OrderingContract
expectedOrderingContract =
  OrderingContract
    { phaseDomainLower = PhaseOrdinal 0
    , phaseDomainUpper = PhaseOrdinal 95
    , predecessorRule = ImmediateNumericPredecessor
    , hardwareFreeDslBarrierPhase = PhaseOrdinal 49
    , boundedPbHandoffValidationPhase = PhaseOrdinal 50
    , haskellHostEnsurePhase = PhaseOrdinal 51
    , firstHardwareValidationPhase = PhaseOrdinal 52
    , phase50MigrationRule = NoSourceMigration
    , dslBarrierSourceClosure = AllLtdSrcQueriesZeroBeforePhase49
    , prehardwareRule = NoHardwareThroughPhase51
    , pbTransportRule = DirectHaskellThrough49ObservedPbAt50ApprovalBoundAfter50
    }

expectedPromotionContract :: PromotionContract
expectedPromotionContract =
  PromotionContract
    { promotionAuthority = ExternallyAnchoredHumanOnly
    , automationRole = CandidateEvidenceOnly
    , statusMutationAuthority = HumanUserOnly
    }

checkPolicyContract :: PolicyContract -> CheckResult
checkPolicyContract contract =
  CheckResult
    { checkName = "policy-contract"
    , checkObservations =
        [ observation "policy.source-language" (renderBehavioralLanguage (sourceBehavioralLanguage (sourceContract contract)))
        , observation "policy.pb-root" (Text.pack (pbRoot (pbContract contract)))
        , observation "policy.pb-source-language" (renderPbSourceLanguage (pbSourceLanguage (pbContract contract)))
        , observation "policy.pb-operations" (renderBootstrapOperations (pbOperations (pbContract contract)))
        , observation "policy.generation-root" (renderGenerationRoot (generationRoot (generationContract contract)))
        , observation "policy.registry-provider" (registryImageReference (registryProvider (registryContract contract)))
        , observation "policy.active-register" (Text.pack (activeRegisterPath (registerContract contract)))
        , observation "policy.phase-zero-status" (renderResetPhaseStatus (phaseZeroResetStatus (statusResetContract contract)))
        , observation "policy.phase-roles" (renderPhaseRoles (orderingContract contract))
        , observation "policy.dsl-barrier-source-closure" (renderDslBarrierSourceClosure (dslBarrierSourceClosure (orderingContract contract)))
        , observation "policy.pb-transport" (renderPbTransportRule (pbTransportRule (orderingContract contract)))
        , observation "policy.promotion-authority" (renderPromotionAuthority (promotionAuthority (promotionContract contract)))
        , observation "policy.owner-count" (showText (Map.size (contractOwners contract)))
        , observation "policy.contract-sha256" (policyContractDigest contract)
        ]
    , checkFindings =
        universeFindings
          <> sourceFindings
          <> pbFindings
          <> generationFindings
          <> registryFindings
          <> registerFindings
          <> statusResetFindings
          <> orderingFindings
          <> promotionFindings
          <> ownerFindings
    }
 where
  universeFindings =
    universeMismatch "POLICY-ID-UNIVERSE" "policy.universe.policy-id" expectedPolicyIdUniverse ([minBound .. maxBound] :: [PolicyId])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.behavioral-language" expectedBehavioralLanguageUniverse ([minBound .. maxBound] :: [BehavioralLanguage])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.source-classification" expectedSourceClassificationUniverse ([minBound .. maxBound] :: [SourceClassification])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.public-behavior-authority" expectedPublicBehaviorAuthorityUniverse ([minBound .. maxBound] :: [PublicBehaviorAuthority])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.pb-source-language" expectedPbSourceLanguageUniverse ([minBound .. maxBound] :: [PbSourceLanguage])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.bootstrap-operation" expectedBootstrapOperationUniverse ([minBound .. maxBound] :: [BootstrapOperation])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.pb-admission" expectedPbAdmissionUniverse ([minBound .. maxBound] :: [PbAdmission])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.generation-timing" expectedGenerationTimingUniverse ([minBound .. maxBound] :: [GenerationTiming])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.generation-root" expectedGenerationRootUniverse ([minBound .. maxBound] :: [GenerationRoot])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.tracked-generated-artifact" expectedTrackedGeneratedArtifactUniverse ([minBound .. maxBound] :: [TrackedGeneratedArtifact])
      <> registryUniverseFindings
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.registry-placement" expectedRegistryPlacementUniverse ([minBound .. maxBound] :: [RegistryPlacement])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.register-cardinality" expectedRegisterCardinalityUniverse ([minBound .. maxBound] :: [RegisterCardinality])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.archive-register-rule" expectedArchiveRegisterRuleUniverse ([minBound .. maxBound] :: [ArchiveRegisterRule])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.register-history" expectedRegisterHistoryUniverse ([minBound .. maxBound] :: [RegisterHistory])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.register-predicate-authority" expectedRegisterPredicateAuthorityUniverse ([minBound .. maxBound] :: [RegisterPredicateAuthority])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.reset-phase-status" expectedResetPhaseStatusUniverse ([minBound .. maxBound] :: [ResetPhaseStatus])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.sprint-reset-rule" expectedSprintResetRuleUniverse ([minBound .. maxBound] :: [SprintResetRule])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.historical-evidence-rule" expectedHistoricalEvidenceRuleUniverse ([minBound .. maxBound] :: [HistoricalEvidenceRule])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.predecessor-rule" expectedPredecessorRuleUniverse ([minBound .. maxBound] :: [PredecessorRule])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.phase-role" expectedPhaseRoleUniverse ([minBound .. maxBound] :: [PhaseRole])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.phase50-migration-rule" expectedPhase50MigrationRuleUniverse ([minBound .. maxBound] :: [Phase50MigrationRule])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.dsl-barrier-source-closure" expectedDslBarrierSourceClosureUniverse ([minBound .. maxBound] :: [DslBarrierSourceClosure])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.prehardware-rule" expectedPrehardwareRuleUniverse ([minBound .. maxBound] :: [PrehardwareRule])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.pb-transport-rule" expectedPbTransportRuleUniverse ([minBound .. maxBound] :: [PbTransportRule])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.promotion-authority" expectedPromotionAuthorityUniverse ([minBound .. maxBound] :: [PromotionAuthority])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.automation-role" expectedAutomationRoleUniverse ([minBound .. maxBound] :: [AutomationRole])
      <> universeMismatch "POLICY-CLOSED-UNIVERSE" "policy.universe.status-mutation-authority" expectedStatusMutationAuthorityUniverse ([minBound .. maxBound] :: [StatusMutationAuthority])
  registryUniverseFindings =
    universeMismatch
      "POLICY-REGISTRY-UNIVERSE"
      "policy.registry"
      expectedRegistryProviderUniverse
      ([minBound .. maxBound] :: [RegistryProvider])
  sourceFindings =
    mismatchWith policySourceContractMatches "POLICY-SOURCE" "policy.source" expectedSourceContract (sourceContract contract)
  pbFindings =
    mismatchWith policyPbContractMatches "POLICY-PB" "policy.pb" expectedPbContract (pbContract contract)
  generationFindings =
    mismatchWith policyGenerationContractMatches "POLICY-GENERATION" "policy.generation" expectedGenerationContract (generationContract contract)
  registry = registryContract contract
  registryFindings =
    mismatchWith policyRegistryContractMatches "POLICY-REGISTRY" "policy.registry" (RegistryContract DistributionRegistry2 SeparatelyPinnedAndPreloaded) registry
      <> [ finding "POLICY-REGISTRY-SELECTION" "policy.registry" "the selected Registry provider must be DistributionRegistry2"
         | not (policyRegistrySelectionAccepted (registryProvider registry))
         ]
      <> [ finding "POLICY-REGISTRY-REFERENCE" "policy.registry" "DistributionRegistry2 must render exactly registry:2"
         | not (policyRegistryReferenceAccepted (registryImageReference (registryProvider registry)))
         ]
      <> [ finding "POLICY-REGISTRY-PLACEMENT" "policy.registry" "registry:2 must be separately pinned and preloaded, never baked into amoebius-base"
         | not (policyRegistryPlacementAccepted (registryPlacement registry))
         ]
  registerFindings =
    mismatchWith policyRegisterContractMatches "POLICY-REGISTER" "policy.legacy-register" expectedRegisterContract (registerContract contract)
  statusResetFindings =
    mismatchWith policyStatusResetContractMatches "POLICY-STATUS-RESET" "policy.status-reset" expectedStatusResetContract (statusResetContract contract)
  orderingFindings =
    mismatchWith policyOrderingContractMatches "POLICY-ORDERING" "policy.phase-order" expectedOrderingContract (orderingContract contract)
  promotionFindings =
    mismatchWith policyPromotionContractMatches "POLICY-PROMOTION" "policy.promotion" expectedPromotionContract (promotionContract contract)
  owners = contractOwners contract
  policyIdUniverse = Set.fromList ([minBound .. maxBound] :: [PolicyId])
  ownerFindings =
    [ finding
        "POLICY-OWNER-INVENTORY"
        "policy.owners"
        "the decision-to-owner map must contain each closed PolicyId exactly once"
    | not (policyOwnerInventoryAccepted owners expectedOwners policyIdUniverse)
    ]
      <> [ finding
             "POLICY-OWNER-MISMATCH"
             (Text.unpack ("policy." <> policySlug identifier))
             ("policy owner must be " <> renderOwner expected)
         | (identifier, expected) <- Map.toAscList expectedOwners
         , not (policyOwnerMatches identifier expected (Map.lookup identifier owners))
         ]

policyOwnerInventoryAccepted :: Map PolicyId PolicyOwnerReference -> Map PolicyId PolicyOwnerReference -> Set PolicyId -> Bool
#if defined(VALIDATION_POLICY_OWNER_INVENTORY_PREDICATE_MUTANT)
policyOwnerInventoryAccepted _ _ _ = False
#else
policyOwnerInventoryAccepted owners expected universe =
  Map.keysSet owners == Map.keysSet expected && Map.keysSet owners == universe
#endif

policyOwnerMatches :: PolicyId -> PolicyOwnerReference -> Maybe PolicyOwnerReference -> Bool
policyOwnerMatches identifier expected observed
  | identifier == TrackedSourceBoundary =
#if defined(VALIDATION_POLICY_OWNER_TRACKED_SOURCE_MATCH_MUTANT)
      False
#else
      observed == Just expected
#endif
  | identifier == PbBootstrapBoundary =
#if defined(VALIDATION_POLICY_OWNER_PB_BOOTSTRAP_MATCH_MUTANT)
      False
#else
      observed == Just expected
#endif
  | identifier == LazyBuildGeneration =
#if defined(VALIDATION_POLICY_OWNER_LAZY_BUILD_GENERATION_MATCH_MUTANT)
      False
#else
      observed == Just expected
#endif
  | identifier == ClusterRegistryProvider =
#if defined(VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PROVIDER_MATCH_MUTANT)
      False
#else
      observed == Just expected
#endif
  | identifier == ClusterRegistryPlacement =
#if defined(VALIDATION_POLICY_OWNER_CLUSTER_REGISTRY_PLACEMENT_MATCH_MUTANT)
      False
#else
      observed == Just expected
#endif
  | identifier == ActiveLegacyRegister =
#if defined(VALIDATION_POLICY_OWNER_ACTIVE_LEGACY_REGISTER_MATCH_MUTANT)
      False
#else
      observed == Just expected
#endif
  | identifier == ValidationStatusReset =
#if defined(VALIDATION_POLICY_OWNER_VALIDATION_STATUS_RESET_MATCH_MUTANT)
      False
#else
      observed == Just expected
#endif
  | identifier == NumericPhaseOrder =
#if defined(VALIDATION_POLICY_OWNER_NUMERIC_PHASE_ORDER_MATCH_MUTANT)
      False
#else
      observed == Just expected
#endif
  | identifier == DslBarrierSourceClosurePolicy =
#if defined(VALIDATION_POLICY_OWNER_DSL_BARRIER_SOURCE_CLOSURE_MATCH_MUTANT)
      False
#else
      observed == Just expected
#endif
  | identifier == PrehardwarePromotionBarrier =
#if defined(VALIDATION_POLICY_OWNER_PREHARDWARE_PROMOTION_BARRIER_MATCH_MUTANT)
      False
#else
      observed == Just expected
#endif
  | identifier == PromotionAuthorityPolicy =
#if defined(VALIDATION_POLICY_OWNER_PROMOTION_AUTHORITY_MATCH_MUTANT)
      False
#else
      observed == Just expected
#endif
  | otherwise = False

-- | Public-facing standard-value diagnostic.  It observes only the exact
-- package-owned canonical contract and always retains explicit non-authority
-- residue.  It performs no filesystem, process, pb, network, hardware, or
-- container action and cannot construct candidate evidence.
policyContractDiagnostic :: CheckResult
policyContractDiagnostic =
  canonicalResult
    { checkName = policyDiagnosticName
    , checkObservations =
        policyDiagnosticObservationOrder
          ( filter policyDiagnosticObservationRetained
              (checkObservations canonicalResult <> [observation "policy.diagnostic-status" "refused"])
          )
    , checkFindings =
        policyDiagnosticFindingOrder
          ( checkFindings canonicalResult
              <> [ policyMandatoryFinding kind commitmentDetail
                 | kind <- [minBound .. maxBound]
                 , policyMandatoryFindingRetained kind
                 ]
          )
    }
 where
  canonicalResult = checkPolicyContract canonicalPolicyContract
  commitmentDetail = "; policy-contract-sha256=" <> policyContractDigest canonicalPolicyContract

policyDiagnosticName :: Text
#if defined(VALIDATION_POLICY_RESULT_NAME_MUTANT)
policyDiagnosticName = "policy-contract-diagnostic-mutated"
#else
policyDiagnosticName = "policy-contract-diagnostic"
#endif

policyDiagnosticObservationOrder :: [Observation] -> [Observation]
#if defined(VALIDATION_POLICY_OBSERVATION_ORDER_MUTANT)
policyDiagnosticObservationOrder values = case values of
  first : second : rest -> second : first : rest
  _ -> values
#else
policyDiagnosticObservationOrder = id
#endif

policyDiagnosticFindingOrder :: [Finding] -> [Finding]
#if defined(VALIDATION_POLICY_FINDING_ORDER_MUTANT)
policyDiagnosticFindingOrder values = case values of
  first : second : rest -> second : first : rest
  _ -> values
#else
policyDiagnosticFindingOrder = id
#endif

policyDiagnosticObservationRetained :: Observation -> Bool
policyDiagnosticObservationRetained item = case observationKey item of
  "policy.source-language" ->
#if defined(VALIDATION_POLICY_OBSERVATION_SOURCE_LANGUAGE_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.pb-root" ->
#if defined(VALIDATION_POLICY_OBSERVATION_PB_ROOT_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.pb-source-language" ->
#if defined(VALIDATION_POLICY_OBSERVATION_PB_SOURCE_LANGUAGE_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.pb-operations" ->
#if defined(VALIDATION_POLICY_OBSERVATION_PB_OPERATIONS_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.generation-root" ->
#if defined(VALIDATION_POLICY_OBSERVATION_GENERATION_ROOT_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.registry-provider" ->
#if defined(VALIDATION_POLICY_OBSERVATION_REGISTRY_PROVIDER_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.active-register" ->
#if defined(VALIDATION_POLICY_OBSERVATION_ACTIVE_REGISTER_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.phase-zero-status" ->
#if defined(VALIDATION_POLICY_OBSERVATION_PHASE_ZERO_STATUS_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.phase-roles" ->
#if defined(VALIDATION_POLICY_OBSERVATION_PHASE_ROLES_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.dsl-barrier-source-closure" ->
#if defined(VALIDATION_POLICY_OBSERVATION_DSL_BARRIER_SOURCE_CLOSURE_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.pb-transport" ->
#if defined(VALIDATION_POLICY_OBSERVATION_PB_TRANSPORT_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.promotion-authority" ->
#if defined(VALIDATION_POLICY_OBSERVATION_PROMOTION_AUTHORITY_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.owner-count" ->
#if defined(VALIDATION_POLICY_OBSERVATION_OWNER_COUNT_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.contract-sha256" ->
#if defined(VALIDATION_POLICY_OBSERVATION_CONTRACT_SHA256_DROP_MUTANT)
    False
#else
    True
#endif
  "policy.diagnostic-status" ->
#if defined(VALIDATION_POLICY_OBSERVATION_DIAGNOSTIC_STATUS_DROP_MUTANT)
    False
#else
    True
#endif
  _ -> True

data PolicyMandatoryFinding
  = PolicyMandatoryDiagnosticOnly
  | PolicyMandatorySourceCustody
  | PolicyMandatoryQualification
  | PolicyMandatoryHumanReview
  deriving (Bounded, Enum, Eq, Ord, Show)

policyMandatoryFindingRetained :: PolicyMandatoryFinding -> Bool
policyMandatoryFindingRetained kind = case kind of
  PolicyMandatoryDiagnosticOnly ->
#if defined(VALIDATION_POLICY_RESIDUE_DIAGNOSTIC_ONLY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicyMandatorySourceCustody ->
#if defined(VALIDATION_POLICY_RESIDUE_SOURCE_CUSTODY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicyMandatoryQualification ->
#if defined(VALIDATION_POLICY_RESIDUE_QUALIFICATION_DROP_MUTANT)
    False
#else
    True
#endif
  PolicyMandatoryHumanReview ->
#if defined(VALIDATION_POLICY_RESIDUE_HUMAN_REVIEW_DROP_MUTANT)
    False
#else
    True
#endif

policyMandatoryFinding :: PolicyMandatoryFinding -> Text -> Finding
policyMandatoryFinding kind commitmentDetail =
  finding
    (policyMandatoryFindingCode kind)
    (policyMandatoryFindingSubject kind)
    (policyMandatoryFindingDetail kind <> commitmentDetail)

policyMandatoryFindingCode :: PolicyMandatoryFinding -> Text
policyMandatoryFindingCode kind = case kind of
  PolicyMandatoryDiagnosticOnly ->
#if defined(VALIDATION_POLICY_RESIDUE_DIAGNOSTIC_ONLY_CODE_MUTANT)
    "POLICY-MUTATED"
#else
    "POLICY-DIAGNOSTIC-ONLY"
#endif
  PolicyMandatorySourceCustody ->
#if defined(VALIDATION_POLICY_RESIDUE_SOURCE_CUSTODY_CODE_MUTANT)
    "POLICY-MUTATED"
#else
    "POLICY-SOURCE-CUSTODY-UNAVAILABLE"
#endif
  PolicyMandatoryQualification ->
#if defined(VALIDATION_POLICY_RESIDUE_QUALIFICATION_CODE_MUTANT)
    "POLICY-MUTATED"
#else
    "POLICY-QUALIFICATION-UNAVAILABLE"
#endif
  PolicyMandatoryHumanReview ->
#if defined(VALIDATION_POLICY_RESIDUE_HUMAN_REVIEW_CODE_MUTANT)
    "POLICY-MUTATED"
#else
    "POLICY-HUMAN-REVIEW-UNAVAILABLE"
#endif

policyMandatoryFindingSubject :: PolicyMandatoryFinding -> FilePath
policyMandatoryFindingSubject kind = case kind of
  PolicyMandatoryDiagnosticOnly ->
#if defined(VALIDATION_POLICY_RESIDUE_DIAGNOSTIC_ONLY_SUBJECT_MUTANT)
    "<mutated>"
#else
    "Amoebius.Validation.PolicyContract.policyContractDiagnostic"
#endif
  PolicyMandatorySourceCustody ->
#if defined(VALIDATION_POLICY_RESIDUE_SOURCE_CUSTODY_SUBJECT_MUTANT)
    "<mutated>"
#else
    "Amoebius.Validation.PolicyContract.Internal"
#endif
  PolicyMandatoryQualification ->
#if defined(VALIDATION_POLICY_RESIDUE_QUALIFICATION_SUBJECT_MUTANT)
    "<mutated>"
#else
    "policy-contract-changed-subject-matrix"
#endif
  PolicyMandatoryHumanReview ->
#if defined(VALIDATION_POLICY_RESIDUE_HUMAN_REVIEW_SUBJECT_MUTANT)
    "<mutated>"
#else
    "DEVELOPMENT_PLAN/phase_00_documentation_suite.md"
#endif

policyMandatoryFindingDetail :: PolicyMandatoryFinding -> Text
policyMandatoryFindingDetail kind = case kind of
  PolicyMandatoryDiagnosticOnly ->
#if defined(VALIDATION_POLICY_RESIDUE_DIAGNOSTIC_ONLY_DETAIL_MUTANT)
    "the public standard-value facade cannot mint candidate evidence (mutated)"
#else
    "the public standard-value facade cannot mint candidate evidence"
#endif
  PolicyMandatorySourceCustody ->
#if defined(VALIDATION_POLICY_RESIDUE_SOURCE_CUSTODY_DETAIL_MUTANT)
    "the canonical policy value is not authenticated source acquisition evidence (mutated)"
#else
    "the canonical policy value is not authenticated source acquisition evidence"
#endif
  PolicyMandatoryQualification ->
#if defined(VALIDATION_POLICY_RESIDUE_QUALIFICATION_DETAIL_MUTANT)
    "component diagnostics cannot qualify a complete atomic changed-production corpus for this exact subject (mutated)"
#else
    "component diagnostics cannot qualify a complete atomic changed-production corpus for this exact subject"
#endif
  PolicyMandatoryHumanReview ->
#if defined(VALIDATION_POLICY_RESIDUE_HUMAN_REVIEW_DETAIL_MUTANT)
    "policy-to-prose correspondence requires independent human review (mutated)"
#else
    "policy-to-prose correspondence requires independent human review"
#endif

mismatchWith :: Show value => (value -> value -> Bool) -> Text -> FilePath -> value -> value -> [Finding]
mismatchWith predicate code subject expected observed =
  [ finding code subject ("expected " <> showText expected <> ", observed " <> showText observed)
  | not (predicate expected observed)
  ]

policySourceContractMatches :: SourceContract -> SourceContract -> Bool
#if defined(VALIDATION_POLICY_CONTRACT_SOURCE_FIELD_MUTANT)
policySourceContractMatches _ _ = False
#else
policySourceContractMatches = (==)
#endif

policyPbContractMatches :: PbContract -> PbContract -> Bool
#if defined(VALIDATION_POLICY_CONTRACT_PB_FIELD_MUTANT)
policyPbContractMatches _ _ = False
#else
policyPbContractMatches = (==)
#endif

policyGenerationContractMatches :: GenerationContract -> GenerationContract -> Bool
#if defined(VALIDATION_POLICY_CONTRACT_GENERATION_FIELD_MUTANT)
policyGenerationContractMatches _ _ = False
#else
policyGenerationContractMatches = (==)
#endif

policyRegistryContractMatches :: RegistryContract -> RegistryContract -> Bool
#if defined(VALIDATION_POLICY_CONTRACT_REGISTRY_FIELD_MUTANT)
policyRegistryContractMatches _ _ = False
#else
policyRegistryContractMatches = (==)
#endif

policyRegisterContractMatches :: RegisterContract -> RegisterContract -> Bool
#if defined(VALIDATION_POLICY_CONTRACT_REGISTER_FIELD_MUTANT)
policyRegisterContractMatches _ _ = False
#else
policyRegisterContractMatches = (==)
#endif

policyStatusResetContractMatches :: StatusResetContract -> StatusResetContract -> Bool
#if defined(VALIDATION_POLICY_CONTRACT_STATUS_RESET_FIELD_MUTANT)
policyStatusResetContractMatches _ _ = False
#else
policyStatusResetContractMatches = (==)
#endif

policyOrderingContractMatches :: OrderingContract -> OrderingContract -> Bool
#if defined(VALIDATION_POLICY_CONTRACT_ORDERING_FIELD_MUTANT)
policyOrderingContractMatches _ _ = False
#else
policyOrderingContractMatches = (==)
#endif

policyPromotionContractMatches :: PromotionContract -> PromotionContract -> Bool
#if defined(VALIDATION_POLICY_CONTRACT_PROMOTION_FIELD_MUTANT)
policyPromotionContractMatches _ _ = False
#else
policyPromotionContractMatches = (==)
#endif

policyRegistrySelectionAccepted :: RegistryProvider -> Bool
#if defined(VALIDATION_POLICY_REGISTRY_SELECTION_PREDICATE_MUTANT)
policyRegistrySelectionAccepted _ = False
#else
policyRegistrySelectionAccepted = (== DistributionRegistry2)
#endif

policyRegistryReferenceAccepted :: Text -> Bool
#if defined(VALIDATION_POLICY_REGISTRY_REFERENCE_PREDICATE_MUTANT)
policyRegistryReferenceAccepted _ = False
#else
policyRegistryReferenceAccepted = (== "registry:2")
#endif

policyRegistryPlacementAccepted :: RegistryPlacement -> Bool
#if defined(VALIDATION_POLICY_REGISTRY_PLACEMENT_PREDICATE_MUTANT)
policyRegistryPlacementAccepted _ = False
#else
policyRegistryPlacementAccepted = (== SeparatelyPinnedAndPreloaded)
#endif

universeMismatch :: (Eq value, Show value) => Text -> FilePath -> [value] -> [value] -> [Finding]
universeMismatch code subject expected observed =
  [ finding code subject ("expected closed constructor universe " <> showText expected <> ", observed " <> showText observed)
  | observed /= expected
  ]

renderPolicyContract :: PolicyContract -> ByteString
renderPolicyContract contract =
  TextEncoding.encodeUtf8
    ( policySerializationFrame
        ( selectPolicySerializationLines
            ( [ "amoebius-policy-contract-v4"
          , "universe.policy-id=" <> renderUniverse policySlug ([minBound .. maxBound] :: [PolicyId])
          , "universe.behavioral-language=" <> renderUniverse renderBehavioralLanguage ([minBound .. maxBound] :: [BehavioralLanguage])
          , "universe.source-classification=" <> renderUniverse renderSourceClassification ([minBound .. maxBound] :: [SourceClassification])
          , "universe.public-behavior-authority=" <> renderUniverse renderPublicBehaviorAuthority ([minBound .. maxBound] :: [PublicBehaviorAuthority])
          , "universe.pb-source-language=" <> renderUniverse renderPbSourceLanguage ([minBound .. maxBound] :: [PbSourceLanguage])
          , "universe.bootstrap-operation=" <> renderUniverse renderBootstrapOperation ([minBound .. maxBound] :: [BootstrapOperation])
          , "universe.pb-admission=" <> renderUniverse renderPbAdmission ([minBound .. maxBound] :: [PbAdmission])
          , "universe.generation-timing=" <> renderUniverse renderGenerationTiming ([minBound .. maxBound] :: [GenerationTiming])
          , "universe.generation-root=" <> renderUniverse renderGenerationRoot ([minBound .. maxBound] :: [GenerationRoot])
          , "universe.tracked-generated-artifact=" <> renderUniverse renderTrackedGeneratedArtifact ([minBound .. maxBound] :: [TrackedGeneratedArtifact])
          , "universe.registry-provider=" <> renderUniverse registryImageReference ([minBound .. maxBound] :: [RegistryProvider])
          , "universe.registry-placement=" <> renderUniverse renderRegistryPlacement ([minBound .. maxBound] :: [RegistryPlacement])
          , "universe.register-cardinality=" <> renderUniverse renderRegisterCardinality ([minBound .. maxBound] :: [RegisterCardinality])
          , "universe.archive-register-rule=" <> renderUniverse renderArchiveRegisterRule ([minBound .. maxBound] :: [ArchiveRegisterRule])
          , "universe.register-history=" <> renderUniverse renderRegisterHistory ([minBound .. maxBound] :: [RegisterHistory])
          , "universe.register-predicate-authority=" <> renderUniverse renderRegisterPredicateAuthority ([minBound .. maxBound] :: [RegisterPredicateAuthority])
          , "universe.reset-phase-status=" <> renderUniverse renderResetPhaseStatus ([minBound .. maxBound] :: [ResetPhaseStatus])
          , "universe.sprint-reset-rule=" <> renderUniverse renderSprintResetRule ([minBound .. maxBound] :: [SprintResetRule])
          , "universe.historical-evidence-rule=" <> renderUniverse renderHistoricalEvidenceRule ([minBound .. maxBound] :: [HistoricalEvidenceRule])
          , "universe.predecessor-rule=" <> renderUniverse renderPredecessorRule ([minBound .. maxBound] :: [PredecessorRule])
          , "universe.phase-role=" <> renderUniverse renderPhaseRole ([minBound .. maxBound] :: [PhaseRole])
          , "universe.phase50-migration-rule=" <> renderUniverse renderPhase50MigrationRule ([minBound .. maxBound] :: [Phase50MigrationRule])
          , "universe.dsl-barrier-source-closure=" <> renderUniverse renderDslBarrierSourceClosure ([minBound .. maxBound] :: [DslBarrierSourceClosure])
          , "universe.prehardware-rule=" <> renderUniverse renderPrehardwareRule ([minBound .. maxBound] :: [PrehardwareRule])
          , "universe.pb-transport-rule=" <> renderUniverse renderPbTransportRule ([minBound .. maxBound] :: [PbTransportRule])
          , "universe.promotion-authority=" <> renderUniverse renderPromotionAuthority ([minBound .. maxBound] :: [PromotionAuthority])
          , "universe.automation-role=" <> renderUniverse renderAutomationRole ([minBound .. maxBound] :: [AutomationRole])
          , "universe.status-mutation-authority=" <> renderUniverse renderStatusMutationAuthority ([minBound .. maxBound] :: [StatusMutationAuthority])
          , "source.behavioral-language=" <> renderBehavioralLanguage (sourceBehavioralLanguage source)
          , "source.classification=" <> renderSourceClassification (sourceClassification source)
          , "source.public-behavior-authority=" <> renderPublicBehaviorAuthority (sourcePublicBehaviorAuthority source)
          , "pb.root=" <> Text.pack (pbRoot pb)
          , "pb.source-language=" <> renderPbSourceLanguage (pbSourceLanguage pb)
          , "pb.operations=" <> renderBootstrapOperations (pbOperations pb)
          , "pb.admission=" <> renderPbAdmission (pbAdmission pb)
          , "generation.timing=" <> renderGenerationTiming (generationTiming generation)
          , "generation.root=" <> renderGenerationRoot (generationRoot generation)
          , "generation.tracked-artifact=" <> renderTrackedGeneratedArtifact (trackedGeneratedArtifact generation)
          , "registry.provider=" <> registryImageReference (registryProvider registry)
          , "registry.placement=" <> renderRegistryPlacement (registryPlacement registry)
          , "legacy.active-register=" <> Text.pack (activeRegisterPath register)
          , "legacy.active-register-cardinality=" <> renderRegisterCardinality (activeRegisterCardinality register)
          , "legacy.forbidden-archive=" <> Text.pack (forbiddenArchivePath register)
          , "legacy.archive-rule=" <> renderArchiveRegisterRule (archiveRegisterRule register)
          , "legacy.history=" <> renderRegisterHistory (registerHistory register)
          , "legacy.predicate-authority=" <> renderRegisterPredicateAuthority (registerPredicateAuthority register)
          , "status.phase-00=" <> renderResetPhaseStatus (phaseZeroResetStatus statusReset)
          , "status.phases-01-95=" <> renderResetPhaseStatus (laterPhaseResetStatus statusReset)
          , "status.sprints=" <> renderSprintResetRule (sprintResetRule statusReset)
          , "status.historical-evidence=" <> renderHistoricalEvidenceRule (historicalEvidenceRule statusReset)
          , "ordering.domain=" <> renderPhaseOrdinal (phaseDomainLower ordering) <> ".." <> renderPhaseOrdinal (phaseDomainUpper ordering)
          , "ordering.predecessor=" <> renderPredecessorRule (predecessorRule ordering)
          , "ordering.roles=" <> renderPhaseRoles ordering
          , "ordering.phase50-migration=" <> renderPhase50MigrationRule (phase50MigrationRule ordering)
          , "ordering.dsl-barrier-source-closure=" <> renderDslBarrierSourceClosure (dslBarrierSourceClosure ordering)
          , "ordering.prehardware=" <> renderPrehardwareRule (prehardwareRule ordering)
          , "ordering.pb-transport=" <> renderPbTransportRule (pbTransportRule ordering)
          , "promotion.authority=" <> renderPromotionAuthority (promotionAuthority promotion)
          , "promotion.automation-role=" <> renderAutomationRole (automationRole promotion)
          , "promotion.status-mutation=" <> renderStatusMutationAuthority (statusMutationAuthority promotion)
          ]
            <> [ "owner." <> policySlug identifier <> "=" <> renderOwner reference
               | (identifier, reference) <- Map.toAscList (contractOwners contract)
               ]
            )
        )
    )
 where
  source = sourceContract contract
  pb = pbContract contract
  generation = generationContract contract
  registry = registryContract contract
  register = registerContract contract
  statusReset = statusResetContract contract
  ordering = orderingContract contract
  promotion = promotionContract contract

data PolicySerializationKey
  = PolicySerializationHeader
  | PolicySerializationUniversePolicyId
  | PolicySerializationUniverseBehavioralLanguage
  | PolicySerializationUniverseSourceClassification
  | PolicySerializationUniversePublicBehaviorAuthority
  | PolicySerializationUniversePbSourceLanguage
  | PolicySerializationUniverseBootstrapOperation
  | PolicySerializationUniversePbAdmission
  | PolicySerializationUniverseGenerationTiming
  | PolicySerializationUniverseGenerationRoot
  | PolicySerializationUniverseTrackedGeneratedArtifact
  | PolicySerializationUniverseRegistryProvider
  | PolicySerializationUniverseRegistryPlacement
  | PolicySerializationUniverseRegisterCardinality
  | PolicySerializationUniverseArchiveRegisterRule
  | PolicySerializationUniverseRegisterHistory
  | PolicySerializationUniverseRegisterPredicateAuthority
  | PolicySerializationUniverseResetPhaseStatus
  | PolicySerializationUniverseSprintResetRule
  | PolicySerializationUniverseHistoricalEvidenceRule
  | PolicySerializationUniversePredecessorRule
  | PolicySerializationUniversePhaseRole
  | PolicySerializationUniversePhase50MigrationRule
  | PolicySerializationUniverseDslBarrierSourceClosure
  | PolicySerializationUniversePrehardwareRule
  | PolicySerializationUniversePbTransportRule
  | PolicySerializationUniversePromotionAuthority
  | PolicySerializationUniverseAutomationRole
  | PolicySerializationUniverseStatusMutationAuthority
  | PolicySerializationSourceBehavioralLanguage
  | PolicySerializationSourceClassification
  | PolicySerializationSourcePublicBehaviorAuthority
  | PolicySerializationPbRoot
  | PolicySerializationPbSourceLanguage
  | PolicySerializationPbOperations
  | PolicySerializationPbAdmission
  | PolicySerializationGenerationTiming
  | PolicySerializationGenerationRoot
  | PolicySerializationGenerationTrackedArtifact
  | PolicySerializationRegistryProvider
  | PolicySerializationRegistryPlacement
  | PolicySerializationLegacyActiveRegister
  | PolicySerializationLegacyActiveRegisterCardinality
  | PolicySerializationLegacyForbiddenArchive
  | PolicySerializationLegacyArchiveRule
  | PolicySerializationLegacyHistory
  | PolicySerializationLegacyPredicateAuthority
  | PolicySerializationStatusPhase00
  | PolicySerializationStatusPhases0195
  | PolicySerializationStatusSprints
  | PolicySerializationStatusHistoricalEvidence
  | PolicySerializationOrderingDomain
  | PolicySerializationOrderingPredecessor
  | PolicySerializationOrderingRoles
  | PolicySerializationOrderingPhase50Migration
  | PolicySerializationOrderingDslBarrierSourceClosure
  | PolicySerializationOrderingPrehardware
  | PolicySerializationOrderingPbTransport
  | PolicySerializationPromotionAuthority
  | PolicySerializationPromotionAutomationRole
  | PolicySerializationPromotionStatusMutation
  | PolicySerializationOwnerTrackedSource
  | PolicySerializationOwnerPbBootstrap
  | PolicySerializationOwnerLazyBuildGeneration
  | PolicySerializationOwnerClusterRegistryProvider
  | PolicySerializationOwnerClusterRegistryPlacement
  | PolicySerializationOwnerActiveLegacyRegister
  | PolicySerializationOwnerValidationStatusReset
  | PolicySerializationOwnerNumericPhaseOrder
  | PolicySerializationOwnerDslBarrierSourceClosure
  | PolicySerializationOwnerPrehardwarePromotionBarrier
  | PolicySerializationOwnerPromotionAuthority
  deriving (Bounded, Enum, Eq, Ord, Show)

policySerializationKeys :: [PolicySerializationKey]
policySerializationKeys = [minBound .. maxBound]

selectPolicySerializationLines :: [Text] -> [Text]
selectPolicySerializationLines values =
  policySerializationOrder
    [ value
    | (key, value) <- zip policySerializationKeys values
    , policySerializationLineRetained key
    ]

policySerializationLineRetained :: PolicySerializationKey -> Bool
policySerializationLineRetained key = case key of
  PolicySerializationHeader ->
#if defined(VALIDATION_POLICY_SERIALIZER_HEADER_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniversePolicyId ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_POLICY_ID_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseBehavioralLanguage ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_BEHAVIORAL_LANGUAGE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseSourceClassification ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_SOURCE_CLASSIFICATION_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniversePublicBehaviorAuthority ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_PUBLIC_BEHAVIOR_AUTHORITY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniversePbSourceLanguage ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_PB_SOURCE_LANGUAGE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseBootstrapOperation ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_BOOTSTRAP_OPERATION_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniversePbAdmission ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_PB_ADMISSION_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseGenerationTiming ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_GENERATION_TIMING_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseGenerationRoot ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_GENERATION_ROOT_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseTrackedGeneratedArtifact ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_TRACKED_GENERATED_ARTIFACT_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseRegistryProvider ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_REGISTRY_PROVIDER_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseRegistryPlacement ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_REGISTRY_PLACEMENT_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseRegisterCardinality ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_REGISTER_CARDINALITY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseArchiveRegisterRule ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_ARCHIVE_REGISTER_RULE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseRegisterHistory ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_REGISTER_HISTORY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseRegisterPredicateAuthority ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_REGISTER_PREDICATE_AUTHORITY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseResetPhaseStatus ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_RESET_PHASE_STATUS_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseSprintResetRule ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_SPRINT_RESET_RULE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseHistoricalEvidenceRule ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_HISTORICAL_EVIDENCE_RULE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniversePredecessorRule ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_PREDECESSOR_RULE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniversePhaseRole ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_PHASE_ROLE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniversePhase50MigrationRule ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_PHASE50_MIGRATION_RULE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseDslBarrierSourceClosure ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_DSL_BARRIER_SOURCE_CLOSURE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniversePrehardwareRule ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_PREHARDWARE_RULE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniversePbTransportRule ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_PB_TRANSPORT_RULE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniversePromotionAuthority ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_PROMOTION_AUTHORITY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseAutomationRole ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_AUTOMATION_ROLE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationUniverseStatusMutationAuthority ->
#if defined(VALIDATION_POLICY_SERIALIZER_UNIVERSE_STATUS_MUTATION_AUTHORITY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationSourceBehavioralLanguage ->
#if defined(VALIDATION_POLICY_SERIALIZER_SOURCE_BEHAVIORAL_LANGUAGE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationSourceClassification ->
#if defined(VALIDATION_POLICY_SERIALIZER_SOURCE_CLASSIFICATION_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationSourcePublicBehaviorAuthority ->
#if defined(VALIDATION_POLICY_SERIALIZER_SOURCE_PUBLIC_BEHAVIOR_AUTHORITY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationPbRoot ->
#if defined(VALIDATION_POLICY_SERIALIZER_PB_ROOT_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationPbSourceLanguage ->
#if defined(VALIDATION_POLICY_SERIALIZER_PB_SOURCE_LANGUAGE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationPbOperations ->
#if defined(VALIDATION_POLICY_SERIALIZER_PB_OPERATIONS_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationPbAdmission ->
#if defined(VALIDATION_POLICY_SERIALIZER_PB_ADMISSION_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationGenerationTiming ->
#if defined(VALIDATION_POLICY_SERIALIZER_GENERATION_TIMING_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationGenerationRoot ->
#if defined(VALIDATION_POLICY_SERIALIZER_GENERATION_ROOT_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationGenerationTrackedArtifact ->
#if defined(VALIDATION_POLICY_SERIALIZER_GENERATION_TRACKED_ARTIFACT_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationRegistryProvider ->
#if defined(VALIDATION_POLICY_SERIALIZER_REGISTRY_PROVIDER_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationRegistryPlacement ->
#if defined(VALIDATION_POLICY_SERIALIZER_REGISTRY_PLACEMENT_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationLegacyActiveRegister ->
#if defined(VALIDATION_POLICY_SERIALIZER_LEGACY_ACTIVE_REGISTER_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationLegacyActiveRegisterCardinality ->
#if defined(VALIDATION_POLICY_SERIALIZER_LEGACY_ACTIVE_REGISTER_CARDINALITY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationLegacyForbiddenArchive ->
#if defined(VALIDATION_POLICY_SERIALIZER_LEGACY_FORBIDDEN_ARCHIVE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationLegacyArchiveRule ->
#if defined(VALIDATION_POLICY_SERIALIZER_LEGACY_ARCHIVE_RULE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationLegacyHistory ->
#if defined(VALIDATION_POLICY_SERIALIZER_LEGACY_HISTORY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationLegacyPredicateAuthority ->
#if defined(VALIDATION_POLICY_SERIALIZER_LEGACY_PREDICATE_AUTHORITY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationStatusPhase00 ->
#if defined(VALIDATION_POLICY_SERIALIZER_STATUS_PHASE_00_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationStatusPhases0195 ->
#if defined(VALIDATION_POLICY_SERIALIZER_STATUS_PHASES_01_95_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationStatusSprints ->
#if defined(VALIDATION_POLICY_SERIALIZER_STATUS_SPRINTS_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationStatusHistoricalEvidence ->
#if defined(VALIDATION_POLICY_SERIALIZER_STATUS_HISTORICAL_EVIDENCE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOrderingDomain ->
#if defined(VALIDATION_POLICY_SERIALIZER_ORDERING_DOMAIN_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOrderingPredecessor ->
#if defined(VALIDATION_POLICY_SERIALIZER_ORDERING_PREDECESSOR_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOrderingRoles ->
#if defined(VALIDATION_POLICY_SERIALIZER_ORDERING_ROLES_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOrderingPhase50Migration ->
#if defined(VALIDATION_POLICY_SERIALIZER_ORDERING_PHASE50_MIGRATION_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOrderingDslBarrierSourceClosure ->
#if defined(VALIDATION_POLICY_SERIALIZER_ORDERING_DSL_BARRIER_SOURCE_CLOSURE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOrderingPrehardware ->
#if defined(VALIDATION_POLICY_SERIALIZER_ORDERING_PREHARDWARE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOrderingPbTransport ->
#if defined(VALIDATION_POLICY_SERIALIZER_ORDERING_PB_TRANSPORT_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationPromotionAuthority ->
#if defined(VALIDATION_POLICY_SERIALIZER_PROMOTION_AUTHORITY_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationPromotionAutomationRole ->
#if defined(VALIDATION_POLICY_SERIALIZER_PROMOTION_AUTOMATION_ROLE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationPromotionStatusMutation ->
#if defined(VALIDATION_POLICY_SERIALIZER_PROMOTION_STATUS_MUTATION_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOwnerTrackedSource ->
#if defined(VALIDATION_POLICY_SERIALIZER_OWNER_TRACKED_SOURCE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOwnerPbBootstrap ->
#if defined(VALIDATION_POLICY_SERIALIZER_OWNER_PB_BOOTSTRAP_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOwnerLazyBuildGeneration ->
#if defined(VALIDATION_POLICY_SERIALIZER_OWNER_LAZY_BUILD_GENERATION_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOwnerClusterRegistryProvider ->
#if defined(VALIDATION_POLICY_SERIALIZER_OWNER_CLUSTER_REGISTRY_PROVIDER_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOwnerClusterRegistryPlacement ->
#if defined(VALIDATION_POLICY_SERIALIZER_OWNER_CLUSTER_REGISTRY_PLACEMENT_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOwnerActiveLegacyRegister ->
#if defined(VALIDATION_POLICY_SERIALIZER_OWNER_ACTIVE_LEGACY_REGISTER_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOwnerValidationStatusReset ->
#if defined(VALIDATION_POLICY_SERIALIZER_OWNER_VALIDATION_STATUS_RESET_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOwnerNumericPhaseOrder ->
#if defined(VALIDATION_POLICY_SERIALIZER_OWNER_NUMERIC_PHASE_ORDER_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOwnerDslBarrierSourceClosure ->
#if defined(VALIDATION_POLICY_SERIALIZER_OWNER_DSL_BARRIER_SOURCE_CLOSURE_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOwnerPrehardwarePromotionBarrier ->
#if defined(VALIDATION_POLICY_SERIALIZER_OWNER_PREHARDWARE_PROMOTION_BARRIER_DROP_MUTANT)
    False
#else
    True
#endif
  PolicySerializationOwnerPromotionAuthority ->
#if defined(VALIDATION_POLICY_SERIALIZER_OWNER_PROMOTION_AUTHORITY_DROP_MUTANT)
    False
#else
    True
#endif

policySerializationOrder :: [Text] -> [Text]
#if defined(VALIDATION_POLICY_SERIALIZER_ORDER_MUTANT)
policySerializationOrder values = case values of
  first : second : rest -> second : first : rest
  _ -> values
#else
policySerializationOrder = id
#endif

policySerializationFrame :: [Text] -> Text
#if defined(VALIDATION_POLICY_SERIALIZER_TRAILING_NEWLINE_MUTANT)
policySerializationFrame = Text.intercalate "\n"
#else
policySerializationFrame = Text.unlines
#endif

policyContractDigest :: PolicyContract -> Text
policyContractDigest = hex . SHA256.hash . policyDigestPayload

policyDigestPayload :: PolicyContract -> ByteString
#if defined(VALIDATION_POLICY_DIGEST_BINDING_MUTANT)
policyDigestPayload _ = ByteString.empty
#else
policyDigestPayload = renderPolicyContract
#endif

renderUniverse :: (value -> Text) -> [value] -> Text
renderUniverse render = Text.intercalate "," . map render

renderBehavioralLanguage :: BehavioralLanguage -> Text
renderBehavioralLanguage value
  | value == HaskellDotHs = "haskell-.hs-only"
  | otherwise = "mutation-only-behavioral-language"

renderSourceClassification :: SourceClassification -> Text
renderSourceClassification value
  | value == SemanticClosedWorld = "semantic-closed-world"
  | otherwise = "mutation-only-source-classification"

renderPublicBehaviorAuthority :: PublicBehaviorAuthority -> Text
renderPublicBehaviorAuthority value
  | value == HaskellBinaryOnly = "haskell-binary-only"
  | otherwise = "mutation-only-public-behavior-authority"

renderPbSourceLanguage :: PbSourceLanguage -> Text
renderPbSourceLanguage value
  | value == PythonSourceLanguage = "python"
  | otherwise = "mutation-only-pb-source-language"

renderBootstrapOperations :: Set BootstrapOperation -> Text
renderBootstrapOperations = Text.intercalate "," . map renderBootstrapOperation . Set.toAscList

renderBootstrapOperation :: BootstrapOperation -> Text
renderBootstrapOperation value
  | value == MinimalPlatformDistinction = "minimal-platform-distinction"
  | value == ContainedToolchainEstablishment = "contained-toolchain-establishment"
  | value == SourceBoundHaskellBuild = "source-bound-haskell-build"
  | value == OpaqueArgumentPreservingExec = "opaque-argument-preserving-exec"
  | otherwise = "mutation-only-bootstrap-operation"

renderPbAdmission :: PbAdmission -> Text
renderPbAdmission value
  | value == DenyByDefaultStaticAstImportCallControlFlowPotentialEffect =
      "deny-by-default-static-ast-import-call-control-flow-potential-effect"
  | otherwise = "mutation-only-pb-admission"

renderGenerationTiming :: GenerationTiming -> Text
renderGenerationTiming value
  | value == LazyAtConsumption = "lazy-at-consumption"
  | otherwise = "mutation-only-generation-timing"

renderGenerationRoot :: GenerationRoot -> Text
renderGenerationRoot value
  | value == IgnoredDotBuild = ".build/**"
  | otherwise = ".mutation-only/**"

renderTrackedGeneratedArtifact :: TrackedGeneratedArtifact -> Text
renderTrackedGeneratedArtifact value
  | value == TrackedGeneratedArtifactForbidden = "forbidden"
  | otherwise = "mutation-only-tracked-generated-artifact"

renderRegistryPlacement :: RegistryPlacement -> Text
renderRegistryPlacement value
  | value == SeparatelyPinnedAndPreloaded = "separately-pinned-and-preloaded"
  | otherwise = "mutation-only-registry-placement"

renderRegisterCardinality :: RegisterCardinality -> Text
renderRegisterCardinality value
  | value == ExactlyOneActiveRegister = "exactly-one-active-register"
  | otherwise = "mutation-only-register-cardinality"

renderArchiveRegisterRule :: ArchiveRegisterRule -> Text
renderArchiveRegisterRule value
  | value == ArchiveRegisterForbidden = "forbidden"
  | otherwise = "mutation-only-archive-rule"

renderRegisterHistory :: RegisterHistory -> Text
renderRegisterHistory value
  | value == GitHistoryOnly = "git-history-only"
  | otherwise = "mutation-only-register-history"

renderRegisterPredicateAuthority :: RegisterPredicateAuthority -> Text
renderRegisterPredicateAuthority value
  | value == HaskellPredicateOnly = "haskell-predicate-only"
  | otherwise = "mutation-only-register-predicate-authority"

renderResetPhaseStatus :: ResetPhaseStatus -> Text
renderResetPhaseStatus status
  | status == ActiveNotValidated = "active-not-validated"
  | status == BlockedNotValidated = "blocked-not-validated"
  | otherwise = "mutation-only-reset-phase-status"

renderSprintResetRule :: SprintResetRule -> Text
renderSprintResetRule value
  | value == EverySprintNotValidated = "every-sprint-not-validated"
  | otherwise = "mutation-only-sprint-reset-rule"

renderHistoricalEvidenceRule :: HistoricalEvidenceRule -> Text
renderHistoricalEvidenceRule value
  | value == PriorValidationPermanentlyInvalid = "prior-validation-permanently-invalid"
  | otherwise = "mutation-only-historical-evidence-rule"

renderPredecessorRule :: PredecessorRule -> Text
renderPredecessorRule value
  | value == ImmediateNumericPredecessor = "immediate-numeric-predecessor"
  | otherwise = "mutation-only-predecessor-rule"

renderPhaseRoles :: OrderingContract -> Text
renderPhaseRoles ordering =
  Text.intercalate
    ","
    [ renderPhaseRole role <> "=" <> renderPhaseOrdinal (phaseRoleOrdinal ordering role)
    | role <- [minBound .. maxBound]
    ]

renderPhaseRole :: PhaseRole -> Text
renderPhaseRole value
  | value == HardwareFreeDslBarrier = "hardware-free-dsl-barrier"
  | value == BoundedPbHandoffValidation = "bounded-pb-handoff-validation"
  | value == HaskellHostEnsure = "haskell-host-ensure"
  | value == FirstHardwareValidation = "first-hardware-validation"
  | otherwise = "mutation-only-phase-role"

renderPhaseOrdinal :: PhaseOrdinal -> Text
renderPhaseOrdinal ordinal = Text.justifyRight 2 '0' (showText (phaseOrdinalNumber ordinal))

renderPhase50MigrationRule :: Phase50MigrationRule -> Text
renderPhase50MigrationRule value
  | value == NoSourceMigration = "no-source-migration"
  | otherwise = "mutation-only-phase50-migration-rule"

renderDslBarrierSourceClosure :: DslBarrierSourceClosure -> Text
renderDslBarrierSourceClosure value
  | value == AllLtdSrcQueriesZeroBeforePhase49 = "all-ltd-src-queries-zero-before-phase-49"
  | otherwise = "mutation-only-dsl-barrier-source-closure"

renderPrehardwareRule :: PrehardwareRule -> Text
renderPrehardwareRule value
  | value == NoHardwareThroughPhase51 = "no-hardware-through-phase-51"
  | otherwise = "mutation-only-prehardware-rule"

renderPbTransportRule :: PbTransportRule -> Text
renderPbTransportRule rule
  | rule == DirectHaskellThrough49ObservedPbAt50ApprovalBoundAfter50 =
      "direct-haskell-through-49;observed-pb-at-50;phase-50-approval-bound-pb-after-50"
  | otherwise = "mutation-only-pb-admitted-before-phase-50"

renderPromotionAuthority :: PromotionAuthority -> Text
renderPromotionAuthority value
  | value == ExternallyAnchoredHumanOnly = "externally-anchored-human-only"
  | otherwise = "mutation-only-promotion-authority"

renderAutomationRole :: AutomationRole -> Text
renderAutomationRole value
  | value == CandidateEvidenceOnly = "candidate-evidence-only"
  | otherwise = "mutation-only-automation-role"

renderStatusMutationAuthority :: StatusMutationAuthority -> Text
renderStatusMutationAuthority value
  | value == HumanUserOnly = "human-user-only"
  | otherwise = "mutation-only-status-mutation-authority"

renderOwner :: PolicyOwnerReference -> Text
renderOwner reference =
  Text.pack (policyOwnerPath reference)
    <> "#"
    <> policyOwnerAnchor reference
    <> "|"
    <> policyOwnerSection reference

policySlug :: PolicyId -> Text
policySlug identifier
  | identifier == TrackedSourceBoundary = "tracked-source-boundary"
  | identifier == PbBootstrapBoundary = "pb-bootstrap-boundary"
  | identifier == LazyBuildGeneration = "lazy-build-generation"
  | identifier == ClusterRegistryProvider = "cluster-registry-provider"
  | identifier == ClusterRegistryPlacement = "cluster-registry-placement"
  | identifier == ActiveLegacyRegister = "active-legacy-register"
  | identifier == ValidationStatusReset = "validation-status-reset"
  | identifier == NumericPhaseOrder = "numeric-phase-order"
  | identifier == DslBarrierSourceClosurePolicy = "dsl-barrier-source-closure"
  | identifier == PrehardwarePromotionBarrier = "prehardware-promotion-barrier"
  | identifier == PromotionAuthorityPolicy = "promotion-authority"
  | otherwise = "mutation-only-policy-id"

showText :: Show value => value -> Text
showText = Text.pack . show

hex :: ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value =
    [ intToDigit (fromIntegral value `div` 16)
    , intToDigit (fromIntegral value `mod` 16)
    ]
