{-# LANGUAGE OverloadedStrings #-}

module PolicyContractOracle
  ( runPolicyContractOracle
  ) where

-- Component diagnostics only. The expected values below are stated
-- independently of the production constructor. This is not human prose
-- correspondence review, changed-subject qualification, phase validation, or
-- promotion evidence.

import Amoebius.Validation.PolicyContract
import Amoebius.Validation.Dispatch (checkPhaseZeroSnapshot)
import Amoebius.Validation.SourceClosure (SourceSnapshot (..))
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  )
import Control.Monad (unless)
import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as ByteString8
import Data.List ((\\))
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

runPolicyContractOracle :: IO ()
runPolicyContractOracle =
  finishDiagnostics
    "PolicyContractOracle"
    ( concat
        [ expectCanonicalSurface
        , expectDeltaFindings
            "missing pb operation"
            [ ExpectedFinding
                "POLICY-PB"
                "policy.pb"
                "OpaqueArgumentPreservingExec"
            ]
            ( canonicalPolicyContract
                { pbContract =
                    (pbContract canonicalPolicyContract)
                      { pbOperations = Set.delete OpaqueArgumentPreservingExec (pbOperations (pbContract canonicalPolicyContract))
                      }
                }
            )
        , expectDeltaFindings
            "owner-map production value redirected"
            [ ExpectedFinding
                "POLICY-OWNER-MISMATCH"
                "policy.tracked-source-boundary"
                "documents/engineering/repository_layout_doctrine.md#1-classification-rule"
            ]
            ( canonicalPolicyContract
                { contractOwners =
                    Map.insert
                      TrackedSourceBoundary
                      (PolicyOwnerReference "documents/engineering/image_build_doctrine.md" "2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster" "2. The single Distribution rule")
                      (contractOwners canonicalPolicyContract)
                }
            )
        , expectDeltaFindings
            "registry placement owner collapsed into provider owner"
            [ ExpectedFinding
                "POLICY-OWNER-MISMATCH"
                "policy.cluster-registry-placement"
                "documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster"
            ]
            ( canonicalPolicyContract
                { contractOwners =
                    Map.insert
                      ClusterRegistryPlacement
                      (PolicyOwnerReference "documents/engineering/service_capability_doctrine.md" "3-canonical-providers-extension-is-capability-specific" "3. Canonical providers; extension is capability-specific")
                      (contractOwners canonicalPolicyContract)
                }
            )
        , expectDeltaFindings
            "owner-map member omitted"
            [ ExpectedFinding
                "POLICY-OWNER-INVENTORY"
                "policy.owners"
                "each closed PolicyId exactly once"
            , ExpectedFinding
                "POLICY-OWNER-MISMATCH"
                "policy.promotion-authority"
                "development_plan_gate_integrity.md#m6-candidate-evidence-and-human-promotion"
            ]
            (canonicalPolicyContract {contractOwners = Map.delete PromotionAuthorityPolicy (contractOwners canonicalPolicyContract)})
        , expectDeltaFindings
            "legacy register renamed to eliminated archive"
            [ ExpectedFinding
                "POLICY-REGISTER"
                "policy.legacy-register"
                "observed RegisterContract {activeRegisterPath = \"DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md\""
            ]
            ( canonicalPolicyContract
                { registerContract =
                    (registerContract canonicalPolicyContract)
                      { activeRegisterPath = "DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md"
                      }
                }
            )
        , expectDeltaFindings
            "forbidden archive path redirected"
            [ ExpectedFinding
                "POLICY-REGISTER"
                "policy.legacy-register"
                "forbiddenArchivePath = \"DEVELOPMENT_PLAN/legacy_tracking_for_deletion_retired.md\""
            ]
            ( canonicalPolicyContract
                { registerContract =
                    (registerContract canonicalPolicyContract)
                      { forbiddenArchivePath = "DEVELOPMENT_PLAN/legacy_tracking_for_deletion_retired.md"
                      }
                }
            )
        , expectDeltaFindings
            "Phase 0 reset status changed to Blocked"
            [ ExpectedFinding
                "POLICY-STATUS-RESET"
                "policy.status-reset"
                "observed StatusResetContract {phaseZeroResetStatus = BlockedNotValidated"
            ]
            ( canonicalPolicyContract
                { statusResetContract =
                    (statusResetContract canonicalPolicyContract)
                      { phaseZeroResetStatus = BlockedNotValidated
                      }
                }
            )
        , expectDeltaFindings
            "Phase 49 and Phase 50 roles swapped"
            [ ExpectedFinding
                "POLICY-ORDERING"
                "policy.phase-order"
                "hardwareFreeDslBarrierPhase = PhaseOrdinal 50, boundedPbHandoffValidationPhase = PhaseOrdinal 49"
            ]
            ( canonicalPolicyContract
                { orderingContract =
                    (orderingContract canonicalPolicyContract)
                      { hardwareFreeDslBarrierPhase = boundedPbHandoffValidationPhase (orderingContract canonicalPolicyContract)
                      , boundedPbHandoffValidationPhase = hardwareFreeDslBarrierPhase (orderingContract canonicalPolicyContract)
                      }
                }
            )
        , expectDeltaFindings
            "hardware admitted at Phase 51"
            [ ExpectedFinding
                "POLICY-ORDERING"
                "policy.phase-order"
                "firstHardwareValidationPhase = PhaseOrdinal 51"
            ]
            ( canonicalPolicyContract
                { orderingContract =
                    (orderingContract canonicalPolicyContract)
                      { firstHardwareValidationPhase = haskellHostEnsurePhase (orderingContract canonicalPolicyContract)
                      }
                }
            )
        ]
    )

data ExpectedFinding = ExpectedFinding
  { expectedFindingCode :: Text
  , expectedFindingSubject :: FilePath
  , expectedFindingDetailFragment :: Text
  }
  deriving (Eq, Show)

expectedPolicyIds :: [PolicyId]
expectedPolicyIds =
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

expectedBehavioralLanguages :: [BehavioralLanguage]
expectedBehavioralLanguages = [HaskellDotHs]

expectedSourceClassifications :: [SourceClassification]
expectedSourceClassifications = [SemanticClosedWorld]

expectedPublicBehaviorAuthorities :: [PublicBehaviorAuthority]
expectedPublicBehaviorAuthorities = [HaskellBinaryOnly]

expectedPbSourceLanguages :: [PbSourceLanguage]
expectedPbSourceLanguages = [PythonSourceLanguage]

expectedBootstrapOperations :: [BootstrapOperation]
expectedBootstrapOperations =
  [ MinimalPlatformDistinction
  , ContainedToolchainEstablishment
  , SourceBoundHaskellBuild
  , OpaqueArgumentPreservingExec
  ]

expectedPbAdmissions :: [PbAdmission]
expectedPbAdmissions = [DenyByDefaultStaticAstImportCallControlFlowPotentialEffect]

expectedGenerationTimings :: [GenerationTiming]
expectedGenerationTimings = [LazyAtConsumption]

expectedGenerationRoots :: [GenerationRoot]
expectedGenerationRoots = [IgnoredDotBuild]

expectedTrackedGeneratedArtifacts :: [TrackedGeneratedArtifact]
expectedTrackedGeneratedArtifacts = [TrackedGeneratedArtifactForbidden]

expectedRegistryProviders :: [RegistryProvider]
expectedRegistryProviders = [DistributionRegistry2]

expectedRegistryPlacements :: [RegistryPlacement]
expectedRegistryPlacements = [SeparatelyPinnedAndPreloaded]

expectedRegisterCardinalities :: [RegisterCardinality]
expectedRegisterCardinalities = [ExactlyOneActiveRegister]

expectedArchiveRegisterRules :: [ArchiveRegisterRule]
expectedArchiveRegisterRules = [ArchiveRegisterForbidden]

expectedRegisterHistories :: [RegisterHistory]
expectedRegisterHistories = [GitHistoryOnly]

expectedRegisterPredicateAuthorities :: [RegisterPredicateAuthority]
expectedRegisterPredicateAuthorities = [HaskellPredicateOnly]

expectedResetPhaseStatuses :: [ResetPhaseStatus]
expectedResetPhaseStatuses = [ActiveNotValidated, BlockedNotValidated]

expectedSprintResetRules :: [SprintResetRule]
expectedSprintResetRules = [EverySprintNotValidated]

expectedHistoricalEvidenceRules :: [HistoricalEvidenceRule]
expectedHistoricalEvidenceRules = [PriorValidationPermanentlyInvalid]

expectedPredecessorRules :: [PredecessorRule]
expectedPredecessorRules = [ImmediateNumericPredecessor]

expectedPhaseRoles :: [PhaseRole]
expectedPhaseRoles =
  [ HardwareFreeDslBarrier
  , BoundedPbHandoffValidation
  , HaskellHostEnsure
  , FirstHardwareValidation
  ]

expectedPhase50MigrationRules :: [Phase50MigrationRule]
expectedPhase50MigrationRules = [NoSourceMigration]

expectedDslBarrierSourceClosures :: [DslBarrierSourceClosure]
expectedDslBarrierSourceClosures = [AllLtdSrcQueriesZeroBeforePhase49]

expectedPrehardwareRules :: [PrehardwareRule]
expectedPrehardwareRules = [NoHardwareThroughPhase51]

expectedPbTransportRules :: [PbTransportRule]
expectedPbTransportRules = [DirectHaskellThrough49ObservedPbAt50ApprovalBoundAfter50]

expectedPromotionAuthorities :: [PromotionAuthority]
expectedPromotionAuthorities = [ExternallyAnchoredHumanOnly]

expectedAutomationRoles :: [AutomationRole]
expectedAutomationRoles = [CandidateEvidenceOnly]

expectedStatusMutationAuthorities :: [StatusMutationAuthority]
expectedStatusMutationAuthorities = [HumanUserOnly]

expectedOwners :: Map.Map PolicyId PolicyOwnerReference
expectedOwners =
  Map.fromList
    [ owner TrackedSourceBoundary "documents/engineering/repository_layout_doctrine.md" "1-classification-rule" "1. Classification rule"
    , owner PbBootstrapBoundary "documents/engineering/substrate_doctrine.md" "6-the-pre-binary-handoff-contract" "6. The pre-binary handoff contract"
    , owner LazyBuildGeneration "documents/engineering/generated_artifacts_doctrine.md" "3-the-rule" "3. The rule"
    , owner ClusterRegistryProvider "documents/engineering/service_capability_doctrine.md" "3-canonical-providers-extension-is-capability-specific" "3. Canonical providers; extension is capability-specific"
    , owner ClusterRegistryPlacement "documents/engineering/image_build_doctrine.md" "2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster" "2. The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster"
    , owner ActiveLegacyRegister "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md" "1-register-contract" "1. Register contract"
    , owner ValidationStatusReset "DEVELOPMENT_PLAN/phase_00_documentation_suite.md" "phase-status" "Phase Status"
    , owner NumericPhaseOrder "DEVELOPMENT_PLAN/development_plan_phase_model.md" "e-one-canonical-phase-model" "E. One canonical phase model"
    , owner DslBarrierSourceClosurePolicy "DEVELOPMENT_PLAN/development_plan_phase_model.md" "e-one-canonical-phase-model" "E. One canonical phase model"
    , owner PrehardwarePromotionBarrier "DEVELOPMENT_PLAN/development_plan_phase_model.md" "l-one-substrate-discipline" "L. One-substrate discipline"
    , owner PromotionAuthorityPolicy "DEVELOPMENT_PLAN/development_plan_gate_integrity.md" "m6-candidate-evidence-and-human-promotion" "M.6 Candidate evidence and human promotion"
    ]
 where
  owner identifier path anchor section = (identifier, PolicyOwnerReference path anchor section)

oracleSourceContract :: SourceContract
oracleSourceContract = SourceContract HaskellDotHs SemanticClosedWorld HaskellBinaryOnly

oraclePbContract :: PbContract
oraclePbContract =
  PbContract
    "pb"
    PythonSourceLanguage
    (Set.fromList [MinimalPlatformDistinction, ContainedToolchainEstablishment, SourceBoundHaskellBuild, OpaqueArgumentPreservingExec])
    DenyByDefaultStaticAstImportCallControlFlowPotentialEffect

oracleGenerationContract :: GenerationContract
oracleGenerationContract = GenerationContract LazyAtConsumption IgnoredDotBuild TrackedGeneratedArtifactForbidden

oracleRegistryContract :: RegistryContract
oracleRegistryContract = RegistryContract DistributionRegistry2 SeparatelyPinnedAndPreloaded

oracleRegisterContract :: RegisterContract
oracleRegisterContract =
  RegisterContract
    "DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md"
    ExactlyOneActiveRegister
    "DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md"
    ArchiveRegisterForbidden
    GitHistoryOnly
    HaskellPredicateOnly

oracleStatusResetContract :: StatusResetContract
oracleStatusResetContract =
  StatusResetContract
    ActiveNotValidated
    BlockedNotValidated
    EverySprintNotValidated
    PriorValidationPermanentlyInvalid

oracleOrderingContract :: OrderingContract
oracleOrderingContract =
  OrderingContract
    (maybe (error "oracle phase 0 must be representable") id (mkPhaseOrdinal 0))
    (maybe (error "oracle phase 95 must be representable") id (mkPhaseOrdinal 95))
    ImmediateNumericPredecessor
    (maybe (error "oracle phase 49 must be representable") id (mkPhaseOrdinal 49))
    (maybe (error "oracle phase 50 must be representable") id (mkPhaseOrdinal 50))
    (maybe (error "oracle phase 51 must be representable") id (mkPhaseOrdinal 51))
    (maybe (error "oracle phase 52 must be representable") id (mkPhaseOrdinal 52))
    NoSourceMigration
    AllLtdSrcQueriesZeroBeforePhase49
    NoHardwareThroughPhase51
    DirectHaskellThrough49ObservedPbAt50ApprovalBoundAfter50

oraclePromotionContract :: PromotionContract
oraclePromotionContract =
  PromotionContract ExternallyAnchoredHumanOnly CandidateEvidenceOnly HumanUserOnly

expectedRendering :: ByteString
expectedRendering =
  ByteString8.pack
    ( unlines
        [ "amoebius-policy-contract-v4"
        , "universe.policy-id=tracked-source-boundary,pb-bootstrap-boundary,lazy-build-generation,cluster-registry-provider,cluster-registry-placement,active-legacy-register,validation-status-reset,numeric-phase-order,dsl-barrier-source-closure,prehardware-promotion-barrier,promotion-authority"
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
        , "universe.pb-transport-rule=direct-haskell-through-49;observed-pb-at-50;phase-50-approval-bound-pb-after-50"
        , "universe.promotion-authority=externally-anchored-human-only"
        , "universe.automation-role=candidate-evidence-only"
        , "universe.status-mutation-authority=human-user-only"
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
        , "ordering.pb-transport=direct-haskell-through-49;observed-pb-at-50;phase-50-approval-bound-pb-after-50"
        , "promotion.authority=externally-anchored-human-only"
        , "promotion.automation-role=candidate-evidence-only"
        , "promotion.status-mutation=human-user-only"
        , "owner.tracked-source-boundary=documents/engineering/repository_layout_doctrine.md#1-classification-rule|1. Classification rule"
        , "owner.pb-bootstrap-boundary=documents/engineering/substrate_doctrine.md#6-the-pre-binary-handoff-contract|6. The pre-binary handoff contract"
        , "owner.lazy-build-generation=documents/engineering/generated_artifacts_doctrine.md#3-the-rule|3. The rule"
        , "owner.cluster-registry-provider=documents/engineering/service_capability_doctrine.md#3-canonical-providers-extension-is-capability-specific|3. Canonical providers; extension is capability-specific"
        , "owner.cluster-registry-placement=documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster|2. The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster"
        , "owner.active-legacy-register=DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md#1-register-contract|1. Register contract"
        , "owner.validation-status-reset=DEVELOPMENT_PLAN/phase_00_documentation_suite.md#phase-status|Phase Status"
        , "owner.numeric-phase-order=DEVELOPMENT_PLAN/development_plan_phase_model.md#e-one-canonical-phase-model|E. One canonical phase model"
        , "owner.dsl-barrier-source-closure=DEVELOPMENT_PLAN/development_plan_phase_model.md#e-one-canonical-phase-model|E. One canonical phase model"
        , "owner.prehardware-promotion-barrier=DEVELOPMENT_PLAN/development_plan_phase_model.md#l-one-substrate-discipline|L. One-substrate discipline"
        , "owner.promotion-authority=DEVELOPMENT_PLAN/development_plan_gate_integrity.md#m6-candidate-evidence-and-human-promotion|M.6 Candidate evidence and human promotion"
        ]
    )

expectedDigest :: Text
expectedDigest = "ba12753bf42242da9b30bc9d58cf81311b230e609741fbbd140a4e534d1959b3"

expectCanonicalSurface :: [String]
expectCanonicalSurface =
  case problems of
    [] -> []
    _ -> ["canonical policy surface:\n    " <> Text.unpack (Text.intercalate "\n    " (map Text.pack problems))]
 where
  problems =
    concat
      [ expectClean "contract check" canonicalPolicyContract
      , expectClosedEnumUniverses
      , expectEqual "independent owner map" expectedOwners (contractOwners canonicalPolicyContract)
      , expectEqual "typed source contract" oracleSourceContract (sourceContract canonicalPolicyContract)
      , expectEqual "typed pb contract" oraclePbContract (pbContract canonicalPolicyContract)
      , expectEqual "selected pb source language" PythonSourceLanguage (pbSourceLanguage (pbContract canonicalPolicyContract))
      , expectEqual "typed generation contract" oracleGenerationContract (generationContract canonicalPolicyContract)
      , expectEqual "typed Registry contract" oracleRegistryContract (registryContract canonicalPolicyContract)
      , expectEqual "typed register contract" oracleRegisterContract (registerContract canonicalPolicyContract)
      , expectEqual "typed status-reset contract" oracleStatusResetContract (statusResetContract canonicalPolicyContract)
      , expectEqual "typed ordering contract" oracleOrderingContract (orderingContract canonicalPolicyContract)
      , expectOrderingSurface
      , expectEqual "typed promotion contract" oraclePromotionContract (promotionContract canonicalPolicyContract)
      , expectEqual "selected Registry provider" DistributionRegistry2 (registryProvider (registryContract canonicalPolicyContract))
      , expectEqual "exact Registry image reference" "registry:2" (registryImageReference DistributionRegistry2)
      , expectEqual "exact canonical policy rendering" expectedRendering (renderPolicyContract canonicalPolicyContract)
      , expectEqual "exact canonical policy digest" expectedDigest (policyContractDigest canonicalPolicyContract)
      , expectDispatchIntegration
      ]

expectClosedEnumUniverses :: [String]
expectClosedEnumUniverses =
  concat
    [ expectEqual "closed PolicyId universe" expectedPolicyIds ([minBound .. maxBound] :: [PolicyId])
    , expectEqual "closed BehavioralLanguage universe" expectedBehavioralLanguages ([minBound .. maxBound] :: [BehavioralLanguage])
    , expectEqual "closed SourceClassification universe" expectedSourceClassifications ([minBound .. maxBound] :: [SourceClassification])
    , expectEqual "closed PublicBehaviorAuthority universe" expectedPublicBehaviorAuthorities ([minBound .. maxBound] :: [PublicBehaviorAuthority])
    , expectEqual "closed PbSourceLanguage universe" expectedPbSourceLanguages ([minBound .. maxBound] :: [PbSourceLanguage])
    , expectEqual "closed BootstrapOperation universe" expectedBootstrapOperations ([minBound .. maxBound] :: [BootstrapOperation])
    , expectEqual "closed PbAdmission universe" expectedPbAdmissions ([minBound .. maxBound] :: [PbAdmission])
    , expectEqual "closed GenerationTiming universe" expectedGenerationTimings ([minBound .. maxBound] :: [GenerationTiming])
    , expectEqual "closed GenerationRoot universe" expectedGenerationRoots ([minBound .. maxBound] :: [GenerationRoot])
    , expectEqual "closed TrackedGeneratedArtifact universe" expectedTrackedGeneratedArtifacts ([minBound .. maxBound] :: [TrackedGeneratedArtifact])
    , expectEqual "closed RegistryProvider universe" expectedRegistryProviders ([minBound .. maxBound] :: [RegistryProvider])
    , expectEqual "closed RegistryPlacement universe" expectedRegistryPlacements ([minBound .. maxBound] :: [RegistryPlacement])
    , expectEqual "closed RegisterCardinality universe" expectedRegisterCardinalities ([minBound .. maxBound] :: [RegisterCardinality])
    , expectEqual "closed ArchiveRegisterRule universe" expectedArchiveRegisterRules ([minBound .. maxBound] :: [ArchiveRegisterRule])
    , expectEqual "closed RegisterHistory universe" expectedRegisterHistories ([minBound .. maxBound] :: [RegisterHistory])
    , expectEqual "closed RegisterPredicateAuthority universe" expectedRegisterPredicateAuthorities ([minBound .. maxBound] :: [RegisterPredicateAuthority])
    , expectEqual "closed ResetPhaseStatus universe" expectedResetPhaseStatuses ([minBound .. maxBound] :: [ResetPhaseStatus])
    , expectEqual "closed SprintResetRule universe" expectedSprintResetRules ([minBound .. maxBound] :: [SprintResetRule])
    , expectEqual "closed HistoricalEvidenceRule universe" expectedHistoricalEvidenceRules ([minBound .. maxBound] :: [HistoricalEvidenceRule])
    , expectEqual "closed PredecessorRule universe" expectedPredecessorRules ([minBound .. maxBound] :: [PredecessorRule])
    , expectEqual "closed PhaseRole universe" expectedPhaseRoles ([minBound .. maxBound] :: [PhaseRole])
    , expectEqual "closed Phase50MigrationRule universe" expectedPhase50MigrationRules ([minBound .. maxBound] :: [Phase50MigrationRule])
    , expectEqual "closed DslBarrierSourceClosure universe" expectedDslBarrierSourceClosures ([minBound .. maxBound] :: [DslBarrierSourceClosure])
    , expectEqual "closed PrehardwareRule universe" expectedPrehardwareRules ([minBound .. maxBound] :: [PrehardwareRule])
    , expectEqual "closed PbTransportRule universe" expectedPbTransportRules ([minBound .. maxBound] :: [PbTransportRule])
    , expectEqual "closed PromotionAuthority universe" expectedPromotionAuthorities ([minBound .. maxBound] :: [PromotionAuthority])
    , expectEqual "closed AutomationRole universe" expectedAutomationRoles ([minBound .. maxBound] :: [AutomationRole])
    , expectEqual "closed StatusMutationAuthority universe" expectedStatusMutationAuthorities ([minBound .. maxBound] :: [StatusMutationAuthority])
    ]

expectOrderingSurface :: [String]
expectOrderingSurface =
  concat
    [ expectEqual "ordering phase-domain lower bound" 0 (phaseOrdinalNumber (phaseDomainLower ordering))
    , expectEqual "ordering phase-domain upper bound" 95 (phaseOrdinalNumber (phaseDomainUpper ordering))
    , expectEqual "ordering predecessor rule" ImmediateNumericPredecessor (predecessorRule ordering)
    , expectEqual "hardware-free DSL barrier phase" 49 (phaseOrdinalNumber (hardwareFreeDslBarrierPhase ordering))
    , expectEqual "bounded pb handoff validation phase" 50 (phaseOrdinalNumber (boundedPbHandoffValidationPhase ordering))
    , expectEqual "Haskell host ensure phase" 51 (phaseOrdinalNumber (haskellHostEnsurePhase ordering))
    , expectEqual "first hardware validation phase" 52 (phaseOrdinalNumber (firstHardwareValidationPhase ordering))
    , expectEqual "Phase 50 migration rule" NoSourceMigration (phase50MigrationRule ordering)
    , expectEqual "DSL barrier source closure" AllLtdSrcQueriesZeroBeforePhase49 (dslBarrierSourceClosure ordering)
    , expectEqual "prehardware rule" NoHardwareThroughPhase51 (prehardwareRule ordering)
    , expectEqual "pb transport rule" DirectHaskellThrough49ObservedPbAt50ApprovalBoundAfter50 (pbTransportRule ordering)
    ]
 where
  ordering = orderingContract canonicalPolicyContract

expectDispatchIntegration :: [String]
expectDispatchIntegration =
  concat
    [ expectEqual "dispatch policy provider observation count" 1 (length providerObservations)
    , expectEqual "dispatch policy provider observation" ["registry:2"] providerObservations
    , expectEqual "dispatch policy digest observation count" 1 (length digestObservations)
    , expectEqual "dispatch policy digest observation" [expectedDigest] digestObservations
    , expectEqual "dispatch canonical policy findings" [] integrityFindings
    ]
 where
  result = checkPhaseZeroSnapshot (SourceSnapshot "/synthetic-policy-oracle" "synthetic-policy-oracle" [])
  valuesFor key = [observationValue item | item <- checkObservations result, observationKey item == key]
  providerObservations = valuesFor "policy.registry-provider"
  digestObservations = valuesFor "policy.contract-sha256"
  integrityFindings =
    [ findingCode item
    | item <- checkFindings result
    , "POLICY-" `Text.isPrefixOf` findingCode item
    , findingCode item /= "POLICY-CONTRACT-UNQUALIFIED"
    ]

expectClean :: String -> PolicyContract -> [String]
expectClean label contract =
  [label <> ": unexpected findings " <> show (checkFindings result) | not (null (checkFindings result))]
 where
  result = checkPolicyContract contract

expectDeltaFindings :: String -> [ExpectedFinding] -> PolicyContract -> [String]
expectDeltaFindings label expected contract =
  [ label <> ": the negative removed baseline findings " <> show missingBaseline
  | not (null missingBaseline)
  ]
    <> expectEqual (label <> " finding count") (length expected) (length deltaFindings)
    <> concat (zipWith (expectFinding label) expected deltaFindings)
 where
  baselineFindings = checkFindings (checkPolicyContract canonicalPolicyContract)
  observedFindings = checkFindings (checkPolicyContract contract)
  missingBaseline = baselineFindings \\ observedFindings
  deltaFindings = observedFindings \\ baselineFindings

expectFinding :: String -> ExpectedFinding -> Finding -> [String]
expectFinding label expected observed =
  concat
    [ expectEqual (label <> " finding code") (expectedFindingCode expected) (findingCode observed)
    , expectEqual (label <> " finding subject") (expectedFindingSubject expected) (findingSubject observed)
    , [ label
          <> ": expected finding detail to contain "
          <> show (expectedFindingDetailFragment expected)
          <> ", observed "
          <> show (findingDetail observed)
      | not (expectedFindingDetailFragment expected `Text.isInfixOf` findingDetail observed)
      ]
    ]

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected observed
  | expected == observed = []
  | otherwise = [label <> ": expected " <> show expected <> ", observed " <> show observed]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless
    (null problems)
    (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack problems))))
