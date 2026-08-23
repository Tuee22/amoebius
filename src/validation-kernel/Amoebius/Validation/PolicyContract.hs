{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.PolicyContract
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
  , policyOwnerReference
  , promotionAuthorityMarker
  , registryImageReference
  , renderPolicyContract
  , resetPhaseStatusText
  ) where

import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
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
  deriving (Bounded, Enum, Eq, Ord, Show)

data PolicyOwnerReference = PolicyOwnerReference
  { policyOwnerPath :: FilePath
  , policyOwnerAnchor :: Text
  , policyOwnerSection :: Text
  }
  deriving (Eq, Ord, Show)

data BehavioralLanguage = HaskellDotHs
  deriving (Bounded, Enum, Eq, Ord, Show)

data SourceClassification = SemanticClosedWorld
  deriving (Bounded, Enum, Eq, Ord, Show)

data PublicBehaviorAuthority = HaskellBinaryOnly
  deriving (Bounded, Enum, Eq, Ord, Show)

data SourceContract = SourceContract
  { sourceBehavioralLanguage :: BehavioralLanguage
  , sourceClassification :: SourceClassification
  , sourcePublicBehaviorAuthority :: PublicBehaviorAuthority
  }
  deriving (Eq, Ord, Show)

behavioralSourceSuffix :: BehavioralLanguage -> FilePath
behavioralSourceSuffix HaskellDotHs = ".hs"

data BootstrapOperation
  = MinimalPlatformDistinction
  | ContainedToolchainEstablishment
  | SourceBoundHaskellBuild
  | OpaqueArgumentPreservingExec
  deriving (Bounded, Enum, Eq, Ord, Show)

data PbAdmission = DenyByDefaultStaticAstImportCallControlFlowPotentialEffect
  deriving (Bounded, Enum, Eq, Ord, Show)

data PbSourceLanguage = PythonSourceLanguage
  deriving (Bounded, Enum, Eq, Ord, Show)

data PbContract = PbContract
  { pbRoot :: FilePath
  , pbSourceLanguage :: PbSourceLanguage
  , pbOperations :: Set BootstrapOperation
  , pbAdmission :: PbAdmission
  }
  deriving (Eq, Ord, Show)

data GenerationTiming = LazyAtConsumption
  deriving (Bounded, Enum, Eq, Ord, Show)

data GenerationRoot = IgnoredDotBuild
  deriving (Bounded, Enum, Eq, Ord, Show)

data TrackedGeneratedArtifact = TrackedGeneratedArtifactForbidden
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

data RegistryPlacement = SeparatelyPinnedAndPreloaded
  deriving (Bounded, Enum, Eq, Ord, Show)

data RegistryContract = RegistryContract
  { registryProvider :: RegistryProvider
  , registryPlacement :: RegistryPlacement
  }
  deriving (Eq, Ord, Show)

data RegisterHistory = GitHistoryOnly
  deriving (Bounded, Enum, Eq, Ord, Show)

data RegisterPredicateAuthority = HaskellPredicateOnly
  deriving (Bounded, Enum, Eq, Ord, Show)

data RegisterCardinality = ExactlyOneActiveRegister
  deriving (Bounded, Enum, Eq, Ord, Show)

data ArchiveRegisterRule = ArchiveRegisterForbidden
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
  deriving (Bounded, Enum, Eq, Ord, Show)

data SprintResetRule = EverySprintNotValidated
  deriving (Bounded, Enum, Eq, Ord, Show)

data HistoricalEvidenceRule = PriorValidationPermanentlyInvalid
  deriving (Bounded, Enum, Eq, Ord, Show)

data StatusResetContract = StatusResetContract
  { phaseZeroResetStatus :: ResetPhaseStatus
  , laterPhaseResetStatus :: ResetPhaseStatus
  , sprintResetRule :: SprintResetRule
  , historicalEvidenceRule :: HistoricalEvidenceRule
  }
  deriving (Eq, Ord, Show)

resetPhaseStatusText :: ResetPhaseStatus -> Text
resetPhaseStatusText status = case status of
  ActiveNotValidated -> "🔄 Active — NOT VALIDATED"
  BlockedNotValidated -> "⏸️ Blocked — NOT VALIDATED"

newtype PhaseOrdinal = PhaseOrdinal Word8
  deriving (Eq, Ord, Show)

mkPhaseOrdinal :: Int -> Maybe PhaseOrdinal
mkPhaseOrdinal value
  | value >= 0 && value <= 95 = Just (PhaseOrdinal (fromIntegral value))
  | otherwise = Nothing

phaseOrdinalNumber :: PhaseOrdinal -> Int
phaseOrdinalNumber (PhaseOrdinal value) = fromIntegral value

data PredecessorRule = ImmediateNumericPredecessor
  deriving (Bounded, Enum, Eq, Ord, Show)

data PhaseRole
  = HardwareFreeDslBarrier
  | BoundedPbHandoffValidation
  | HaskellHostEnsure
  | FirstHardwareValidation
  deriving (Bounded, Enum, Eq, Ord, Show)

data Phase50MigrationRule = NoSourceMigration
  deriving (Bounded, Enum, Eq, Ord, Show)

data DslBarrierSourceClosure = AllLtdSrcQueriesZeroBeforePhase49
  deriving (Bounded, Enum, Eq, Ord, Show)

data PrehardwareRule = NoHardwareThroughPhase51
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
phaseRoleOrdinal ordering role = case role of
  HardwareFreeDslBarrier -> hardwareFreeDslBarrierPhase ordering
  BoundedPbHandoffValidation -> boundedPbHandoffValidationPhase ordering
  HaskellHostEnsure -> haskellHostEnsurePhase ordering
  FirstHardwareValidation -> firstHardwareValidationPhase ordering

data PromotionAuthority = ExternallyAnchoredHumanOnly
  deriving (Bounded, Enum, Eq, Ord, Show)

data AutomationRole = CandidateEvidenceOnly
  deriving (Bounded, Enum, Eq, Ord, Show)

data StatusMutationAuthority = HumanUserOnly
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
    [ owner TrackedSourceBoundary "documents/engineering/repository_layout_doctrine.md" "1-classification-rule" "1. Classification rule"
    , owner PbBootstrapBoundary "documents/engineering/substrate_doctrine.md" "6-the-pre-binary-handoff-contract" "6. The pre-binary handoff contract"
    , owner LazyBuildGeneration "documents/engineering/generated_artifacts_doctrine.md" "3-the-rule" "3. The rule"
    , owner ClusterRegistryProvider "documents/engineering/service_capability_doctrine.md" "3-canonical-providers-extension-is-capability-specific" "3. Canonical providers; extension is capability-specific"
    , (ClusterRegistryPlacement, registryPlacementOwner)
    , owner ActiveLegacyRegister "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md" "1-register-contract" "1. Register contract"
    , owner ValidationStatusReset "DEVELOPMENT_PLAN/phase_00_documentation_suite.md" "phase-status" "Phase Status"
    , owner NumericPhaseOrder "DEVELOPMENT_PLAN/development_plan_phase_model.md" "e-one-canonical-phase-model" "E. One canonical phase model"
    , owner DslBarrierSourceClosurePolicy "DEVELOPMENT_PLAN/development_plan_phase_model.md" "e-one-canonical-phase-model" "E. One canonical phase model"
    , owner PrehardwarePromotionBarrier "DEVELOPMENT_PLAN/development_plan_phase_model.md" "l-one-substrate-discipline" "L. One-substrate discipline"
    , owner PromotionAuthorityPolicy "DEVELOPMENT_PLAN/development_plan_gate_integrity.md" "m6-candidate-evidence-and-human-promotion" "M.6 Candidate evidence and human promotion"
    ]
 where
  owner identifier path anchor section = (identifier, PolicyOwnerReference path anchor section)

registryPlacementOwner :: PolicyOwnerReference
registryPlacementOwner =
  PolicyOwnerReference
    "documents/engineering/image_build_doctrine.md"
    "2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster"
    "2. The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster"

policyOwnerReference :: PolicyContract -> PolicyId -> Maybe PolicyOwnerReference
policyOwnerReference contract identifier = Map.lookup identifier (contractOwners contract)

canonicalActiveRegisterPath :: PolicyContract -> FilePath
canonicalActiveRegisterPath = activeRegisterPath . registerContract

canonicalForbiddenArchivePath :: PolicyContract -> FilePath
canonicalForbiddenArchivePath = forbiddenArchivePath . registerContract

registryImageReference :: RegistryProvider -> Text
registryImageReference provider = case provider of
  DistributionRegistry2 -> "registry:2"
#ifdef VALIDATION_POLICY_ALTERNATE_REGISTRY_MUTANT
  AlternateRegistryProvider -> "mutation-only-alternate-registry"
#endif

generationRootPath :: GenerationRoot -> FilePath
generationRootPath IgnoredDotBuild = ".build"

promotionAuthorityMarker :: PromotionAuthority -> Text
promotionAuthorityMarker ExternallyAnchoredHumanOnly = "human"

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
    mismatch "POLICY-SOURCE" "policy.source" expectedSourceContract (sourceContract contract)
  pbFindings =
    mismatch "POLICY-PB" "policy.pb" expectedPbContract (pbContract contract)
  generationFindings =
    mismatch "POLICY-GENERATION" "policy.generation" expectedGenerationContract (generationContract contract)
  registry = registryContract contract
  registryFindings =
    [ finding "POLICY-REGISTRY-SELECTION" "policy.registry" "the selected Registry provider must be DistributionRegistry2"
         | registryProvider registry /= DistributionRegistry2
         ]
      <> [ finding "POLICY-REGISTRY-REFERENCE" "policy.registry" "DistributionRegistry2 must render exactly registry:2"
         | registryImageReference (registryProvider registry) /= "registry:2"
         ]
      <> [ finding "POLICY-REGISTRY-PLACEMENT" "policy.registry" "registry:2 must be separately pinned and preloaded, never baked into amoebius-base"
         | registryPlacement registry /= SeparatelyPinnedAndPreloaded
         ]
  registerFindings =
    mismatch "POLICY-REGISTER" "policy.legacy-register" expectedRegisterContract (registerContract contract)
  statusResetFindings =
    mismatch "POLICY-STATUS-RESET" "policy.status-reset" expectedStatusResetContract (statusResetContract contract)
  orderingFindings =
    mismatch "POLICY-ORDERING" "policy.phase-order" expectedOrderingContract (orderingContract contract)
  promotionFindings =
    mismatch "POLICY-PROMOTION" "policy.promotion" expectedPromotionContract (promotionContract contract)
  owners = contractOwners contract
  policyIdUniverse = Set.fromList ([minBound .. maxBound] :: [PolicyId])
  ownerFindings =
    [ finding
        "POLICY-OWNER-INVENTORY"
        "policy.owners"
        "the decision-to-owner map must contain each closed PolicyId exactly once"
    | Map.keysSet owners /= Map.keysSet expectedOwners
        || Map.keysSet owners /= policyIdUniverse
    ]
      <> [ finding
             "POLICY-OWNER-MISMATCH"
             (Text.unpack ("policy." <> policySlug identifier))
             ("policy owner must be " <> renderOwner expected)
         | (identifier, expected) <- Map.toAscList expectedOwners
         , Map.lookup identifier owners /= Just expected
         ]

mismatch :: (Eq value, Show value) => Text -> FilePath -> value -> value -> [Finding]
mismatch code subject expected observed =
  [ finding code subject ("expected " <> showText expected <> ", observed " <> showText observed)
  | observed /= expected
  ]

universeMismatch :: (Eq value, Show value) => Text -> FilePath -> [value] -> [value] -> [Finding]
universeMismatch code subject expected observed =
  [ finding code subject ("expected closed constructor universe " <> showText expected <> ", observed " <> showText observed)
  | observed /= expected
  ]

renderPolicyContract :: PolicyContract -> ByteString
renderPolicyContract contract =
  TextEncoding.encodeUtf8
    ( Text.unlines
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
 where
  source = sourceContract contract
  pb = pbContract contract
  generation = generationContract contract
  registry = registryContract contract
  register = registerContract contract
  statusReset = statusResetContract contract
  ordering = orderingContract contract
  promotion = promotionContract contract

policyContractDigest :: PolicyContract -> Text
policyContractDigest = hex . SHA256.hash . renderPolicyContract

renderUniverse :: (value -> Text) -> [value] -> Text
renderUniverse render = Text.intercalate "," . map render

renderBehavioralLanguage :: BehavioralLanguage -> Text
renderBehavioralLanguage HaskellDotHs = "haskell-.hs-only"

renderSourceClassification :: SourceClassification -> Text
renderSourceClassification SemanticClosedWorld = "semantic-closed-world"

renderPublicBehaviorAuthority :: PublicBehaviorAuthority -> Text
renderPublicBehaviorAuthority HaskellBinaryOnly = "haskell-binary-only"

renderPbSourceLanguage :: PbSourceLanguage -> Text
renderPbSourceLanguage PythonSourceLanguage = "python"

renderBootstrapOperations :: Set BootstrapOperation -> Text
renderBootstrapOperations = Text.intercalate "," . map renderBootstrapOperation . Set.toAscList

renderBootstrapOperation :: BootstrapOperation -> Text
renderBootstrapOperation MinimalPlatformDistinction = "minimal-platform-distinction"
renderBootstrapOperation ContainedToolchainEstablishment = "contained-toolchain-establishment"
renderBootstrapOperation SourceBoundHaskellBuild = "source-bound-haskell-build"
renderBootstrapOperation OpaqueArgumentPreservingExec = "opaque-argument-preserving-exec"

renderPbAdmission :: PbAdmission -> Text
renderPbAdmission DenyByDefaultStaticAstImportCallControlFlowPotentialEffect = "deny-by-default-static-ast-import-call-control-flow-potential-effect"

renderGenerationTiming :: GenerationTiming -> Text
renderGenerationTiming LazyAtConsumption = "lazy-at-consumption"

renderGenerationRoot :: GenerationRoot -> Text
renderGenerationRoot IgnoredDotBuild = ".build/**"

renderTrackedGeneratedArtifact :: TrackedGeneratedArtifact -> Text
renderTrackedGeneratedArtifact TrackedGeneratedArtifactForbidden = "forbidden"

renderRegistryPlacement :: RegistryPlacement -> Text
renderRegistryPlacement SeparatelyPinnedAndPreloaded = "separately-pinned-and-preloaded"

renderRegisterCardinality :: RegisterCardinality -> Text
renderRegisterCardinality ExactlyOneActiveRegister = "exactly-one-active-register"

renderArchiveRegisterRule :: ArchiveRegisterRule -> Text
renderArchiveRegisterRule ArchiveRegisterForbidden = "forbidden"

renderRegisterHistory :: RegisterHistory -> Text
renderRegisterHistory GitHistoryOnly = "git-history-only"

renderRegisterPredicateAuthority :: RegisterPredicateAuthority -> Text
renderRegisterPredicateAuthority HaskellPredicateOnly = "haskell-predicate-only"

renderResetPhaseStatus :: ResetPhaseStatus -> Text
renderResetPhaseStatus status = case status of
  ActiveNotValidated -> "active-not-validated"
  BlockedNotValidated -> "blocked-not-validated"

renderSprintResetRule :: SprintResetRule -> Text
renderSprintResetRule EverySprintNotValidated = "every-sprint-not-validated"

renderHistoricalEvidenceRule :: HistoricalEvidenceRule -> Text
renderHistoricalEvidenceRule PriorValidationPermanentlyInvalid = "prior-validation-permanently-invalid"

renderPredecessorRule :: PredecessorRule -> Text
renderPredecessorRule ImmediateNumericPredecessor = "immediate-numeric-predecessor"

renderPhaseRoles :: OrderingContract -> Text
renderPhaseRoles ordering =
  Text.intercalate
    ","
    [ renderPhaseRole role <> "=" <> renderPhaseOrdinal (phaseRoleOrdinal ordering role)
    | role <- [minBound .. maxBound]
    ]

renderPhaseRole :: PhaseRole -> Text
renderPhaseRole HardwareFreeDslBarrier = "hardware-free-dsl-barrier"
renderPhaseRole BoundedPbHandoffValidation = "bounded-pb-handoff-validation"
renderPhaseRole HaskellHostEnsure = "haskell-host-ensure"
renderPhaseRole FirstHardwareValidation = "first-hardware-validation"

renderPhaseOrdinal :: PhaseOrdinal -> Text
renderPhaseOrdinal ordinal = Text.justifyRight 2 '0' (showText (phaseOrdinalNumber ordinal))

renderPhase50MigrationRule :: Phase50MigrationRule -> Text
renderPhase50MigrationRule NoSourceMigration = "no-source-migration"

renderDslBarrierSourceClosure :: DslBarrierSourceClosure -> Text
renderDslBarrierSourceClosure AllLtdSrcQueriesZeroBeforePhase49 = "all-ltd-src-queries-zero-before-phase-49"

renderPrehardwareRule :: PrehardwareRule -> Text
renderPrehardwareRule NoHardwareThroughPhase51 = "no-hardware-through-phase-51"

renderPbTransportRule :: PbTransportRule -> Text
renderPbTransportRule DirectHaskellThrough49ObservedPbAt50ApprovalBoundAfter50 =
  "direct-haskell-through-49;observed-pb-at-50;phase-50-approval-bound-pb-after-50"
#ifdef VALIDATION_POLICY_PB_TRANSPORT_MUTANT
renderPbTransportRule PbAdmittedBeforePhase50 = "mutation-only-pb-admitted-before-phase-50"
#endif

renderPromotionAuthority :: PromotionAuthority -> Text
renderPromotionAuthority ExternallyAnchoredHumanOnly = "externally-anchored-human-only"

renderAutomationRole :: AutomationRole -> Text
renderAutomationRole CandidateEvidenceOnly = "candidate-evidence-only"

renderStatusMutationAuthority :: StatusMutationAuthority -> Text
renderStatusMutationAuthority HumanUserOnly = "human-user-only"

renderOwner :: PolicyOwnerReference -> Text
renderOwner reference =
  Text.pack (policyOwnerPath reference)
    <> "#"
    <> policyOwnerAnchor reference
    <> "|"
    <> policyOwnerSection reference

policySlug :: PolicyId -> Text
policySlug identifier = case identifier of
  TrackedSourceBoundary -> "tracked-source-boundary"
  PbBootstrapBoundary -> "pb-bootstrap-boundary"
  LazyBuildGeneration -> "lazy-build-generation"
  ClusterRegistryProvider -> "cluster-registry-provider"
  ClusterRegistryPlacement -> "cluster-registry-placement"
  ActiveLegacyRegister -> "active-legacy-register"
  ValidationStatusReset -> "validation-status-reset"
  NumericPhaseOrder -> "numeric-phase-order"
  DslBarrierSourceClosurePolicy -> "dsl-barrier-source-closure"
  PrehardwarePromotionBarrier -> "prehardware-promotion-barrier"
  PromotionAuthorityPolicy -> "promotion-authority"

showText :: Show value => value -> Text
showText = Text.pack . show

hex :: ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value =
    [ intToDigit (fromIntegral value `div` 16)
    , intToDigit (fromIntegral value `mod` 16)
    ]
