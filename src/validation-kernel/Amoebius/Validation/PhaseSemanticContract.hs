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
  | RequirePhaseOne PhaseOneRequirement
  | RequirePhaseTwo PhaseTwoRequirement
  | RequirePhaseThree PhaseThreeRequirement
  | RequirePhaseFour PhaseFourRequirement
  | RequirePhaseFive PhaseFiveRequirement
  | RequirePhaseSix PhaseSixRequirement
  | RequirePhaseSeven PhaseSevenRequirement
  | RequirePhaseEight PhaseEightRequirement
  | RequirePhaseNine PhaseNineRequirement
  | RequirePhaseTen PhaseTenRequirement
  | RequirePhaseEleven PhaseElevenRequirement
  | RequirePhaseTwelve PhaseTwelveRequirement
  | RequirePhaseThirteen PhaseThirteenRequirement
  | RequirePhaseFourteen PhaseFourteenRequirement
  | RequirePhaseFifteen PhaseFifteenRequirement
  | RequirePhaseSixteen PhaseSixteenRequirement
  | RequirePhaseSeventeen PhaseSeventeenRequirement
  | RequirePhaseEighteen PhaseEighteenRequirement
  | RequirePhaseNineteen PhaseNineteenRequirement
  | RequirePhaseTwenty PhaseTwentyRequirement
  | RequirePhaseTwentyOne PhaseTwentyOneRequirement
  | RequirePhaseTwentyTwo PhaseTwentyTwoRequirement
  | RequirePhaseTwentyThree PhaseTwentyThreeRequirement
  | RequirePhaseTwentyFour PhaseTwentyFourRequirement
  | RequirePhaseTwentyFive PhaseTwentyFiveRequirement
  | RequirePhaseTwentySix PhaseTwentySixRequirement
  | RequirePhaseTwentySeven PhaseTwentySevenRequirement
  | RequirePhaseTwentyEight PhaseTwentyEightRequirement
  | RequirePhaseTwentyNine PhaseTwentyNineRequirement
  | RequirePhaseThirty PhaseThirtyRequirement
  | RequirePhaseThirtyOne PhaseThirtyOneRequirement
  | RequirePhaseThirtyTwo PhaseThirtyTwoRequirement
  | RequirePhaseThirtyThree PhaseThirtyThreeRequirement
  | RequirePhaseThirtyFour PhaseThirtyFourRequirement
  | RequirePhaseThirtyFive PhaseThirtyFiveRequirement
  | RequirePhaseThirtySix PhaseThirtySixRequirement
  | RequirePhaseThirtySeven PhaseThirtySevenRequirement
  | RequirePhaseThirtyEight PhaseThirtyEightRequirement
  | RequirePhaseThirtyNine PhaseThirtyNineRequirement
  | RequirePhaseForty PhaseFortyRequirement
  | RequirePhaseFortyOne PhaseFortyOneRequirement
  | RequirePhaseFortyTwo PhaseFortyTwoRequirement
  | RequirePhaseFortyThree PhaseFortyThreeRequirement
  | RequirePhaseFortyFour PhaseFortyFourRequirement
  | RequirePhaseFortyFive PhaseFortyFiveRequirement
  | RequirePhaseFortySix PhaseFortySixRequirement
  deriving (Eq, Ord, Show)

-- | The Phase-1 payload is compiled independently of its Markdown projection.
-- Each constructor owns one exact gate category and describes the evidence
-- that the toolchain supervisor must acquire before finalization.
data PhaseOneRequirement
  = RequireAuthenticatedReproducibleToolchainAndProbeClosure
  | RequireAcquiredToolchainSpikeSupervisor
  | RequireDirectOfflineSerialToolchainInvocation
  | RequireIndependentToolchainProbeOracle
  | RequireCompleteRepresentativeProbeControls
  | RequireToolchainProbePairedNegatives
  | RequireAppliedToolchainPolicyMutants
  | RequireExactDependencyAndProbeDiscovery
  | RequirePostStartProbeChallenge
  | RequireProcessExitStdoutAndDigestObservation
  | RequireNoNetworkHardwareOrAuthBypass
  | RequireTwoFreshBuildRootsAndStableSource
  | RequireQualifiedToolchainHarness
  | RequireRunScopedGeneratedProductsAndCleanup
  | RequirePhaseOneLegacyFamiliesClosed
  | RequireExactPhaseZeroReceipt
  | RequireGenesisAssumptionAndLaterClaimsExplicit
  | RequireQualifiedPhaseOneGatePass
  deriving (Eq, Ord, Show)

-- | Phase 2 binds repository-layout closure to an authenticated compiler run
-- and four independently challenged legacy predicates.
data PhaseTwoRequirement
  = RequireCompilerBackedRepositoryLayoutClosure
  | RequireAcquiredRepositoryLayoutSupervisor
  | RequireDirectOfflineSerialRepositoryBuild
  | RequireIndependentRepositoryLayoutOracle
  | RequireCleanRepositoryLayoutControls
  | RequireRepositoryLayoutPairedNegatives
  | RequireAppliedRepositoryLayoutMutants
  | RequireTwoWaySourceAndComponentDiscovery
  | RequirePostStartRepositoryChallenge
  | RequireCompilerProcessAndGraphObservation
  | RequireNoPbNetworkHardwareOrAmbientBypass
  | RequireOpeningClosingSourceAndFreshBuildRoot
  | RequireQualifiedRepositoryLayoutHarness
  | RequireGeneratedProductsContainedBelowBuild
  | RequirePhaseTwoLegacyFamiliesClosed
  | RequireExactPhaseOneReceipt
  | RequireOnlyTypedLaterSourceDebt
  | RequireQualifiedPhaseTwoGatePass
  deriving (Eq, Ord, Show)

-- | Phase 3 binds the pure artifact calculus to an independently compiled
-- oracle, paired compile-negative lifetime control, and three applied
-- changed-production subjects.
data PhaseThreeRequirement
  = RequireCompleteArtifactCalculus
  | RequireAcquiredArtifactCalculusSupervisor
  | RequireDirectSerialArtifactCompilerMatrix
  | RequireIndependentArtifactCalculusOracle
  | RequireArtifactCalculusPositiveControls
  | RequireArtifactCalculusPairedNegatives
  | RequireAppliedArtifactCalculusMutants
  | RequireExactArtifactCalculusDiscovery
  | RequirePostAcquisitionArtifactChallenge
  | RequireArtifactProcessObservation
  | RequireNoPbNetworkHardwareOrCompilerParallelism
  | RequireFreshArtifactBuildRootsAndStableSource
  | RequireQualifiedArtifactCalculusHarness
  | RequireArtifactProductsContainedBelowBuild
  | RequireNoPhaseThreeLegacyDebt
  | RequireExactPhaseTwoReceipt
  | RequireLaterArtifactConsumersExplicit
  | RequireQualifiedPhaseThreeGatePass
  deriving (Eq, Ord, Show)

data PhaseFourRequirement
  = RequireCompleteBudgetCalculus
  | RequireAcquiredBudgetCalculusSupervisor
  | RequireDirectSerialBudgetCompilerMatrix
  | RequireIndependentBudgetCalculusOracle
  | RequireBudgetCalculusPositiveControls
  | RequireBudgetCalculusPairedNegatives
  | RequireAppliedBudgetCalculusMutants
  | RequireExactBudgetCalculusDiscovery
  | RequirePostAcquisitionBudgetChallenge
  | RequireBudgetProcessObservation
  | RequireNoPbNetworkHardwareOrBudgetCompilerParallelism
  | RequireFreshBudgetBuildRootsAndStableSource
  | RequireQualifiedBudgetCalculusHarness
  | RequireBudgetProductsContainedBelowBuild
  | RequireNoPhaseFourLegacyDebt
  | RequireExactPhaseThreeReceipt
  | RequireLaterBudgetConsumersExplicit
  | RequireQualifiedPhaseFourGatePass
  deriving (Eq, Ord, Show)

data PhaseFiveRequirement
  = RequireCompleteLiftCalculus
  | RequireAcquiredLiftCalculusSupervisor
  | RequireDirectSerialLiftCompilerMatrix
  | RequireIndependentLiftCalculusOracle
  | RequireLiftCalculusPositiveControls
  | RequireLiftCalculusPairedNegatives
  | RequireAppliedLiftCalculusMutants
  | RequireExactLiftCalculusDiscovery
  | RequirePostAcquisitionLiftChallenge
  | RequireLiftProcessObservation
  | RequireNoPbNetworkHardwareOrLiftCompilerParallelism
  | RequireFreshLiftBuildRootsAndStableSource
  | RequireQualifiedLiftCalculusHarness
  | RequireLiftProductsContainedBelowBuild
  | RequireNoPhaseFiveLegacyDebt
  | RequireExactPhaseFourReceipt
  | RequireLaterLiftConsumersExplicit
  | RequireQualifiedPhaseFiveGatePass
  deriving (Eq, Ord, Show)

data PhaseSixRequirement
  = RequireCompleteWorkflowCalculus
  | RequireAcquiredWorkflowCalculusSupervisor
  | RequireDirectSerialWorkflowCompilerMatrix
  | RequireIndependentWorkflowCalculusOracle
  | RequireWorkflowCalculusPositiveControls
  | RequireWorkflowCalculusPairedNegatives
  | RequireAppliedWorkflowCalculusMutants
  | RequireExactWorkflowCalculusDiscovery
  | RequirePostAcquisitionWorkflowChallenge
  | RequireWorkflowProcessObservation
  | RequireNoPbNetworkHardwareOrWorkflowCompilerParallelism
  | RequireFreshWorkflowBuildRootsAndStableSource
  | RequireQualifiedWorkflowCalculusHarness
  | RequireWorkflowProductsContainedBelowBuild
  | RequireNoPhaseSixLegacyDebt
  | RequireExactPhaseFiveReceipt
  | RequireLaterWorkflowConsumersExplicit
  | RequireQualifiedPhaseSixGatePass
  deriving (Eq, Ord, Show)

data PhaseSevenRequirement
  = RequireCompleteEvidenceCalculus
  | RequireAcquiredEvidenceCalculusSupervisor
  | RequireDirectSerialEvidenceCompilerMatrix
  | RequireIndependentEvidenceCalculusOracle
  | RequireEvidenceCalculusPositiveControls
  | RequireEvidenceCalculusPairedNegatives
  | RequireAppliedEvidenceCalculusMutants
  | RequireExactEvidenceCalculusDiscovery
  | RequirePostAcquisitionEvidenceChallenge
  | RequireEvidenceProcessObservation
  | RequireNoPbNetworkHardwareOrEvidenceCompilerParallelism
  | RequireFreshEvidenceBuildRootsAndStableSource
  | RequireQualifiedEvidenceCalculusHarness
  | RequireEvidenceProductsContainedBelowBuild
  | RequireNoPhaseSevenLegacyDebt
  | RequireExactPhaseSixReceipt
  | RequireLaterEvidenceConsumersExplicit
  | RequireQualifiedPhaseSevenGatePass
  deriving (Eq, Ord, Show)

data PhaseEightRequirement
  = RequireCompleteScopedIdentityKernel
  | RequireAcquiredScopeIndexSupervisor
  | RequireDirectSerialScopeCompilerMatrix
  | RequireIndependentScopeIndexOracle
  | RequireScopeIndexPositiveControls
  | RequireScopeIndexPairedNegatives
  | RequireAppliedScopeIndexMutants
  | RequireExactScopeIndexDiscovery
  | RequirePostAcquisitionScopeChallenge
  | RequireScopeProcessObservation
  | RequireNoPbNetworkHardwareOrScopeCompilerParallelism
  | RequireFreshScopeBuildRootsAndStableSource
  | RequireQualifiedScopeIndexHarness
  | RequireScopeProductsContainedBelowBuild
  | RequireNoPhaseEightLegacyDebt
  | RequireExactPhaseSevenReceipt
  | RequireLaterScopeConsumersExplicit
  | RequireQualifiedPhaseEightGatePass
  deriving (Eq, Ord, Show)

data PhaseNineRequirement
  = RequireCompleteResourceIndex
  | RequireAcquiredResourceIndexSupervisor
  | RequireDirectSerialResourceCompilerMatrix
  | RequireIndependentResourceIndexOracle
  | RequireResourceIndexPositiveControls
  | RequireResourceIndexPairedNegatives
  | RequireAppliedResourceIndexMutants
  | RequireExactResourceIndexDiscovery
  | RequirePostAcquisitionResourceChallenge
  | RequireResourceProcessObservation
  | RequireNoPbNetworkHardwareOrResourceCompilerParallelism
  | RequireFreshResourceBuildRootsAndStableSource
  | RequireQualifiedResourceIndexHarness
  | RequireResourceProductsContainedBelowBuild
  | RequireNoPhaseNineLegacyDebt
  | RequireExactPhaseEightReceipt
  | RequireLaterResourceConsumersExplicit
  | RequireQualifiedPhaseNineGatePass
  deriving (Eq, Ord, Show)

data PhaseTenRequirement
  = RequireCompleteCalculusComposition
  | RequireAcquiredCalculusCompositionSupervisor
  | RequireDirectSerialCompositionCompilerMatrix
  | RequireIndependentCalculusCompositionOracle
  | RequireCalculusCompositionPositiveControls
  | RequireCalculusCompositionPairedNegatives
  | RequireAppliedCalculusCompositionMutants
  | RequireExactCalculusCompositionDiscovery
  | RequirePostAcquisitionCompositionChallenge
  | RequireCompositionProcessObservation
  | RequireNoPbNetworkHardwareOrCompositionCompilerParallelism
  | RequireFreshCompositionBuildRootsAndStableSource
  | RequireQualifiedCalculusCompositionHarness
  | RequireCompositionProductsContainedBelowBuild
  | RequireNoPhaseTenLegacyDebt
  | RequireExactPhaseNineReceipt
  | RequireLaterCompositionConsumersExplicit
  | RequireQualifiedPhaseTenGatePass
  deriving (Eq, Ord, Show)

data PhaseElevenRequirement
  = RequireCompleteFormalModelKernel
  | RequireAcquiredFormalModelKernelSupervisor
  | RequireDirectSerialFormalModelCompilerMatrix
  | RequireIndependentFormalModelSemanticOracle
  | RequireFormalModelPositiveControls
  | RequireFormalModelPairedNegatives
  | RequireAppliedFormalModelProductionMutants
  | RequireExactFormalModelSourceDiscovery
  | RequirePostAcquisitionFormalModelChallenge
  | RequireFormalModelProcessObservation
  | RequireNoPbNetworkJvmHardwareOrFormalModelCompilerParallelism
  | RequireFreshFormalModelBuildRootsAndStableSource
  | RequireQualifiedFormalModelHarness
  | RequireFormalModelProductsContainedBelowBuild
  | RequireRetiredFormalModelBehavioralSourcesAbsent
  | RequireExactPhaseTenReceipt
  | RequireLaterCheckerAndRuntimeClaimsExplicit
  | RequireQualifiedPhaseElevenGatePass
  deriving (Eq, Ord, Show)

data PhaseTwelveRequirement
  = RequireCompleteExplicitStateChecker
  | RequireAcquiredExplicitStateCheckerSupervisor
  | RequireDirectSerialExplicitStateCompilerMatrix
  | RequireIndependentExplicitStateSemanticOracle
  | RequireExplicitStatePositiveControls
  | RequireExplicitStatePairedNegatives
  | RequireAppliedExplicitStateProductionMutants
  | RequireExactExplicitStateSourceDiscovery
  | RequirePostAcquisitionExplicitStateChallenge
  | RequireExplicitStateProcessObservation
  | RequireNoPbNetworkJvmHardwareOrExplicitStateCompilerParallelism
  | RequireFreshExplicitStateBuildRootsAndStableSource
  | RequireQualifiedExplicitStateHarness
  | RequireExplicitStateProductsContainedBelowBuild
  | RequireRetiredExplicitStateBehavioralSourcesAbsent
  | RequireExactPhaseElevenReceipt
  | RequireLaterCheckerSimulationAndRuntimeClaimsExplicit
  | RequireQualifiedPhaseTwelveGatePass
  deriving (Eq, Ord, Show)

data PhaseThirteenRequirement
  = RequireCompleteSymbolicChecker
  | RequireAcquiredSymbolicCheckerSupervisor
  | RequireDirectSerialSymbolicCompilerMatrix
  | RequireIndependentSymbolicSemanticOracle
  | RequireSymbolicPositiveControls
  | RequireSymbolicPairedNegatives
  | RequireAppliedSymbolicProductionMutants
  | RequireExactSymbolicSourceDiscovery
  | RequirePostAcquisitionSymbolicChallenge
  | RequireSymbolicProcessObservation
  | RequireNoPbNetworkHostHardwareOrSymbolicCompilerParallelism
  | RequireFreshSymbolicBuildRootsAndStableSource
  | RequireQualifiedSymbolicHarness
  | RequireSymbolicProductsContainedBelowBuild
  | RequireRetiredSymbolicBehavioralSourcesAbsent
  | RequireExactPhaseTwelveReceipt
  | RequireLaterRefinementSimulationAndRuntimeClaimsExplicit
  | RequireQualifiedPhaseThirteenGatePass
  deriving (Eq, Ord, Show)

data PhaseFourteenRequirement
  = RequireCompleteRefinementChecker
  | RequireAcquiredRefinementCheckerSupervisor
  | RequireDirectSerialRefinementCompilerMatrix
  | RequireIndependentRefinementSemanticOracle
  | RequireRefinementPositiveControls
  | RequireRefinementPairedNegatives
  | RequireAppliedRefinementProductionMutants
  | RequireExactRefinementSourceDiscovery
  | RequirePostAcquisitionRefinementChallenge
  | RequireRefinementProcessObservation
  | RequireNoPbNetworkHostHardwareOrRefinementCompilerParallelism
  | RequireFreshRefinementBuildRootsAndStableSource
  | RequireQualifiedRefinementHarness
  | RequireRefinementProductsContainedBelowBuild
  | RequireRetiredRefinementBehavioralSourcesAbsent
  | RequireExactPhaseThirteenReceipt
  | RequireLaterCompileFailSimulationAndRuntimeClaimsExplicit
  | RequireQualifiedPhaseFourteenGatePass
  deriving (Eq, Ord, Show)

data PhaseFifteenRequirement
  = RequireCompleteCompileFailHarness
  | RequireAcquiredCompileFailHarnessSupervisor
  | RequireDirectSerialCompileFailCompilerMatrix
  | RequireIndependentCompileFailCorpusOracle
  | RequireCompileFailLegalTwinControls
  | RequireCompileFailPinnedIllegalTwins
  | RequireAppliedCompileFailProductionMutants
  | RequireExactCompileFailSourceDiscovery
  | RequirePostAcquisitionCompileFailChallenge
  | RequireCompileFailProcessObservation
  | RequireNoPbNetworkHostHardwareOrCompileFailParallelism
  | RequireFreshCompileFailBuildRootsAndStableSource
  | RequireQualifiedCompileFailHarness
  | RequireCompileFailProductsContainedBelowBuild
  | RequireRetiredCompileFailBehavioralSourcesAbsent
  | RequireExactPhaseFourteenReceipt
  | RequireLaterSimulationAndRuntimeClaimsExplicit
  | RequireQualifiedPhaseFifteenGatePass
  deriving (Eq, Ord, Show)

data PhaseSixteenRequirement
  = RequireCompleteDeterministicSimulationSubstrate
  | RequireAcquiredDeterministicSimulationSupervisor
  | RequireDirectOfflineSerialSimulationMatrix
  | RequireIndependentDeterministicSimulationOracle
  | RequireTwoInterpreterSimulationControls
  | RequireFaultKnobAndSchedulePairedNegatives
  | RequireAppliedDeterministicSimulationProductionMutants
  | RequireExactDeterministicSimulationSourceDiscovery
  | RequirePostAcquisitionDeterministicSimulationChallenge
  | RequireDeterministicSimulationProcessObservation
  | RequireNoPbNetworkHostHardwareOrSimulationParallelism
  | RequireFreshSimulationBuildRootAndStableSource
  | RequireQualifiedDeterministicSimulationHarness
  | RequireSimulationProductsContainedBelowBuild
  | RequireRetiredSimulationBehavioralSourcesAbsent
  | RequireExactPhaseFifteenReceipt
  | RequireLaterModelsRuntimesAndHardwareExplicit
  | RequireQualifiedPhaseSixteenGatePass
  deriving (Eq, Ord, Show)

data PhaseSeventeenRequirement
  = RequireCompleteGatewayMigrationModel
  | RequireAcquiredGatewayMigrationModelSupervisor
  | RequireDirectOfflineSerialGatewayModelMatrix
  | RequireIndependentGatewayMigrationOracle
  | RequireGatewayExplorerTlcAndScheduleControls
  | RequireGatewayInvariantFairnessAndCutoffNegatives
  | RequireAppliedGatewayMigrationProductionMutants
  | RequireExactGatewayMigrationSourceDiscovery
  | RequirePostAcquisitionGatewayMigrationChallenge
  | RequireGatewayMigrationProcessObservation
  | RequireNoPbNetworkHostHardwareOrGatewayParallelism
  | RequireFreshGatewayBuildRootAndStableSource
  | RequireQualifiedGatewayMigrationHarness
  | RequireGatewayProductsContainedBelowBuild
  | RequireRetiredGatewayBehavioralSourcesAbsent
  | RequireExactPhaseSixteenReceipt
  | RequireGatewayRuntimeFidelityAndDecompositionExplicit
  | RequireQualifiedPhaseSeventeenGatePass
  deriving (Eq, Ord, Show)

data PhaseEighteenRequirement
  = RequireCompleteDslFormalModel
  | RequireAcquiredDslFormalModelSupervisor
  | RequireDirectOfflineSerialDslFormalMatrix
  | RequireIndependentDslFormalOracle
  | RequireDslModelCapacityCalculusAndProtocolControls
  | RequireDslSafetyFairnessAndDecisionNegatives
  | RequireAppliedDslFormalProductionMutants
  | RequireExactDslFormalSourceDiscovery
  | RequirePostAcquisitionDslFormalChallenge
  | RequireDslFormalProcessObservation
  | RequireNoPbNetworkHostHardwareOrDslFormalParallelism
  | RequireFreshDslFormalBuildRootAndStableSource
  | RequireQualifiedDslFormalHarness
  | RequireDslFormalProductsContainedBelowBuild
  | RequireRetiredDslFormalBehavioralSourcesAbsent
  | RequireExactPhaseSeventeenReceipt
  | RequireLaterDslRuntimeAndProjectionOwnersExplicit
  | RequireQualifiedPhaseEighteenGatePass
  deriving (Eq, Ord, Show)

data PhaseNineteenRequirement
  = RequireCompleteReconcileCoreSimulation
  | RequireAcquiredReconcileCoreSupervisor
  | RequireDirectOfflineSerialReconcileCoreMatrix
  | RequireIndependentReconcileCoreOracle
  | RequireReconcileCoreScheduleProtocolAndFormalControls
  | RequireReconcileCorePairedNegatives
  | RequireAppliedReconcileCoreProductionMutants
  | RequireExactReconcileCoreSourceDiscovery
  | RequirePostAcquisitionReconcileCoreChallenge
  | RequireReconcileCoreProcessObservation
  | RequireNoPbNetworkHostHardwareOrReconcileCoreParallelism
  | RequireFreshReconcileCoreBuildRootAndStableSource
  | RequireQualifiedReconcileCoreHarness
  | RequireReconcileCoreProductsContainedBelowBuild
  | RequireRetiredReconcileCoreBehavioralSourcesAbsent
  | RequireExactPhaseEighteenReceipt
  | RequireLaterEffectfulReconcileRuntimeExplicit
  | RequireQualifiedPhaseNineteenGatePass
  deriving (Eq, Ord, Show)

data PhaseTwentyRequirement
  = RequireCompleteIndexedExtensionDeclaration
  | RequireAcquiredExtensionDeclarationSupervisor
  | RequireDirectOfflineSerialExtensionDeclarationMatrix
  | RequireIndependentExtensionDeclarationOracle
  | RequireDeclarationReaderResourceAndDigestControls
  | RequireDeclarationSemanticAndCompileNegatives
  | RequireAppliedExtensionDeclarationProductionMutants
  | RequireExactExtensionDeclarationSourceDiscovery
  | RequirePostAcquisitionExtensionDeclarationChallenge
  | RequireExtensionDeclarationProcessObservation
  | RequireNoPbNetworkHostHardwareOrExtensionDeclarationParallelism
  | RequireFreshExtensionDeclarationBuildRootAndStableSource
  | RequireQualifiedExtensionDeclarationHarness
  | RequireExtensionDeclarationProductsContainedBelowBuild
  | RequireRetiredExtensionDeclarationBehavioralSourcesAbsent
  | RequireExactPhaseNineteenReceipt
  | RequireLaterExtensionLawAndRuntimeOwnersExplicit
  | RequireQualifiedPhaseTwentyGatePass
  deriving (Eq, Ord, Show)

data PhaseTwentyOneRequirement
  = RequireCompletePerExtensionLawEvaluator
  | RequireAcquiredExtensionLawsSupervisor
  | RequireDirectOfflineSerialExtensionLawsMatrix
  | RequireIndependentExtensionLawsOracle
  | RequireLawfulOperationRenderBudgetAndEvidenceControls
  | RequireSingleLawAndClaimCompileNegatives
  | RequireAppliedExtensionLawsProductionMutants
  | RequireExactExtensionLawsSourceDiscovery
  | RequirePostAcquisitionExtensionLawsChallenge
  | RequireExtensionLawsProcessObservation
  | RequireNoPbNetworkHostHardwareOrExtensionLawsParallelism
  | RequireFreshExtensionLawsBuildRootAndStableSource
  | RequireQualifiedExtensionLawsHarness
  | RequireExtensionLawsProductsContainedBelowBuild
  | RequireRetiredExtensionLawsBehavioralSourcesAbsent
  | RequireExactPhaseTwentyReceipt
  | RequireLaterCompositionalSecurityConformanceAndRuntimeOwnersExplicit
  | RequireQualifiedPhaseTwentyOneGatePass
  deriving (Eq, Ord, Show)

data PhaseTwentyTwoRequirement
  = RequireCompleteNormalizedCompositeAndC1C7Evaluator
  | RequireAcquiredExtensionCompositionSupervisor
  | RequireDirectOfflineSerialExtensionCompositionMatrix
  | RequireIndependentExtensionCompositionOracle
  | RequireLawfulCompositionIdentityAssociationBudgetAndAddressControls
  | RequireCompositionLawAndRequestScopeNegatives
  | RequireAppliedExtensionCompositionProductionMutants
  | RequireExactExtensionCompositionSourceDiscovery
  | RequirePostAcquisitionExtensionCompositionChallenge
  | RequireExtensionCompositionProcessObservation
  | RequireNoPbNetworkHostHardwareOrExtensionCompositionParallelism
  | RequireFreshExtensionCompositionBuildRootAndStableSource
  | RequireQualifiedExtensionCompositionHarness
  | RequireExtensionCompositionProductsContainedBelowBuild
  | RequireRetiredExtensionCompositionBehavioralSourcesAbsent
  | RequireExactPhaseTwentyOneReceipt
  | RequireLaterSecurityConformanceProofAndRuntimeOwnersExplicit
  | RequireQualifiedPhaseTwentyTwoGatePass
  deriving (Eq, Ord, Show)

data PhaseTwentyThreeRequirement
  = RequireBoundedTypedSecurityKernelAndS1S6Evaluator
  | RequireAcquiredExtensionSecuritySupervisor
  | RequireDirectOfflineSerialExtensionSecurityMatrix
  | RequireIndependentExtensionSecurityOracle
  | RequireIdentityOperationRefusalNamespaceAndPolicyControls
  | RequireSecurityLawAndFourCompilerBarrierNegatives
  | RequireAppliedExtensionSecurityProductionMutants
  | RequireExactExtensionSecuritySourceDiscovery
  | RequirePostAcquisitionExtensionSecurityChallenge
  | RequireExtensionSecurityProcessObservation
  | RequireNoPbNetworkHostHardwareOrExtensionSecurityParallelism
  | RequireFreshExtensionSecurityBuildRootAndStableSource
  | RequireQualifiedExtensionSecurityHarness
  | RequireExtensionSecurityProductsContainedBelowBuild
  | RequireRetiredExtensionSecurityBehavioralSourcesAbsent
  | RequireExactPhaseTwentyTwoReceipt
  | RequireLaterSecurityClosureConformanceCryptoTimingAndRuntimeOwnersExplicit
  | RequireQualifiedPhaseTwentyThreeGatePass
  deriving (Eq, Ord, Show)

data PhaseTwentyFourRequirement
  = RequireDeclarationDerivedConformancePlanVerdictAndAdmission
  | RequireAcquiredConformanceGateSupervisor
  | RequireDirectOfflineSerialConformanceGateMatrix
  | RequireIndependentConformanceGateOracle
  | RequireSuiteCoverageVerdictAndAdmissionControls
  | RequireConformanceRefusalAndCompilerBarrierNegatives
  | RequireAppliedConformanceGateProductionMutants
  | RequireExactConformanceGateSourceDiscovery
  | RequirePostAcquisitionConformanceGateChallenge
  | RequireConformanceGateProcessObservation
  | RequireNoPbNetworkHostHardwareOrConformanceGateParallelism
  | RequireFreshConformanceGateBuildRootAndStableSource
  | RequireQualifiedConformanceGateHarness
  | RequireConformanceGateProductsContainedBelowBuild
  | RequireRetiredConformanceGateBehavioralSourcesAbsent
  | RequireExactPhaseTwentyThreeReceipt
  | RequireLaterTransactionObserverSemanticClosureAndRuntimeOwnersExplicit
  | RequireQualifiedPhaseTwentyFourGatePass
  deriving (Eq, Ord, Show)

data PhaseTwentyFiveRequirement
  = RequireHaskellDerivedDhallStructuralLanguage
  | RequireAcquiredDhallSchemaSupervisor
  | RequireDirectOfflineSerialDhallSchemaMatrix
  | RequireIndependentDhallSchemaOracle
  | RequireSchemaModuleAndPositiveTypecheckControls
  | RequirePairedDhallStructuralAndImportNegatives
  | RequireAppliedDhallSchemaProductionMutants
  | RequireExactDhallSchemaSourceDiscovery
  | RequirePostAcquisitionDhallSchemaChallenge
  | RequireDhallSchemaProcessObservation
  | RequireNoPbNetworkHostHardwareOrDhallSchemaParallelism
  | RequireFreshDhallSchemaBuildRootAndStableSource
  | RequireQualifiedDhallSchemaHarness
  | RequireDhallSchemaProductsContainedBelowBuild
  | RequireRetiredDhallBehavioralSourcesAbsent
  | RequireExactPhaseTwentyFourReceipt
  | RequireLaterBindingDecodeProvisionRuntimeOwnersExplicit
  | RequireQualifiedPhaseTwentyFiveGatePass
  deriving (Eq, Ord, Show)

data PhaseTwentySixRequirement
  = RequireHaskellProtocolAndIndexedDecodeBoundary
  | RequireAcquiredGadtDecodeSupervisor
  | RequireDirectOfflineSerialGadtDecodeMatrix
  | RequireIndependentGadtDecodeOracle
  | RequireControllerIndexedPositiveDecodeControls
  | RequirePairedGadtDecodeNegatives
  | RequireAppliedGadtDecodeProductionMutants
  | RequireExactGadtDecodeSourceDiscovery
  | RequirePostAcquisitionGadtDecodeChallenge
  | RequireGadtDecodeProcessObservation
  | RequireNoPbNetworkHostHardwareOrGadtDecodeParallelism
  | RequireFreshGadtDecodeBuildRootAndStableSource
  | RequireQualifiedGadtDecodeHarness
  | RequireGadtDecodeProductsContainedBelowBuild
  | RequireRetiredProtoAndGadtDecodeAuthoritiesAbsent
  | RequireExactPhaseTwentyFiveReceipt
  | RequireLaterCapacityBindingProvisionRuntimeOwnersExplicit
  | RequireQualifiedPhaseTwentySixGatePass
  deriving (Eq, Ord, Show)

data PhaseTwentySevenRequirement
  = RequireClosedHaskellIllegalStateCoverageLedger
  | RequireAcquiredIllegalStateCoveringSupervisor
  | RequireDirectOfflineSerialIllegalStateCoveringMatrix
  | RequireIndependentIllegalStateCoveringOracle
  | RequireDhallDecodeCompileAndPropertyPositiveControls
  | RequirePairedIllegalStateForeclosureNegatives
  | RequireAppliedIllegalStateCoveringProductionMutants
  | RequireExactIllegalStateCoveringSourceDiscovery
  | RequirePostAcquisitionIllegalStateCoveringChallenge
  | RequireIllegalStateCoveringProcessObservation
  | RequireNoPbNetworkHostHardwareOrIllegalStateParallelism
  | RequireFreshIllegalStateBuildRootAndStableSource
  | RequireQualifiedIllegalStateCoveringHarness
  | RequireIllegalStateProductsContainedBelowBuild
  | RequireRetiredBehavioralDocumentAuthoritiesAbsent
  | RequireExactPhaseTwentySixReceipt
  | RequireLaterProvisionRenderRuntimeOwnersExplicit
  | RequireQualifiedPhaseTwentySevenGatePass
  deriving (Eq, Ord, Show)

data PhaseTwentyEightRequirement
  = RequirePureStorageGeometryFoldBoundary
  | RequireAcquiredStorageGeometrySupervisor
  | RequireDirectOfflineSerialStorageGeometryMatrix
  | RequireIndependentStorageGeometryOracle
  | RequireStorageGeometryPositiveControls
  | RequirePairedStorageGeometryNegatives
  | RequireAppliedStorageGeometryProductionMutants
  | RequireExactStorageGeometrySourceDiscovery
  | RequirePostAcquisitionStorageGeometryChallenge
  | RequireStorageGeometryProcessObservation
  | RequireNoPbNetworkHostHardwareOrStorageParallelism
  | RequireFreshStorageGeometryBuildRootAndStableSource
  | RequireQualifiedStorageGeometryHarness
  | RequireStorageGeometryProductsContainedBelowBuild
  | RequireRetiredStorageGeometryAuthoritiesAbsent
  | RequireExactPhaseTwentySevenReceipt
  | RequireLaterBindingProvisionRuntimeStorageOwnersExplicit
  | RequireQualifiedPhaseTwentyEightGatePass
  deriving (Eq, Ord, Show)

data PhaseTwentyNineRequirement
  = RequirePureExecutionAcceleratorFoldBoundary
  | RequireAcquiredExecutionAcceleratorSupervisor
  | RequireDirectOfflineSerialExecutionAcceleratorMatrix
  | RequireIndependentExecutionAcceleratorOracle
  | RequireExecutionAcceleratorPositiveControls
  | RequirePairedExecutionAcceleratorNegatives
  | RequireAppliedExecutionAcceleratorProductionMutants
  | RequireExactExecutionAcceleratorSourceDiscovery
  | RequirePostAcquisitionExecutionAcceleratorChallenge
  | RequireExecutionAcceleratorProcessObservation
  | RequireNoPbNetworkHostHardwareOrExecutionParallelism
  | RequireFreshExecutionAcceleratorBuildRootAndStableSource
  | RequireQualifiedExecutionAcceleratorHarness
  | RequireExecutionAcceleratorProductsContainedBelowBuild
  | RequireRetiredExecutionAcceleratorAuthoritiesAbsent
  | RequireExactPhaseTwentyEightReceipt
  | RequireLaterBindingProvisionRuntimeExecutionOwnersExplicit
  | RequireQualifiedPhaseTwentyNineGatePass
  deriving (Eq, Ord, Show)

data PhaseThirtyRequirement
  = RequirePureCapabilityBindBoundary
  | RequireAcquiredCapabilityBindSupervisor
  | RequireDirectOfflineSerialCapabilityBindMatrix
  | RequireIndependentCapabilityBindOracle
  | RequireCapabilityBindPositiveControls
  | RequirePairedCapabilityBindNegatives
  | RequireAppliedCapabilityBindProductionMutants
  | RequireExactCapabilityBindSourceDiscovery
  | RequirePostAcquisitionCapabilityBindChallenge
  | RequireCapabilityBindProcessObservation
  | RequireNoPbNetworkHostHardwareOrCapabilityBindParallelism
  | RequireFreshCapabilityBindBuildRootAndStableSource
  | RequireQualifiedCapabilityBindHarness
  | RequireCapabilityBindProductsContainedBelowBuild
  | RequireRetiredCapabilityBindAuthoritiesAbsent
  | RequireExactPhaseTwentyNineReceipt
  | RequireLaterProvisionRenderRuntimeCapabilityOwnersExplicit
  | RequireQualifiedPhaseThirtyGatePass
  deriving (Eq, Ord, Show)

data PhaseThirtyOneRequirement
  = RequireCompleteProvisionSealBoundary
  | RequireAcquiredProvisionSealSupervisor
  | RequireDirectOfflineSerialProvisionSealMatrix
  | RequireIndependentProvisionSealOracle
  | RequireProvisionSealPositiveControls
  | RequirePairedProvisionSealNegatives
  | RequireAppliedProvisionSealProductionMutants
  | RequireExactProvisionSealSourceDiscovery
  | RequirePostAcquisitionProvisionSealChallenge
  | RequireProvisionSealProcessObservation
  | RequireNoPbNetworkHostHardwareOrProvisionSealParallelism
  | RequireFreshProvisionSealBuildRootAndStableSource
  | RequireQualifiedProvisionSealHarness
  | RequireProvisionSealProductsContainedBelowBuild
  | RequireRetiredProvisionSealAuthoritiesAbsent
  | RequireExactPhaseThirtyReceipt
  | RequireLaterRenderRuntimeLiveProvisionOwnersExplicit
  | RequireQualifiedPhaseThirtyOneGatePass
  deriving (Eq, Ord, Show)

data PhaseThirtyTwoRequirement
  = RequireClosedInferenceAcceleratorProvisionBoundary
  | RequireAcquiredInferenceAcceleratorSupervisor
  | RequireDirectOfflineSerialInferenceAcceleratorMatrix
  | RequireIndependentInferenceAcceleratorOracle
  | RequireInferenceAcceleratorPositiveControls
  | RequirePairedInferenceAcceleratorNegatives
  | RequireAppliedInferenceAcceleratorProductionMutants
  | RequireExactInferenceAcceleratorSourceDiscovery
  | RequirePostAcquisitionInferenceAcceleratorChallenge
  | RequireInferenceAcceleratorProcessObservation
  | RequireNoPbNetworkHostHardwareOrInferenceAcceleratorParallelism
  | RequireFreshInferenceAcceleratorBuildRootAndStableSource
  | RequireQualifiedInferenceAcceleratorHarness
  | RequireInferenceAcceleratorProductsContainedBelowBuild
  | RequireRetiredInferenceAcceleratorAuthoritiesAbsent
  | RequireExactPhaseThirtyOneReceipt
  | RequireLaterRenderRuntimeLiveEngineOwnersExplicit
  | RequireQualifiedPhaseThirtyTwoGatePass
  deriving (Eq, Ord, Show)

data PhaseThirtyThreeRequirement
  = RequirePureTotalRenderAllBoundary
  | RequireAcquiredRenderManifestSupervisor
  | RequireDirectOfflineSerialRenderManifestMatrix
  | RequireIndependentRenderManifestOracle
  | RequireRenderManifestPositiveControls
  | RequirePairedRenderManifestNegatives
  | RequireAppliedRenderManifestProductionMutants
  | RequireExactRenderManifestSourceDiscovery
  | RequirePostAcquisitionRenderManifestChallenge
  | RequireRenderManifestProcessObservation
  | RequireNoPbNetworkHostHardwareOrRenderManifestParallelism
  | RequireFreshRenderManifestBuildRootAndStableSource
  | RequireQualifiedRenderManifestHarness
  | RequireRenderManifestProductsContainedBelowBuild
  | RequireRetiredRenderManifestAuthoritiesAbsent
  | RequireExactPhaseThirtyTwoReceipt
  | RequireLaterActionsDryRunRuntimeLiveOwnersExplicit
  | RequireQualifiedPhaseThirtyThreeGatePass
  deriving (Eq, Ord, Show)

data PhaseThirtyFourRequirement
  = RequirePureChainAndFakeBoundary
  | RequireAcquiredChainBoundarySupervisor
  | RequireDirectOfflineSerialChainBoundaryMatrix
  | RequireIndependentChainBoundaryOracle
  | RequireChainBoundaryPositiveControls
  | RequirePairedChainBoundaryNegatives
  | RequireAppliedChainBoundaryProductionMutants
  | RequireExactChainBoundarySourceDiscovery
  | RequirePostAcquisitionChainBoundaryChallenge
  | RequireChainBoundaryProcessObservation
  | RequireNoPbNetworkLiveHostHardwareOrParallelism
  | RequireFreshChainBoundaryBuildRootAndStableSource
  | RequireQualifiedChainBoundaryHarness
  | RequireChainBoundaryProductsContainedBelowBuild
  | RequireRetiredChainBoundaryAuthoritiesAbsent
  | RequireExactPhaseThirtyThreeReceipt
  | RequireLiveInterpreterRuntimeAndHardwareOwnersExplicit
  | RequireQualifiedPhaseThirtyFourGatePass
  deriving (Eq, Ord, Show)

data PhaseThirtyFiveRequirement
  = RequirePureTotalImageRecipeBoundary
  | RequireAcquiredImageRecipeSupervisor
  | RequireDirectOfflineSerialImageRecipeMatrix
  | RequireIndependentImageRecipeOracle
  | RequireImageRecipePositiveControls
  | RequirePairedImageRecipeNegatives
  | RequireAppliedImageRecipeProductionMutants
  | RequireExactImageRecipeSourceDiscovery
  | RequirePostAcquisitionImageRecipeChallenge
  | RequireImageRecipeProcessObservation
  | RequireNoPbNetworkEngineHostHardwareOrParallelism
  | RequireFreshImageRecipeBuildRootAndStableSource
  | RequireQualifiedImageRecipeHarness
  | RequireImageRecipeProductsContainedBelowBuild
  | RequireRetiredImageRecipeAuthoritiesAbsent
  | RequireExactPhaseThirtyFourReceipt
  | RequireLiveResolutionBuildPublicationRuntimeOwnersExplicit
  | RequireQualifiedPhaseThirtyFiveGatePass
  deriving (Eq, Ord, Show)

data PhaseThirtySixRequirement
  = RequirePureClosedTransactionVocabulary
  | RequireAcquiredTransactionVocabularySupervisor
  | RequireDirectOfflineSerialTransactionVocabularyMatrix
  | RequireIndependentTransactionVocabularyOracle
  | RequireTransactionVocabularyPositiveControls
  | RequireTransactionVocabularyCompilerNegatives
  | RequireAppliedTransactionVocabularyProductionMutants
  | RequireExactTransactionVocabularySourceDiscovery
  | RequirePostAcquisitionTransactionVocabularyChallenge
  | RequireTransactionVocabularyProcessObservation
  | RequireNoPbNetworkDatabaseHostHardwareOrParallelism
  | RequireFreshTransactionVocabularyBuildRootAndStableSource
  | RequireQualifiedTransactionVocabularyHarness
  | RequireTransactionVocabularyProductsContainedBelowBuild
  | RequireRetiredTransactionVocabularyAuthoritiesAbsent
  | RequireExactPhaseThirtyFiveReceipt
  | RequireLiveDatabasePolicyRuntimeOwnersExplicit
  | RequireQualifiedPhaseThirtySixGatePass
  deriving (Eq, Ord, Show)

data PhaseThirtySevenRequirement
  = RequirePureBoundedUiProgramSchema
  | RequireAcquiredUiProgramSchemaSupervisor
  | RequireDirectOfflineSerialUiProgramSchemaMatrix
  | RequireIndependentUiProgramSchemaOracle
  | RequireUiProgramSchemaPositiveControls
  | RequireExactUiProgramSchemaNegatives
  | RequireAppliedUiProgramSchemaProductionMutants
  | RequireExactUiProgramSchemaSourceDiscovery
  | RequirePostAcquisitionUiProgramSchemaChallenge
  | RequireUiProgramSchemaProcessObservation
  | RequireNoPbNetworkBrowserHostHardwareOrParallelism
  | RequireFreshUiProgramSchemaBuildRootAndStableSource
  | RequireQualifiedUiProgramSchemaHarness
  | RequireUiProgramSchemaProductsContainedBelowBuild
  | RequireRetiredUiProgramSchemaAuthoritiesAbsent
  | RequireExactPhaseThirtySixReceipt
  | RequireUiRuntimeAndProviderOwnersExplicit
  | RequireQualifiedPhaseThirtySevenGatePass
  deriving (Eq, Ord, Show)

data PhaseThirtyEightRequirement
  = RequirePureSealedUiAuthorizationKernel
  | RequireAcquiredUiAuthorizationSupervisor
  | RequireDirectOfflineSerialUiAuthorizationMatrix
  | RequireIndependentUiAuthorizationOracle
  | RequireUiAuthorizationPositiveControls
  | RequireExactUiAuthorizationPairedNegatives
  | RequireAppliedUiAuthorizationProductionMutants
  | RequireExactUiAuthorizationSourceDiscovery
  | RequirePostAcquisitionUiAuthorizationChallenge
  | RequireUiAuthorizationProcessObservation
  | RequireNoPbNetworkIdentityProviderHostHardwareOrParallelism
  | RequireFreshUiAuthorizationBuildRootAndStableSource
  | RequireQualifiedUiAuthorizationHarness
  | RequireUiAuthorizationProductsContainedBelowBuild
  | RequireRetiredUiAuthorizationAuthoritiesAbsent
  | RequireExactPhaseThirtySevenReceipt
  | RequireUiEffectRuntimeAndProviderOwnersExplicit
  | RequireQualifiedPhaseThirtyEightGatePass
  deriving (Eq, Ord, Show)

data PhaseThirtyNineRequirement
  = RequirePureExactUiEffectBinding
  | RequireAcquiredUiEffectBindingSupervisor
  | RequireDirectOfflineSerialUiEffectBindingMatrix
  | RequireIndependentUiEffectBindingOracle
  | RequireUiEffectBindingPositiveControls
  | RequireExactUiEffectBindingPairedNegatives
  | RequireAppliedUiEffectBindingProductionMutants
  | RequireExactUiEffectBindingSourceDiscovery
  | RequirePostAcquisitionUiEffectBindingChallenge
  | RequireUiEffectBindingProcessObservation
  | RequireNoPbNetworkProviderBrowserHostHardwareOrParallelism
  | RequireFreshUiEffectBindingBuildRootAndStableSource
  | RequireQualifiedUiEffectBindingHarness
  | RequireUiEffectBindingProductsContainedBelowBuild
  | RequireRetiredUiEffectBindingAuthoritiesAbsent
  | RequireExactPhaseThirtyEightReceipt
  | RequireUiPlanRuntimeAndProviderOwnersExplicit
  | RequireQualifiedPhaseThirtyNineGatePass
  deriving (Eq, Ord, Show)

data PhaseFortyRequirement
  = RequirePureDeterministicUiPlanCompiler
  | RequireAcquiredUiPlanCompilerSupervisor
  | RequireDirectOfflineSerialUiPlanCompilerMatrix
  | RequireIndependentUiPlanCompilerOracle
  | RequireUiPlanCompilerPositiveControls
  | RequireExactUiPlanCompilerPairedNegatives
  | RequireAppliedUiPlanCompilerProductionMutants
  | RequireExactUiPlanCompilerSourceDiscovery
  | RequirePostAcquisitionUiPlanCompilerChallenge
  | RequireUiPlanCompilerProcessObservation
  | RequireNoPbNetworkInterpreterProviderHostHardwareOrParallelism
  | RequireFreshUiPlanCompilerBuildRootAndStableSource
  | RequireQualifiedUiPlanCompilerHarness
  | RequireUiPlanCompilerProductsContainedBelowBuild
  | RequireRetiredUiPlanCompilerAuthoritiesAbsent
  | RequireExactPhaseThirtyNineReceipt
  | RequireUiInterpreterOfflineRuntimeAndPublicationOwnersExplicit
  | RequireQualifiedPhaseFortyGatePass
  deriving (Eq, Ord, Show)

data PhaseFortyOneRequirement
  = RequirePureBoundedOfflineContinuityLanguage
  | RequireAcquiredOfflineLanguagePlanSupervisor
  | RequireDirectOfflineSerialOfflineLanguagePlanMatrix
  | RequireIndependentOfflineLanguagePlanOracle
  | RequireOfflineLanguagePlanPositiveControls
  | RequireExactOfflineLanguagePlanPairedNegatives
  | RequireAppliedOfflineLanguagePlanProductionMutants
  | RequireExactOfflineLanguagePlanSourceDiscovery
  | RequirePostAcquisitionOfflineLanguagePlanChallenge
  | RequireOfflineLanguagePlanProcessObservation
  | RequireNoPbNetworkBrowserStorageReplayHostHardwareOrParallelism
  | RequireFreshOfflineLanguagePlanBuildRootAndStableSource
  | RequireQualifiedOfflineLanguagePlanHarness
  | RequireOfflineLanguagePlanProductsContainedBelowBuild
  | RequireRetiredOfflineLanguagePlanAuthoritiesAbsent
  | RequireExactPhaseFortyReceipt
  | RequireBrowserStorageServerReplayAndPublicationOwnersExplicit
  | RequireQualifiedPhaseFortyOneGatePass
  deriving (Eq, Ord, Show)

data PhaseFortyTwoRequirement
  = RequirePureGenericUiBrowserInterpreterSemantics
  | RequireAcquiredUiBrowserInterpreterSupervisor
  | RequireDirectOfflineSerialUiBrowserInterpreterMatrix
  | RequireIndependentUiBrowserInterpreterOracle
  | RequireUiBrowserInterpreterPositiveControls
  | RequireExactUiBrowserInterpreterPairedNegatives
  | RequireAppliedUiBrowserInterpreterProductionMutants
  | RequireExactUiBrowserInterpreterSourceDiscovery
  | RequirePostAcquisitionUiBrowserInterpreterChallenge
  | RequireUiBrowserInterpreterProcessObservation
  | RequireNoPbBrowserNodePythonNetworkHostHardwareOrParallelism
  | RequireFreshUiBrowserInterpreterBuildRootAndStableSource
  | RequireQualifiedUiBrowserInterpreterHarness
  | RequireUiBrowserInterpreterProductsContainedBelowBuild
  | RequireRetiredUiBrowserInterpreterAuthoritiesAbsent
  | RequireExactPhaseFortyOneReceipt
  | RequireLiveBrowserServerProviderReleaseAndHaOwnersExplicit
  | RequireQualifiedPhaseFortyTwoGatePass
  deriving (Eq, Ord, Show)

data PhaseFortyThreeRequirement
  = RequireAuthenticatedScopedUiServerBoundary
  | RequireAcquiredUiServerBoundarySupervisor
  | RequireDirectOfflineSerialUiServerBoundaryMatrix
  | RequireIndependentUiServerBoundaryOracle
  | RequireUiServerBoundaryPositiveControls
  | RequireExactUiServerBoundaryPairedNegatives
  | RequireAppliedUiServerBoundaryProductionMutants
  | RequireExactUiServerBoundarySourceDiscovery
  | RequirePostAcquisitionUiServerBoundaryChallenge
  | RequireUiServerBoundaryProcessObservation
  | RequireNoPbNodeNetworkLiveIdentityProviderHostHardwareOrParallelism
  | RequireFreshUiServerBoundaryBuildRootAndStableSource
  | RequireQualifiedUiServerBoundaryHarness
  | RequireUiServerBoundaryProductsContainedBelowBuild
  | RequireRetiredUiServerBoundaryAuthoritiesAbsent
  | RequireExactPhaseFortyTwoReceipt
  | RequireLiveIdentityProviderBrowserDeploymentAndHaOwnersExplicit
  | RequireQualifiedPhaseFortyThreeGatePass
  deriving (Eq, Ord, Show)

data PhaseFortyFourRequirement
  = RequireHardwareFreeHaskellUiComposition
  | RequireAcquiredUiLocalCompositionSupervisor
  | RequireDirectOfflineSerialUiLocalCompositionMatrix
  | RequireIndependentUiLocalCompositionOracle
  | RequireUiLocalCompositionPositiveControls
  | RequireExactUiLocalCompositionPairedNegatives
  | RequireAppliedUiLocalCompositionProductionMutants
  | RequireExactUiLocalCompositionSourceDiscovery
  | RequirePostAcquisitionUiLocalCompositionChallenge
  | RequireUiLocalCompositionProcessObservation
  | RequireNoPbNodeDhallNetworkLiveProviderHostHardwareOrParallelism
  | RequireFreshUiLocalCompositionBuildRootAndStableSource
  | RequireQualifiedUiLocalCompositionHarness
  | RequireUiLocalCompositionProductsContainedBelowBuild
  | RequireRetiredUiLocalCompositionAuthoritiesAbsent
  | RequireExactPhaseFortyThreeReceipt
  | RequireLiveWorkflowProviderBrowserDeploymentReleaseAndHaOwnersExplicit
  | RequireQualifiedPhaseFortyFourGatePass
  deriving (Eq, Ord, Show)

data PhaseFortyFiveRequirement
  = RequireHaskellEncryptedOfflineStateAndRuntimeProjection
  | RequireAcquiredEncryptedBrowserRuntimeSupervisor
  | RequireDirectOfflineSerialEncryptedBrowserRuntimeMatrix
  | RequireIndependentEncryptedBrowserRuntimeOracle
  | RequireEncryptedBrowserRuntimePositiveControls
  | RequireExactEncryptedBrowserRuntimePairedNegatives
  | RequireAppliedEncryptedBrowserRuntimeProductionMutants
  | RequireExactEncryptedBrowserRuntimeSourceDiscovery
  | RequirePostAcquisitionEncryptedBrowserRuntimeChallenge
  | RequireEncryptedBrowserRuntimeProcessObservation
  | RequireNoPbBrowserNodePurescriptJavascriptDhallNetworkLiveHostHardwareOrParallelism
  | RequireFreshEncryptedBrowserRuntimeBuildRootAndStableSource
  | RequireQualifiedEncryptedBrowserRuntimeHarness
  | RequireEncryptedBrowserRuntimeProductsContainedBelowBuild
  | RequireRetiredEncryptedBrowserRuntimeAuthoritiesAbsent
  | RequireExactPhaseFortyFourReceipt
  | RequireLiveBrowserStorageCryptoLockServiceWorkerReplayReleaseHaAndHardwareOwnersExplicit
  | RequireQualifiedPhaseFortyFiveGatePass
  deriving (Eq, Ord, Show)

data PhaseFortySixRequirement
  = RequireHaskellGeneratedBrowserContractsAndBundle
  | RequireAcquiredUiContractGenerationSupervisor
  | RequireDirectOfflineSerialUiContractGenerationMatrix
  | RequireIndependentUiContractGenerationOracle
  | RequireUiContractGenerationPositiveControls
  | RequireExactUiContractGenerationPairedNegatives
  | RequireAppliedUiContractGenerationProductionMutants
  | RequireExactUiContractGenerationSourceDiscovery
  | RequirePostAcquisitionUiContractGenerationChallenge
  | RequireUiContractGenerationProcessObservation
  | RequireNoPbBrowserNodePurescriptJavascriptNetworkLiveHostHardwareOrParallelism
  | RequireFreshUiContractGenerationBuildRootAndStableSource
  | RequireQualifiedUiContractGenerationHarness
  | RequireUiContractGenerationProductsContainedBelowBuild
  | RequireRetiredUiContractGenerationAuthoritiesAbsent
  | RequireExactPhaseFortyFiveReceipt
  | RequireBrowserCompileExecutionProtocolPublicationDeploymentHaAndHardwareOwnersExplicit
  | RequireQualifiedPhaseFortySixGatePass
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
slotFor 1 category =
  BoundSpecification (GateSpecification 1 category (RequirePhaseOne (phaseOneRequirement category)))
slotFor 2 category =
  BoundSpecification (GateSpecification 2 category (RequirePhaseTwo (phaseTwoRequirement category)))
slotFor 3 category =
  BoundSpecification (GateSpecification 3 category (RequirePhaseThree (phaseThreeRequirement category)))
slotFor 4 category =
  BoundSpecification (GateSpecification 4 category (RequirePhaseFour (phaseFourRequirement category)))
slotFor 5 category =
  BoundSpecification (GateSpecification 5 category (RequirePhaseFive (phaseFiveRequirement category)))
slotFor 6 category =
  BoundSpecification (GateSpecification 6 category (RequirePhaseSix (phaseSixRequirement category)))
slotFor 7 category =
  BoundSpecification (GateSpecification 7 category (RequirePhaseSeven (phaseSevenRequirement category)))
slotFor 8 category =
  BoundSpecification (GateSpecification 8 category (RequirePhaseEight (phaseEightRequirement category)))
slotFor 9 category =
  BoundSpecification (GateSpecification 9 category (RequirePhaseNine (phaseNineRequirement category)))
slotFor 10 category =
  BoundSpecification (GateSpecification 10 category (RequirePhaseTen (phaseTenRequirement category)))
slotFor 11 category =
  BoundSpecification (GateSpecification 11 category (RequirePhaseEleven (phaseElevenRequirement category)))
slotFor 12 category =
  BoundSpecification (GateSpecification 12 category (RequirePhaseTwelve (phaseTwelveRequirement category)))
slotFor 13 category =
  BoundSpecification (GateSpecification 13 category (RequirePhaseThirteen (phaseThirteenRequirement category)))
slotFor 14 category =
  BoundSpecification (GateSpecification 14 category (RequirePhaseFourteen (phaseFourteenRequirement category)))
slotFor 15 category =
  BoundSpecification (GateSpecification 15 category (RequirePhaseFifteen (phaseFifteenRequirement category)))
slotFor 16 category =
  BoundSpecification (GateSpecification 16 category (RequirePhaseSixteen (phaseSixteenRequirement category)))
slotFor 17 category =
  BoundSpecification (GateSpecification 17 category (RequirePhaseSeventeen (phaseSeventeenRequirement category)))
slotFor 18 category =
  BoundSpecification (GateSpecification 18 category (RequirePhaseEighteen (phaseEighteenRequirement category)))
slotFor 19 category =
  BoundSpecification (GateSpecification 19 category (RequirePhaseNineteen (phaseNineteenRequirement category)))
slotFor 20 category =
  BoundSpecification (GateSpecification 20 category (RequirePhaseTwenty (phaseTwentyRequirement category)))
slotFor 21 category =
  BoundSpecification (GateSpecification 21 category (RequirePhaseTwentyOne (phaseTwentyOneRequirement category)))
slotFor 22 category =
  BoundSpecification (GateSpecification 22 category (RequirePhaseTwentyTwo (phaseTwentyTwoRequirement category)))
slotFor 23 category =
  BoundSpecification (GateSpecification 23 category (RequirePhaseTwentyThree (phaseTwentyThreeRequirement category)))
slotFor 24 category =
  BoundSpecification (GateSpecification 24 category (RequirePhaseTwentyFour (phaseTwentyFourRequirement category)))
slotFor 25 category =
  BoundSpecification (GateSpecification 25 category (RequirePhaseTwentyFive (phaseTwentyFiveRequirement category)))
slotFor 26 category =
  BoundSpecification (GateSpecification 26 category (RequirePhaseTwentySix (phaseTwentySixRequirement category)))
slotFor 27 category =
  BoundSpecification (GateSpecification 27 category (RequirePhaseTwentySeven (phaseTwentySevenRequirement category)))
slotFor 28 category =
  BoundSpecification (GateSpecification 28 category (RequirePhaseTwentyEight (phaseTwentyEightRequirement category)))
slotFor 29 category =
  BoundSpecification (GateSpecification 29 category (RequirePhaseTwentyNine (phaseTwentyNineRequirement category)))
slotFor 30 category =
  BoundSpecification (GateSpecification 30 category (RequirePhaseThirty (phaseThirtyRequirement category)))
slotFor 31 category =
  BoundSpecification (GateSpecification 31 category (RequirePhaseThirtyOne (phaseThirtyOneRequirement category)))
slotFor 32 category =
  BoundSpecification (GateSpecification 32 category (RequirePhaseThirtyTwo (phaseThirtyTwoRequirement category)))
slotFor 33 category =
  BoundSpecification (GateSpecification 33 category (RequirePhaseThirtyThree (phaseThirtyThreeRequirement category)))
slotFor 34 category =
  BoundSpecification (GateSpecification 34 category (RequirePhaseThirtyFour (phaseThirtyFourRequirement category)))
slotFor 35 category =
  BoundSpecification (GateSpecification 35 category (RequirePhaseThirtyFive (phaseThirtyFiveRequirement category)))
slotFor 36 category =
  BoundSpecification (GateSpecification 36 category (RequirePhaseThirtySix (phaseThirtySixRequirement category)))
slotFor 37 category =
  BoundSpecification (GateSpecification 37 category (RequirePhaseThirtySeven (phaseThirtySevenRequirement category)))
slotFor 38 category =
  BoundSpecification (GateSpecification 38 category (RequirePhaseThirtyEight (phaseThirtyEightRequirement category)))
slotFor 39 category =
  BoundSpecification (GateSpecification 39 category (RequirePhaseThirtyNine (phaseThirtyNineRequirement category)))
slotFor 40 category =
  BoundSpecification (GateSpecification 40 category (RequirePhaseForty (phaseFortyRequirement category)))
slotFor 41 category =
  BoundSpecification (GateSpecification 41 category (RequirePhaseFortyOne (phaseFortyOneRequirement category)))
slotFor 42 category =
  BoundSpecification (GateSpecification 42 category (RequirePhaseFortyTwo (phaseFortyTwoRequirement category)))
slotFor 43 category =
  BoundSpecification (GateSpecification 43 category (RequirePhaseFortyThree (phaseFortyThreeRequirement category)))
slotFor 44 category =
  BoundSpecification (GateSpecification 44 category (RequirePhaseFortyFour (phaseFortyFourRequirement category)))
slotFor 45 category =
  BoundSpecification (GateSpecification 45 category (RequirePhaseFortyFive (phaseFortyFiveRequirement category)))
slotFor 46 category =
  BoundSpecification (GateSpecification 46 category (RequirePhaseFortySix (phaseFortySixRequirement category)))
#ifdef VALIDATION_PHASE_SEMANTIC_GAP_ACCEPTANCE_MUTANT
slotFor 1 Subject =
  BoundSpecification (GateSpecification 1 Subject RequireExactSourceBoundPhaseZeroDispatcher)
#endif
slotFor ordinal category = ContractGap (GapId ordinal category)

phaseTwoRequirement :: GateCategory -> PhaseTwoRequirement
phaseTwoRequirement category = case category of
  Claim -> RequireCompilerBackedRepositoryLayoutClosure
  Subject -> RequireAcquiredRepositoryLayoutSupervisor
  Command -> RequireDirectOfflineSerialRepositoryBuild
  Oracle -> RequireIndependentRepositoryLayoutOracle
  PositiveControls -> RequireCleanRepositoryLayoutControls
  PairedNegatives -> RequireRepositoryLayoutPairedNegatives
  Mutants -> RequireAppliedRepositoryLayoutMutants
  Discovery -> RequireTwoWaySourceAndComponentDiscovery
  Challenge -> RequirePostStartRepositoryChallenge
  Observer -> RequireCompilerProcessAndGraphObservation
  AuthorityBypass -> RequireNoPbNetworkHardwareOrAmbientBypass
  Freshness -> RequireOpeningClosingSourceAndFreshBuildRoot
  Qualification -> RequireQualifiedRepositoryLayoutHarness
  Cleanroom -> RequireGeneratedProductsContainedBelowBuild
  LegacyClosure -> RequirePhaseTwoLegacyFamiliesClosed
  PredecessorCategory -> RequireExactPhaseOneReceipt
  Residue -> RequireOnlyTypedLaterSourceDebt
  PassCriterion -> RequireQualifiedPhaseTwoGatePass

phaseThreeRequirement :: GateCategory -> PhaseThreeRequirement
phaseThreeRequirement category = case category of
  Claim -> RequireCompleteArtifactCalculus
  Subject -> RequireAcquiredArtifactCalculusSupervisor
  Command -> RequireDirectSerialArtifactCompilerMatrix
  Oracle -> RequireIndependentArtifactCalculusOracle
  PositiveControls -> RequireArtifactCalculusPositiveControls
  PairedNegatives -> RequireArtifactCalculusPairedNegatives
  Mutants -> RequireAppliedArtifactCalculusMutants
  Discovery -> RequireExactArtifactCalculusDiscovery
  Challenge -> RequirePostAcquisitionArtifactChallenge
  Observer -> RequireArtifactProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHardwareOrCompilerParallelism
  Freshness -> RequireFreshArtifactBuildRootsAndStableSource
  Qualification -> RequireQualifiedArtifactCalculusHarness
  Cleanroom -> RequireArtifactProductsContainedBelowBuild
  LegacyClosure -> RequireNoPhaseThreeLegacyDebt
  PredecessorCategory -> RequireExactPhaseTwoReceipt
  Residue -> RequireLaterArtifactConsumersExplicit
  PassCriterion -> RequireQualifiedPhaseThreeGatePass

phaseFourRequirement :: GateCategory -> PhaseFourRequirement
phaseFourRequirement category = case category of
  Claim -> RequireCompleteBudgetCalculus
  Subject -> RequireAcquiredBudgetCalculusSupervisor
  Command -> RequireDirectSerialBudgetCompilerMatrix
  Oracle -> RequireIndependentBudgetCalculusOracle
  PositiveControls -> RequireBudgetCalculusPositiveControls
  PairedNegatives -> RequireBudgetCalculusPairedNegatives
  Mutants -> RequireAppliedBudgetCalculusMutants
  Discovery -> RequireExactBudgetCalculusDiscovery
  Challenge -> RequirePostAcquisitionBudgetChallenge
  Observer -> RequireBudgetProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHardwareOrBudgetCompilerParallelism
  Freshness -> RequireFreshBudgetBuildRootsAndStableSource
  Qualification -> RequireQualifiedBudgetCalculusHarness
  Cleanroom -> RequireBudgetProductsContainedBelowBuild
  LegacyClosure -> RequireNoPhaseFourLegacyDebt
  PredecessorCategory -> RequireExactPhaseThreeReceipt
  Residue -> RequireLaterBudgetConsumersExplicit
  PassCriterion -> RequireQualifiedPhaseFourGatePass

phaseFiveRequirement :: GateCategory -> PhaseFiveRequirement
phaseFiveRequirement category = case category of
  Claim -> RequireCompleteLiftCalculus
  Subject -> RequireAcquiredLiftCalculusSupervisor
  Command -> RequireDirectSerialLiftCompilerMatrix
  Oracle -> RequireIndependentLiftCalculusOracle
  PositiveControls -> RequireLiftCalculusPositiveControls
  PairedNegatives -> RequireLiftCalculusPairedNegatives
  Mutants -> RequireAppliedLiftCalculusMutants
  Discovery -> RequireExactLiftCalculusDiscovery
  Challenge -> RequirePostAcquisitionLiftChallenge
  Observer -> RequireLiftProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHardwareOrLiftCompilerParallelism
  Freshness -> RequireFreshLiftBuildRootsAndStableSource
  Qualification -> RequireQualifiedLiftCalculusHarness
  Cleanroom -> RequireLiftProductsContainedBelowBuild
  LegacyClosure -> RequireNoPhaseFiveLegacyDebt
  PredecessorCategory -> RequireExactPhaseFourReceipt
  Residue -> RequireLaterLiftConsumersExplicit
  PassCriterion -> RequireQualifiedPhaseFiveGatePass

phaseSixRequirement :: GateCategory -> PhaseSixRequirement
phaseSixRequirement category = case category of
  Claim -> RequireCompleteWorkflowCalculus
  Subject -> RequireAcquiredWorkflowCalculusSupervisor
  Command -> RequireDirectSerialWorkflowCompilerMatrix
  Oracle -> RequireIndependentWorkflowCalculusOracle
  PositiveControls -> RequireWorkflowCalculusPositiveControls
  PairedNegatives -> RequireWorkflowCalculusPairedNegatives
  Mutants -> RequireAppliedWorkflowCalculusMutants
  Discovery -> RequireExactWorkflowCalculusDiscovery
  Challenge -> RequirePostAcquisitionWorkflowChallenge
  Observer -> RequireWorkflowProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHardwareOrWorkflowCompilerParallelism
  Freshness -> RequireFreshWorkflowBuildRootsAndStableSource
  Qualification -> RequireQualifiedWorkflowCalculusHarness
  Cleanroom -> RequireWorkflowProductsContainedBelowBuild
  LegacyClosure -> RequireNoPhaseSixLegacyDebt
  PredecessorCategory -> RequireExactPhaseFiveReceipt
  Residue -> RequireLaterWorkflowConsumersExplicit
  PassCriterion -> RequireQualifiedPhaseSixGatePass

phaseSevenRequirement :: GateCategory -> PhaseSevenRequirement
phaseSevenRequirement category = case category of
  Claim -> RequireCompleteEvidenceCalculus
  Subject -> RequireAcquiredEvidenceCalculusSupervisor
  Command -> RequireDirectSerialEvidenceCompilerMatrix
  Oracle -> RequireIndependentEvidenceCalculusOracle
  PositiveControls -> RequireEvidenceCalculusPositiveControls
  PairedNegatives -> RequireEvidenceCalculusPairedNegatives
  Mutants -> RequireAppliedEvidenceCalculusMutants
  Discovery -> RequireExactEvidenceCalculusDiscovery
  Challenge -> RequirePostAcquisitionEvidenceChallenge
  Observer -> RequireEvidenceProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHardwareOrEvidenceCompilerParallelism
  Freshness -> RequireFreshEvidenceBuildRootsAndStableSource
  Qualification -> RequireQualifiedEvidenceCalculusHarness
  Cleanroom -> RequireEvidenceProductsContainedBelowBuild
  LegacyClosure -> RequireNoPhaseSevenLegacyDebt
  PredecessorCategory -> RequireExactPhaseSixReceipt
  Residue -> RequireLaterEvidenceConsumersExplicit
  PassCriterion -> RequireQualifiedPhaseSevenGatePass

phaseEightRequirement :: GateCategory -> PhaseEightRequirement
phaseEightRequirement category = case category of
  Claim -> RequireCompleteScopedIdentityKernel
  Subject -> RequireAcquiredScopeIndexSupervisor
  Command -> RequireDirectSerialScopeCompilerMatrix
  Oracle -> RequireIndependentScopeIndexOracle
  PositiveControls -> RequireScopeIndexPositiveControls
  PairedNegatives -> RequireScopeIndexPairedNegatives
  Mutants -> RequireAppliedScopeIndexMutants
  Discovery -> RequireExactScopeIndexDiscovery
  Challenge -> RequirePostAcquisitionScopeChallenge
  Observer -> RequireScopeProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHardwareOrScopeCompilerParallelism
  Freshness -> RequireFreshScopeBuildRootsAndStableSource
  Qualification -> RequireQualifiedScopeIndexHarness
  Cleanroom -> RequireScopeProductsContainedBelowBuild
  LegacyClosure -> RequireNoPhaseEightLegacyDebt
  PredecessorCategory -> RequireExactPhaseSevenReceipt
  Residue -> RequireLaterScopeConsumersExplicit
  PassCriterion -> RequireQualifiedPhaseEightGatePass

phaseNineRequirement :: GateCategory -> PhaseNineRequirement
phaseNineRequirement category = case category of
  Claim -> RequireCompleteResourceIndex
  Subject -> RequireAcquiredResourceIndexSupervisor
  Command -> RequireDirectSerialResourceCompilerMatrix
  Oracle -> RequireIndependentResourceIndexOracle
  PositiveControls -> RequireResourceIndexPositiveControls
  PairedNegatives -> RequireResourceIndexPairedNegatives
  Mutants -> RequireAppliedResourceIndexMutants
  Discovery -> RequireExactResourceIndexDiscovery
  Challenge -> RequirePostAcquisitionResourceChallenge
  Observer -> RequireResourceProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHardwareOrResourceCompilerParallelism
  Freshness -> RequireFreshResourceBuildRootsAndStableSource
  Qualification -> RequireQualifiedResourceIndexHarness
  Cleanroom -> RequireResourceProductsContainedBelowBuild
  LegacyClosure -> RequireNoPhaseNineLegacyDebt
  PredecessorCategory -> RequireExactPhaseEightReceipt
  Residue -> RequireLaterResourceConsumersExplicit
  PassCriterion -> RequireQualifiedPhaseNineGatePass

phaseTenRequirement :: GateCategory -> PhaseTenRequirement
phaseTenRequirement category = case category of
  Claim -> RequireCompleteCalculusComposition
  Subject -> RequireAcquiredCalculusCompositionSupervisor
  Command -> RequireDirectSerialCompositionCompilerMatrix
  Oracle -> RequireIndependentCalculusCompositionOracle
  PositiveControls -> RequireCalculusCompositionPositiveControls
  PairedNegatives -> RequireCalculusCompositionPairedNegatives
  Mutants -> RequireAppliedCalculusCompositionMutants
  Discovery -> RequireExactCalculusCompositionDiscovery
  Challenge -> RequirePostAcquisitionCompositionChallenge
  Observer -> RequireCompositionProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHardwareOrCompositionCompilerParallelism
  Freshness -> RequireFreshCompositionBuildRootsAndStableSource
  Qualification -> RequireQualifiedCalculusCompositionHarness
  Cleanroom -> RequireCompositionProductsContainedBelowBuild
  LegacyClosure -> RequireNoPhaseTenLegacyDebt
  PredecessorCategory -> RequireExactPhaseNineReceipt
  Residue -> RequireLaterCompositionConsumersExplicit
  PassCriterion -> RequireQualifiedPhaseTenGatePass

phaseElevenRequirement :: GateCategory -> PhaseElevenRequirement
phaseElevenRequirement category = case category of
  Claim -> RequireCompleteFormalModelKernel
  Subject -> RequireAcquiredFormalModelKernelSupervisor
  Command -> RequireDirectSerialFormalModelCompilerMatrix
  Oracle -> RequireIndependentFormalModelSemanticOracle
  PositiveControls -> RequireFormalModelPositiveControls
  PairedNegatives -> RequireFormalModelPairedNegatives
  Mutants -> RequireAppliedFormalModelProductionMutants
  Discovery -> RequireExactFormalModelSourceDiscovery
  Challenge -> RequirePostAcquisitionFormalModelChallenge
  Observer -> RequireFormalModelProcessObservation
  AuthorityBypass -> RequireNoPbNetworkJvmHardwareOrFormalModelCompilerParallelism
  Freshness -> RequireFreshFormalModelBuildRootsAndStableSource
  Qualification -> RequireQualifiedFormalModelHarness
  Cleanroom -> RequireFormalModelProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredFormalModelBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseTenReceipt
  Residue -> RequireLaterCheckerAndRuntimeClaimsExplicit
  PassCriterion -> RequireQualifiedPhaseElevenGatePass

phaseTwelveRequirement :: GateCategory -> PhaseTwelveRequirement
phaseTwelveRequirement category = case category of
  Claim -> RequireCompleteExplicitStateChecker
  Subject -> RequireAcquiredExplicitStateCheckerSupervisor
  Command -> RequireDirectSerialExplicitStateCompilerMatrix
  Oracle -> RequireIndependentExplicitStateSemanticOracle
  PositiveControls -> RequireExplicitStatePositiveControls
  PairedNegatives -> RequireExplicitStatePairedNegatives
  Mutants -> RequireAppliedExplicitStateProductionMutants
  Discovery -> RequireExactExplicitStateSourceDiscovery
  Challenge -> RequirePostAcquisitionExplicitStateChallenge
  Observer -> RequireExplicitStateProcessObservation
  AuthorityBypass -> RequireNoPbNetworkJvmHardwareOrExplicitStateCompilerParallelism
  Freshness -> RequireFreshExplicitStateBuildRootsAndStableSource
  Qualification -> RequireQualifiedExplicitStateHarness
  Cleanroom -> RequireExplicitStateProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredExplicitStateBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseElevenReceipt
  Residue -> RequireLaterCheckerSimulationAndRuntimeClaimsExplicit
  PassCriterion -> RequireQualifiedPhaseTwelveGatePass

phaseThirteenRequirement :: GateCategory -> PhaseThirteenRequirement
phaseThirteenRequirement category = case category of
  Claim -> RequireCompleteSymbolicChecker
  Subject -> RequireAcquiredSymbolicCheckerSupervisor
  Command -> RequireDirectSerialSymbolicCompilerMatrix
  Oracle -> RequireIndependentSymbolicSemanticOracle
  PositiveControls -> RequireSymbolicPositiveControls
  PairedNegatives -> RequireSymbolicPairedNegatives
  Mutants -> RequireAppliedSymbolicProductionMutants
  Discovery -> RequireExactSymbolicSourceDiscovery
  Challenge -> RequirePostAcquisitionSymbolicChallenge
  Observer -> RequireSymbolicProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrSymbolicCompilerParallelism
  Freshness -> RequireFreshSymbolicBuildRootsAndStableSource
  Qualification -> RequireQualifiedSymbolicHarness
  Cleanroom -> RequireSymbolicProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredSymbolicBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseTwelveReceipt
  Residue -> RequireLaterRefinementSimulationAndRuntimeClaimsExplicit
  PassCriterion -> RequireQualifiedPhaseThirteenGatePass

phaseFourteenRequirement :: GateCategory -> PhaseFourteenRequirement
phaseFourteenRequirement category = case category of
  Claim -> RequireCompleteRefinementChecker
  Subject -> RequireAcquiredRefinementCheckerSupervisor
  Command -> RequireDirectSerialRefinementCompilerMatrix
  Oracle -> RequireIndependentRefinementSemanticOracle
  PositiveControls -> RequireRefinementPositiveControls
  PairedNegatives -> RequireRefinementPairedNegatives
  Mutants -> RequireAppliedRefinementProductionMutants
  Discovery -> RequireExactRefinementSourceDiscovery
  Challenge -> RequirePostAcquisitionRefinementChallenge
  Observer -> RequireRefinementProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrRefinementCompilerParallelism
  Freshness -> RequireFreshRefinementBuildRootsAndStableSource
  Qualification -> RequireQualifiedRefinementHarness
  Cleanroom -> RequireRefinementProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredRefinementBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseThirteenReceipt
  Residue -> RequireLaterCompileFailSimulationAndRuntimeClaimsExplicit
  PassCriterion -> RequireQualifiedPhaseFourteenGatePass

phaseFifteenRequirement :: GateCategory -> PhaseFifteenRequirement
phaseFifteenRequirement category = case category of
  Claim -> RequireCompleteCompileFailHarness
  Subject -> RequireAcquiredCompileFailHarnessSupervisor
  Command -> RequireDirectSerialCompileFailCompilerMatrix
  Oracle -> RequireIndependentCompileFailCorpusOracle
  PositiveControls -> RequireCompileFailLegalTwinControls
  PairedNegatives -> RequireCompileFailPinnedIllegalTwins
  Mutants -> RequireAppliedCompileFailProductionMutants
  Discovery -> RequireExactCompileFailSourceDiscovery
  Challenge -> RequirePostAcquisitionCompileFailChallenge
  Observer -> RequireCompileFailProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrCompileFailParallelism
  Freshness -> RequireFreshCompileFailBuildRootsAndStableSource
  Qualification -> RequireQualifiedCompileFailHarness
  Cleanroom -> RequireCompileFailProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredCompileFailBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseFourteenReceipt
  Residue -> RequireLaterSimulationAndRuntimeClaimsExplicit
  PassCriterion -> RequireQualifiedPhaseFifteenGatePass

phaseSixteenRequirement :: GateCategory -> PhaseSixteenRequirement
phaseSixteenRequirement category = case category of
  Claim -> RequireCompleteDeterministicSimulationSubstrate
  Subject -> RequireAcquiredDeterministicSimulationSupervisor
  Command -> RequireDirectOfflineSerialSimulationMatrix
  Oracle -> RequireIndependentDeterministicSimulationOracle
  PositiveControls -> RequireTwoInterpreterSimulationControls
  PairedNegatives -> RequireFaultKnobAndSchedulePairedNegatives
  Mutants -> RequireAppliedDeterministicSimulationProductionMutants
  Discovery -> RequireExactDeterministicSimulationSourceDiscovery
  Challenge -> RequirePostAcquisitionDeterministicSimulationChallenge
  Observer -> RequireDeterministicSimulationProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrSimulationParallelism
  Freshness -> RequireFreshSimulationBuildRootAndStableSource
  Qualification -> RequireQualifiedDeterministicSimulationHarness
  Cleanroom -> RequireSimulationProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredSimulationBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseFifteenReceipt
  Residue -> RequireLaterModelsRuntimesAndHardwareExplicit
  PassCriterion -> RequireQualifiedPhaseSixteenGatePass

phaseSeventeenRequirement :: GateCategory -> PhaseSeventeenRequirement
phaseSeventeenRequirement category = case category of
  Claim -> RequireCompleteGatewayMigrationModel
  Subject -> RequireAcquiredGatewayMigrationModelSupervisor
  Command -> RequireDirectOfflineSerialGatewayModelMatrix
  Oracle -> RequireIndependentGatewayMigrationOracle
  PositiveControls -> RequireGatewayExplorerTlcAndScheduleControls
  PairedNegatives -> RequireGatewayInvariantFairnessAndCutoffNegatives
  Mutants -> RequireAppliedGatewayMigrationProductionMutants
  Discovery -> RequireExactGatewayMigrationSourceDiscovery
  Challenge -> RequirePostAcquisitionGatewayMigrationChallenge
  Observer -> RequireGatewayMigrationProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrGatewayParallelism
  Freshness -> RequireFreshGatewayBuildRootAndStableSource
  Qualification -> RequireQualifiedGatewayMigrationHarness
  Cleanroom -> RequireGatewayProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredGatewayBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseSixteenReceipt
  Residue -> RequireGatewayRuntimeFidelityAndDecompositionExplicit
  PassCriterion -> RequireQualifiedPhaseSeventeenGatePass

phaseEighteenRequirement :: GateCategory -> PhaseEighteenRequirement
phaseEighteenRequirement category = case category of
  Claim -> RequireCompleteDslFormalModel
  Subject -> RequireAcquiredDslFormalModelSupervisor
  Command -> RequireDirectOfflineSerialDslFormalMatrix
  Oracle -> RequireIndependentDslFormalOracle
  PositiveControls -> RequireDslModelCapacityCalculusAndProtocolControls
  PairedNegatives -> RequireDslSafetyFairnessAndDecisionNegatives
  Mutants -> RequireAppliedDslFormalProductionMutants
  Discovery -> RequireExactDslFormalSourceDiscovery
  Challenge -> RequirePostAcquisitionDslFormalChallenge
  Observer -> RequireDslFormalProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrDslFormalParallelism
  Freshness -> RequireFreshDslFormalBuildRootAndStableSource
  Qualification -> RequireQualifiedDslFormalHarness
  Cleanroom -> RequireDslFormalProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredDslFormalBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseSeventeenReceipt
  Residue -> RequireLaterDslRuntimeAndProjectionOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseEighteenGatePass

phaseNineteenRequirement :: GateCategory -> PhaseNineteenRequirement
phaseNineteenRequirement category = case category of
  Claim -> RequireCompleteReconcileCoreSimulation
  Subject -> RequireAcquiredReconcileCoreSupervisor
  Command -> RequireDirectOfflineSerialReconcileCoreMatrix
  Oracle -> RequireIndependentReconcileCoreOracle
  PositiveControls -> RequireReconcileCoreScheduleProtocolAndFormalControls
  PairedNegatives -> RequireReconcileCorePairedNegatives
  Mutants -> RequireAppliedReconcileCoreProductionMutants
  Discovery -> RequireExactReconcileCoreSourceDiscovery
  Challenge -> RequirePostAcquisitionReconcileCoreChallenge
  Observer -> RequireReconcileCoreProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrReconcileCoreParallelism
  Freshness -> RequireFreshReconcileCoreBuildRootAndStableSource
  Qualification -> RequireQualifiedReconcileCoreHarness
  Cleanroom -> RequireReconcileCoreProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredReconcileCoreBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseEighteenReceipt
  Residue -> RequireLaterEffectfulReconcileRuntimeExplicit
  PassCriterion -> RequireQualifiedPhaseNineteenGatePass

phaseTwentyRequirement :: GateCategory -> PhaseTwentyRequirement
phaseTwentyRequirement category = case category of
  Claim -> RequireCompleteIndexedExtensionDeclaration
  Subject -> RequireAcquiredExtensionDeclarationSupervisor
  Command -> RequireDirectOfflineSerialExtensionDeclarationMatrix
  Oracle -> RequireIndependentExtensionDeclarationOracle
  PositiveControls -> RequireDeclarationReaderResourceAndDigestControls
  PairedNegatives -> RequireDeclarationSemanticAndCompileNegatives
  Mutants -> RequireAppliedExtensionDeclarationProductionMutants
  Discovery -> RequireExactExtensionDeclarationSourceDiscovery
  Challenge -> RequirePostAcquisitionExtensionDeclarationChallenge
  Observer -> RequireExtensionDeclarationProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrExtensionDeclarationParallelism
  Freshness -> RequireFreshExtensionDeclarationBuildRootAndStableSource
  Qualification -> RequireQualifiedExtensionDeclarationHarness
  Cleanroom -> RequireExtensionDeclarationProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredExtensionDeclarationBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseNineteenReceipt
  Residue -> RequireLaterExtensionLawAndRuntimeOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseTwentyGatePass

phaseTwentyOneRequirement :: GateCategory -> PhaseTwentyOneRequirement
phaseTwentyOneRequirement category = case category of
  Claim -> RequireCompletePerExtensionLawEvaluator
  Subject -> RequireAcquiredExtensionLawsSupervisor
  Command -> RequireDirectOfflineSerialExtensionLawsMatrix
  Oracle -> RequireIndependentExtensionLawsOracle
  PositiveControls -> RequireLawfulOperationRenderBudgetAndEvidenceControls
  PairedNegatives -> RequireSingleLawAndClaimCompileNegatives
  Mutants -> RequireAppliedExtensionLawsProductionMutants
  Discovery -> RequireExactExtensionLawsSourceDiscovery
  Challenge -> RequirePostAcquisitionExtensionLawsChallenge
  Observer -> RequireExtensionLawsProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrExtensionLawsParallelism
  Freshness -> RequireFreshExtensionLawsBuildRootAndStableSource
  Qualification -> RequireQualifiedExtensionLawsHarness
  Cleanroom -> RequireExtensionLawsProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredExtensionLawsBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseTwentyReceipt
  Residue -> RequireLaterCompositionalSecurityConformanceAndRuntimeOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseTwentyOneGatePass

phaseTwentyTwoRequirement :: GateCategory -> PhaseTwentyTwoRequirement
phaseTwentyTwoRequirement category = case category of
  Claim -> RequireCompleteNormalizedCompositeAndC1C7Evaluator
  Subject -> RequireAcquiredExtensionCompositionSupervisor
  Command -> RequireDirectOfflineSerialExtensionCompositionMatrix
  Oracle -> RequireIndependentExtensionCompositionOracle
  PositiveControls -> RequireLawfulCompositionIdentityAssociationBudgetAndAddressControls
  PairedNegatives -> RequireCompositionLawAndRequestScopeNegatives
  Mutants -> RequireAppliedExtensionCompositionProductionMutants
  Discovery -> RequireExactExtensionCompositionSourceDiscovery
  Challenge -> RequirePostAcquisitionExtensionCompositionChallenge
  Observer -> RequireExtensionCompositionProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrExtensionCompositionParallelism
  Freshness -> RequireFreshExtensionCompositionBuildRootAndStableSource
  Qualification -> RequireQualifiedExtensionCompositionHarness
  Cleanroom -> RequireExtensionCompositionProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredExtensionCompositionBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseTwentyOneReceipt
  Residue -> RequireLaterSecurityConformanceProofAndRuntimeOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseTwentyTwoGatePass

phaseTwentyThreeRequirement :: GateCategory -> PhaseTwentyThreeRequirement
phaseTwentyThreeRequirement category = case category of
  Claim -> RequireBoundedTypedSecurityKernelAndS1S6Evaluator
  Subject -> RequireAcquiredExtensionSecuritySupervisor
  Command -> RequireDirectOfflineSerialExtensionSecurityMatrix
  Oracle -> RequireIndependentExtensionSecurityOracle
  PositiveControls -> RequireIdentityOperationRefusalNamespaceAndPolicyControls
  PairedNegatives -> RequireSecurityLawAndFourCompilerBarrierNegatives
  Mutants -> RequireAppliedExtensionSecurityProductionMutants
  Discovery -> RequireExactExtensionSecuritySourceDiscovery
  Challenge -> RequirePostAcquisitionExtensionSecurityChallenge
  Observer -> RequireExtensionSecurityProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrExtensionSecurityParallelism
  Freshness -> RequireFreshExtensionSecurityBuildRootAndStableSource
  Qualification -> RequireQualifiedExtensionSecurityHarness
  Cleanroom -> RequireExtensionSecurityProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredExtensionSecurityBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseTwentyTwoReceipt
  Residue -> RequireLaterSecurityClosureConformanceCryptoTimingAndRuntimeOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseTwentyThreeGatePass

phaseTwentyFourRequirement :: GateCategory -> PhaseTwentyFourRequirement
phaseTwentyFourRequirement category = case category of
  Claim -> RequireDeclarationDerivedConformancePlanVerdictAndAdmission
  Subject -> RequireAcquiredConformanceGateSupervisor
  Command -> RequireDirectOfflineSerialConformanceGateMatrix
  Oracle -> RequireIndependentConformanceGateOracle
  PositiveControls -> RequireSuiteCoverageVerdictAndAdmissionControls
  PairedNegatives -> RequireConformanceRefusalAndCompilerBarrierNegatives
  Mutants -> RequireAppliedConformanceGateProductionMutants
  Discovery -> RequireExactConformanceGateSourceDiscovery
  Challenge -> RequirePostAcquisitionConformanceGateChallenge
  Observer -> RequireConformanceGateProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrConformanceGateParallelism
  Freshness -> RequireFreshConformanceGateBuildRootAndStableSource
  Qualification -> RequireQualifiedConformanceGateHarness
  Cleanroom -> RequireConformanceGateProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredConformanceGateBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseTwentyThreeReceipt
  Residue -> RequireLaterTransactionObserverSemanticClosureAndRuntimeOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseTwentyFourGatePass

phaseTwentyFiveRequirement :: GateCategory -> PhaseTwentyFiveRequirement
phaseTwentyFiveRequirement category = case category of
  Claim -> RequireHaskellDerivedDhallStructuralLanguage
  Subject -> RequireAcquiredDhallSchemaSupervisor
  Command -> RequireDirectOfflineSerialDhallSchemaMatrix
  Oracle -> RequireIndependentDhallSchemaOracle
  PositiveControls -> RequireSchemaModuleAndPositiveTypecheckControls
  PairedNegatives -> RequirePairedDhallStructuralAndImportNegatives
  Mutants -> RequireAppliedDhallSchemaProductionMutants
  Discovery -> RequireExactDhallSchemaSourceDiscovery
  Challenge -> RequirePostAcquisitionDhallSchemaChallenge
  Observer -> RequireDhallSchemaProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrDhallSchemaParallelism
  Freshness -> RequireFreshDhallSchemaBuildRootAndStableSource
  Qualification -> RequireQualifiedDhallSchemaHarness
  Cleanroom -> RequireDhallSchemaProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredDhallBehavioralSourcesAbsent
  PredecessorCategory -> RequireExactPhaseTwentyFourReceipt
  Residue -> RequireLaterBindingDecodeProvisionRuntimeOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseTwentyFiveGatePass

phaseTwentySixRequirement :: GateCategory -> PhaseTwentySixRequirement
phaseTwentySixRequirement category = case category of
  Claim -> RequireHaskellProtocolAndIndexedDecodeBoundary
  Subject -> RequireAcquiredGadtDecodeSupervisor
  Command -> RequireDirectOfflineSerialGadtDecodeMatrix
  Oracle -> RequireIndependentGadtDecodeOracle
  PositiveControls -> RequireControllerIndexedPositiveDecodeControls
  PairedNegatives -> RequirePairedGadtDecodeNegatives
  Mutants -> RequireAppliedGadtDecodeProductionMutants
  Discovery -> RequireExactGadtDecodeSourceDiscovery
  Challenge -> RequirePostAcquisitionGadtDecodeChallenge
  Observer -> RequireGadtDecodeProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrGadtDecodeParallelism
  Freshness -> RequireFreshGadtDecodeBuildRootAndStableSource
  Qualification -> RequireQualifiedGadtDecodeHarness
  Cleanroom -> RequireGadtDecodeProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredProtoAndGadtDecodeAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseTwentyFiveReceipt
  Residue -> RequireLaterCapacityBindingProvisionRuntimeOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseTwentySixGatePass

phaseTwentySevenRequirement :: GateCategory -> PhaseTwentySevenRequirement
phaseTwentySevenRequirement category = case category of
  Claim -> RequireClosedHaskellIllegalStateCoverageLedger
  Subject -> RequireAcquiredIllegalStateCoveringSupervisor
  Command -> RequireDirectOfflineSerialIllegalStateCoveringMatrix
  Oracle -> RequireIndependentIllegalStateCoveringOracle
  PositiveControls -> RequireDhallDecodeCompileAndPropertyPositiveControls
  PairedNegatives -> RequirePairedIllegalStateForeclosureNegatives
  Mutants -> RequireAppliedIllegalStateCoveringProductionMutants
  Discovery -> RequireExactIllegalStateCoveringSourceDiscovery
  Challenge -> RequirePostAcquisitionIllegalStateCoveringChallenge
  Observer -> RequireIllegalStateCoveringProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrIllegalStateParallelism
  Freshness -> RequireFreshIllegalStateBuildRootAndStableSource
  Qualification -> RequireQualifiedIllegalStateCoveringHarness
  Cleanroom -> RequireIllegalStateProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredBehavioralDocumentAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseTwentySixReceipt
  Residue -> RequireLaterProvisionRenderRuntimeOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseTwentySevenGatePass

phaseTwentyEightRequirement :: GateCategory -> PhaseTwentyEightRequirement
phaseTwentyEightRequirement category = case category of
  Claim -> RequirePureStorageGeometryFoldBoundary
  Subject -> RequireAcquiredStorageGeometrySupervisor
  Command -> RequireDirectOfflineSerialStorageGeometryMatrix
  Oracle -> RequireIndependentStorageGeometryOracle
  PositiveControls -> RequireStorageGeometryPositiveControls
  PairedNegatives -> RequirePairedStorageGeometryNegatives
  Mutants -> RequireAppliedStorageGeometryProductionMutants
  Discovery -> RequireExactStorageGeometrySourceDiscovery
  Challenge -> RequirePostAcquisitionStorageGeometryChallenge
  Observer -> RequireStorageGeometryProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrStorageParallelism
  Freshness -> RequireFreshStorageGeometryBuildRootAndStableSource
  Qualification -> RequireQualifiedStorageGeometryHarness
  Cleanroom -> RequireStorageGeometryProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredStorageGeometryAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseTwentySevenReceipt
  Residue -> RequireLaterBindingProvisionRuntimeStorageOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseTwentyEightGatePass

phaseTwentyNineRequirement :: GateCategory -> PhaseTwentyNineRequirement
phaseTwentyNineRequirement category = case category of
  Claim -> RequirePureExecutionAcceleratorFoldBoundary
  Subject -> RequireAcquiredExecutionAcceleratorSupervisor
  Command -> RequireDirectOfflineSerialExecutionAcceleratorMatrix
  Oracle -> RequireIndependentExecutionAcceleratorOracle
  PositiveControls -> RequireExecutionAcceleratorPositiveControls
  PairedNegatives -> RequirePairedExecutionAcceleratorNegatives
  Mutants -> RequireAppliedExecutionAcceleratorProductionMutants
  Discovery -> RequireExactExecutionAcceleratorSourceDiscovery
  Challenge -> RequirePostAcquisitionExecutionAcceleratorChallenge
  Observer -> RequireExecutionAcceleratorProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrExecutionParallelism
  Freshness -> RequireFreshExecutionAcceleratorBuildRootAndStableSource
  Qualification -> RequireQualifiedExecutionAcceleratorHarness
  Cleanroom -> RequireExecutionAcceleratorProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredExecutionAcceleratorAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseTwentyEightReceipt
  Residue -> RequireLaterBindingProvisionRuntimeExecutionOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseTwentyNineGatePass

phaseThirtyRequirement :: GateCategory -> PhaseThirtyRequirement
phaseThirtyRequirement category = case category of
  Claim -> RequirePureCapabilityBindBoundary
  Subject -> RequireAcquiredCapabilityBindSupervisor
  Command -> RequireDirectOfflineSerialCapabilityBindMatrix
  Oracle -> RequireIndependentCapabilityBindOracle
  PositiveControls -> RequireCapabilityBindPositiveControls
  PairedNegatives -> RequirePairedCapabilityBindNegatives
  Mutants -> RequireAppliedCapabilityBindProductionMutants
  Discovery -> RequireExactCapabilityBindSourceDiscovery
  Challenge -> RequirePostAcquisitionCapabilityBindChallenge
  Observer -> RequireCapabilityBindProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrCapabilityBindParallelism
  Freshness -> RequireFreshCapabilityBindBuildRootAndStableSource
  Qualification -> RequireQualifiedCapabilityBindHarness
  Cleanroom -> RequireCapabilityBindProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredCapabilityBindAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseTwentyNineReceipt
  Residue -> RequireLaterProvisionRenderRuntimeCapabilityOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseThirtyGatePass

phaseThirtyOneRequirement :: GateCategory -> PhaseThirtyOneRequirement
phaseThirtyOneRequirement category = case category of
  Claim -> RequireCompleteProvisionSealBoundary
  Subject -> RequireAcquiredProvisionSealSupervisor
  Command -> RequireDirectOfflineSerialProvisionSealMatrix
  Oracle -> RequireIndependentProvisionSealOracle
  PositiveControls -> RequireProvisionSealPositiveControls
  PairedNegatives -> RequirePairedProvisionSealNegatives
  Mutants -> RequireAppliedProvisionSealProductionMutants
  Discovery -> RequireExactProvisionSealSourceDiscovery
  Challenge -> RequirePostAcquisitionProvisionSealChallenge
  Observer -> RequireProvisionSealProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrProvisionSealParallelism
  Freshness -> RequireFreshProvisionSealBuildRootAndStableSource
  Qualification -> RequireQualifiedProvisionSealHarness
  Cleanroom -> RequireProvisionSealProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredProvisionSealAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseThirtyReceipt
  Residue -> RequireLaterRenderRuntimeLiveProvisionOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseThirtyOneGatePass

phaseThirtyTwoRequirement :: GateCategory -> PhaseThirtyTwoRequirement
phaseThirtyTwoRequirement category = case category of
  Claim -> RequireClosedInferenceAcceleratorProvisionBoundary
  Subject -> RequireAcquiredInferenceAcceleratorSupervisor
  Command -> RequireDirectOfflineSerialInferenceAcceleratorMatrix
  Oracle -> RequireIndependentInferenceAcceleratorOracle
  PositiveControls -> RequireInferenceAcceleratorPositiveControls
  PairedNegatives -> RequirePairedInferenceAcceleratorNegatives
  Mutants -> RequireAppliedInferenceAcceleratorProductionMutants
  Discovery -> RequireExactInferenceAcceleratorSourceDiscovery
  Challenge -> RequirePostAcquisitionInferenceAcceleratorChallenge
  Observer -> RequireInferenceAcceleratorProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrInferenceAcceleratorParallelism
  Freshness -> RequireFreshInferenceAcceleratorBuildRootAndStableSource
  Qualification -> RequireQualifiedInferenceAcceleratorHarness
  Cleanroom -> RequireInferenceAcceleratorProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredInferenceAcceleratorAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseThirtyOneReceipt
  Residue -> RequireLaterRenderRuntimeLiveEngineOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseThirtyTwoGatePass

phaseThirtyThreeRequirement :: GateCategory -> PhaseThirtyThreeRequirement
phaseThirtyThreeRequirement category = case category of
  Claim -> RequirePureTotalRenderAllBoundary
  Subject -> RequireAcquiredRenderManifestSupervisor
  Command -> RequireDirectOfflineSerialRenderManifestMatrix
  Oracle -> RequireIndependentRenderManifestOracle
  PositiveControls -> RequireRenderManifestPositiveControls
  PairedNegatives -> RequirePairedRenderManifestNegatives
  Mutants -> RequireAppliedRenderManifestProductionMutants
  Discovery -> RequireExactRenderManifestSourceDiscovery
  Challenge -> RequirePostAcquisitionRenderManifestChallenge
  Observer -> RequireRenderManifestProcessObservation
  AuthorityBypass -> RequireNoPbNetworkHostHardwareOrRenderManifestParallelism
  Freshness -> RequireFreshRenderManifestBuildRootAndStableSource
  Qualification -> RequireQualifiedRenderManifestHarness
  Cleanroom -> RequireRenderManifestProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredRenderManifestAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseThirtyTwoReceipt
  Residue -> RequireLaterActionsDryRunRuntimeLiveOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseThirtyThreeGatePass

phaseThirtyFourRequirement :: GateCategory -> PhaseThirtyFourRequirement
phaseThirtyFourRequirement category = case category of
  Claim -> RequirePureChainAndFakeBoundary
  Subject -> RequireAcquiredChainBoundarySupervisor
  Command -> RequireDirectOfflineSerialChainBoundaryMatrix
  Oracle -> RequireIndependentChainBoundaryOracle
  PositiveControls -> RequireChainBoundaryPositiveControls
  PairedNegatives -> RequirePairedChainBoundaryNegatives
  Mutants -> RequireAppliedChainBoundaryProductionMutants
  Discovery -> RequireExactChainBoundarySourceDiscovery
  Challenge -> RequirePostAcquisitionChainBoundaryChallenge
  Observer -> RequireChainBoundaryProcessObservation
  AuthorityBypass -> RequireNoPbNetworkLiveHostHardwareOrParallelism
  Freshness -> RequireFreshChainBoundaryBuildRootAndStableSource
  Qualification -> RequireQualifiedChainBoundaryHarness
  Cleanroom -> RequireChainBoundaryProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredChainBoundaryAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseThirtyThreeReceipt
  Residue -> RequireLiveInterpreterRuntimeAndHardwareOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseThirtyFourGatePass

phaseThirtyFiveRequirement :: GateCategory -> PhaseThirtyFiveRequirement
phaseThirtyFiveRequirement category = case category of
  Claim -> RequirePureTotalImageRecipeBoundary
  Subject -> RequireAcquiredImageRecipeSupervisor
  Command -> RequireDirectOfflineSerialImageRecipeMatrix
  Oracle -> RequireIndependentImageRecipeOracle
  PositiveControls -> RequireImageRecipePositiveControls
  PairedNegatives -> RequirePairedImageRecipeNegatives
  Mutants -> RequireAppliedImageRecipeProductionMutants
  Discovery -> RequireExactImageRecipeSourceDiscovery
  Challenge -> RequirePostAcquisitionImageRecipeChallenge
  Observer -> RequireImageRecipeProcessObservation
  AuthorityBypass -> RequireNoPbNetworkEngineHostHardwareOrParallelism
  Freshness -> RequireFreshImageRecipeBuildRootAndStableSource
  Qualification -> RequireQualifiedImageRecipeHarness
  Cleanroom -> RequireImageRecipeProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredImageRecipeAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseThirtyFourReceipt
  Residue -> RequireLiveResolutionBuildPublicationRuntimeOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseThirtyFiveGatePass

phaseThirtySixRequirement :: GateCategory -> PhaseThirtySixRequirement
phaseThirtySixRequirement category = case category of
  Claim -> RequirePureClosedTransactionVocabulary
  Subject -> RequireAcquiredTransactionVocabularySupervisor
  Command -> RequireDirectOfflineSerialTransactionVocabularyMatrix
  Oracle -> RequireIndependentTransactionVocabularyOracle
  PositiveControls -> RequireTransactionVocabularyPositiveControls
  PairedNegatives -> RequireTransactionVocabularyCompilerNegatives
  Mutants -> RequireAppliedTransactionVocabularyProductionMutants
  Discovery -> RequireExactTransactionVocabularySourceDiscovery
  Challenge -> RequirePostAcquisitionTransactionVocabularyChallenge
  Observer -> RequireTransactionVocabularyProcessObservation
  AuthorityBypass -> RequireNoPbNetworkDatabaseHostHardwareOrParallelism
  Freshness -> RequireFreshTransactionVocabularyBuildRootAndStableSource
  Qualification -> RequireQualifiedTransactionVocabularyHarness
  Cleanroom -> RequireTransactionVocabularyProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredTransactionVocabularyAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseThirtyFiveReceipt
  Residue -> RequireLiveDatabasePolicyRuntimeOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseThirtySixGatePass

phaseThirtySevenRequirement :: GateCategory -> PhaseThirtySevenRequirement
phaseThirtySevenRequirement category = case category of
  Claim -> RequirePureBoundedUiProgramSchema
  Subject -> RequireAcquiredUiProgramSchemaSupervisor
  Command -> RequireDirectOfflineSerialUiProgramSchemaMatrix
  Oracle -> RequireIndependentUiProgramSchemaOracle
  PositiveControls -> RequireUiProgramSchemaPositiveControls
  PairedNegatives -> RequireExactUiProgramSchemaNegatives
  Mutants -> RequireAppliedUiProgramSchemaProductionMutants
  Discovery -> RequireExactUiProgramSchemaSourceDiscovery
  Challenge -> RequirePostAcquisitionUiProgramSchemaChallenge
  Observer -> RequireUiProgramSchemaProcessObservation
  AuthorityBypass -> RequireNoPbNetworkBrowserHostHardwareOrParallelism
  Freshness -> RequireFreshUiProgramSchemaBuildRootAndStableSource
  Qualification -> RequireQualifiedUiProgramSchemaHarness
  Cleanroom -> RequireUiProgramSchemaProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredUiProgramSchemaAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseThirtySixReceipt
  Residue -> RequireUiRuntimeAndProviderOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseThirtySevenGatePass

phaseThirtyEightRequirement :: GateCategory -> PhaseThirtyEightRequirement
phaseThirtyEightRequirement category = case category of
  Claim -> RequirePureSealedUiAuthorizationKernel
  Subject -> RequireAcquiredUiAuthorizationSupervisor
  Command -> RequireDirectOfflineSerialUiAuthorizationMatrix
  Oracle -> RequireIndependentUiAuthorizationOracle
  PositiveControls -> RequireUiAuthorizationPositiveControls
  PairedNegatives -> RequireExactUiAuthorizationPairedNegatives
  Mutants -> RequireAppliedUiAuthorizationProductionMutants
  Discovery -> RequireExactUiAuthorizationSourceDiscovery
  Challenge -> RequirePostAcquisitionUiAuthorizationChallenge
  Observer -> RequireUiAuthorizationProcessObservation
  AuthorityBypass -> RequireNoPbNetworkIdentityProviderHostHardwareOrParallelism
  Freshness -> RequireFreshUiAuthorizationBuildRootAndStableSource
  Qualification -> RequireQualifiedUiAuthorizationHarness
  Cleanroom -> RequireUiAuthorizationProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredUiAuthorizationAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseThirtySevenReceipt
  Residue -> RequireUiEffectRuntimeAndProviderOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseThirtyEightGatePass

phaseThirtyNineRequirement :: GateCategory -> PhaseThirtyNineRequirement
phaseThirtyNineRequirement category = case category of
  Claim -> RequirePureExactUiEffectBinding
  Subject -> RequireAcquiredUiEffectBindingSupervisor
  Command -> RequireDirectOfflineSerialUiEffectBindingMatrix
  Oracle -> RequireIndependentUiEffectBindingOracle
  PositiveControls -> RequireUiEffectBindingPositiveControls
  PairedNegatives -> RequireExactUiEffectBindingPairedNegatives
  Mutants -> RequireAppliedUiEffectBindingProductionMutants
  Discovery -> RequireExactUiEffectBindingSourceDiscovery
  Challenge -> RequirePostAcquisitionUiEffectBindingChallenge
  Observer -> RequireUiEffectBindingProcessObservation
  AuthorityBypass -> RequireNoPbNetworkProviderBrowserHostHardwareOrParallelism
  Freshness -> RequireFreshUiEffectBindingBuildRootAndStableSource
  Qualification -> RequireQualifiedUiEffectBindingHarness
  Cleanroom -> RequireUiEffectBindingProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredUiEffectBindingAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseThirtyEightReceipt
  Residue -> RequireUiPlanRuntimeAndProviderOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseThirtyNineGatePass

phaseFortyRequirement :: GateCategory -> PhaseFortyRequirement
phaseFortyRequirement category = case category of
  Claim -> RequirePureDeterministicUiPlanCompiler
  Subject -> RequireAcquiredUiPlanCompilerSupervisor
  Command -> RequireDirectOfflineSerialUiPlanCompilerMatrix
  Oracle -> RequireIndependentUiPlanCompilerOracle
  PositiveControls -> RequireUiPlanCompilerPositiveControls
  PairedNegatives -> RequireExactUiPlanCompilerPairedNegatives
  Mutants -> RequireAppliedUiPlanCompilerProductionMutants
  Discovery -> RequireExactUiPlanCompilerSourceDiscovery
  Challenge -> RequirePostAcquisitionUiPlanCompilerChallenge
  Observer -> RequireUiPlanCompilerProcessObservation
  AuthorityBypass -> RequireNoPbNetworkInterpreterProviderHostHardwareOrParallelism
  Freshness -> RequireFreshUiPlanCompilerBuildRootAndStableSource
  Qualification -> RequireQualifiedUiPlanCompilerHarness
  Cleanroom -> RequireUiPlanCompilerProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredUiPlanCompilerAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseThirtyNineReceipt
  Residue -> RequireUiInterpreterOfflineRuntimeAndPublicationOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseFortyGatePass

phaseFortyOneRequirement :: GateCategory -> PhaseFortyOneRequirement
phaseFortyOneRequirement category = case category of
  Claim -> RequirePureBoundedOfflineContinuityLanguage
  Subject -> RequireAcquiredOfflineLanguagePlanSupervisor
  Command -> RequireDirectOfflineSerialOfflineLanguagePlanMatrix
  Oracle -> RequireIndependentOfflineLanguagePlanOracle
  PositiveControls -> RequireOfflineLanguagePlanPositiveControls
  PairedNegatives -> RequireExactOfflineLanguagePlanPairedNegatives
  Mutants -> RequireAppliedOfflineLanguagePlanProductionMutants
  Discovery -> RequireExactOfflineLanguagePlanSourceDiscovery
  Challenge -> RequirePostAcquisitionOfflineLanguagePlanChallenge
  Observer -> RequireOfflineLanguagePlanProcessObservation
  AuthorityBypass -> RequireNoPbNetworkBrowserStorageReplayHostHardwareOrParallelism
  Freshness -> RequireFreshOfflineLanguagePlanBuildRootAndStableSource
  Qualification -> RequireQualifiedOfflineLanguagePlanHarness
  Cleanroom -> RequireOfflineLanguagePlanProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredOfflineLanguagePlanAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseFortyReceipt
  Residue -> RequireBrowserStorageServerReplayAndPublicationOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseFortyOneGatePass

phaseFortyTwoRequirement :: GateCategory -> PhaseFortyTwoRequirement
phaseFortyTwoRequirement category = case category of
  Claim -> RequirePureGenericUiBrowserInterpreterSemantics
  Subject -> RequireAcquiredUiBrowserInterpreterSupervisor
  Command -> RequireDirectOfflineSerialUiBrowserInterpreterMatrix
  Oracle -> RequireIndependentUiBrowserInterpreterOracle
  PositiveControls -> RequireUiBrowserInterpreterPositiveControls
  PairedNegatives -> RequireExactUiBrowserInterpreterPairedNegatives
  Mutants -> RequireAppliedUiBrowserInterpreterProductionMutants
  Discovery -> RequireExactUiBrowserInterpreterSourceDiscovery
  Challenge -> RequirePostAcquisitionUiBrowserInterpreterChallenge
  Observer -> RequireUiBrowserInterpreterProcessObservation
  AuthorityBypass -> RequireNoPbBrowserNodePythonNetworkHostHardwareOrParallelism
  Freshness -> RequireFreshUiBrowserInterpreterBuildRootAndStableSource
  Qualification -> RequireQualifiedUiBrowserInterpreterHarness
  Cleanroom -> RequireUiBrowserInterpreterProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredUiBrowserInterpreterAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseFortyOneReceipt
  Residue -> RequireLiveBrowserServerProviderReleaseAndHaOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseFortyTwoGatePass

phaseFortyThreeRequirement :: GateCategory -> PhaseFortyThreeRequirement
phaseFortyThreeRequirement category = case category of
  Claim -> RequireAuthenticatedScopedUiServerBoundary
  Subject -> RequireAcquiredUiServerBoundarySupervisor
  Command -> RequireDirectOfflineSerialUiServerBoundaryMatrix
  Oracle -> RequireIndependentUiServerBoundaryOracle
  PositiveControls -> RequireUiServerBoundaryPositiveControls
  PairedNegatives -> RequireExactUiServerBoundaryPairedNegatives
  Mutants -> RequireAppliedUiServerBoundaryProductionMutants
  Discovery -> RequireExactUiServerBoundarySourceDiscovery
  Challenge -> RequirePostAcquisitionUiServerBoundaryChallenge
  Observer -> RequireUiServerBoundaryProcessObservation
  AuthorityBypass -> RequireNoPbNodeNetworkLiveIdentityProviderHostHardwareOrParallelism
  Freshness -> RequireFreshUiServerBoundaryBuildRootAndStableSource
  Qualification -> RequireQualifiedUiServerBoundaryHarness
  Cleanroom -> RequireUiServerBoundaryProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredUiServerBoundaryAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseFortyTwoReceipt
  Residue -> RequireLiveIdentityProviderBrowserDeploymentAndHaOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseFortyThreeGatePass

phaseFortyFourRequirement :: GateCategory -> PhaseFortyFourRequirement
phaseFortyFourRequirement category = case category of
  Claim -> RequireHardwareFreeHaskellUiComposition
  Subject -> RequireAcquiredUiLocalCompositionSupervisor
  Command -> RequireDirectOfflineSerialUiLocalCompositionMatrix
  Oracle -> RequireIndependentUiLocalCompositionOracle
  PositiveControls -> RequireUiLocalCompositionPositiveControls
  PairedNegatives -> RequireExactUiLocalCompositionPairedNegatives
  Mutants -> RequireAppliedUiLocalCompositionProductionMutants
  Discovery -> RequireExactUiLocalCompositionSourceDiscovery
  Challenge -> RequirePostAcquisitionUiLocalCompositionChallenge
  Observer -> RequireUiLocalCompositionProcessObservation
  AuthorityBypass -> RequireNoPbNodeDhallNetworkLiveProviderHostHardwareOrParallelism
  Freshness -> RequireFreshUiLocalCompositionBuildRootAndStableSource
  Qualification -> RequireQualifiedUiLocalCompositionHarness
  Cleanroom -> RequireUiLocalCompositionProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredUiLocalCompositionAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseFortyThreeReceipt
  Residue -> RequireLiveWorkflowProviderBrowserDeploymentReleaseAndHaOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseFortyFourGatePass

phaseFortyFiveRequirement :: GateCategory -> PhaseFortyFiveRequirement
phaseFortyFiveRequirement category = case category of
  Claim -> RequireHaskellEncryptedOfflineStateAndRuntimeProjection
  Subject -> RequireAcquiredEncryptedBrowserRuntimeSupervisor
  Command -> RequireDirectOfflineSerialEncryptedBrowserRuntimeMatrix
  Oracle -> RequireIndependentEncryptedBrowserRuntimeOracle
  PositiveControls -> RequireEncryptedBrowserRuntimePositiveControls
  PairedNegatives -> RequireExactEncryptedBrowserRuntimePairedNegatives
  Mutants -> RequireAppliedEncryptedBrowserRuntimeProductionMutants
  Discovery -> RequireExactEncryptedBrowserRuntimeSourceDiscovery
  Challenge -> RequirePostAcquisitionEncryptedBrowserRuntimeChallenge
  Observer -> RequireEncryptedBrowserRuntimeProcessObservation
  AuthorityBypass -> RequireNoPbBrowserNodePurescriptJavascriptDhallNetworkLiveHostHardwareOrParallelism
  Freshness -> RequireFreshEncryptedBrowserRuntimeBuildRootAndStableSource
  Qualification -> RequireQualifiedEncryptedBrowserRuntimeHarness
  Cleanroom -> RequireEncryptedBrowserRuntimeProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredEncryptedBrowserRuntimeAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseFortyFourReceipt
  Residue -> RequireLiveBrowserStorageCryptoLockServiceWorkerReplayReleaseHaAndHardwareOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseFortyFiveGatePass

phaseFortySixRequirement :: GateCategory -> PhaseFortySixRequirement
phaseFortySixRequirement category = case category of
  Claim -> RequireHaskellGeneratedBrowserContractsAndBundle
  Subject -> RequireAcquiredUiContractGenerationSupervisor
  Command -> RequireDirectOfflineSerialUiContractGenerationMatrix
  Oracle -> RequireIndependentUiContractGenerationOracle
  PositiveControls -> RequireUiContractGenerationPositiveControls
  PairedNegatives -> RequireExactUiContractGenerationPairedNegatives
  Mutants -> RequireAppliedUiContractGenerationProductionMutants
  Discovery -> RequireExactUiContractGenerationSourceDiscovery
  Challenge -> RequirePostAcquisitionUiContractGenerationChallenge
  Observer -> RequireUiContractGenerationProcessObservation
  AuthorityBypass -> RequireNoPbBrowserNodePurescriptJavascriptNetworkLiveHostHardwareOrParallelism
  Freshness -> RequireFreshUiContractGenerationBuildRootAndStableSource
  Qualification -> RequireQualifiedUiContractGenerationHarness
  Cleanroom -> RequireUiContractGenerationProductsContainedBelowBuild
  LegacyClosure -> RequireRetiredUiContractGenerationAuthoritiesAbsent
  PredecessorCategory -> RequireExactPhaseFortyFiveReceipt
  Residue -> RequireBrowserCompileExecutionProtocolPublicationDeploymentHaAndHardwareOwnersExplicit
  PassCriterion -> RequireQualifiedPhaseFortySixGatePass

phaseOneRequirement :: GateCategory -> PhaseOneRequirement
phaseOneRequirement category = case category of
  Claim -> RequireAuthenticatedReproducibleToolchainAndProbeClosure
  Subject -> RequireAcquiredToolchainSpikeSupervisor
  Command -> RequireDirectOfflineSerialToolchainInvocation
  Oracle -> RequireIndependentToolchainProbeOracle
  PositiveControls -> RequireCompleteRepresentativeProbeControls
  PairedNegatives -> RequireToolchainProbePairedNegatives
  Mutants -> RequireAppliedToolchainPolicyMutants
  Discovery -> RequireExactDependencyAndProbeDiscovery
  Challenge -> RequirePostStartProbeChallenge
  Observer -> RequireProcessExitStdoutAndDigestObservation
  AuthorityBypass -> RequireNoNetworkHardwareOrAuthBypass
  Freshness -> RequireTwoFreshBuildRootsAndStableSource
  Qualification -> RequireQualifiedToolchainHarness
  Cleanroom -> RequireRunScopedGeneratedProductsAndCleanup
  LegacyClosure -> RequirePhaseOneLegacyFamiliesClosed
  PredecessorCategory -> RequireExactPhaseZeroReceipt
  Residue -> RequireGenesisAssumptionAndLaterClaimsExplicit
  PassCriterion -> RequireQualifiedPhaseOneGatePass

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
  RequirePhaseOne phaseOne -> phaseOneRequirementCategory phaseOne
  RequirePhaseTwo phaseTwo -> phaseTwoRequirementCategory phaseTwo
  RequirePhaseThree phaseThree -> phaseThreeRequirementCategory phaseThree
  RequirePhaseFour phaseFour -> phaseFourRequirementCategory phaseFour
  RequirePhaseFive phaseFive -> phaseFiveRequirementCategory phaseFive
  RequirePhaseSix phaseSix -> phaseSixRequirementCategory phaseSix
  RequirePhaseSeven phaseSeven -> phaseSevenRequirementCategory phaseSeven
  RequirePhaseEight phaseEight -> phaseEightRequirementCategory phaseEight
  RequirePhaseNine phaseNine -> phaseNineRequirementCategory phaseNine
  RequirePhaseTen phaseTen -> phaseTenRequirementCategory phaseTen
  RequirePhaseEleven phaseEleven -> phaseElevenRequirementCategory phaseEleven
  RequirePhaseTwelve phaseTwelve -> phaseTwelveRequirementCategory phaseTwelve
  RequirePhaseThirteen phaseThirteen -> phaseThirteenRequirementCategory phaseThirteen
  RequirePhaseFourteen phaseFourteen -> phaseFourteenRequirementCategory phaseFourteen
  RequirePhaseFifteen phaseFifteen -> phaseFifteenRequirementCategory phaseFifteen
  RequirePhaseSixteen phaseSixteen -> phaseSixteenRequirementCategory phaseSixteen
  RequirePhaseSeventeen phaseSeventeen -> phaseSeventeenRequirementCategory phaseSeventeen
  RequirePhaseEighteen phaseEighteen -> phaseEighteenRequirementCategory phaseEighteen
  RequirePhaseNineteen phaseNineteen -> phaseNineteenRequirementCategory phaseNineteen
  RequirePhaseTwenty phaseTwenty -> phaseTwentyRequirementCategory phaseTwenty
  RequirePhaseTwentyOne phaseTwentyOne -> phaseTwentyOneRequirementCategory phaseTwentyOne
  RequirePhaseTwentyTwo phaseTwentyTwo -> phaseTwentyTwoRequirementCategory phaseTwentyTwo
  RequirePhaseTwentyThree phaseTwentyThree -> phaseTwentyThreeRequirementCategory phaseTwentyThree
  RequirePhaseTwentyFour phaseTwentyFour -> phaseTwentyFourRequirementCategory phaseTwentyFour
  RequirePhaseTwentyFive phaseTwentyFive -> phaseTwentyFiveRequirementCategory phaseTwentyFive
  RequirePhaseTwentySix phaseTwentySix -> phaseTwentySixRequirementCategory phaseTwentySix
  RequirePhaseTwentySeven phaseTwentySeven -> phaseTwentySevenRequirementCategory phaseTwentySeven
  RequirePhaseTwentyEight phaseTwentyEight -> phaseTwentyEightRequirementCategory phaseTwentyEight
  RequirePhaseTwentyNine phaseTwentyNine -> phaseTwentyNineRequirementCategory phaseTwentyNine
  RequirePhaseThirty phaseThirty -> phaseThirtyRequirementCategory phaseThirty
  RequirePhaseThirtyOne phaseThirtyOne -> phaseThirtyOneRequirementCategory phaseThirtyOne
  RequirePhaseThirtyTwo phaseThirtyTwo -> phaseThirtyTwoRequirementCategory phaseThirtyTwo
  RequirePhaseThirtyThree phaseThirtyThree -> phaseThirtyThreeRequirementCategory phaseThirtyThree
  RequirePhaseThirtyFour phaseThirtyFour -> phaseThirtyFourRequirementCategory phaseThirtyFour
  RequirePhaseThirtyFive phaseThirtyFive -> phaseThirtyFiveRequirementCategory phaseThirtyFive
  RequirePhaseThirtySix phaseThirtySix -> phaseThirtySixRequirementCategory phaseThirtySix
  RequirePhaseThirtySeven phaseThirtySeven -> phaseThirtySevenRequirementCategory phaseThirtySeven
  RequirePhaseThirtyEight phaseThirtyEight -> phaseThirtyEightRequirementCategory phaseThirtyEight
  RequirePhaseThirtyNine phaseThirtyNine -> phaseThirtyNineRequirementCategory phaseThirtyNine
  RequirePhaseForty phaseForty -> phaseFortyRequirementCategory phaseForty
  RequirePhaseFortyOne phaseFortyOne -> phaseFortyOneRequirementCategory phaseFortyOne
  RequirePhaseFortyTwo phaseFortyTwo -> phaseFortyTwoRequirementCategory phaseFortyTwo
  RequirePhaseFortyThree phaseFortyThree -> phaseFortyThreeRequirementCategory phaseFortyThree
  RequirePhaseFortyFour phaseFortyFour -> phaseFortyFourRequirementCategory phaseFortyFour
  RequirePhaseFortyFive phaseFortyFive -> phaseFortyFiveRequirementCategory phaseFortyFive
  RequirePhaseFortySix phaseFortySix -> phaseFortySixRequirementCategory phaseFortySix

phaseOneRequirementCategory :: PhaseOneRequirement -> GateCategory
phaseOneRequirementCategory requirement = case requirement of
  RequireAuthenticatedReproducibleToolchainAndProbeClosure -> Claim
  RequireAcquiredToolchainSpikeSupervisor -> Subject
  RequireDirectOfflineSerialToolchainInvocation -> Command
  RequireIndependentToolchainProbeOracle -> Oracle
  RequireCompleteRepresentativeProbeControls -> PositiveControls
  RequireToolchainProbePairedNegatives -> PairedNegatives
  RequireAppliedToolchainPolicyMutants -> Mutants
  RequireExactDependencyAndProbeDiscovery -> Discovery
  RequirePostStartProbeChallenge -> Challenge
  RequireProcessExitStdoutAndDigestObservation -> Observer
  RequireNoNetworkHardwareOrAuthBypass -> AuthorityBypass
  RequireTwoFreshBuildRootsAndStableSource -> Freshness
  RequireQualifiedToolchainHarness -> Qualification
  RequireRunScopedGeneratedProductsAndCleanup -> Cleanroom
  RequirePhaseOneLegacyFamiliesClosed -> LegacyClosure
  RequireExactPhaseZeroReceipt -> PredecessorCategory
  RequireGenesisAssumptionAndLaterClaimsExplicit -> Residue
  RequireQualifiedPhaseOneGatePass -> PassCriterion

phaseTwoRequirementCategory :: PhaseTwoRequirement -> GateCategory
phaseTwoRequirementCategory requirement = case requirement of
  RequireCompilerBackedRepositoryLayoutClosure -> Claim
  RequireAcquiredRepositoryLayoutSupervisor -> Subject
  RequireDirectOfflineSerialRepositoryBuild -> Command
  RequireIndependentRepositoryLayoutOracle -> Oracle
  RequireCleanRepositoryLayoutControls -> PositiveControls
  RequireRepositoryLayoutPairedNegatives -> PairedNegatives
  RequireAppliedRepositoryLayoutMutants -> Mutants
  RequireTwoWaySourceAndComponentDiscovery -> Discovery
  RequirePostStartRepositoryChallenge -> Challenge
  RequireCompilerProcessAndGraphObservation -> Observer
  RequireNoPbNetworkHardwareOrAmbientBypass -> AuthorityBypass
  RequireOpeningClosingSourceAndFreshBuildRoot -> Freshness
  RequireQualifiedRepositoryLayoutHarness -> Qualification
  RequireGeneratedProductsContainedBelowBuild -> Cleanroom
  RequirePhaseTwoLegacyFamiliesClosed -> LegacyClosure
  RequireExactPhaseOneReceipt -> PredecessorCategory
  RequireOnlyTypedLaterSourceDebt -> Residue
  RequireQualifiedPhaseTwoGatePass -> PassCriterion

phaseThreeRequirementCategory :: PhaseThreeRequirement -> GateCategory
phaseThreeRequirementCategory requirement = case requirement of
  RequireCompleteArtifactCalculus -> Claim
  RequireAcquiredArtifactCalculusSupervisor -> Subject
  RequireDirectSerialArtifactCompilerMatrix -> Command
  RequireIndependentArtifactCalculusOracle -> Oracle
  RequireArtifactCalculusPositiveControls -> PositiveControls
  RequireArtifactCalculusPairedNegatives -> PairedNegatives
  RequireAppliedArtifactCalculusMutants -> Mutants
  RequireExactArtifactCalculusDiscovery -> Discovery
  RequirePostAcquisitionArtifactChallenge -> Challenge
  RequireArtifactProcessObservation -> Observer
  RequireNoPbNetworkHardwareOrCompilerParallelism -> AuthorityBypass
  RequireFreshArtifactBuildRootsAndStableSource -> Freshness
  RequireQualifiedArtifactCalculusHarness -> Qualification
  RequireArtifactProductsContainedBelowBuild -> Cleanroom
  RequireNoPhaseThreeLegacyDebt -> LegacyClosure
  RequireExactPhaseTwoReceipt -> PredecessorCategory
  RequireLaterArtifactConsumersExplicit -> Residue
  RequireQualifiedPhaseThreeGatePass -> PassCriterion

phaseFourRequirementCategory :: PhaseFourRequirement -> GateCategory
phaseFourRequirementCategory requirement = case requirement of
  RequireCompleteBudgetCalculus -> Claim
  RequireAcquiredBudgetCalculusSupervisor -> Subject
  RequireDirectSerialBudgetCompilerMatrix -> Command
  RequireIndependentBudgetCalculusOracle -> Oracle
  RequireBudgetCalculusPositiveControls -> PositiveControls
  RequireBudgetCalculusPairedNegatives -> PairedNegatives
  RequireAppliedBudgetCalculusMutants -> Mutants
  RequireExactBudgetCalculusDiscovery -> Discovery
  RequirePostAcquisitionBudgetChallenge -> Challenge
  RequireBudgetProcessObservation -> Observer
  RequireNoPbNetworkHardwareOrBudgetCompilerParallelism -> AuthorityBypass
  RequireFreshBudgetBuildRootsAndStableSource -> Freshness
  RequireQualifiedBudgetCalculusHarness -> Qualification
  RequireBudgetProductsContainedBelowBuild -> Cleanroom
  RequireNoPhaseFourLegacyDebt -> LegacyClosure
  RequireExactPhaseThreeReceipt -> PredecessorCategory
  RequireLaterBudgetConsumersExplicit -> Residue
  RequireQualifiedPhaseFourGatePass -> PassCriterion

phaseFiveRequirementCategory :: PhaseFiveRequirement -> GateCategory
phaseFiveRequirementCategory requirement = case requirement of
  RequireCompleteLiftCalculus -> Claim
  RequireAcquiredLiftCalculusSupervisor -> Subject
  RequireDirectSerialLiftCompilerMatrix -> Command
  RequireIndependentLiftCalculusOracle -> Oracle
  RequireLiftCalculusPositiveControls -> PositiveControls
  RequireLiftCalculusPairedNegatives -> PairedNegatives
  RequireAppliedLiftCalculusMutants -> Mutants
  RequireExactLiftCalculusDiscovery -> Discovery
  RequirePostAcquisitionLiftChallenge -> Challenge
  RequireLiftProcessObservation -> Observer
  RequireNoPbNetworkHardwareOrLiftCompilerParallelism -> AuthorityBypass
  RequireFreshLiftBuildRootsAndStableSource -> Freshness
  RequireQualifiedLiftCalculusHarness -> Qualification
  RequireLiftProductsContainedBelowBuild -> Cleanroom
  RequireNoPhaseFiveLegacyDebt -> LegacyClosure
  RequireExactPhaseFourReceipt -> PredecessorCategory
  RequireLaterLiftConsumersExplicit -> Residue
  RequireQualifiedPhaseFiveGatePass -> PassCriterion

phaseSixRequirementCategory :: PhaseSixRequirement -> GateCategory
phaseSixRequirementCategory requirement = case requirement of
  RequireCompleteWorkflowCalculus -> Claim
  RequireAcquiredWorkflowCalculusSupervisor -> Subject
  RequireDirectSerialWorkflowCompilerMatrix -> Command
  RequireIndependentWorkflowCalculusOracle -> Oracle
  RequireWorkflowCalculusPositiveControls -> PositiveControls
  RequireWorkflowCalculusPairedNegatives -> PairedNegatives
  RequireAppliedWorkflowCalculusMutants -> Mutants
  RequireExactWorkflowCalculusDiscovery -> Discovery
  RequirePostAcquisitionWorkflowChallenge -> Challenge
  RequireWorkflowProcessObservation -> Observer
  RequireNoPbNetworkHardwareOrWorkflowCompilerParallelism -> AuthorityBypass
  RequireFreshWorkflowBuildRootsAndStableSource -> Freshness
  RequireQualifiedWorkflowCalculusHarness -> Qualification
  RequireWorkflowProductsContainedBelowBuild -> Cleanroom
  RequireNoPhaseSixLegacyDebt -> LegacyClosure
  RequireExactPhaseFiveReceipt -> PredecessorCategory
  RequireLaterWorkflowConsumersExplicit -> Residue
  RequireQualifiedPhaseSixGatePass -> PassCriterion

phaseSevenRequirementCategory :: PhaseSevenRequirement -> GateCategory
phaseSevenRequirementCategory requirement = case requirement of
  RequireCompleteEvidenceCalculus -> Claim
  RequireAcquiredEvidenceCalculusSupervisor -> Subject
  RequireDirectSerialEvidenceCompilerMatrix -> Command
  RequireIndependentEvidenceCalculusOracle -> Oracle
  RequireEvidenceCalculusPositiveControls -> PositiveControls
  RequireEvidenceCalculusPairedNegatives -> PairedNegatives
  RequireAppliedEvidenceCalculusMutants -> Mutants
  RequireExactEvidenceCalculusDiscovery -> Discovery
  RequirePostAcquisitionEvidenceChallenge -> Challenge
  RequireEvidenceProcessObservation -> Observer
  RequireNoPbNetworkHardwareOrEvidenceCompilerParallelism -> AuthorityBypass
  RequireFreshEvidenceBuildRootsAndStableSource -> Freshness
  RequireQualifiedEvidenceCalculusHarness -> Qualification
  RequireEvidenceProductsContainedBelowBuild -> Cleanroom
  RequireNoPhaseSevenLegacyDebt -> LegacyClosure
  RequireExactPhaseSixReceipt -> PredecessorCategory
  RequireLaterEvidenceConsumersExplicit -> Residue
  RequireQualifiedPhaseSevenGatePass -> PassCriterion

phaseEightRequirementCategory :: PhaseEightRequirement -> GateCategory
phaseEightRequirementCategory requirement = case requirement of
  RequireCompleteScopedIdentityKernel -> Claim
  RequireAcquiredScopeIndexSupervisor -> Subject
  RequireDirectSerialScopeCompilerMatrix -> Command
  RequireIndependentScopeIndexOracle -> Oracle
  RequireScopeIndexPositiveControls -> PositiveControls
  RequireScopeIndexPairedNegatives -> PairedNegatives
  RequireAppliedScopeIndexMutants -> Mutants
  RequireExactScopeIndexDiscovery -> Discovery
  RequirePostAcquisitionScopeChallenge -> Challenge
  RequireScopeProcessObservation -> Observer
  RequireNoPbNetworkHardwareOrScopeCompilerParallelism -> AuthorityBypass
  RequireFreshScopeBuildRootsAndStableSource -> Freshness
  RequireQualifiedScopeIndexHarness -> Qualification
  RequireScopeProductsContainedBelowBuild -> Cleanroom
  RequireNoPhaseEightLegacyDebt -> LegacyClosure
  RequireExactPhaseSevenReceipt -> PredecessorCategory
  RequireLaterScopeConsumersExplicit -> Residue
  RequireQualifiedPhaseEightGatePass -> PassCriterion

phaseNineRequirementCategory :: PhaseNineRequirement -> GateCategory
phaseNineRequirementCategory requirement = case requirement of
  RequireCompleteResourceIndex -> Claim
  RequireAcquiredResourceIndexSupervisor -> Subject
  RequireDirectSerialResourceCompilerMatrix -> Command
  RequireIndependentResourceIndexOracle -> Oracle
  RequireResourceIndexPositiveControls -> PositiveControls
  RequireResourceIndexPairedNegatives -> PairedNegatives
  RequireAppliedResourceIndexMutants -> Mutants
  RequireExactResourceIndexDiscovery -> Discovery
  RequirePostAcquisitionResourceChallenge -> Challenge
  RequireResourceProcessObservation -> Observer
  RequireNoPbNetworkHardwareOrResourceCompilerParallelism -> AuthorityBypass
  RequireFreshResourceBuildRootsAndStableSource -> Freshness
  RequireQualifiedResourceIndexHarness -> Qualification
  RequireResourceProductsContainedBelowBuild -> Cleanroom
  RequireNoPhaseNineLegacyDebt -> LegacyClosure
  RequireExactPhaseEightReceipt -> PredecessorCategory
  RequireLaterResourceConsumersExplicit -> Residue
  RequireQualifiedPhaseNineGatePass -> PassCriterion

phaseTenRequirementCategory :: PhaseTenRequirement -> GateCategory
phaseTenRequirementCategory requirement = case requirement of
  RequireCompleteCalculusComposition -> Claim
  RequireAcquiredCalculusCompositionSupervisor -> Subject
  RequireDirectSerialCompositionCompilerMatrix -> Command
  RequireIndependentCalculusCompositionOracle -> Oracle
  RequireCalculusCompositionPositiveControls -> PositiveControls
  RequireCalculusCompositionPairedNegatives -> PairedNegatives
  RequireAppliedCalculusCompositionMutants -> Mutants
  RequireExactCalculusCompositionDiscovery -> Discovery
  RequirePostAcquisitionCompositionChallenge -> Challenge
  RequireCompositionProcessObservation -> Observer
  RequireNoPbNetworkHardwareOrCompositionCompilerParallelism -> AuthorityBypass
  RequireFreshCompositionBuildRootsAndStableSource -> Freshness
  RequireQualifiedCalculusCompositionHarness -> Qualification
  RequireCompositionProductsContainedBelowBuild -> Cleanroom
  RequireNoPhaseTenLegacyDebt -> LegacyClosure
  RequireExactPhaseNineReceipt -> PredecessorCategory
  RequireLaterCompositionConsumersExplicit -> Residue
  RequireQualifiedPhaseTenGatePass -> PassCriterion

phaseElevenRequirementCategory :: PhaseElevenRequirement -> GateCategory
phaseElevenRequirementCategory requirement = case requirement of
  RequireCompleteFormalModelKernel -> Claim
  RequireAcquiredFormalModelKernelSupervisor -> Subject
  RequireDirectSerialFormalModelCompilerMatrix -> Command
  RequireIndependentFormalModelSemanticOracle -> Oracle
  RequireFormalModelPositiveControls -> PositiveControls
  RequireFormalModelPairedNegatives -> PairedNegatives
  RequireAppliedFormalModelProductionMutants -> Mutants
  RequireExactFormalModelSourceDiscovery -> Discovery
  RequirePostAcquisitionFormalModelChallenge -> Challenge
  RequireFormalModelProcessObservation -> Observer
  RequireNoPbNetworkJvmHardwareOrFormalModelCompilerParallelism -> AuthorityBypass
  RequireFreshFormalModelBuildRootsAndStableSource -> Freshness
  RequireQualifiedFormalModelHarness -> Qualification
  RequireFormalModelProductsContainedBelowBuild -> Cleanroom
  RequireRetiredFormalModelBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseTenReceipt -> PredecessorCategory
  RequireLaterCheckerAndRuntimeClaimsExplicit -> Residue
  RequireQualifiedPhaseElevenGatePass -> PassCriterion

phaseTwelveRequirementCategory :: PhaseTwelveRequirement -> GateCategory
phaseTwelveRequirementCategory requirement = case requirement of
  RequireCompleteExplicitStateChecker -> Claim
  RequireAcquiredExplicitStateCheckerSupervisor -> Subject
  RequireDirectSerialExplicitStateCompilerMatrix -> Command
  RequireIndependentExplicitStateSemanticOracle -> Oracle
  RequireExplicitStatePositiveControls -> PositiveControls
  RequireExplicitStatePairedNegatives -> PairedNegatives
  RequireAppliedExplicitStateProductionMutants -> Mutants
  RequireExactExplicitStateSourceDiscovery -> Discovery
  RequirePostAcquisitionExplicitStateChallenge -> Challenge
  RequireExplicitStateProcessObservation -> Observer
  RequireNoPbNetworkJvmHardwareOrExplicitStateCompilerParallelism -> AuthorityBypass
  RequireFreshExplicitStateBuildRootsAndStableSource -> Freshness
  RequireQualifiedExplicitStateHarness -> Qualification
  RequireExplicitStateProductsContainedBelowBuild -> Cleanroom
  RequireRetiredExplicitStateBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseElevenReceipt -> PredecessorCategory
  RequireLaterCheckerSimulationAndRuntimeClaimsExplicit -> Residue
  RequireQualifiedPhaseTwelveGatePass -> PassCriterion

phaseThirteenRequirementCategory :: PhaseThirteenRequirement -> GateCategory
phaseThirteenRequirementCategory requirement = case requirement of
  RequireCompleteSymbolicChecker -> Claim
  RequireAcquiredSymbolicCheckerSupervisor -> Subject
  RequireDirectSerialSymbolicCompilerMatrix -> Command
  RequireIndependentSymbolicSemanticOracle -> Oracle
  RequireSymbolicPositiveControls -> PositiveControls
  RequireSymbolicPairedNegatives -> PairedNegatives
  RequireAppliedSymbolicProductionMutants -> Mutants
  RequireExactSymbolicSourceDiscovery -> Discovery
  RequirePostAcquisitionSymbolicChallenge -> Challenge
  RequireSymbolicProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrSymbolicCompilerParallelism -> AuthorityBypass
  RequireFreshSymbolicBuildRootsAndStableSource -> Freshness
  RequireQualifiedSymbolicHarness -> Qualification
  RequireSymbolicProductsContainedBelowBuild -> Cleanroom
  RequireRetiredSymbolicBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseTwelveReceipt -> PredecessorCategory
  RequireLaterRefinementSimulationAndRuntimeClaimsExplicit -> Residue
  RequireQualifiedPhaseThirteenGatePass -> PassCriterion

phaseFourteenRequirementCategory :: PhaseFourteenRequirement -> GateCategory
phaseFourteenRequirementCategory requirement = case requirement of
  RequireCompleteRefinementChecker -> Claim
  RequireAcquiredRefinementCheckerSupervisor -> Subject
  RequireDirectSerialRefinementCompilerMatrix -> Command
  RequireIndependentRefinementSemanticOracle -> Oracle
  RequireRefinementPositiveControls -> PositiveControls
  RequireRefinementPairedNegatives -> PairedNegatives
  RequireAppliedRefinementProductionMutants -> Mutants
  RequireExactRefinementSourceDiscovery -> Discovery
  RequirePostAcquisitionRefinementChallenge -> Challenge
  RequireRefinementProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrRefinementCompilerParallelism -> AuthorityBypass
  RequireFreshRefinementBuildRootsAndStableSource -> Freshness
  RequireQualifiedRefinementHarness -> Qualification
  RequireRefinementProductsContainedBelowBuild -> Cleanroom
  RequireRetiredRefinementBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseThirteenReceipt -> PredecessorCategory
  RequireLaterCompileFailSimulationAndRuntimeClaimsExplicit -> Residue
  RequireQualifiedPhaseFourteenGatePass -> PassCriterion

phaseFifteenRequirementCategory :: PhaseFifteenRequirement -> GateCategory
phaseFifteenRequirementCategory requirement = case requirement of
  RequireCompleteCompileFailHarness -> Claim
  RequireAcquiredCompileFailHarnessSupervisor -> Subject
  RequireDirectSerialCompileFailCompilerMatrix -> Command
  RequireIndependentCompileFailCorpusOracle -> Oracle
  RequireCompileFailLegalTwinControls -> PositiveControls
  RequireCompileFailPinnedIllegalTwins -> PairedNegatives
  RequireAppliedCompileFailProductionMutants -> Mutants
  RequireExactCompileFailSourceDiscovery -> Discovery
  RequirePostAcquisitionCompileFailChallenge -> Challenge
  RequireCompileFailProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrCompileFailParallelism -> AuthorityBypass
  RequireFreshCompileFailBuildRootsAndStableSource -> Freshness
  RequireQualifiedCompileFailHarness -> Qualification
  RequireCompileFailProductsContainedBelowBuild -> Cleanroom
  RequireRetiredCompileFailBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseFourteenReceipt -> PredecessorCategory
  RequireLaterSimulationAndRuntimeClaimsExplicit -> Residue
  RequireQualifiedPhaseFifteenGatePass -> PassCriterion

phaseSixteenRequirementCategory :: PhaseSixteenRequirement -> GateCategory
phaseSixteenRequirementCategory requirement = case requirement of
  RequireCompleteDeterministicSimulationSubstrate -> Claim
  RequireAcquiredDeterministicSimulationSupervisor -> Subject
  RequireDirectOfflineSerialSimulationMatrix -> Command
  RequireIndependentDeterministicSimulationOracle -> Oracle
  RequireTwoInterpreterSimulationControls -> PositiveControls
  RequireFaultKnobAndSchedulePairedNegatives -> PairedNegatives
  RequireAppliedDeterministicSimulationProductionMutants -> Mutants
  RequireExactDeterministicSimulationSourceDiscovery -> Discovery
  RequirePostAcquisitionDeterministicSimulationChallenge -> Challenge
  RequireDeterministicSimulationProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrSimulationParallelism -> AuthorityBypass
  RequireFreshSimulationBuildRootAndStableSource -> Freshness
  RequireQualifiedDeterministicSimulationHarness -> Qualification
  RequireSimulationProductsContainedBelowBuild -> Cleanroom
  RequireRetiredSimulationBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseFifteenReceipt -> PredecessorCategory
  RequireLaterModelsRuntimesAndHardwareExplicit -> Residue
  RequireQualifiedPhaseSixteenGatePass -> PassCriterion

phaseSeventeenRequirementCategory :: PhaseSeventeenRequirement -> GateCategory
phaseSeventeenRequirementCategory requirement = case requirement of
  RequireCompleteGatewayMigrationModel -> Claim
  RequireAcquiredGatewayMigrationModelSupervisor -> Subject
  RequireDirectOfflineSerialGatewayModelMatrix -> Command
  RequireIndependentGatewayMigrationOracle -> Oracle
  RequireGatewayExplorerTlcAndScheduleControls -> PositiveControls
  RequireGatewayInvariantFairnessAndCutoffNegatives -> PairedNegatives
  RequireAppliedGatewayMigrationProductionMutants -> Mutants
  RequireExactGatewayMigrationSourceDiscovery -> Discovery
  RequirePostAcquisitionGatewayMigrationChallenge -> Challenge
  RequireGatewayMigrationProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrGatewayParallelism -> AuthorityBypass
  RequireFreshGatewayBuildRootAndStableSource -> Freshness
  RequireQualifiedGatewayMigrationHarness -> Qualification
  RequireGatewayProductsContainedBelowBuild -> Cleanroom
  RequireRetiredGatewayBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseSixteenReceipt -> PredecessorCategory
  RequireGatewayRuntimeFidelityAndDecompositionExplicit -> Residue
  RequireQualifiedPhaseSeventeenGatePass -> PassCriterion

phaseEighteenRequirementCategory :: PhaseEighteenRequirement -> GateCategory
phaseEighteenRequirementCategory requirement = case requirement of
  RequireCompleteDslFormalModel -> Claim
  RequireAcquiredDslFormalModelSupervisor -> Subject
  RequireDirectOfflineSerialDslFormalMatrix -> Command
  RequireIndependentDslFormalOracle -> Oracle
  RequireDslModelCapacityCalculusAndProtocolControls -> PositiveControls
  RequireDslSafetyFairnessAndDecisionNegatives -> PairedNegatives
  RequireAppliedDslFormalProductionMutants -> Mutants
  RequireExactDslFormalSourceDiscovery -> Discovery
  RequirePostAcquisitionDslFormalChallenge -> Challenge
  RequireDslFormalProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrDslFormalParallelism -> AuthorityBypass
  RequireFreshDslFormalBuildRootAndStableSource -> Freshness
  RequireQualifiedDslFormalHarness -> Qualification
  RequireDslFormalProductsContainedBelowBuild -> Cleanroom
  RequireRetiredDslFormalBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseSeventeenReceipt -> PredecessorCategory
  RequireLaterDslRuntimeAndProjectionOwnersExplicit -> Residue
  RequireQualifiedPhaseEighteenGatePass -> PassCriterion

phaseNineteenRequirementCategory :: PhaseNineteenRequirement -> GateCategory
phaseNineteenRequirementCategory requirement = case requirement of
  RequireCompleteReconcileCoreSimulation -> Claim
  RequireAcquiredReconcileCoreSupervisor -> Subject
  RequireDirectOfflineSerialReconcileCoreMatrix -> Command
  RequireIndependentReconcileCoreOracle -> Oracle
  RequireReconcileCoreScheduleProtocolAndFormalControls -> PositiveControls
  RequireReconcileCorePairedNegatives -> PairedNegatives
  RequireAppliedReconcileCoreProductionMutants -> Mutants
  RequireExactReconcileCoreSourceDiscovery -> Discovery
  RequirePostAcquisitionReconcileCoreChallenge -> Challenge
  RequireReconcileCoreProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrReconcileCoreParallelism -> AuthorityBypass
  RequireFreshReconcileCoreBuildRootAndStableSource -> Freshness
  RequireQualifiedReconcileCoreHarness -> Qualification
  RequireReconcileCoreProductsContainedBelowBuild -> Cleanroom
  RequireRetiredReconcileCoreBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseEighteenReceipt -> PredecessorCategory
  RequireLaterEffectfulReconcileRuntimeExplicit -> Residue
  RequireQualifiedPhaseNineteenGatePass -> PassCriterion

phaseTwentyRequirementCategory :: PhaseTwentyRequirement -> GateCategory
phaseTwentyRequirementCategory requirement = case requirement of
  RequireCompleteIndexedExtensionDeclaration -> Claim
  RequireAcquiredExtensionDeclarationSupervisor -> Subject
  RequireDirectOfflineSerialExtensionDeclarationMatrix -> Command
  RequireIndependentExtensionDeclarationOracle -> Oracle
  RequireDeclarationReaderResourceAndDigestControls -> PositiveControls
  RequireDeclarationSemanticAndCompileNegatives -> PairedNegatives
  RequireAppliedExtensionDeclarationProductionMutants -> Mutants
  RequireExactExtensionDeclarationSourceDiscovery -> Discovery
  RequirePostAcquisitionExtensionDeclarationChallenge -> Challenge
  RequireExtensionDeclarationProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrExtensionDeclarationParallelism -> AuthorityBypass
  RequireFreshExtensionDeclarationBuildRootAndStableSource -> Freshness
  RequireQualifiedExtensionDeclarationHarness -> Qualification
  RequireExtensionDeclarationProductsContainedBelowBuild -> Cleanroom
  RequireRetiredExtensionDeclarationBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseNineteenReceipt -> PredecessorCategory
  RequireLaterExtensionLawAndRuntimeOwnersExplicit -> Residue
  RequireQualifiedPhaseTwentyGatePass -> PassCriterion

phaseTwentyOneRequirementCategory :: PhaseTwentyOneRequirement -> GateCategory
phaseTwentyOneRequirementCategory requirement = case requirement of
  RequireCompletePerExtensionLawEvaluator -> Claim
  RequireAcquiredExtensionLawsSupervisor -> Subject
  RequireDirectOfflineSerialExtensionLawsMatrix -> Command
  RequireIndependentExtensionLawsOracle -> Oracle
  RequireLawfulOperationRenderBudgetAndEvidenceControls -> PositiveControls
  RequireSingleLawAndClaimCompileNegatives -> PairedNegatives
  RequireAppliedExtensionLawsProductionMutants -> Mutants
  RequireExactExtensionLawsSourceDiscovery -> Discovery
  RequirePostAcquisitionExtensionLawsChallenge -> Challenge
  RequireExtensionLawsProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrExtensionLawsParallelism -> AuthorityBypass
  RequireFreshExtensionLawsBuildRootAndStableSource -> Freshness
  RequireQualifiedExtensionLawsHarness -> Qualification
  RequireExtensionLawsProductsContainedBelowBuild -> Cleanroom
  RequireRetiredExtensionLawsBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseTwentyReceipt -> PredecessorCategory
  RequireLaterCompositionalSecurityConformanceAndRuntimeOwnersExplicit -> Residue
  RequireQualifiedPhaseTwentyOneGatePass -> PassCriterion

phaseTwentyTwoRequirementCategory :: PhaseTwentyTwoRequirement -> GateCategory
phaseTwentyTwoRequirementCategory requirement = case requirement of
  RequireCompleteNormalizedCompositeAndC1C7Evaluator -> Claim
  RequireAcquiredExtensionCompositionSupervisor -> Subject
  RequireDirectOfflineSerialExtensionCompositionMatrix -> Command
  RequireIndependentExtensionCompositionOracle -> Oracle
  RequireLawfulCompositionIdentityAssociationBudgetAndAddressControls -> PositiveControls
  RequireCompositionLawAndRequestScopeNegatives -> PairedNegatives
  RequireAppliedExtensionCompositionProductionMutants -> Mutants
  RequireExactExtensionCompositionSourceDiscovery -> Discovery
  RequirePostAcquisitionExtensionCompositionChallenge -> Challenge
  RequireExtensionCompositionProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrExtensionCompositionParallelism -> AuthorityBypass
  RequireFreshExtensionCompositionBuildRootAndStableSource -> Freshness
  RequireQualifiedExtensionCompositionHarness -> Qualification
  RequireExtensionCompositionProductsContainedBelowBuild -> Cleanroom
  RequireRetiredExtensionCompositionBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseTwentyOneReceipt -> PredecessorCategory
  RequireLaterSecurityConformanceProofAndRuntimeOwnersExplicit -> Residue
  RequireQualifiedPhaseTwentyTwoGatePass -> PassCriterion

phaseTwentyThreeRequirementCategory :: PhaseTwentyThreeRequirement -> GateCategory
phaseTwentyThreeRequirementCategory requirement = case requirement of
  RequireBoundedTypedSecurityKernelAndS1S6Evaluator -> Claim
  RequireAcquiredExtensionSecuritySupervisor -> Subject
  RequireDirectOfflineSerialExtensionSecurityMatrix -> Command
  RequireIndependentExtensionSecurityOracle -> Oracle
  RequireIdentityOperationRefusalNamespaceAndPolicyControls -> PositiveControls
  RequireSecurityLawAndFourCompilerBarrierNegatives -> PairedNegatives
  RequireAppliedExtensionSecurityProductionMutants -> Mutants
  RequireExactExtensionSecuritySourceDiscovery -> Discovery
  RequirePostAcquisitionExtensionSecurityChallenge -> Challenge
  RequireExtensionSecurityProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrExtensionSecurityParallelism -> AuthorityBypass
  RequireFreshExtensionSecurityBuildRootAndStableSource -> Freshness
  RequireQualifiedExtensionSecurityHarness -> Qualification
  RequireExtensionSecurityProductsContainedBelowBuild -> Cleanroom
  RequireRetiredExtensionSecurityBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseTwentyTwoReceipt -> PredecessorCategory
  RequireLaterSecurityClosureConformanceCryptoTimingAndRuntimeOwnersExplicit -> Residue
  RequireQualifiedPhaseTwentyThreeGatePass -> PassCriterion

phaseTwentyFourRequirementCategory :: PhaseTwentyFourRequirement -> GateCategory
phaseTwentyFourRequirementCategory requirement = case requirement of
  RequireDeclarationDerivedConformancePlanVerdictAndAdmission -> Claim
  RequireAcquiredConformanceGateSupervisor -> Subject
  RequireDirectOfflineSerialConformanceGateMatrix -> Command
  RequireIndependentConformanceGateOracle -> Oracle
  RequireSuiteCoverageVerdictAndAdmissionControls -> PositiveControls
  RequireConformanceRefusalAndCompilerBarrierNegatives -> PairedNegatives
  RequireAppliedConformanceGateProductionMutants -> Mutants
  RequireExactConformanceGateSourceDiscovery -> Discovery
  RequirePostAcquisitionConformanceGateChallenge -> Challenge
  RequireConformanceGateProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrConformanceGateParallelism -> AuthorityBypass
  RequireFreshConformanceGateBuildRootAndStableSource -> Freshness
  RequireQualifiedConformanceGateHarness -> Qualification
  RequireConformanceGateProductsContainedBelowBuild -> Cleanroom
  RequireRetiredConformanceGateBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseTwentyThreeReceipt -> PredecessorCategory
  RequireLaterTransactionObserverSemanticClosureAndRuntimeOwnersExplicit -> Residue
  RequireQualifiedPhaseTwentyFourGatePass -> PassCriterion

phaseTwentyFiveRequirementCategory :: PhaseTwentyFiveRequirement -> GateCategory
phaseTwentyFiveRequirementCategory requirement = case requirement of
  RequireHaskellDerivedDhallStructuralLanguage -> Claim
  RequireAcquiredDhallSchemaSupervisor -> Subject
  RequireDirectOfflineSerialDhallSchemaMatrix -> Command
  RequireIndependentDhallSchemaOracle -> Oracle
  RequireSchemaModuleAndPositiveTypecheckControls -> PositiveControls
  RequirePairedDhallStructuralAndImportNegatives -> PairedNegatives
  RequireAppliedDhallSchemaProductionMutants -> Mutants
  RequireExactDhallSchemaSourceDiscovery -> Discovery
  RequirePostAcquisitionDhallSchemaChallenge -> Challenge
  RequireDhallSchemaProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrDhallSchemaParallelism -> AuthorityBypass
  RequireFreshDhallSchemaBuildRootAndStableSource -> Freshness
  RequireQualifiedDhallSchemaHarness -> Qualification
  RequireDhallSchemaProductsContainedBelowBuild -> Cleanroom
  RequireRetiredDhallBehavioralSourcesAbsent -> LegacyClosure
  RequireExactPhaseTwentyFourReceipt -> PredecessorCategory
  RequireLaterBindingDecodeProvisionRuntimeOwnersExplicit -> Residue
  RequireQualifiedPhaseTwentyFiveGatePass -> PassCriterion

phaseTwentySixRequirementCategory :: PhaseTwentySixRequirement -> GateCategory
phaseTwentySixRequirementCategory requirement = case requirement of
  RequireHaskellProtocolAndIndexedDecodeBoundary -> Claim
  RequireAcquiredGadtDecodeSupervisor -> Subject
  RequireDirectOfflineSerialGadtDecodeMatrix -> Command
  RequireIndependentGadtDecodeOracle -> Oracle
  RequireControllerIndexedPositiveDecodeControls -> PositiveControls
  RequirePairedGadtDecodeNegatives -> PairedNegatives
  RequireAppliedGadtDecodeProductionMutants -> Mutants
  RequireExactGadtDecodeSourceDiscovery -> Discovery
  RequirePostAcquisitionGadtDecodeChallenge -> Challenge
  RequireGadtDecodeProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrGadtDecodeParallelism -> AuthorityBypass
  RequireFreshGadtDecodeBuildRootAndStableSource -> Freshness
  RequireQualifiedGadtDecodeHarness -> Qualification
  RequireGadtDecodeProductsContainedBelowBuild -> Cleanroom
  RequireRetiredProtoAndGadtDecodeAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseTwentyFiveReceipt -> PredecessorCategory
  RequireLaterCapacityBindingProvisionRuntimeOwnersExplicit -> Residue
  RequireQualifiedPhaseTwentySixGatePass -> PassCriterion

phaseTwentySevenRequirementCategory :: PhaseTwentySevenRequirement -> GateCategory
phaseTwentySevenRequirementCategory requirement = case requirement of
  RequireClosedHaskellIllegalStateCoverageLedger -> Claim
  RequireAcquiredIllegalStateCoveringSupervisor -> Subject
  RequireDirectOfflineSerialIllegalStateCoveringMatrix -> Command
  RequireIndependentIllegalStateCoveringOracle -> Oracle
  RequireDhallDecodeCompileAndPropertyPositiveControls -> PositiveControls
  RequirePairedIllegalStateForeclosureNegatives -> PairedNegatives
  RequireAppliedIllegalStateCoveringProductionMutants -> Mutants
  RequireExactIllegalStateCoveringSourceDiscovery -> Discovery
  RequirePostAcquisitionIllegalStateCoveringChallenge -> Challenge
  RequireIllegalStateCoveringProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrIllegalStateParallelism -> AuthorityBypass
  RequireFreshIllegalStateBuildRootAndStableSource -> Freshness
  RequireQualifiedIllegalStateCoveringHarness -> Qualification
  RequireIllegalStateProductsContainedBelowBuild -> Cleanroom
  RequireRetiredBehavioralDocumentAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseTwentySixReceipt -> PredecessorCategory
  RequireLaterProvisionRenderRuntimeOwnersExplicit -> Residue
  RequireQualifiedPhaseTwentySevenGatePass -> PassCriterion

phaseTwentyEightRequirementCategory :: PhaseTwentyEightRequirement -> GateCategory
phaseTwentyEightRequirementCategory requirement = case requirement of
  RequirePureStorageGeometryFoldBoundary -> Claim
  RequireAcquiredStorageGeometrySupervisor -> Subject
  RequireDirectOfflineSerialStorageGeometryMatrix -> Command
  RequireIndependentStorageGeometryOracle -> Oracle
  RequireStorageGeometryPositiveControls -> PositiveControls
  RequirePairedStorageGeometryNegatives -> PairedNegatives
  RequireAppliedStorageGeometryProductionMutants -> Mutants
  RequireExactStorageGeometrySourceDiscovery -> Discovery
  RequirePostAcquisitionStorageGeometryChallenge -> Challenge
  RequireStorageGeometryProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrStorageParallelism -> AuthorityBypass
  RequireFreshStorageGeometryBuildRootAndStableSource -> Freshness
  RequireQualifiedStorageGeometryHarness -> Qualification
  RequireStorageGeometryProductsContainedBelowBuild -> Cleanroom
  RequireRetiredStorageGeometryAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseTwentySevenReceipt -> PredecessorCategory
  RequireLaterBindingProvisionRuntimeStorageOwnersExplicit -> Residue
  RequireQualifiedPhaseTwentyEightGatePass -> PassCriterion

phaseTwentyNineRequirementCategory :: PhaseTwentyNineRequirement -> GateCategory
phaseTwentyNineRequirementCategory requirement = case requirement of
  RequirePureExecutionAcceleratorFoldBoundary -> Claim
  RequireAcquiredExecutionAcceleratorSupervisor -> Subject
  RequireDirectOfflineSerialExecutionAcceleratorMatrix -> Command
  RequireIndependentExecutionAcceleratorOracle -> Oracle
  RequireExecutionAcceleratorPositiveControls -> PositiveControls
  RequirePairedExecutionAcceleratorNegatives -> PairedNegatives
  RequireAppliedExecutionAcceleratorProductionMutants -> Mutants
  RequireExactExecutionAcceleratorSourceDiscovery -> Discovery
  RequirePostAcquisitionExecutionAcceleratorChallenge -> Challenge
  RequireExecutionAcceleratorProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrExecutionParallelism -> AuthorityBypass
  RequireFreshExecutionAcceleratorBuildRootAndStableSource -> Freshness
  RequireQualifiedExecutionAcceleratorHarness -> Qualification
  RequireExecutionAcceleratorProductsContainedBelowBuild -> Cleanroom
  RequireRetiredExecutionAcceleratorAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseTwentyEightReceipt -> PredecessorCategory
  RequireLaterBindingProvisionRuntimeExecutionOwnersExplicit -> Residue
  RequireQualifiedPhaseTwentyNineGatePass -> PassCriterion

phaseThirtyRequirementCategory :: PhaseThirtyRequirement -> GateCategory
phaseThirtyRequirementCategory requirement = case requirement of
  RequirePureCapabilityBindBoundary -> Claim
  RequireAcquiredCapabilityBindSupervisor -> Subject
  RequireDirectOfflineSerialCapabilityBindMatrix -> Command
  RequireIndependentCapabilityBindOracle -> Oracle
  RequireCapabilityBindPositiveControls -> PositiveControls
  RequirePairedCapabilityBindNegatives -> PairedNegatives
  RequireAppliedCapabilityBindProductionMutants -> Mutants
  RequireExactCapabilityBindSourceDiscovery -> Discovery
  RequirePostAcquisitionCapabilityBindChallenge -> Challenge
  RequireCapabilityBindProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrCapabilityBindParallelism -> AuthorityBypass
  RequireFreshCapabilityBindBuildRootAndStableSource -> Freshness
  RequireQualifiedCapabilityBindHarness -> Qualification
  RequireCapabilityBindProductsContainedBelowBuild -> Cleanroom
  RequireRetiredCapabilityBindAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseTwentyNineReceipt -> PredecessorCategory
  RequireLaterProvisionRenderRuntimeCapabilityOwnersExplicit -> Residue
  RequireQualifiedPhaseThirtyGatePass -> PassCriterion

phaseThirtyOneRequirementCategory :: PhaseThirtyOneRequirement -> GateCategory
phaseThirtyOneRequirementCategory requirement = case requirement of
  RequireCompleteProvisionSealBoundary -> Claim
  RequireAcquiredProvisionSealSupervisor -> Subject
  RequireDirectOfflineSerialProvisionSealMatrix -> Command
  RequireIndependentProvisionSealOracle -> Oracle
  RequireProvisionSealPositiveControls -> PositiveControls
  RequirePairedProvisionSealNegatives -> PairedNegatives
  RequireAppliedProvisionSealProductionMutants -> Mutants
  RequireExactProvisionSealSourceDiscovery -> Discovery
  RequirePostAcquisitionProvisionSealChallenge -> Challenge
  RequireProvisionSealProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrProvisionSealParallelism -> AuthorityBypass
  RequireFreshProvisionSealBuildRootAndStableSource -> Freshness
  RequireQualifiedProvisionSealHarness -> Qualification
  RequireProvisionSealProductsContainedBelowBuild -> Cleanroom
  RequireRetiredProvisionSealAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseThirtyReceipt -> PredecessorCategory
  RequireLaterRenderRuntimeLiveProvisionOwnersExplicit -> Residue
  RequireQualifiedPhaseThirtyOneGatePass -> PassCriterion

phaseThirtyTwoRequirementCategory :: PhaseThirtyTwoRequirement -> GateCategory
phaseThirtyTwoRequirementCategory requirement = case requirement of
  RequireClosedInferenceAcceleratorProvisionBoundary -> Claim
  RequireAcquiredInferenceAcceleratorSupervisor -> Subject
  RequireDirectOfflineSerialInferenceAcceleratorMatrix -> Command
  RequireIndependentInferenceAcceleratorOracle -> Oracle
  RequireInferenceAcceleratorPositiveControls -> PositiveControls
  RequirePairedInferenceAcceleratorNegatives -> PairedNegatives
  RequireAppliedInferenceAcceleratorProductionMutants -> Mutants
  RequireExactInferenceAcceleratorSourceDiscovery -> Discovery
  RequirePostAcquisitionInferenceAcceleratorChallenge -> Challenge
  RequireInferenceAcceleratorProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrInferenceAcceleratorParallelism -> AuthorityBypass
  RequireFreshInferenceAcceleratorBuildRootAndStableSource -> Freshness
  RequireQualifiedInferenceAcceleratorHarness -> Qualification
  RequireInferenceAcceleratorProductsContainedBelowBuild -> Cleanroom
  RequireRetiredInferenceAcceleratorAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseThirtyOneReceipt -> PredecessorCategory
  RequireLaterRenderRuntimeLiveEngineOwnersExplicit -> Residue
  RequireQualifiedPhaseThirtyTwoGatePass -> PassCriterion

phaseThirtyThreeRequirementCategory :: PhaseThirtyThreeRequirement -> GateCategory
phaseThirtyThreeRequirementCategory requirement = case requirement of
  RequirePureTotalRenderAllBoundary -> Claim
  RequireAcquiredRenderManifestSupervisor -> Subject
  RequireDirectOfflineSerialRenderManifestMatrix -> Command
  RequireIndependentRenderManifestOracle -> Oracle
  RequireRenderManifestPositiveControls -> PositiveControls
  RequirePairedRenderManifestNegatives -> PairedNegatives
  RequireAppliedRenderManifestProductionMutants -> Mutants
  RequireExactRenderManifestSourceDiscovery -> Discovery
  RequirePostAcquisitionRenderManifestChallenge -> Challenge
  RequireRenderManifestProcessObservation -> Observer
  RequireNoPbNetworkHostHardwareOrRenderManifestParallelism -> AuthorityBypass
  RequireFreshRenderManifestBuildRootAndStableSource -> Freshness
  RequireQualifiedRenderManifestHarness -> Qualification
  RequireRenderManifestProductsContainedBelowBuild -> Cleanroom
  RequireRetiredRenderManifestAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseThirtyTwoReceipt -> PredecessorCategory
  RequireLaterActionsDryRunRuntimeLiveOwnersExplicit -> Residue
  RequireQualifiedPhaseThirtyThreeGatePass -> PassCriterion

phaseThirtyFourRequirementCategory :: PhaseThirtyFourRequirement -> GateCategory
phaseThirtyFourRequirementCategory requirement = case requirement of
  RequirePureChainAndFakeBoundary -> Claim
  RequireAcquiredChainBoundarySupervisor -> Subject
  RequireDirectOfflineSerialChainBoundaryMatrix -> Command
  RequireIndependentChainBoundaryOracle -> Oracle
  RequireChainBoundaryPositiveControls -> PositiveControls
  RequirePairedChainBoundaryNegatives -> PairedNegatives
  RequireAppliedChainBoundaryProductionMutants -> Mutants
  RequireExactChainBoundarySourceDiscovery -> Discovery
  RequirePostAcquisitionChainBoundaryChallenge -> Challenge
  RequireChainBoundaryProcessObservation -> Observer
  RequireNoPbNetworkLiveHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshChainBoundaryBuildRootAndStableSource -> Freshness
  RequireQualifiedChainBoundaryHarness -> Qualification
  RequireChainBoundaryProductsContainedBelowBuild -> Cleanroom
  RequireRetiredChainBoundaryAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseThirtyThreeReceipt -> PredecessorCategory
  RequireLiveInterpreterRuntimeAndHardwareOwnersExplicit -> Residue
  RequireQualifiedPhaseThirtyFourGatePass -> PassCriterion

phaseThirtyFiveRequirementCategory :: PhaseThirtyFiveRequirement -> GateCategory
phaseThirtyFiveRequirementCategory requirement = case requirement of
  RequirePureTotalImageRecipeBoundary -> Claim
  RequireAcquiredImageRecipeSupervisor -> Subject
  RequireDirectOfflineSerialImageRecipeMatrix -> Command
  RequireIndependentImageRecipeOracle -> Oracle
  RequireImageRecipePositiveControls -> PositiveControls
  RequirePairedImageRecipeNegatives -> PairedNegatives
  RequireAppliedImageRecipeProductionMutants -> Mutants
  RequireExactImageRecipeSourceDiscovery -> Discovery
  RequirePostAcquisitionImageRecipeChallenge -> Challenge
  RequireImageRecipeProcessObservation -> Observer
  RequireNoPbNetworkEngineHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshImageRecipeBuildRootAndStableSource -> Freshness
  RequireQualifiedImageRecipeHarness -> Qualification
  RequireImageRecipeProductsContainedBelowBuild -> Cleanroom
  RequireRetiredImageRecipeAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseThirtyFourReceipt -> PredecessorCategory
  RequireLiveResolutionBuildPublicationRuntimeOwnersExplicit -> Residue
  RequireQualifiedPhaseThirtyFiveGatePass -> PassCriterion

phaseThirtySixRequirementCategory :: PhaseThirtySixRequirement -> GateCategory
phaseThirtySixRequirementCategory requirement = case requirement of
  RequirePureClosedTransactionVocabulary -> Claim
  RequireAcquiredTransactionVocabularySupervisor -> Subject
  RequireDirectOfflineSerialTransactionVocabularyMatrix -> Command
  RequireIndependentTransactionVocabularyOracle -> Oracle
  RequireTransactionVocabularyPositiveControls -> PositiveControls
  RequireTransactionVocabularyCompilerNegatives -> PairedNegatives
  RequireAppliedTransactionVocabularyProductionMutants -> Mutants
  RequireExactTransactionVocabularySourceDiscovery -> Discovery
  RequirePostAcquisitionTransactionVocabularyChallenge -> Challenge
  RequireTransactionVocabularyProcessObservation -> Observer
  RequireNoPbNetworkDatabaseHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshTransactionVocabularyBuildRootAndStableSource -> Freshness
  RequireQualifiedTransactionVocabularyHarness -> Qualification
  RequireTransactionVocabularyProductsContainedBelowBuild -> Cleanroom
  RequireRetiredTransactionVocabularyAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseThirtyFiveReceipt -> PredecessorCategory
  RequireLiveDatabasePolicyRuntimeOwnersExplicit -> Residue
  RequireQualifiedPhaseThirtySixGatePass -> PassCriterion

phaseThirtySevenRequirementCategory :: PhaseThirtySevenRequirement -> GateCategory
phaseThirtySevenRequirementCategory requirement = case requirement of
  RequirePureBoundedUiProgramSchema -> Claim
  RequireAcquiredUiProgramSchemaSupervisor -> Subject
  RequireDirectOfflineSerialUiProgramSchemaMatrix -> Command
  RequireIndependentUiProgramSchemaOracle -> Oracle
  RequireUiProgramSchemaPositiveControls -> PositiveControls
  RequireExactUiProgramSchemaNegatives -> PairedNegatives
  RequireAppliedUiProgramSchemaProductionMutants -> Mutants
  RequireExactUiProgramSchemaSourceDiscovery -> Discovery
  RequirePostAcquisitionUiProgramSchemaChallenge -> Challenge
  RequireUiProgramSchemaProcessObservation -> Observer
  RequireNoPbNetworkBrowserHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshUiProgramSchemaBuildRootAndStableSource -> Freshness
  RequireQualifiedUiProgramSchemaHarness -> Qualification
  RequireUiProgramSchemaProductsContainedBelowBuild -> Cleanroom
  RequireRetiredUiProgramSchemaAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseThirtySixReceipt -> PredecessorCategory
  RequireUiRuntimeAndProviderOwnersExplicit -> Residue
  RequireQualifiedPhaseThirtySevenGatePass -> PassCriterion

phaseThirtyEightRequirementCategory :: PhaseThirtyEightRequirement -> GateCategory
phaseThirtyEightRequirementCategory requirement = case requirement of
  RequirePureSealedUiAuthorizationKernel -> Claim
  RequireAcquiredUiAuthorizationSupervisor -> Subject
  RequireDirectOfflineSerialUiAuthorizationMatrix -> Command
  RequireIndependentUiAuthorizationOracle -> Oracle
  RequireUiAuthorizationPositiveControls -> PositiveControls
  RequireExactUiAuthorizationPairedNegatives -> PairedNegatives
  RequireAppliedUiAuthorizationProductionMutants -> Mutants
  RequireExactUiAuthorizationSourceDiscovery -> Discovery
  RequirePostAcquisitionUiAuthorizationChallenge -> Challenge
  RequireUiAuthorizationProcessObservation -> Observer
  RequireNoPbNetworkIdentityProviderHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshUiAuthorizationBuildRootAndStableSource -> Freshness
  RequireQualifiedUiAuthorizationHarness -> Qualification
  RequireUiAuthorizationProductsContainedBelowBuild -> Cleanroom
  RequireRetiredUiAuthorizationAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseThirtySevenReceipt -> PredecessorCategory
  RequireUiEffectRuntimeAndProviderOwnersExplicit -> Residue
  RequireQualifiedPhaseThirtyEightGatePass -> PassCriterion

phaseThirtyNineRequirementCategory :: PhaseThirtyNineRequirement -> GateCategory
phaseThirtyNineRequirementCategory requirement = case requirement of
  RequirePureExactUiEffectBinding -> Claim
  RequireAcquiredUiEffectBindingSupervisor -> Subject
  RequireDirectOfflineSerialUiEffectBindingMatrix -> Command
  RequireIndependentUiEffectBindingOracle -> Oracle
  RequireUiEffectBindingPositiveControls -> PositiveControls
  RequireExactUiEffectBindingPairedNegatives -> PairedNegatives
  RequireAppliedUiEffectBindingProductionMutants -> Mutants
  RequireExactUiEffectBindingSourceDiscovery -> Discovery
  RequirePostAcquisitionUiEffectBindingChallenge -> Challenge
  RequireUiEffectBindingProcessObservation -> Observer
  RequireNoPbNetworkProviderBrowserHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshUiEffectBindingBuildRootAndStableSource -> Freshness
  RequireQualifiedUiEffectBindingHarness -> Qualification
  RequireUiEffectBindingProductsContainedBelowBuild -> Cleanroom
  RequireRetiredUiEffectBindingAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseThirtyEightReceipt -> PredecessorCategory
  RequireUiPlanRuntimeAndProviderOwnersExplicit -> Residue
  RequireQualifiedPhaseThirtyNineGatePass -> PassCriterion

phaseFortyRequirementCategory :: PhaseFortyRequirement -> GateCategory
phaseFortyRequirementCategory requirement = case requirement of
  RequirePureDeterministicUiPlanCompiler -> Claim
  RequireAcquiredUiPlanCompilerSupervisor -> Subject
  RequireDirectOfflineSerialUiPlanCompilerMatrix -> Command
  RequireIndependentUiPlanCompilerOracle -> Oracle
  RequireUiPlanCompilerPositiveControls -> PositiveControls
  RequireExactUiPlanCompilerPairedNegatives -> PairedNegatives
  RequireAppliedUiPlanCompilerProductionMutants -> Mutants
  RequireExactUiPlanCompilerSourceDiscovery -> Discovery
  RequirePostAcquisitionUiPlanCompilerChallenge -> Challenge
  RequireUiPlanCompilerProcessObservation -> Observer
  RequireNoPbNetworkInterpreterProviderHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshUiPlanCompilerBuildRootAndStableSource -> Freshness
  RequireQualifiedUiPlanCompilerHarness -> Qualification
  RequireUiPlanCompilerProductsContainedBelowBuild -> Cleanroom
  RequireRetiredUiPlanCompilerAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseThirtyNineReceipt -> PredecessorCategory
  RequireUiInterpreterOfflineRuntimeAndPublicationOwnersExplicit -> Residue
  RequireQualifiedPhaseFortyGatePass -> PassCriterion

phaseFortyOneRequirementCategory :: PhaseFortyOneRequirement -> GateCategory
phaseFortyOneRequirementCategory requirement = case requirement of
  RequirePureBoundedOfflineContinuityLanguage -> Claim
  RequireAcquiredOfflineLanguagePlanSupervisor -> Subject
  RequireDirectOfflineSerialOfflineLanguagePlanMatrix -> Command
  RequireIndependentOfflineLanguagePlanOracle -> Oracle
  RequireOfflineLanguagePlanPositiveControls -> PositiveControls
  RequireExactOfflineLanguagePlanPairedNegatives -> PairedNegatives
  RequireAppliedOfflineLanguagePlanProductionMutants -> Mutants
  RequireExactOfflineLanguagePlanSourceDiscovery -> Discovery
  RequirePostAcquisitionOfflineLanguagePlanChallenge -> Challenge
  RequireOfflineLanguagePlanProcessObservation -> Observer
  RequireNoPbNetworkBrowserStorageReplayHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshOfflineLanguagePlanBuildRootAndStableSource -> Freshness
  RequireQualifiedOfflineLanguagePlanHarness -> Qualification
  RequireOfflineLanguagePlanProductsContainedBelowBuild -> Cleanroom
  RequireRetiredOfflineLanguagePlanAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseFortyReceipt -> PredecessorCategory
  RequireBrowserStorageServerReplayAndPublicationOwnersExplicit -> Residue
  RequireQualifiedPhaseFortyOneGatePass -> PassCriterion

phaseFortyTwoRequirementCategory :: PhaseFortyTwoRequirement -> GateCategory
phaseFortyTwoRequirementCategory requirement = case requirement of
  RequirePureGenericUiBrowserInterpreterSemantics -> Claim
  RequireAcquiredUiBrowserInterpreterSupervisor -> Subject
  RequireDirectOfflineSerialUiBrowserInterpreterMatrix -> Command
  RequireIndependentUiBrowserInterpreterOracle -> Oracle
  RequireUiBrowserInterpreterPositiveControls -> PositiveControls
  RequireExactUiBrowserInterpreterPairedNegatives -> PairedNegatives
  RequireAppliedUiBrowserInterpreterProductionMutants -> Mutants
  RequireExactUiBrowserInterpreterSourceDiscovery -> Discovery
  RequirePostAcquisitionUiBrowserInterpreterChallenge -> Challenge
  RequireUiBrowserInterpreterProcessObservation -> Observer
  RequireNoPbBrowserNodePythonNetworkHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshUiBrowserInterpreterBuildRootAndStableSource -> Freshness
  RequireQualifiedUiBrowserInterpreterHarness -> Qualification
  RequireUiBrowserInterpreterProductsContainedBelowBuild -> Cleanroom
  RequireRetiredUiBrowserInterpreterAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseFortyOneReceipt -> PredecessorCategory
  RequireLiveBrowserServerProviderReleaseAndHaOwnersExplicit -> Residue
  RequireQualifiedPhaseFortyTwoGatePass -> PassCriterion

phaseFortyThreeRequirementCategory :: PhaseFortyThreeRequirement -> GateCategory
phaseFortyThreeRequirementCategory requirement = case requirement of
  RequireAuthenticatedScopedUiServerBoundary -> Claim
  RequireAcquiredUiServerBoundarySupervisor -> Subject
  RequireDirectOfflineSerialUiServerBoundaryMatrix -> Command
  RequireIndependentUiServerBoundaryOracle -> Oracle
  RequireUiServerBoundaryPositiveControls -> PositiveControls
  RequireExactUiServerBoundaryPairedNegatives -> PairedNegatives
  RequireAppliedUiServerBoundaryProductionMutants -> Mutants
  RequireExactUiServerBoundarySourceDiscovery -> Discovery
  RequirePostAcquisitionUiServerBoundaryChallenge -> Challenge
  RequireUiServerBoundaryProcessObservation -> Observer
  RequireNoPbNodeNetworkLiveIdentityProviderHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshUiServerBoundaryBuildRootAndStableSource -> Freshness
  RequireQualifiedUiServerBoundaryHarness -> Qualification
  RequireUiServerBoundaryProductsContainedBelowBuild -> Cleanroom
  RequireRetiredUiServerBoundaryAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseFortyTwoReceipt -> PredecessorCategory
  RequireLiveIdentityProviderBrowserDeploymentAndHaOwnersExplicit -> Residue
  RequireQualifiedPhaseFortyThreeGatePass -> PassCriterion

phaseFortyFourRequirementCategory :: PhaseFortyFourRequirement -> GateCategory
phaseFortyFourRequirementCategory requirement = case requirement of
  RequireHardwareFreeHaskellUiComposition -> Claim
  RequireAcquiredUiLocalCompositionSupervisor -> Subject
  RequireDirectOfflineSerialUiLocalCompositionMatrix -> Command
  RequireIndependentUiLocalCompositionOracle -> Oracle
  RequireUiLocalCompositionPositiveControls -> PositiveControls
  RequireExactUiLocalCompositionPairedNegatives -> PairedNegatives
  RequireAppliedUiLocalCompositionProductionMutants -> Mutants
  RequireExactUiLocalCompositionSourceDiscovery -> Discovery
  RequirePostAcquisitionUiLocalCompositionChallenge -> Challenge
  RequireUiLocalCompositionProcessObservation -> Observer
  RequireNoPbNodeDhallNetworkLiveProviderHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshUiLocalCompositionBuildRootAndStableSource -> Freshness
  RequireQualifiedUiLocalCompositionHarness -> Qualification
  RequireUiLocalCompositionProductsContainedBelowBuild -> Cleanroom
  RequireRetiredUiLocalCompositionAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseFortyThreeReceipt -> PredecessorCategory
  RequireLiveWorkflowProviderBrowserDeploymentReleaseAndHaOwnersExplicit -> Residue
  RequireQualifiedPhaseFortyFourGatePass -> PassCriterion

phaseFortyFiveRequirementCategory :: PhaseFortyFiveRequirement -> GateCategory
phaseFortyFiveRequirementCategory requirement = case requirement of
  RequireHaskellEncryptedOfflineStateAndRuntimeProjection -> Claim
  RequireAcquiredEncryptedBrowserRuntimeSupervisor -> Subject
  RequireDirectOfflineSerialEncryptedBrowserRuntimeMatrix -> Command
  RequireIndependentEncryptedBrowserRuntimeOracle -> Oracle
  RequireEncryptedBrowserRuntimePositiveControls -> PositiveControls
  RequireExactEncryptedBrowserRuntimePairedNegatives -> PairedNegatives
  RequireAppliedEncryptedBrowserRuntimeProductionMutants -> Mutants
  RequireExactEncryptedBrowserRuntimeSourceDiscovery -> Discovery
  RequirePostAcquisitionEncryptedBrowserRuntimeChallenge -> Challenge
  RequireEncryptedBrowserRuntimeProcessObservation -> Observer
  RequireNoPbBrowserNodePurescriptJavascriptDhallNetworkLiveHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshEncryptedBrowserRuntimeBuildRootAndStableSource -> Freshness
  RequireQualifiedEncryptedBrowserRuntimeHarness -> Qualification
  RequireEncryptedBrowserRuntimeProductsContainedBelowBuild -> Cleanroom
  RequireRetiredEncryptedBrowserRuntimeAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseFortyFourReceipt -> PredecessorCategory
  RequireLiveBrowserStorageCryptoLockServiceWorkerReplayReleaseHaAndHardwareOwnersExplicit -> Residue
  RequireQualifiedPhaseFortyFiveGatePass -> PassCriterion

phaseFortySixRequirementCategory :: PhaseFortySixRequirement -> GateCategory
phaseFortySixRequirementCategory requirement = case requirement of
  RequireHaskellGeneratedBrowserContractsAndBundle -> Claim
  RequireAcquiredUiContractGenerationSupervisor -> Subject
  RequireDirectOfflineSerialUiContractGenerationMatrix -> Command
  RequireIndependentUiContractGenerationOracle -> Oracle
  RequireUiContractGenerationPositiveControls -> PositiveControls
  RequireExactUiContractGenerationPairedNegatives -> PairedNegatives
  RequireAppliedUiContractGenerationProductionMutants -> Mutants
  RequireExactUiContractGenerationSourceDiscovery -> Discovery
  RequirePostAcquisitionUiContractGenerationChallenge -> Challenge
  RequireUiContractGenerationProcessObservation -> Observer
  RequireNoPbBrowserNodePurescriptJavascriptNetworkLiveHostHardwareOrParallelism -> AuthorityBypass
  RequireFreshUiContractGenerationBuildRootAndStableSource -> Freshness
  RequireQualifiedUiContractGenerationHarness -> Qualification
  RequireUiContractGenerationProductsContainedBelowBuild -> Cleanroom
  RequireRetiredUiContractGenerationAuthoritiesAbsent -> LegacyClosure
  RequireExactPhaseFortyFiveReceipt -> PredecessorCategory
  RequireBrowserCompileExecutionProtocolPublicationDeploymentHaAndHardwareOwnersExplicit -> Residue
  RequireQualifiedPhaseFortySixGatePass -> PassCriterion

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
  RequirePhaseOne phaseOne -> phaseOneRequirementSlug phaseOne
  RequirePhaseTwo phaseTwo -> phaseTwoRequirementSlug phaseTwo
  RequirePhaseThree phaseThree -> phaseThreeRequirementSlug phaseThree
  RequirePhaseFour phaseFour -> phaseFourRequirementSlug phaseFour
  RequirePhaseFive phaseFive -> phaseFiveRequirementSlug phaseFive
  RequirePhaseSix phaseSix -> phaseSixRequirementSlug phaseSix
  RequirePhaseSeven phaseSeven -> phaseSevenRequirementSlug phaseSeven
  RequirePhaseEight phaseEight -> phaseEightRequirementSlug phaseEight
  RequirePhaseNine phaseNine -> phaseNineRequirementSlug phaseNine
  RequirePhaseTen phaseTen -> phaseTenRequirementSlug phaseTen
  RequirePhaseEleven phaseEleven -> phaseElevenRequirementSlug phaseEleven
  RequirePhaseTwelve phaseTwelve -> phaseTwelveRequirementSlug phaseTwelve
  RequirePhaseThirteen phaseThirteen -> phaseThirteenRequirementSlug phaseThirteen
  RequirePhaseFourteen phaseFourteen -> phaseFourteenRequirementSlug phaseFourteen
  RequirePhaseFifteen phaseFifteen -> phaseFifteenRequirementSlug phaseFifteen
  RequirePhaseSixteen phaseSixteen -> phaseSixteenRequirementSlug phaseSixteen
  RequirePhaseSeventeen phaseSeventeen -> phaseSeventeenRequirementSlug phaseSeventeen
  RequirePhaseEighteen phaseEighteen -> phaseEighteenRequirementSlug phaseEighteen
  RequirePhaseNineteen phaseNineteen -> phaseNineteenRequirementSlug phaseNineteen
  RequirePhaseTwenty phaseTwenty -> phaseTwentyRequirementSlug phaseTwenty
  RequirePhaseTwentyOne phaseTwentyOne -> phaseTwentyOneRequirementSlug phaseTwentyOne
  RequirePhaseTwentyTwo phaseTwentyTwo -> phaseTwentyTwoRequirementSlug phaseTwentyTwo
  RequirePhaseTwentyThree phaseTwentyThree -> phaseTwentyThreeRequirementSlug phaseTwentyThree
  RequirePhaseTwentyFour phaseTwentyFour -> phaseTwentyFourRequirementSlug phaseTwentyFour
  RequirePhaseTwentyFive phaseTwentyFive -> phaseTwentyFiveRequirementSlug phaseTwentyFive
  RequirePhaseTwentySix phaseTwentySix -> phaseTwentySixRequirementSlug phaseTwentySix
  RequirePhaseTwentySeven phaseTwentySeven -> phaseTwentySevenRequirementSlug phaseTwentySeven
  RequirePhaseTwentyEight phaseTwentyEight -> phaseTwentyEightRequirementSlug phaseTwentyEight
  RequirePhaseTwentyNine phaseTwentyNine -> phaseTwentyNineRequirementSlug phaseTwentyNine
  RequirePhaseThirty phaseThirty -> phaseThirtyRequirementSlug phaseThirty
  RequirePhaseThirtyOne phaseThirtyOne -> phaseThirtyOneRequirementSlug phaseThirtyOne
  RequirePhaseThirtyTwo phaseThirtyTwo -> phaseThirtyTwoRequirementSlug phaseThirtyTwo
  RequirePhaseThirtyThree phaseThirtyThree -> phaseThirtyThreeRequirementSlug phaseThirtyThree
  RequirePhaseThirtyFour phaseThirtyFour -> phaseThirtyFourRequirementSlug phaseThirtyFour
  RequirePhaseThirtyFive phaseThirtyFive -> phaseThirtyFiveRequirementSlug phaseThirtyFive
  RequirePhaseThirtySix phaseThirtySix -> phaseThirtySixRequirementSlug phaseThirtySix
  RequirePhaseThirtySeven phaseThirtySeven -> phaseThirtySevenRequirementSlug phaseThirtySeven
  RequirePhaseThirtyEight phaseThirtyEight -> phaseThirtyEightRequirementSlug phaseThirtyEight
  RequirePhaseThirtyNine phaseThirtyNine -> phaseThirtyNineRequirementSlug phaseThirtyNine
  RequirePhaseForty phaseForty -> phaseFortyRequirementSlug phaseForty
  RequirePhaseFortyOne phaseFortyOne -> phaseFortyOneRequirementSlug phaseFortyOne
  RequirePhaseFortyTwo phaseFortyTwo -> phaseFortyTwoRequirementSlug phaseFortyTwo
  RequirePhaseFortyThree phaseFortyThree -> phaseFortyThreeRequirementSlug phaseFortyThree
  RequirePhaseFortyFour phaseFortyFour -> phaseFortyFourRequirementSlug phaseFortyFour
  RequirePhaseFortyFive phaseFortyFive -> phaseFortyFiveRequirementSlug phaseFortyFive
  RequirePhaseFortySix phaseFortySix -> phaseFortySixRequirementSlug phaseFortySix

phaseOneRequirementSlug :: PhaseOneRequirement -> Text
phaseOneRequirementSlug requirement = case requirement of
  RequireAuthenticatedReproducibleToolchainAndProbeClosure -> "authenticated-reproducible-toolchain-and-probe-closure"
  RequireAcquiredToolchainSpikeSupervisor -> "acquired-toolchain-spike-supervisor"
  RequireDirectOfflineSerialToolchainInvocation -> "direct-offline-serial-toolchain-invocation"
  RequireIndependentToolchainProbeOracle -> "independent-toolchain-probe-oracle"
  RequireCompleteRepresentativeProbeControls -> "complete-representative-probe-controls"
  RequireToolchainProbePairedNegatives -> "toolchain-probe-paired-negatives"
  RequireAppliedToolchainPolicyMutants -> "applied-toolchain-policy-mutants"
  RequireExactDependencyAndProbeDiscovery -> "exact-dependency-and-probe-discovery"
  RequirePostStartProbeChallenge -> "post-start-probe-challenge"
  RequireProcessExitStdoutAndDigestObservation -> "process-exit-stdout-and-digest-observation"
  RequireNoNetworkHardwareOrAuthBypass -> "no-network-hardware-or-auth-bypass"
  RequireTwoFreshBuildRootsAndStableSource -> "two-fresh-build-roots-and-stable-source"
  RequireQualifiedToolchainHarness -> "qualified-toolchain-harness"
  RequireRunScopedGeneratedProductsAndCleanup -> "run-scoped-generated-products-and-cleanup"
  RequirePhaseOneLegacyFamiliesClosed -> "phase-one-legacy-families-closed"
  RequireExactPhaseZeroReceipt -> "exact-phase-zero-receipt"
  RequireGenesisAssumptionAndLaterClaimsExplicit -> "genesis-assumption-and-later-claims-explicit"
  RequireQualifiedPhaseOneGatePass -> "qualified-phase-one-gate-pass"

phaseTwoRequirementSlug :: PhaseTwoRequirement -> Text
phaseTwoRequirementSlug requirement = case requirement of
  RequireCompilerBackedRepositoryLayoutClosure -> "compiler-backed-repository-layout-closure"
  RequireAcquiredRepositoryLayoutSupervisor -> "acquired-repository-layout-supervisor"
  RequireDirectOfflineSerialRepositoryBuild -> "direct-offline-serial-repository-build"
  RequireIndependentRepositoryLayoutOracle -> "independent-repository-layout-oracle"
  RequireCleanRepositoryLayoutControls -> "clean-repository-layout-controls"
  RequireRepositoryLayoutPairedNegatives -> "repository-layout-paired-negatives"
  RequireAppliedRepositoryLayoutMutants -> "applied-repository-layout-mutants"
  RequireTwoWaySourceAndComponentDiscovery -> "two-way-source-and-component-discovery"
  RequirePostStartRepositoryChallenge -> "post-start-repository-challenge"
  RequireCompilerProcessAndGraphObservation -> "compiler-process-and-graph-observation"
  RequireNoPbNetworkHardwareOrAmbientBypass -> "no-pb-network-hardware-or-ambient-bypass"
  RequireOpeningClosingSourceAndFreshBuildRoot -> "opening-closing-source-and-fresh-build-root"
  RequireQualifiedRepositoryLayoutHarness -> "qualified-repository-layout-harness"
  RequireGeneratedProductsContainedBelowBuild -> "generated-products-contained-below-build"
  RequirePhaseTwoLegacyFamiliesClosed -> "phase-two-legacy-families-closed"
  RequireExactPhaseOneReceipt -> "exact-phase-one-receipt"
  RequireOnlyTypedLaterSourceDebt -> "only-typed-later-source-debt"
  RequireQualifiedPhaseTwoGatePass -> "qualified-phase-two-gate-pass"

phaseThreeRequirementSlug :: PhaseThreeRequirement -> Text
phaseThreeRequirementSlug requirement = case requirement of
  RequireCompleteArtifactCalculus -> "complete-artifact-calculus"
  RequireAcquiredArtifactCalculusSupervisor -> "acquired-artifact-calculus-supervisor"
  RequireDirectSerialArtifactCompilerMatrix -> "direct-serial-artifact-compiler-matrix"
  RequireIndependentArtifactCalculusOracle -> "independent-artifact-calculus-oracle"
  RequireArtifactCalculusPositiveControls -> "artifact-calculus-positive-controls"
  RequireArtifactCalculusPairedNegatives -> "artifact-calculus-paired-negatives"
  RequireAppliedArtifactCalculusMutants -> "applied-artifact-calculus-mutants"
  RequireExactArtifactCalculusDiscovery -> "exact-artifact-calculus-discovery"
  RequirePostAcquisitionArtifactChallenge -> "post-acquisition-artifact-challenge"
  RequireArtifactProcessObservation -> "artifact-process-observation"
  RequireNoPbNetworkHardwareOrCompilerParallelism -> "no-pb-network-hardware-or-compiler-parallelism"
  RequireFreshArtifactBuildRootsAndStableSource -> "fresh-artifact-build-roots-and-stable-source"
  RequireQualifiedArtifactCalculusHarness -> "qualified-artifact-calculus-harness"
  RequireArtifactProductsContainedBelowBuild -> "artifact-products-contained-below-build"
  RequireNoPhaseThreeLegacyDebt -> "no-phase-three-legacy-debt"
  RequireExactPhaseTwoReceipt -> "exact-phase-two-receipt"
  RequireLaterArtifactConsumersExplicit -> "later-artifact-consumers-explicit"
  RequireQualifiedPhaseThreeGatePass -> "qualified-phase-three-gate-pass"

phaseFourRequirementSlug :: PhaseFourRequirement -> Text
phaseFourRequirementSlug requirement = case requirement of
  RequireCompleteBudgetCalculus -> "complete-budget-calculus"
  RequireAcquiredBudgetCalculusSupervisor -> "acquired-budget-calculus-supervisor"
  RequireDirectSerialBudgetCompilerMatrix -> "direct-serial-budget-compiler-matrix"
  RequireIndependentBudgetCalculusOracle -> "independent-budget-calculus-oracle"
  RequireBudgetCalculusPositiveControls -> "budget-calculus-positive-controls"
  RequireBudgetCalculusPairedNegatives -> "budget-calculus-paired-negatives"
  RequireAppliedBudgetCalculusMutants -> "applied-budget-calculus-mutants"
  RequireExactBudgetCalculusDiscovery -> "exact-budget-calculus-discovery"
  RequirePostAcquisitionBudgetChallenge -> "post-acquisition-budget-challenge"
  RequireBudgetProcessObservation -> "budget-process-observation"
  RequireNoPbNetworkHardwareOrBudgetCompilerParallelism -> "no-pb-network-hardware-or-budget-compiler-parallelism"
  RequireFreshBudgetBuildRootsAndStableSource -> "fresh-budget-build-roots-and-stable-source"
  RequireQualifiedBudgetCalculusHarness -> "qualified-budget-calculus-harness"
  RequireBudgetProductsContainedBelowBuild -> "budget-products-contained-below-build"
  RequireNoPhaseFourLegacyDebt -> "no-phase-four-legacy-debt"
  RequireExactPhaseThreeReceipt -> "exact-phase-three-receipt"
  RequireLaterBudgetConsumersExplicit -> "later-budget-consumers-explicit"
  RequireQualifiedPhaseFourGatePass -> "qualified-phase-four-gate-pass"

phaseFiveRequirementSlug :: PhaseFiveRequirement -> Text
phaseFiveRequirementSlug requirement = case requirement of
  RequireCompleteLiftCalculus -> "complete-lift-calculus"
  RequireAcquiredLiftCalculusSupervisor -> "acquired-lift-calculus-supervisor"
  RequireDirectSerialLiftCompilerMatrix -> "direct-serial-lift-compiler-matrix"
  RequireIndependentLiftCalculusOracle -> "independent-lift-calculus-oracle"
  RequireLiftCalculusPositiveControls -> "lift-calculus-positive-controls"
  RequireLiftCalculusPairedNegatives -> "lift-calculus-paired-negatives"
  RequireAppliedLiftCalculusMutants -> "applied-lift-calculus-mutants"
  RequireExactLiftCalculusDiscovery -> "exact-lift-calculus-discovery"
  RequirePostAcquisitionLiftChallenge -> "post-acquisition-lift-challenge"
  RequireLiftProcessObservation -> "lift-process-observation"
  RequireNoPbNetworkHardwareOrLiftCompilerParallelism -> "no-pb-network-hardware-or-lift-compiler-parallelism"
  RequireFreshLiftBuildRootsAndStableSource -> "fresh-lift-build-roots-and-stable-source"
  RequireQualifiedLiftCalculusHarness -> "qualified-lift-calculus-harness"
  RequireLiftProductsContainedBelowBuild -> "lift-products-contained-below-build"
  RequireNoPhaseFiveLegacyDebt -> "no-phase-five-legacy-debt"
  RequireExactPhaseFourReceipt -> "exact-phase-four-receipt"
  RequireLaterLiftConsumersExplicit -> "later-lift-consumers-explicit"
  RequireQualifiedPhaseFiveGatePass -> "qualified-phase-five-gate-pass"

phaseSixRequirementSlug :: PhaseSixRequirement -> Text
phaseSixRequirementSlug requirement = case requirement of
  RequireCompleteWorkflowCalculus -> "complete-workflow-calculus"
  RequireAcquiredWorkflowCalculusSupervisor -> "acquired-workflow-calculus-supervisor"
  RequireDirectSerialWorkflowCompilerMatrix -> "direct-serial-workflow-compiler-matrix"
  RequireIndependentWorkflowCalculusOracle -> "independent-workflow-calculus-oracle"
  RequireWorkflowCalculusPositiveControls -> "workflow-calculus-positive-controls"
  RequireWorkflowCalculusPairedNegatives -> "workflow-calculus-paired-negatives"
  RequireAppliedWorkflowCalculusMutants -> "applied-workflow-calculus-mutants"
  RequireExactWorkflowCalculusDiscovery -> "exact-workflow-calculus-discovery"
  RequirePostAcquisitionWorkflowChallenge -> "post-acquisition-workflow-challenge"
  RequireWorkflowProcessObservation -> "workflow-process-observation"
  RequireNoPbNetworkHardwareOrWorkflowCompilerParallelism -> "no-pb-network-hardware-or-workflow-compiler-parallelism"
  RequireFreshWorkflowBuildRootsAndStableSource -> "fresh-workflow-build-roots-and-stable-source"
  RequireQualifiedWorkflowCalculusHarness -> "qualified-workflow-calculus-harness"
  RequireWorkflowProductsContainedBelowBuild -> "workflow-products-contained-below-build"
  RequireNoPhaseSixLegacyDebt -> "no-phase-six-legacy-debt"
  RequireExactPhaseFiveReceipt -> "exact-phase-five-receipt"
  RequireLaterWorkflowConsumersExplicit -> "later-workflow-consumers-explicit"
  RequireQualifiedPhaseSixGatePass -> "qualified-phase-six-gate-pass"

phaseSevenRequirementSlug :: PhaseSevenRequirement -> Text
phaseSevenRequirementSlug requirement = case requirement of
  RequireCompleteEvidenceCalculus -> "complete-evidence-calculus"
  RequireAcquiredEvidenceCalculusSupervisor -> "acquired-evidence-calculus-supervisor"
  RequireDirectSerialEvidenceCompilerMatrix -> "direct-serial-evidence-compiler-matrix"
  RequireIndependentEvidenceCalculusOracle -> "independent-evidence-calculus-oracle"
  RequireEvidenceCalculusPositiveControls -> "evidence-calculus-positive-controls"
  RequireEvidenceCalculusPairedNegatives -> "evidence-calculus-paired-negatives"
  RequireAppliedEvidenceCalculusMutants -> "applied-evidence-calculus-mutants"
  RequireExactEvidenceCalculusDiscovery -> "exact-evidence-calculus-discovery"
  RequirePostAcquisitionEvidenceChallenge -> "post-acquisition-evidence-challenge"
  RequireEvidenceProcessObservation -> "evidence-process-observation"
  RequireNoPbNetworkHardwareOrEvidenceCompilerParallelism -> "no-pb-network-hardware-or-evidence-compiler-parallelism"
  RequireFreshEvidenceBuildRootsAndStableSource -> "fresh-evidence-build-roots-and-stable-source"
  RequireQualifiedEvidenceCalculusHarness -> "qualified-evidence-calculus-harness"
  RequireEvidenceProductsContainedBelowBuild -> "evidence-products-contained-below-build"
  RequireNoPhaseSevenLegacyDebt -> "no-phase-seven-legacy-debt"
  RequireExactPhaseSixReceipt -> "exact-phase-six-receipt"
  RequireLaterEvidenceConsumersExplicit -> "later-evidence-consumers-explicit"
  RequireQualifiedPhaseSevenGatePass -> "qualified-phase-seven-gate-pass"

phaseEightRequirementSlug :: PhaseEightRequirement -> Text
phaseEightRequirementSlug requirement = case requirement of
  RequireCompleteScopedIdentityKernel -> "complete-scoped-identity-kernel"
  RequireAcquiredScopeIndexSupervisor -> "acquired-scope-index-supervisor"
  RequireDirectSerialScopeCompilerMatrix -> "direct-serial-scope-compiler-matrix"
  RequireIndependentScopeIndexOracle -> "independent-scope-index-oracle"
  RequireScopeIndexPositiveControls -> "scope-index-positive-controls"
  RequireScopeIndexPairedNegatives -> "scope-index-paired-negatives"
  RequireAppliedScopeIndexMutants -> "applied-scope-index-mutants"
  RequireExactScopeIndexDiscovery -> "exact-scope-index-discovery"
  RequirePostAcquisitionScopeChallenge -> "post-acquisition-scope-challenge"
  RequireScopeProcessObservation -> "scope-process-observation"
  RequireNoPbNetworkHardwareOrScopeCompilerParallelism -> "no-pb-network-hardware-or-scope-compiler-parallelism"
  RequireFreshScopeBuildRootsAndStableSource -> "fresh-scope-build-roots-and-stable-source"
  RequireQualifiedScopeIndexHarness -> "qualified-scope-index-harness"
  RequireScopeProductsContainedBelowBuild -> "scope-products-contained-below-build"
  RequireNoPhaseEightLegacyDebt -> "no-phase-eight-legacy-debt"
  RequireExactPhaseSevenReceipt -> "exact-phase-seven-receipt"
  RequireLaterScopeConsumersExplicit -> "later-scope-consumers-explicit"
  RequireQualifiedPhaseEightGatePass -> "qualified-phase-eight-gate-pass"

phaseNineRequirementSlug :: PhaseNineRequirement -> Text
phaseNineRequirementSlug requirement = case requirement of
  RequireCompleteResourceIndex -> "complete-resource-index"
  RequireAcquiredResourceIndexSupervisor -> "acquired-resource-index-supervisor"
  RequireDirectSerialResourceCompilerMatrix -> "direct-serial-resource-compiler-matrix"
  RequireIndependentResourceIndexOracle -> "independent-resource-index-oracle"
  RequireResourceIndexPositiveControls -> "resource-index-positive-controls"
  RequireResourceIndexPairedNegatives -> "resource-index-paired-negatives"
  RequireAppliedResourceIndexMutants -> "applied-resource-index-mutants"
  RequireExactResourceIndexDiscovery -> "exact-resource-index-discovery"
  RequirePostAcquisitionResourceChallenge -> "post-acquisition-resource-challenge"
  RequireResourceProcessObservation -> "resource-process-observation"
  RequireNoPbNetworkHardwareOrResourceCompilerParallelism -> "no-pb-network-hardware-or-resource-compiler-parallelism"
  RequireFreshResourceBuildRootsAndStableSource -> "fresh-resource-build-roots-and-stable-source"
  RequireQualifiedResourceIndexHarness -> "qualified-resource-index-harness"
  RequireResourceProductsContainedBelowBuild -> "resource-products-contained-below-build"
  RequireNoPhaseNineLegacyDebt -> "no-phase-nine-legacy-debt"
  RequireExactPhaseEightReceipt -> "exact-phase-eight-receipt"
  RequireLaterResourceConsumersExplicit -> "later-resource-consumers-explicit"
  RequireQualifiedPhaseNineGatePass -> "qualified-phase-nine-gate-pass"

phaseTenRequirementSlug :: PhaseTenRequirement -> Text
phaseTenRequirementSlug requirement = case requirement of
  RequireCompleteCalculusComposition -> "complete-calculus-composition"
  RequireAcquiredCalculusCompositionSupervisor -> "acquired-calculus-composition-supervisor"
  RequireDirectSerialCompositionCompilerMatrix -> "direct-serial-composition-compiler-matrix"
  RequireIndependentCalculusCompositionOracle -> "independent-calculus-composition-oracle"
  RequireCalculusCompositionPositiveControls -> "calculus-composition-positive-controls"
  RequireCalculusCompositionPairedNegatives -> "calculus-composition-paired-negatives"
  RequireAppliedCalculusCompositionMutants -> "applied-calculus-composition-mutants"
  RequireExactCalculusCompositionDiscovery -> "exact-calculus-composition-discovery"
  RequirePostAcquisitionCompositionChallenge -> "post-acquisition-composition-challenge"
  RequireCompositionProcessObservation -> "composition-process-observation"
  RequireNoPbNetworkHardwareOrCompositionCompilerParallelism -> "no-pb-network-hardware-or-composition-compiler-parallelism"
  RequireFreshCompositionBuildRootsAndStableSource -> "fresh-composition-build-roots-and-stable-source"
  RequireQualifiedCalculusCompositionHarness -> "qualified-calculus-composition-harness"
  RequireCompositionProductsContainedBelowBuild -> "composition-products-contained-below-build"
  RequireNoPhaseTenLegacyDebt -> "no-phase-ten-legacy-debt"
  RequireExactPhaseNineReceipt -> "exact-phase-nine-receipt"
  RequireLaterCompositionConsumersExplicit -> "later-composition-consumers-explicit"
  RequireQualifiedPhaseTenGatePass -> "qualified-phase-ten-gate-pass"

phaseElevenRequirementSlug :: PhaseElevenRequirement -> Text
phaseElevenRequirementSlug requirement = case requirement of
  RequireCompleteFormalModelKernel -> "complete-formal-model-kernel"
  RequireAcquiredFormalModelKernelSupervisor -> "acquired-formal-model-kernel-supervisor"
  RequireDirectSerialFormalModelCompilerMatrix -> "direct-serial-formal-model-compiler-matrix"
  RequireIndependentFormalModelSemanticOracle -> "independent-formal-model-semantic-oracle"
  RequireFormalModelPositiveControls -> "formal-model-positive-controls"
  RequireFormalModelPairedNegatives -> "formal-model-paired-negatives"
  RequireAppliedFormalModelProductionMutants -> "applied-formal-model-production-mutants"
  RequireExactFormalModelSourceDiscovery -> "exact-formal-model-source-discovery"
  RequirePostAcquisitionFormalModelChallenge -> "post-acquisition-formal-model-challenge"
  RequireFormalModelProcessObservation -> "formal-model-process-observation"
  RequireNoPbNetworkJvmHardwareOrFormalModelCompilerParallelism -> "no-pb-network-jvm-hardware-or-formal-model-compiler-parallelism"
  RequireFreshFormalModelBuildRootsAndStableSource -> "fresh-formal-model-build-roots-and-stable-source"
  RequireQualifiedFormalModelHarness -> "qualified-formal-model-harness"
  RequireFormalModelProductsContainedBelowBuild -> "formal-model-products-contained-below-build"
  RequireRetiredFormalModelBehavioralSourcesAbsent -> "retired-formal-model-behavioral-sources-absent"
  RequireExactPhaseTenReceipt -> "exact-phase-ten-receipt"
  RequireLaterCheckerAndRuntimeClaimsExplicit -> "later-checker-and-runtime-claims-explicit"
  RequireQualifiedPhaseElevenGatePass -> "qualified-phase-eleven-gate-pass"

phaseTwelveRequirementSlug :: PhaseTwelveRequirement -> Text
phaseTwelveRequirementSlug requirement = case requirement of
  RequireCompleteExplicitStateChecker -> "complete-explicit-state-checker"
  RequireAcquiredExplicitStateCheckerSupervisor -> "acquired-explicit-state-checker-supervisor"
  RequireDirectSerialExplicitStateCompilerMatrix -> "direct-serial-explicit-state-compiler-matrix"
  RequireIndependentExplicitStateSemanticOracle -> "independent-explicit-state-semantic-oracle"
  RequireExplicitStatePositiveControls -> "explicit-state-positive-controls"
  RequireExplicitStatePairedNegatives -> "explicit-state-paired-negatives"
  RequireAppliedExplicitStateProductionMutants -> "applied-explicit-state-production-mutants"
  RequireExactExplicitStateSourceDiscovery -> "exact-explicit-state-source-discovery"
  RequirePostAcquisitionExplicitStateChallenge -> "post-acquisition-explicit-state-challenge"
  RequireExplicitStateProcessObservation -> "explicit-state-process-observation"
  RequireNoPbNetworkJvmHardwareOrExplicitStateCompilerParallelism -> "no-pb-network-jvm-hardware-or-explicit-state-compiler-parallelism"
  RequireFreshExplicitStateBuildRootsAndStableSource -> "fresh-explicit-state-build-roots-and-stable-source"
  RequireQualifiedExplicitStateHarness -> "qualified-explicit-state-harness"
  RequireExplicitStateProductsContainedBelowBuild -> "explicit-state-products-contained-below-build"
  RequireRetiredExplicitStateBehavioralSourcesAbsent -> "retired-explicit-state-behavioral-sources-absent"
  RequireExactPhaseElevenReceipt -> "exact-phase-eleven-receipt"
  RequireLaterCheckerSimulationAndRuntimeClaimsExplicit -> "later-checker-simulation-and-runtime-claims-explicit"
  RequireQualifiedPhaseTwelveGatePass -> "qualified-phase-twelve-gate-pass"

phaseThirteenRequirementSlug :: PhaseThirteenRequirement -> Text
phaseThirteenRequirementSlug requirement = case requirement of
  RequireCompleteSymbolicChecker -> "complete-symbolic-checker"
  RequireAcquiredSymbolicCheckerSupervisor -> "acquired-symbolic-checker-supervisor"
  RequireDirectSerialSymbolicCompilerMatrix -> "direct-serial-symbolic-compiler-matrix"
  RequireIndependentSymbolicSemanticOracle -> "independent-symbolic-semantic-oracle"
  RequireSymbolicPositiveControls -> "symbolic-positive-controls"
  RequireSymbolicPairedNegatives -> "symbolic-paired-negatives"
  RequireAppliedSymbolicProductionMutants -> "applied-symbolic-production-mutants"
  RequireExactSymbolicSourceDiscovery -> "exact-symbolic-source-discovery"
  RequirePostAcquisitionSymbolicChallenge -> "post-acquisition-symbolic-challenge"
  RequireSymbolicProcessObservation -> "symbolic-process-observation"
  RequireNoPbNetworkHostHardwareOrSymbolicCompilerParallelism -> "no-pb-network-host-hardware-or-symbolic-compiler-parallelism"
  RequireFreshSymbolicBuildRootsAndStableSource -> "fresh-symbolic-build-roots-and-stable-source"
  RequireQualifiedSymbolicHarness -> "qualified-symbolic-harness"
  RequireSymbolicProductsContainedBelowBuild -> "symbolic-products-contained-below-build"
  RequireRetiredSymbolicBehavioralSourcesAbsent -> "retired-symbolic-behavioral-sources-absent"
  RequireExactPhaseTwelveReceipt -> "exact-phase-twelve-receipt"
  RequireLaterRefinementSimulationAndRuntimeClaimsExplicit -> "later-refinement-simulation-and-runtime-claims-explicit"
  RequireQualifiedPhaseThirteenGatePass -> "qualified-phase-thirteen-gate-pass"

phaseFourteenRequirementSlug :: PhaseFourteenRequirement -> Text
phaseFourteenRequirementSlug requirement = case requirement of
  RequireCompleteRefinementChecker -> "complete-refinement-checker"
  RequireAcquiredRefinementCheckerSupervisor -> "acquired-refinement-checker-supervisor"
  RequireDirectSerialRefinementCompilerMatrix -> "direct-serial-refinement-compiler-matrix"
  RequireIndependentRefinementSemanticOracle -> "independent-refinement-semantic-oracle"
  RequireRefinementPositiveControls -> "refinement-positive-controls"
  RequireRefinementPairedNegatives -> "refinement-paired-negatives"
  RequireAppliedRefinementProductionMutants -> "applied-refinement-production-mutants"
  RequireExactRefinementSourceDiscovery -> "exact-refinement-source-discovery"
  RequirePostAcquisitionRefinementChallenge -> "post-acquisition-refinement-challenge"
  RequireRefinementProcessObservation -> "refinement-process-observation"
  RequireNoPbNetworkHostHardwareOrRefinementCompilerParallelism -> "no-pb-network-host-hardware-or-refinement-compiler-parallelism"
  RequireFreshRefinementBuildRootsAndStableSource -> "fresh-refinement-build-roots-and-stable-source"
  RequireQualifiedRefinementHarness -> "qualified-refinement-harness"
  RequireRefinementProductsContainedBelowBuild -> "refinement-products-contained-below-build"
  RequireRetiredRefinementBehavioralSourcesAbsent -> "retired-refinement-behavioral-sources-absent"
  RequireExactPhaseThirteenReceipt -> "exact-phase-thirteen-receipt"
  RequireLaterCompileFailSimulationAndRuntimeClaimsExplicit -> "later-compile-fail-simulation-and-runtime-claims-explicit"
  RequireQualifiedPhaseFourteenGatePass -> "qualified-phase-fourteen-gate-pass"

phaseFifteenRequirementSlug :: PhaseFifteenRequirement -> Text
phaseFifteenRequirementSlug requirement = case requirement of
  RequireCompleteCompileFailHarness -> "complete-compile-fail-harness"
  RequireAcquiredCompileFailHarnessSupervisor -> "acquired-compile-fail-harness-supervisor"
  RequireDirectSerialCompileFailCompilerMatrix -> "direct-serial-compile-fail-compiler-matrix"
  RequireIndependentCompileFailCorpusOracle -> "independent-compile-fail-corpus-oracle"
  RequireCompileFailLegalTwinControls -> "compile-fail-legal-twin-controls"
  RequireCompileFailPinnedIllegalTwins -> "compile-fail-pinned-illegal-twins"
  RequireAppliedCompileFailProductionMutants -> "applied-compile-fail-production-mutants"
  RequireExactCompileFailSourceDiscovery -> "exact-compile-fail-source-discovery"
  RequirePostAcquisitionCompileFailChallenge -> "post-acquisition-compile-fail-challenge"
  RequireCompileFailProcessObservation -> "compile-fail-process-observation"
  RequireNoPbNetworkHostHardwareOrCompileFailParallelism -> "no-pb-network-host-hardware-or-compile-fail-parallelism"
  RequireFreshCompileFailBuildRootsAndStableSource -> "fresh-compile-fail-build-roots-and-stable-source"
  RequireQualifiedCompileFailHarness -> "qualified-compile-fail-harness"
  RequireCompileFailProductsContainedBelowBuild -> "compile-fail-products-contained-below-build"
  RequireRetiredCompileFailBehavioralSourcesAbsent -> "retired-compile-fail-behavioral-sources-absent"
  RequireExactPhaseFourteenReceipt -> "exact-phase-fourteen-receipt"
  RequireLaterSimulationAndRuntimeClaimsExplicit -> "later-simulation-and-runtime-claims-explicit"
  RequireQualifiedPhaseFifteenGatePass -> "qualified-phase-fifteen-gate-pass"

phaseSixteenRequirementSlug :: PhaseSixteenRequirement -> Text
phaseSixteenRequirementSlug requirement = case requirement of
  RequireCompleteDeterministicSimulationSubstrate -> "complete-deterministic-simulation-substrate"
  RequireAcquiredDeterministicSimulationSupervisor -> "acquired-deterministic-simulation-supervisor"
  RequireDirectOfflineSerialSimulationMatrix -> "direct-offline-serial-simulation-matrix"
  RequireIndependentDeterministicSimulationOracle -> "independent-deterministic-simulation-oracle"
  RequireTwoInterpreterSimulationControls -> "two-interpreter-simulation-controls"
  RequireFaultKnobAndSchedulePairedNegatives -> "fault-knob-and-schedule-paired-negatives"
  RequireAppliedDeterministicSimulationProductionMutants -> "applied-deterministic-simulation-production-mutants"
  RequireExactDeterministicSimulationSourceDiscovery -> "exact-deterministic-simulation-source-discovery"
  RequirePostAcquisitionDeterministicSimulationChallenge -> "post-acquisition-deterministic-simulation-challenge"
  RequireDeterministicSimulationProcessObservation -> "deterministic-simulation-process-observation"
  RequireNoPbNetworkHostHardwareOrSimulationParallelism -> "no-pb-network-host-hardware-or-simulation-parallelism"
  RequireFreshSimulationBuildRootAndStableSource -> "fresh-simulation-build-root-and-stable-source"
  RequireQualifiedDeterministicSimulationHarness -> "qualified-deterministic-simulation-harness"
  RequireSimulationProductsContainedBelowBuild -> "simulation-products-contained-below-build"
  RequireRetiredSimulationBehavioralSourcesAbsent -> "retired-simulation-behavioral-sources-absent"
  RequireExactPhaseFifteenReceipt -> "exact-phase-fifteen-receipt"
  RequireLaterModelsRuntimesAndHardwareExplicit -> "later-models-runtimes-and-hardware-explicit"
  RequireQualifiedPhaseSixteenGatePass -> "qualified-phase-sixteen-gate-pass"

phaseSeventeenRequirementSlug :: PhaseSeventeenRequirement -> Text
phaseSeventeenRequirementSlug requirement = case requirement of
  RequireCompleteGatewayMigrationModel -> "complete-gateway-migration-model"
  RequireAcquiredGatewayMigrationModelSupervisor -> "acquired-gateway-migration-model-supervisor"
  RequireDirectOfflineSerialGatewayModelMatrix -> "direct-offline-serial-gateway-model-matrix"
  RequireIndependentGatewayMigrationOracle -> "independent-gateway-migration-oracle"
  RequireGatewayExplorerTlcAndScheduleControls -> "gateway-explorer-tlc-and-schedule-controls"
  RequireGatewayInvariantFairnessAndCutoffNegatives -> "gateway-invariant-fairness-and-cutoff-negatives"
  RequireAppliedGatewayMigrationProductionMutants -> "applied-gateway-migration-production-mutants"
  RequireExactGatewayMigrationSourceDiscovery -> "exact-gateway-migration-source-discovery"
  RequirePostAcquisitionGatewayMigrationChallenge -> "post-acquisition-gateway-migration-challenge"
  RequireGatewayMigrationProcessObservation -> "gateway-migration-process-observation"
  RequireNoPbNetworkHostHardwareOrGatewayParallelism -> "no-pb-network-host-hardware-or-gateway-parallelism"
  RequireFreshGatewayBuildRootAndStableSource -> "fresh-gateway-build-root-and-stable-source"
  RequireQualifiedGatewayMigrationHarness -> "qualified-gateway-migration-harness"
  RequireGatewayProductsContainedBelowBuild -> "gateway-products-contained-below-build"
  RequireRetiredGatewayBehavioralSourcesAbsent -> "retired-gateway-behavioral-sources-absent"
  RequireExactPhaseSixteenReceipt -> "exact-phase-sixteen-receipt"
  RequireGatewayRuntimeFidelityAndDecompositionExplicit -> "gateway-runtime-fidelity-and-decomposition-explicit"
  RequireQualifiedPhaseSeventeenGatePass -> "qualified-phase-seventeen-gate-pass"

phaseEighteenRequirementSlug :: PhaseEighteenRequirement -> Text
phaseEighteenRequirementSlug requirement = case requirement of
  RequireCompleteDslFormalModel -> "complete-dsl-formal-model"
  RequireAcquiredDslFormalModelSupervisor -> "acquired-dsl-formal-model-supervisor"
  RequireDirectOfflineSerialDslFormalMatrix -> "direct-offline-serial-dsl-formal-matrix"
  RequireIndependentDslFormalOracle -> "independent-dsl-formal-oracle"
  RequireDslModelCapacityCalculusAndProtocolControls -> "dsl-model-capacity-calculus-and-protocol-controls"
  RequireDslSafetyFairnessAndDecisionNegatives -> "dsl-safety-fairness-and-decision-negatives"
  RequireAppliedDslFormalProductionMutants -> "applied-dsl-formal-production-mutants"
  RequireExactDslFormalSourceDiscovery -> "exact-dsl-formal-source-discovery"
  RequirePostAcquisitionDslFormalChallenge -> "post-acquisition-dsl-formal-challenge"
  RequireDslFormalProcessObservation -> "dsl-formal-process-observation"
  RequireNoPbNetworkHostHardwareOrDslFormalParallelism -> "no-pb-network-host-hardware-or-dsl-formal-parallelism"
  RequireFreshDslFormalBuildRootAndStableSource -> "fresh-dsl-formal-build-root-and-stable-source"
  RequireQualifiedDslFormalHarness -> "qualified-dsl-formal-harness"
  RequireDslFormalProductsContainedBelowBuild -> "dsl-formal-products-contained-below-build"
  RequireRetiredDslFormalBehavioralSourcesAbsent -> "retired-dsl-formal-behavioral-sources-absent"
  RequireExactPhaseSeventeenReceipt -> "exact-phase-seventeen-receipt"
  RequireLaterDslRuntimeAndProjectionOwnersExplicit -> "later-dsl-runtime-and-projection-owners-explicit"
  RequireQualifiedPhaseEighteenGatePass -> "qualified-phase-eighteen-gate-pass"

phaseNineteenRequirementSlug :: PhaseNineteenRequirement -> Text
phaseNineteenRequirementSlug requirement = case requirement of
  RequireCompleteReconcileCoreSimulation -> "complete-reconcile-core-simulation"
  RequireAcquiredReconcileCoreSupervisor -> "acquired-reconcile-core-supervisor"
  RequireDirectOfflineSerialReconcileCoreMatrix -> "direct-offline-serial-reconcile-core-matrix"
  RequireIndependentReconcileCoreOracle -> "independent-reconcile-core-oracle"
  RequireReconcileCoreScheduleProtocolAndFormalControls -> "reconcile-core-schedule-protocol-and-formal-controls"
  RequireReconcileCorePairedNegatives -> "reconcile-core-paired-negatives"
  RequireAppliedReconcileCoreProductionMutants -> "applied-reconcile-core-production-mutants"
  RequireExactReconcileCoreSourceDiscovery -> "exact-reconcile-core-source-discovery"
  RequirePostAcquisitionReconcileCoreChallenge -> "post-acquisition-reconcile-core-challenge"
  RequireReconcileCoreProcessObservation -> "reconcile-core-process-observation"
  RequireNoPbNetworkHostHardwareOrReconcileCoreParallelism -> "no-pb-network-host-hardware-or-reconcile-core-parallelism"
  RequireFreshReconcileCoreBuildRootAndStableSource -> "fresh-reconcile-core-build-root-and-stable-source"
  RequireQualifiedReconcileCoreHarness -> "qualified-reconcile-core-harness"
  RequireReconcileCoreProductsContainedBelowBuild -> "reconcile-core-products-contained-below-build"
  RequireRetiredReconcileCoreBehavioralSourcesAbsent -> "retired-reconcile-core-behavioral-sources-absent"
  RequireExactPhaseEighteenReceipt -> "exact-phase-eighteen-receipt"
  RequireLaterEffectfulReconcileRuntimeExplicit -> "later-effectful-reconcile-runtime-explicit"
  RequireQualifiedPhaseNineteenGatePass -> "qualified-phase-nineteen-gate-pass"

phaseTwentyRequirementSlug :: PhaseTwentyRequirement -> Text
phaseTwentyRequirementSlug requirement = case requirement of
  RequireCompleteIndexedExtensionDeclaration -> "complete-indexed-extension-declaration"
  RequireAcquiredExtensionDeclarationSupervisor -> "acquired-extension-declaration-supervisor"
  RequireDirectOfflineSerialExtensionDeclarationMatrix -> "direct-offline-serial-extension-declaration-matrix"
  RequireIndependentExtensionDeclarationOracle -> "independent-extension-declaration-oracle"
  RequireDeclarationReaderResourceAndDigestControls -> "declaration-reader-resource-and-digest-controls"
  RequireDeclarationSemanticAndCompileNegatives -> "declaration-semantic-and-compile-negatives"
  RequireAppliedExtensionDeclarationProductionMutants -> "applied-extension-declaration-production-mutants"
  RequireExactExtensionDeclarationSourceDiscovery -> "exact-extension-declaration-source-discovery"
  RequirePostAcquisitionExtensionDeclarationChallenge -> "post-acquisition-extension-declaration-challenge"
  RequireExtensionDeclarationProcessObservation -> "extension-declaration-process-observation"
  RequireNoPbNetworkHostHardwareOrExtensionDeclarationParallelism -> "no-pb-network-host-hardware-or-extension-declaration-parallelism"
  RequireFreshExtensionDeclarationBuildRootAndStableSource -> "fresh-extension-declaration-build-root-and-stable-source"
  RequireQualifiedExtensionDeclarationHarness -> "qualified-extension-declaration-harness"
  RequireExtensionDeclarationProductsContainedBelowBuild -> "extension-declaration-products-contained-below-build"
  RequireRetiredExtensionDeclarationBehavioralSourcesAbsent -> "retired-extension-declaration-behavioral-sources-absent"
  RequireExactPhaseNineteenReceipt -> "exact-phase-nineteen-receipt"
  RequireLaterExtensionLawAndRuntimeOwnersExplicit -> "later-extension-law-and-runtime-owners-explicit"
  RequireQualifiedPhaseTwentyGatePass -> "qualified-phase-twenty-gate-pass"

phaseTwentyOneRequirementSlug :: PhaseTwentyOneRequirement -> Text
phaseTwentyOneRequirementSlug requirement = case requirement of
  RequireCompletePerExtensionLawEvaluator -> "complete-per-extension-law-evaluator"
  RequireAcquiredExtensionLawsSupervisor -> "acquired-extension-laws-supervisor"
  RequireDirectOfflineSerialExtensionLawsMatrix -> "direct-offline-serial-extension-laws-matrix"
  RequireIndependentExtensionLawsOracle -> "independent-extension-laws-oracle"
  RequireLawfulOperationRenderBudgetAndEvidenceControls -> "lawful-operation-render-budget-and-evidence-controls"
  RequireSingleLawAndClaimCompileNegatives -> "single-law-and-claim-compile-negatives"
  RequireAppliedExtensionLawsProductionMutants -> "applied-extension-laws-production-mutants"
  RequireExactExtensionLawsSourceDiscovery -> "exact-extension-laws-source-discovery"
  RequirePostAcquisitionExtensionLawsChallenge -> "post-acquisition-extension-laws-challenge"
  RequireExtensionLawsProcessObservation -> "extension-laws-process-observation"
  RequireNoPbNetworkHostHardwareOrExtensionLawsParallelism -> "no-pb-network-host-hardware-or-extension-laws-parallelism"
  RequireFreshExtensionLawsBuildRootAndStableSource -> "fresh-extension-laws-build-root-and-stable-source"
  RequireQualifiedExtensionLawsHarness -> "qualified-extension-laws-harness"
  RequireExtensionLawsProductsContainedBelowBuild -> "extension-laws-products-contained-below-build"
  RequireRetiredExtensionLawsBehavioralSourcesAbsent -> "retired-extension-laws-behavioral-sources-absent"
  RequireExactPhaseTwentyReceipt -> "exact-phase-twenty-receipt"
  RequireLaterCompositionalSecurityConformanceAndRuntimeOwnersExplicit -> "later-compositional-security-conformance-and-runtime-owners-explicit"
  RequireQualifiedPhaseTwentyOneGatePass -> "qualified-phase-twenty-one-gate-pass"

phaseTwentyTwoRequirementSlug :: PhaseTwentyTwoRequirement -> Text
phaseTwentyTwoRequirementSlug requirement = case requirement of
  RequireCompleteNormalizedCompositeAndC1C7Evaluator -> "complete-normalized-composite-and-c1-c7-evaluator"
  RequireAcquiredExtensionCompositionSupervisor -> "acquired-extension-composition-supervisor"
  RequireDirectOfflineSerialExtensionCompositionMatrix -> "direct-offline-serial-extension-composition-matrix"
  RequireIndependentExtensionCompositionOracle -> "independent-extension-composition-oracle"
  RequireLawfulCompositionIdentityAssociationBudgetAndAddressControls -> "lawful-composition-identity-association-budget-and-address-controls"
  RequireCompositionLawAndRequestScopeNegatives -> "composition-law-and-request-scope-negatives"
  RequireAppliedExtensionCompositionProductionMutants -> "applied-extension-composition-production-mutants"
  RequireExactExtensionCompositionSourceDiscovery -> "exact-extension-composition-source-discovery"
  RequirePostAcquisitionExtensionCompositionChallenge -> "post-acquisition-extension-composition-challenge"
  RequireExtensionCompositionProcessObservation -> "extension-composition-process-observation"
  RequireNoPbNetworkHostHardwareOrExtensionCompositionParallelism -> "no-pb-network-host-hardware-or-extension-composition-parallelism"
  RequireFreshExtensionCompositionBuildRootAndStableSource -> "fresh-extension-composition-build-root-and-stable-source"
  RequireQualifiedExtensionCompositionHarness -> "qualified-extension-composition-harness"
  RequireExtensionCompositionProductsContainedBelowBuild -> "extension-composition-products-contained-below-build"
  RequireRetiredExtensionCompositionBehavioralSourcesAbsent -> "retired-extension-composition-behavioral-sources-absent"
  RequireExactPhaseTwentyOneReceipt -> "exact-phase-twenty-one-receipt"
  RequireLaterSecurityConformanceProofAndRuntimeOwnersExplicit -> "later-security-conformance-proof-and-runtime-owners-explicit"
  RequireQualifiedPhaseTwentyTwoGatePass -> "qualified-phase-twenty-two-gate-pass"

phaseTwentyThreeRequirementSlug :: PhaseTwentyThreeRequirement -> Text
phaseTwentyThreeRequirementSlug requirement = case requirement of
  RequireBoundedTypedSecurityKernelAndS1S6Evaluator -> "bounded-typed-security-kernel-and-s1-s6-evaluator"
  RequireAcquiredExtensionSecuritySupervisor -> "acquired-extension-security-supervisor"
  RequireDirectOfflineSerialExtensionSecurityMatrix -> "direct-offline-serial-extension-security-matrix"
  RequireIndependentExtensionSecurityOracle -> "independent-extension-security-oracle"
  RequireIdentityOperationRefusalNamespaceAndPolicyControls -> "identity-operation-refusal-namespace-and-policy-controls"
  RequireSecurityLawAndFourCompilerBarrierNegatives -> "security-law-and-four-compiler-barrier-negatives"
  RequireAppliedExtensionSecurityProductionMutants -> "applied-extension-security-production-mutants"
  RequireExactExtensionSecuritySourceDiscovery -> "exact-extension-security-source-discovery"
  RequirePostAcquisitionExtensionSecurityChallenge -> "post-acquisition-extension-security-challenge"
  RequireExtensionSecurityProcessObservation -> "extension-security-process-observation"
  RequireNoPbNetworkHostHardwareOrExtensionSecurityParallelism -> "no-pb-network-host-hardware-or-extension-security-parallelism"
  RequireFreshExtensionSecurityBuildRootAndStableSource -> "fresh-extension-security-build-root-and-stable-source"
  RequireQualifiedExtensionSecurityHarness -> "qualified-extension-security-harness"
  RequireExtensionSecurityProductsContainedBelowBuild -> "extension-security-products-contained-below-build"
  RequireRetiredExtensionSecurityBehavioralSourcesAbsent -> "retired-extension-security-behavioral-sources-absent"
  RequireExactPhaseTwentyTwoReceipt -> "exact-phase-twenty-two-receipt"
  RequireLaterSecurityClosureConformanceCryptoTimingAndRuntimeOwnersExplicit -> "later-security-closure-conformance-crypto-timing-and-runtime-owners-explicit"
  RequireQualifiedPhaseTwentyThreeGatePass -> "qualified-phase-twenty-three-gate-pass"

phaseTwentyFourRequirementSlug :: PhaseTwentyFourRequirement -> Text
phaseTwentyFourRequirementSlug requirement = case requirement of
  RequireDeclarationDerivedConformancePlanVerdictAndAdmission -> "declaration-derived-conformance-plan-verdict-and-admission"
  RequireAcquiredConformanceGateSupervisor -> "acquired-conformance-gate-supervisor"
  RequireDirectOfflineSerialConformanceGateMatrix -> "direct-offline-serial-conformance-gate-matrix"
  RequireIndependentConformanceGateOracle -> "independent-conformance-gate-oracle"
  RequireSuiteCoverageVerdictAndAdmissionControls -> "suite-coverage-verdict-and-admission-controls"
  RequireConformanceRefusalAndCompilerBarrierNegatives -> "conformance-refusal-and-compiler-barrier-negatives"
  RequireAppliedConformanceGateProductionMutants -> "applied-conformance-gate-production-mutants"
  RequireExactConformanceGateSourceDiscovery -> "exact-conformance-gate-source-discovery"
  RequirePostAcquisitionConformanceGateChallenge -> "post-acquisition-conformance-gate-challenge"
  RequireConformanceGateProcessObservation -> "conformance-gate-process-observation"
  RequireNoPbNetworkHostHardwareOrConformanceGateParallelism -> "no-pb-network-host-hardware-or-conformance-gate-parallelism"
  RequireFreshConformanceGateBuildRootAndStableSource -> "fresh-conformance-gate-build-root-and-stable-source"
  RequireQualifiedConformanceGateHarness -> "qualified-conformance-gate-harness"
  RequireConformanceGateProductsContainedBelowBuild -> "conformance-gate-products-contained-below-build"
  RequireRetiredConformanceGateBehavioralSourcesAbsent -> "retired-conformance-gate-behavioral-sources-absent"
  RequireExactPhaseTwentyThreeReceipt -> "exact-phase-twenty-three-receipt"
  RequireLaterTransactionObserverSemanticClosureAndRuntimeOwnersExplicit -> "later-transaction-observer-semantic-closure-and-runtime-owners-explicit"
  RequireQualifiedPhaseTwentyFourGatePass -> "qualified-phase-twenty-four-gate-pass"

phaseTwentyFiveRequirementSlug :: PhaseTwentyFiveRequirement -> Text
phaseTwentyFiveRequirementSlug requirement = case requirement of
  RequireHaskellDerivedDhallStructuralLanguage -> "haskell-derived-dhall-structural-language"
  RequireAcquiredDhallSchemaSupervisor -> "acquired-dhall-schema-supervisor"
  RequireDirectOfflineSerialDhallSchemaMatrix -> "direct-offline-serial-dhall-schema-matrix"
  RequireIndependentDhallSchemaOracle -> "independent-dhall-schema-oracle"
  RequireSchemaModuleAndPositiveTypecheckControls -> "schema-module-and-positive-typecheck-controls"
  RequirePairedDhallStructuralAndImportNegatives -> "paired-dhall-structural-and-import-negatives"
  RequireAppliedDhallSchemaProductionMutants -> "applied-dhall-schema-production-mutants"
  RequireExactDhallSchemaSourceDiscovery -> "exact-dhall-schema-source-discovery"
  RequirePostAcquisitionDhallSchemaChallenge -> "post-acquisition-dhall-schema-challenge"
  RequireDhallSchemaProcessObservation -> "dhall-schema-process-observation"
  RequireNoPbNetworkHostHardwareOrDhallSchemaParallelism -> "no-pb-network-host-hardware-or-dhall-schema-parallelism"
  RequireFreshDhallSchemaBuildRootAndStableSource -> "fresh-dhall-schema-build-root-and-stable-source"
  RequireQualifiedDhallSchemaHarness -> "qualified-dhall-schema-harness"
  RequireDhallSchemaProductsContainedBelowBuild -> "dhall-schema-products-contained-below-build"
  RequireRetiredDhallBehavioralSourcesAbsent -> "retired-dhall-behavioral-sources-absent"
  RequireExactPhaseTwentyFourReceipt -> "exact-phase-twenty-four-receipt"
  RequireLaterBindingDecodeProvisionRuntimeOwnersExplicit -> "later-binding-decode-provision-runtime-owners-explicit"
  RequireQualifiedPhaseTwentyFiveGatePass -> "qualified-phase-twenty-five-gate-pass"

phaseTwentySixRequirementSlug :: PhaseTwentySixRequirement -> Text
phaseTwentySixRequirementSlug requirement = case requirement of
  RequireHaskellProtocolAndIndexedDecodeBoundary -> "haskell-protocol-and-indexed-decode-boundary"
  RequireAcquiredGadtDecodeSupervisor -> "acquired-gadt-decode-supervisor"
  RequireDirectOfflineSerialGadtDecodeMatrix -> "direct-offline-serial-gadt-decode-matrix"
  RequireIndependentGadtDecodeOracle -> "independent-gadt-decode-oracle"
  RequireControllerIndexedPositiveDecodeControls -> "controller-indexed-positive-decode-controls"
  RequirePairedGadtDecodeNegatives -> "paired-gadt-decode-negatives"
  RequireAppliedGadtDecodeProductionMutants -> "applied-gadt-decode-production-mutants"
  RequireExactGadtDecodeSourceDiscovery -> "exact-gadt-decode-source-discovery"
  RequirePostAcquisitionGadtDecodeChallenge -> "post-acquisition-gadt-decode-challenge"
  RequireGadtDecodeProcessObservation -> "gadt-decode-process-observation"
  RequireNoPbNetworkHostHardwareOrGadtDecodeParallelism -> "no-pb-network-host-hardware-or-gadt-decode-parallelism"
  RequireFreshGadtDecodeBuildRootAndStableSource -> "fresh-gadt-decode-build-root-and-stable-source"
  RequireQualifiedGadtDecodeHarness -> "qualified-gadt-decode-harness"
  RequireGadtDecodeProductsContainedBelowBuild -> "gadt-decode-products-contained-below-build"
  RequireRetiredProtoAndGadtDecodeAuthoritiesAbsent -> "retired-proto-and-gadt-decode-authorities-absent"
  RequireExactPhaseTwentyFiveReceipt -> "exact-phase-twenty-five-receipt"
  RequireLaterCapacityBindingProvisionRuntimeOwnersExplicit -> "later-capacity-binding-provision-runtime-owners-explicit"
  RequireQualifiedPhaseTwentySixGatePass -> "qualified-phase-twenty-six-gate-pass"

phaseTwentySevenRequirementSlug :: PhaseTwentySevenRequirement -> Text
phaseTwentySevenRequirementSlug requirement = case requirement of
  RequireClosedHaskellIllegalStateCoverageLedger -> "closed-haskell-illegal-state-coverage-ledger"
  RequireAcquiredIllegalStateCoveringSupervisor -> "acquired-illegal-state-covering-supervisor"
  RequireDirectOfflineSerialIllegalStateCoveringMatrix -> "direct-offline-serial-illegal-state-covering-matrix"
  RequireIndependentIllegalStateCoveringOracle -> "independent-illegal-state-covering-oracle"
  RequireDhallDecodeCompileAndPropertyPositiveControls -> "dhall-decode-compile-and-property-positive-controls"
  RequirePairedIllegalStateForeclosureNegatives -> "paired-illegal-state-foreclosure-negatives"
  RequireAppliedIllegalStateCoveringProductionMutants -> "applied-illegal-state-covering-production-mutants"
  RequireExactIllegalStateCoveringSourceDiscovery -> "exact-illegal-state-covering-source-discovery"
  RequirePostAcquisitionIllegalStateCoveringChallenge -> "post-acquisition-illegal-state-covering-challenge"
  RequireIllegalStateCoveringProcessObservation -> "illegal-state-covering-process-observation"
  RequireNoPbNetworkHostHardwareOrIllegalStateParallelism -> "no-pb-network-host-hardware-or-illegal-state-parallelism"
  RequireFreshIllegalStateBuildRootAndStableSource -> "fresh-illegal-state-build-root-and-stable-source"
  RequireQualifiedIllegalStateCoveringHarness -> "qualified-illegal-state-covering-harness"
  RequireIllegalStateProductsContainedBelowBuild -> "illegal-state-products-contained-below-build"
  RequireRetiredBehavioralDocumentAuthoritiesAbsent -> "retired-behavioral-document-authorities-absent"
  RequireExactPhaseTwentySixReceipt -> "exact-phase-twenty-six-receipt"
  RequireLaterProvisionRenderRuntimeOwnersExplicit -> "later-provision-render-runtime-owners-explicit"
  RequireQualifiedPhaseTwentySevenGatePass -> "qualified-phase-twenty-seven-gate-pass"

phaseTwentyEightRequirementSlug :: PhaseTwentyEightRequirement -> Text
phaseTwentyEightRequirementSlug requirement = case requirement of
  RequirePureStorageGeometryFoldBoundary -> "pure-storage-geometry-fold-boundary"
  RequireAcquiredStorageGeometrySupervisor -> "acquired-storage-geometry-supervisor"
  RequireDirectOfflineSerialStorageGeometryMatrix -> "direct-offline-serial-storage-geometry-matrix"
  RequireIndependentStorageGeometryOracle -> "independent-storage-geometry-oracle"
  RequireStorageGeometryPositiveControls -> "storage-geometry-positive-controls"
  RequirePairedStorageGeometryNegatives -> "paired-storage-geometry-negatives"
  RequireAppliedStorageGeometryProductionMutants -> "applied-storage-geometry-production-mutants"
  RequireExactStorageGeometrySourceDiscovery -> "exact-storage-geometry-source-discovery"
  RequirePostAcquisitionStorageGeometryChallenge -> "post-acquisition-storage-geometry-challenge"
  RequireStorageGeometryProcessObservation -> "storage-geometry-process-observation"
  RequireNoPbNetworkHostHardwareOrStorageParallelism -> "no-pb-network-host-hardware-or-storage-parallelism"
  RequireFreshStorageGeometryBuildRootAndStableSource -> "fresh-storage-geometry-build-root-and-stable-source"
  RequireQualifiedStorageGeometryHarness -> "qualified-storage-geometry-harness"
  RequireStorageGeometryProductsContainedBelowBuild -> "storage-geometry-products-contained-below-build"
  RequireRetiredStorageGeometryAuthoritiesAbsent -> "retired-storage-geometry-authorities-absent"
  RequireExactPhaseTwentySevenReceipt -> "exact-phase-twenty-seven-receipt"
  RequireLaterBindingProvisionRuntimeStorageOwnersExplicit -> "later-binding-provision-runtime-storage-owners-explicit"
  RequireQualifiedPhaseTwentyEightGatePass -> "qualified-phase-twenty-eight-gate-pass"

phaseTwentyNineRequirementSlug :: PhaseTwentyNineRequirement -> Text
phaseTwentyNineRequirementSlug requirement = case requirement of
  RequirePureExecutionAcceleratorFoldBoundary -> "pure-execution-accelerator-fold-boundary"
  RequireAcquiredExecutionAcceleratorSupervisor -> "acquired-execution-accelerator-supervisor"
  RequireDirectOfflineSerialExecutionAcceleratorMatrix -> "direct-offline-serial-execution-accelerator-matrix"
  RequireIndependentExecutionAcceleratorOracle -> "independent-execution-accelerator-oracle"
  RequireExecutionAcceleratorPositiveControls -> "execution-accelerator-positive-controls"
  RequirePairedExecutionAcceleratorNegatives -> "paired-execution-accelerator-negatives"
  RequireAppliedExecutionAcceleratorProductionMutants -> "applied-execution-accelerator-production-mutants"
  RequireExactExecutionAcceleratorSourceDiscovery -> "exact-execution-accelerator-source-discovery"
  RequirePostAcquisitionExecutionAcceleratorChallenge -> "post-acquisition-execution-accelerator-challenge"
  RequireExecutionAcceleratorProcessObservation -> "execution-accelerator-process-observation"
  RequireNoPbNetworkHostHardwareOrExecutionParallelism -> "no-pb-network-host-hardware-or-execution-parallelism"
  RequireFreshExecutionAcceleratorBuildRootAndStableSource -> "fresh-execution-accelerator-build-root-and-stable-source"
  RequireQualifiedExecutionAcceleratorHarness -> "qualified-execution-accelerator-harness"
  RequireExecutionAcceleratorProductsContainedBelowBuild -> "execution-accelerator-products-contained-below-build"
  RequireRetiredExecutionAcceleratorAuthoritiesAbsent -> "retired-execution-accelerator-authorities-absent"
  RequireExactPhaseTwentyEightReceipt -> "exact-phase-twenty-eight-receipt"
  RequireLaterBindingProvisionRuntimeExecutionOwnersExplicit -> "later-binding-provision-runtime-execution-owners-explicit"
  RequireQualifiedPhaseTwentyNineGatePass -> "qualified-phase-twenty-nine-gate-pass"

phaseThirtyRequirementSlug :: PhaseThirtyRequirement -> Text
phaseThirtyRequirementSlug requirement = case requirement of
  RequirePureCapabilityBindBoundary -> "pure-capability-bind-boundary"
  RequireAcquiredCapabilityBindSupervisor -> "acquired-capability-bind-supervisor"
  RequireDirectOfflineSerialCapabilityBindMatrix -> "direct-offline-serial-capability-bind-matrix"
  RequireIndependentCapabilityBindOracle -> "independent-capability-bind-oracle"
  RequireCapabilityBindPositiveControls -> "capability-bind-positive-controls"
  RequirePairedCapabilityBindNegatives -> "paired-capability-bind-negatives"
  RequireAppliedCapabilityBindProductionMutants -> "applied-capability-bind-production-mutants"
  RequireExactCapabilityBindSourceDiscovery -> "exact-capability-bind-source-discovery"
  RequirePostAcquisitionCapabilityBindChallenge -> "post-acquisition-capability-bind-challenge"
  RequireCapabilityBindProcessObservation -> "capability-bind-process-observation"
  RequireNoPbNetworkHostHardwareOrCapabilityBindParallelism -> "no-pb-network-host-hardware-or-capability-bind-parallelism"
  RequireFreshCapabilityBindBuildRootAndStableSource -> "fresh-capability-bind-build-root-and-stable-source"
  RequireQualifiedCapabilityBindHarness -> "qualified-capability-bind-harness"
  RequireCapabilityBindProductsContainedBelowBuild -> "capability-bind-products-contained-below-build"
  RequireRetiredCapabilityBindAuthoritiesAbsent -> "retired-capability-bind-authorities-absent"
  RequireExactPhaseTwentyNineReceipt -> "exact-phase-twenty-nine-receipt"
  RequireLaterProvisionRenderRuntimeCapabilityOwnersExplicit -> "later-provision-render-runtime-capability-owners-explicit"
  RequireQualifiedPhaseThirtyGatePass -> "qualified-phase-thirty-gate-pass"

phaseThirtyOneRequirementSlug :: PhaseThirtyOneRequirement -> Text
phaseThirtyOneRequirementSlug requirement = case requirement of
  RequireCompleteProvisionSealBoundary -> "complete-provision-seal-boundary"
  RequireAcquiredProvisionSealSupervisor -> "acquired-provision-seal-supervisor"
  RequireDirectOfflineSerialProvisionSealMatrix -> "direct-offline-serial-provision-seal-matrix"
  RequireIndependentProvisionSealOracle -> "independent-provision-seal-oracle"
  RequireProvisionSealPositiveControls -> "provision-seal-positive-controls"
  RequirePairedProvisionSealNegatives -> "paired-provision-seal-negatives"
  RequireAppliedProvisionSealProductionMutants -> "applied-provision-seal-production-mutants"
  RequireExactProvisionSealSourceDiscovery -> "exact-provision-seal-source-discovery"
  RequirePostAcquisitionProvisionSealChallenge -> "post-acquisition-provision-seal-challenge"
  RequireProvisionSealProcessObservation -> "provision-seal-process-observation"
  RequireNoPbNetworkHostHardwareOrProvisionSealParallelism -> "no-pb-network-host-hardware-or-provision-seal-parallelism"
  RequireFreshProvisionSealBuildRootAndStableSource -> "fresh-provision-seal-build-root-and-stable-source"
  RequireQualifiedProvisionSealHarness -> "qualified-provision-seal-harness"
  RequireProvisionSealProductsContainedBelowBuild -> "provision-seal-products-contained-below-build"
  RequireRetiredProvisionSealAuthoritiesAbsent -> "retired-provision-seal-authorities-absent"
  RequireExactPhaseThirtyReceipt -> "exact-phase-thirty-receipt"
  RequireLaterRenderRuntimeLiveProvisionOwnersExplicit -> "later-render-runtime-live-provision-owners-explicit"
  RequireQualifiedPhaseThirtyOneGatePass -> "qualified-phase-thirty-one-gate-pass"

phaseThirtyTwoRequirementSlug :: PhaseThirtyTwoRequirement -> Text
phaseThirtyTwoRequirementSlug requirement = case requirement of
  RequireClosedInferenceAcceleratorProvisionBoundary -> "closed-inference-accelerator-provision-boundary"
  RequireAcquiredInferenceAcceleratorSupervisor -> "acquired-inference-accelerator-supervisor"
  RequireDirectOfflineSerialInferenceAcceleratorMatrix -> "direct-offline-serial-inference-accelerator-matrix"
  RequireIndependentInferenceAcceleratorOracle -> "independent-inference-accelerator-oracle"
  RequireInferenceAcceleratorPositiveControls -> "inference-accelerator-positive-controls"
  RequirePairedInferenceAcceleratorNegatives -> "paired-inference-accelerator-negatives"
  RequireAppliedInferenceAcceleratorProductionMutants -> "applied-inference-accelerator-production-mutants"
  RequireExactInferenceAcceleratorSourceDiscovery -> "exact-inference-accelerator-source-discovery"
  RequirePostAcquisitionInferenceAcceleratorChallenge -> "post-acquisition-inference-accelerator-challenge"
  RequireInferenceAcceleratorProcessObservation -> "inference-accelerator-process-observation"
  RequireNoPbNetworkHostHardwareOrInferenceAcceleratorParallelism -> "no-pb-network-host-hardware-or-inference-accelerator-parallelism"
  RequireFreshInferenceAcceleratorBuildRootAndStableSource -> "fresh-inference-accelerator-build-root-and-stable-source"
  RequireQualifiedInferenceAcceleratorHarness -> "qualified-inference-accelerator-harness"
  RequireInferenceAcceleratorProductsContainedBelowBuild -> "inference-accelerator-products-contained-below-build"
  RequireRetiredInferenceAcceleratorAuthoritiesAbsent -> "retired-inference-accelerator-authorities-absent"
  RequireExactPhaseThirtyOneReceipt -> "exact-phase-thirty-one-receipt"
  RequireLaterRenderRuntimeLiveEngineOwnersExplicit -> "later-render-runtime-live-engine-owners-explicit"
  RequireQualifiedPhaseThirtyTwoGatePass -> "qualified-phase-thirty-two-gate-pass"

phaseThirtyThreeRequirementSlug :: PhaseThirtyThreeRequirement -> Text
phaseThirtyThreeRequirementSlug requirement = case requirement of
  RequirePureTotalRenderAllBoundary -> "pure-total-render-all-boundary"
  RequireAcquiredRenderManifestSupervisor -> "acquired-render-manifest-supervisor"
  RequireDirectOfflineSerialRenderManifestMatrix -> "direct-offline-serial-render-manifest-matrix"
  RequireIndependentRenderManifestOracle -> "independent-render-manifest-oracle"
  RequireRenderManifestPositiveControls -> "render-manifest-positive-controls"
  RequirePairedRenderManifestNegatives -> "paired-render-manifest-negatives"
  RequireAppliedRenderManifestProductionMutants -> "applied-render-manifest-production-mutants"
  RequireExactRenderManifestSourceDiscovery -> "exact-render-manifest-source-discovery"
  RequirePostAcquisitionRenderManifestChallenge -> "post-acquisition-render-manifest-challenge"
  RequireRenderManifestProcessObservation -> "render-manifest-process-observation"
  RequireNoPbNetworkHostHardwareOrRenderManifestParallelism -> "no-pb-network-host-hardware-or-render-manifest-parallelism"
  RequireFreshRenderManifestBuildRootAndStableSource -> "fresh-render-manifest-build-root-and-stable-source"
  RequireQualifiedRenderManifestHarness -> "qualified-render-manifest-harness"
  RequireRenderManifestProductsContainedBelowBuild -> "render-manifest-products-contained-below-build"
  RequireRetiredRenderManifestAuthoritiesAbsent -> "retired-render-manifest-authorities-absent"
  RequireExactPhaseThirtyTwoReceipt -> "exact-phase-thirty-two-receipt"
  RequireLaterActionsDryRunRuntimeLiveOwnersExplicit -> "later-actions-dry-run-runtime-live-owners-explicit"
  RequireQualifiedPhaseThirtyThreeGatePass -> "qualified-phase-thirty-three-gate-pass"

phaseThirtyFourRequirementSlug :: PhaseThirtyFourRequirement -> Text
phaseThirtyFourRequirementSlug requirement = case requirement of
  RequirePureChainAndFakeBoundary -> "pure-chain-and-fake-boundary"
  RequireAcquiredChainBoundarySupervisor -> "acquired-chain-boundary-supervisor"
  RequireDirectOfflineSerialChainBoundaryMatrix -> "direct-offline-serial-chain-boundary-matrix"
  RequireIndependentChainBoundaryOracle -> "independent-chain-boundary-oracle"
  RequireChainBoundaryPositiveControls -> "chain-boundary-positive-controls"
  RequirePairedChainBoundaryNegatives -> "paired-chain-boundary-negatives"
  RequireAppliedChainBoundaryProductionMutants -> "applied-chain-boundary-production-mutants"
  RequireExactChainBoundarySourceDiscovery -> "exact-chain-boundary-source-discovery"
  RequirePostAcquisitionChainBoundaryChallenge -> "post-acquisition-chain-boundary-challenge"
  RequireChainBoundaryProcessObservation -> "chain-boundary-process-observation"
  RequireNoPbNetworkLiveHostHardwareOrParallelism -> "no-pb-network-live-host-hardware-or-parallelism"
  RequireFreshChainBoundaryBuildRootAndStableSource -> "fresh-chain-boundary-build-root-and-stable-source"
  RequireQualifiedChainBoundaryHarness -> "qualified-chain-boundary-harness"
  RequireChainBoundaryProductsContainedBelowBuild -> "chain-boundary-products-contained-below-build"
  RequireRetiredChainBoundaryAuthoritiesAbsent -> "retired-chain-boundary-authorities-absent"
  RequireExactPhaseThirtyThreeReceipt -> "exact-phase-thirty-three-receipt"
  RequireLiveInterpreterRuntimeAndHardwareOwnersExplicit -> "live-interpreter-runtime-and-hardware-owners-explicit"
  RequireQualifiedPhaseThirtyFourGatePass -> "qualified-phase-thirty-four-gate-pass"

phaseThirtyFiveRequirementSlug :: PhaseThirtyFiveRequirement -> Text
phaseThirtyFiveRequirementSlug requirement = case requirement of
  RequirePureTotalImageRecipeBoundary -> "pure-total-image-recipe-boundary"
  RequireAcquiredImageRecipeSupervisor -> "acquired-image-recipe-supervisor"
  RequireDirectOfflineSerialImageRecipeMatrix -> "direct-offline-serial-image-recipe-matrix"
  RequireIndependentImageRecipeOracle -> "independent-image-recipe-oracle"
  RequireImageRecipePositiveControls -> "image-recipe-positive-controls"
  RequirePairedImageRecipeNegatives -> "paired-image-recipe-negatives"
  RequireAppliedImageRecipeProductionMutants -> "applied-image-recipe-production-mutants"
  RequireExactImageRecipeSourceDiscovery -> "exact-image-recipe-source-discovery"
  RequirePostAcquisitionImageRecipeChallenge -> "post-acquisition-image-recipe-challenge"
  RequireImageRecipeProcessObservation -> "image-recipe-process-observation"
  RequireNoPbNetworkEngineHostHardwareOrParallelism -> "no-pb-network-engine-host-hardware-or-parallelism"
  RequireFreshImageRecipeBuildRootAndStableSource -> "fresh-image-recipe-build-root-and-stable-source"
  RequireQualifiedImageRecipeHarness -> "qualified-image-recipe-harness"
  RequireImageRecipeProductsContainedBelowBuild -> "image-recipe-products-contained-below-build"
  RequireRetiredImageRecipeAuthoritiesAbsent -> "retired-image-recipe-authorities-absent"
  RequireExactPhaseThirtyFourReceipt -> "exact-phase-thirty-four-receipt"
  RequireLiveResolutionBuildPublicationRuntimeOwnersExplicit -> "live-resolution-build-publication-runtime-owners-explicit"
  RequireQualifiedPhaseThirtyFiveGatePass -> "qualified-phase-thirty-five-gate-pass"

phaseThirtySixRequirementSlug :: PhaseThirtySixRequirement -> Text
phaseThirtySixRequirementSlug requirement = case requirement of
  RequirePureClosedTransactionVocabulary -> "pure-closed-transaction-vocabulary"
  RequireAcquiredTransactionVocabularySupervisor -> "acquired-transaction-vocabulary-supervisor"
  RequireDirectOfflineSerialTransactionVocabularyMatrix -> "direct-offline-serial-transaction-vocabulary-matrix"
  RequireIndependentTransactionVocabularyOracle -> "independent-transaction-vocabulary-oracle"
  RequireTransactionVocabularyPositiveControls -> "transaction-vocabulary-positive-controls"
  RequireTransactionVocabularyCompilerNegatives -> "transaction-vocabulary-compiler-negatives"
  RequireAppliedTransactionVocabularyProductionMutants -> "applied-transaction-vocabulary-production-mutants"
  RequireExactTransactionVocabularySourceDiscovery -> "exact-transaction-vocabulary-source-discovery"
  RequirePostAcquisitionTransactionVocabularyChallenge -> "post-acquisition-transaction-vocabulary-challenge"
  RequireTransactionVocabularyProcessObservation -> "transaction-vocabulary-process-observation"
  RequireNoPbNetworkDatabaseHostHardwareOrParallelism -> "no-pb-network-database-host-hardware-or-parallelism"
  RequireFreshTransactionVocabularyBuildRootAndStableSource -> "fresh-transaction-vocabulary-build-root-and-stable-source"
  RequireQualifiedTransactionVocabularyHarness -> "qualified-transaction-vocabulary-harness"
  RequireTransactionVocabularyProductsContainedBelowBuild -> "transaction-vocabulary-products-contained-below-build"
  RequireRetiredTransactionVocabularyAuthoritiesAbsent -> "retired-transaction-vocabulary-authorities-absent"
  RequireExactPhaseThirtyFiveReceipt -> "exact-phase-thirty-five-receipt"
  RequireLiveDatabasePolicyRuntimeOwnersExplicit -> "live-database-policy-runtime-owners-explicit"
  RequireQualifiedPhaseThirtySixGatePass -> "qualified-phase-thirty-six-gate-pass"

phaseThirtySevenRequirementSlug :: PhaseThirtySevenRequirement -> Text
phaseThirtySevenRequirementSlug requirement = case requirement of
  RequirePureBoundedUiProgramSchema -> "pure-bounded-ui-program-schema"
  RequireAcquiredUiProgramSchemaSupervisor -> "acquired-ui-program-schema-supervisor"
  RequireDirectOfflineSerialUiProgramSchemaMatrix -> "direct-offline-serial-ui-program-schema-matrix"
  RequireIndependentUiProgramSchemaOracle -> "independent-ui-program-schema-oracle"
  RequireUiProgramSchemaPositiveControls -> "ui-program-schema-positive-controls"
  RequireExactUiProgramSchemaNegatives -> "exact-ui-program-schema-negatives"
  RequireAppliedUiProgramSchemaProductionMutants -> "applied-ui-program-schema-production-mutants"
  RequireExactUiProgramSchemaSourceDiscovery -> "exact-ui-program-schema-source-discovery"
  RequirePostAcquisitionUiProgramSchemaChallenge -> "post-acquisition-ui-program-schema-challenge"
  RequireUiProgramSchemaProcessObservation -> "ui-program-schema-process-observation"
  RequireNoPbNetworkBrowserHostHardwareOrParallelism -> "no-pb-network-browser-host-hardware-or-parallelism"
  RequireFreshUiProgramSchemaBuildRootAndStableSource -> "fresh-ui-program-schema-build-root-and-stable-source"
  RequireQualifiedUiProgramSchemaHarness -> "qualified-ui-program-schema-harness"
  RequireUiProgramSchemaProductsContainedBelowBuild -> "ui-program-schema-products-contained-below-build"
  RequireRetiredUiProgramSchemaAuthoritiesAbsent -> "retired-ui-program-schema-authorities-absent"
  RequireExactPhaseThirtySixReceipt -> "exact-phase-thirty-six-receipt"
  RequireUiRuntimeAndProviderOwnersExplicit -> "ui-runtime-and-provider-owners-explicit"
  RequireQualifiedPhaseThirtySevenGatePass -> "qualified-phase-thirty-seven-gate-pass"

phaseThirtyEightRequirementSlug :: PhaseThirtyEightRequirement -> Text
phaseThirtyEightRequirementSlug requirement = case requirement of
  RequirePureSealedUiAuthorizationKernel -> "pure-sealed-ui-authorization-kernel"
  RequireAcquiredUiAuthorizationSupervisor -> "acquired-ui-authorization-supervisor"
  RequireDirectOfflineSerialUiAuthorizationMatrix -> "direct-offline-serial-ui-authorization-matrix"
  RequireIndependentUiAuthorizationOracle -> "independent-ui-authorization-oracle"
  RequireUiAuthorizationPositiveControls -> "ui-authorization-positive-controls"
  RequireExactUiAuthorizationPairedNegatives -> "exact-ui-authorization-paired-negatives"
  RequireAppliedUiAuthorizationProductionMutants -> "applied-ui-authorization-production-mutants"
  RequireExactUiAuthorizationSourceDiscovery -> "exact-ui-authorization-source-discovery"
  RequirePostAcquisitionUiAuthorizationChallenge -> "post-acquisition-ui-authorization-challenge"
  RequireUiAuthorizationProcessObservation -> "ui-authorization-process-observation"
  RequireNoPbNetworkIdentityProviderHostHardwareOrParallelism -> "no-pb-network-identity-provider-host-hardware-or-parallelism"
  RequireFreshUiAuthorizationBuildRootAndStableSource -> "fresh-ui-authorization-build-root-and-stable-source"
  RequireQualifiedUiAuthorizationHarness -> "qualified-ui-authorization-harness"
  RequireUiAuthorizationProductsContainedBelowBuild -> "ui-authorization-products-contained-below-build"
  RequireRetiredUiAuthorizationAuthoritiesAbsent -> "retired-ui-authorization-authorities-absent"
  RequireExactPhaseThirtySevenReceipt -> "exact-phase-thirty-seven-receipt"
  RequireUiEffectRuntimeAndProviderOwnersExplicit -> "ui-effect-runtime-and-provider-owners-explicit"
  RequireQualifiedPhaseThirtyEightGatePass -> "qualified-phase-thirty-eight-gate-pass"

phaseThirtyNineRequirementSlug :: PhaseThirtyNineRequirement -> Text
phaseThirtyNineRequirementSlug requirement = case requirement of
  RequirePureExactUiEffectBinding -> "pure-exact-ui-effect-binding"
  RequireAcquiredUiEffectBindingSupervisor -> "acquired-ui-effect-binding-supervisor"
  RequireDirectOfflineSerialUiEffectBindingMatrix -> "direct-offline-serial-ui-effect-binding-matrix"
  RequireIndependentUiEffectBindingOracle -> "independent-ui-effect-binding-oracle"
  RequireUiEffectBindingPositiveControls -> "ui-effect-binding-positive-controls"
  RequireExactUiEffectBindingPairedNegatives -> "exact-ui-effect-binding-paired-negatives"
  RequireAppliedUiEffectBindingProductionMutants -> "applied-ui-effect-binding-production-mutants"
  RequireExactUiEffectBindingSourceDiscovery -> "exact-ui-effect-binding-source-discovery"
  RequirePostAcquisitionUiEffectBindingChallenge -> "post-acquisition-ui-effect-binding-challenge"
  RequireUiEffectBindingProcessObservation -> "ui-effect-binding-process-observation"
  RequireNoPbNetworkProviderBrowserHostHardwareOrParallelism -> "no-pb-network-provider-browser-host-hardware-or-parallelism"
  RequireFreshUiEffectBindingBuildRootAndStableSource -> "fresh-ui-effect-binding-build-root-and-stable-source"
  RequireQualifiedUiEffectBindingHarness -> "qualified-ui-effect-binding-harness"
  RequireUiEffectBindingProductsContainedBelowBuild -> "ui-effect-binding-products-contained-below-build"
  RequireRetiredUiEffectBindingAuthoritiesAbsent -> "retired-ui-effect-binding-authorities-absent"
  RequireExactPhaseThirtyEightReceipt -> "exact-phase-thirty-eight-receipt"
  RequireUiPlanRuntimeAndProviderOwnersExplicit -> "ui-plan-runtime-and-provider-owners-explicit"
  RequireQualifiedPhaseThirtyNineGatePass -> "qualified-phase-thirty-nine-gate-pass"

phaseFortyRequirementSlug :: PhaseFortyRequirement -> Text
phaseFortyRequirementSlug requirement = case requirement of
  RequirePureDeterministicUiPlanCompiler -> "pure-deterministic-ui-plan-compiler"
  RequireAcquiredUiPlanCompilerSupervisor -> "acquired-ui-plan-compiler-supervisor"
  RequireDirectOfflineSerialUiPlanCompilerMatrix -> "direct-offline-serial-ui-plan-compiler-matrix"
  RequireIndependentUiPlanCompilerOracle -> "independent-ui-plan-compiler-oracle"
  RequireUiPlanCompilerPositiveControls -> "ui-plan-compiler-positive-controls"
  RequireExactUiPlanCompilerPairedNegatives -> "exact-ui-plan-compiler-paired-negatives"
  RequireAppliedUiPlanCompilerProductionMutants -> "applied-ui-plan-compiler-production-mutants"
  RequireExactUiPlanCompilerSourceDiscovery -> "exact-ui-plan-compiler-source-discovery"
  RequirePostAcquisitionUiPlanCompilerChallenge -> "post-acquisition-ui-plan-compiler-challenge"
  RequireUiPlanCompilerProcessObservation -> "ui-plan-compiler-process-observation"
  RequireNoPbNetworkInterpreterProviderHostHardwareOrParallelism -> "no-pb-network-interpreter-provider-host-hardware-or-parallelism"
  RequireFreshUiPlanCompilerBuildRootAndStableSource -> "fresh-ui-plan-compiler-build-root-and-stable-source"
  RequireQualifiedUiPlanCompilerHarness -> "qualified-ui-plan-compiler-harness"
  RequireUiPlanCompilerProductsContainedBelowBuild -> "ui-plan-compiler-products-contained-below-build"
  RequireRetiredUiPlanCompilerAuthoritiesAbsent -> "retired-ui-plan-compiler-authorities-absent"
  RequireExactPhaseThirtyNineReceipt -> "exact-phase-thirty-nine-receipt"
  RequireUiInterpreterOfflineRuntimeAndPublicationOwnersExplicit -> "ui-interpreter-offline-runtime-and-publication-owners-explicit"
  RequireQualifiedPhaseFortyGatePass -> "qualified-phase-forty-gate-pass"

phaseFortyOneRequirementSlug :: PhaseFortyOneRequirement -> Text
phaseFortyOneRequirementSlug requirement = case requirement of
  RequirePureBoundedOfflineContinuityLanguage -> "pure-bounded-offline-continuity-language"
  RequireAcquiredOfflineLanguagePlanSupervisor -> "acquired-offline-language-plan-supervisor"
  RequireDirectOfflineSerialOfflineLanguagePlanMatrix -> "direct-offline-serial-offline-language-plan-matrix"
  RequireIndependentOfflineLanguagePlanOracle -> "independent-offline-language-plan-oracle"
  RequireOfflineLanguagePlanPositiveControls -> "offline-language-plan-positive-controls"
  RequireExactOfflineLanguagePlanPairedNegatives -> "exact-offline-language-plan-paired-negatives"
  RequireAppliedOfflineLanguagePlanProductionMutants -> "applied-offline-language-plan-production-mutants"
  RequireExactOfflineLanguagePlanSourceDiscovery -> "exact-offline-language-plan-source-discovery"
  RequirePostAcquisitionOfflineLanguagePlanChallenge -> "post-acquisition-offline-language-plan-challenge"
  RequireOfflineLanguagePlanProcessObservation -> "offline-language-plan-process-observation"
  RequireNoPbNetworkBrowserStorageReplayHostHardwareOrParallelism -> "no-pb-network-browser-storage-replay-host-hardware-or-parallelism"
  RequireFreshOfflineLanguagePlanBuildRootAndStableSource -> "fresh-offline-language-plan-build-root-and-stable-source"
  RequireQualifiedOfflineLanguagePlanHarness -> "qualified-offline-language-plan-harness"
  RequireOfflineLanguagePlanProductsContainedBelowBuild -> "offline-language-plan-products-contained-below-build"
  RequireRetiredOfflineLanguagePlanAuthoritiesAbsent -> "retired-offline-language-plan-authorities-absent"
  RequireExactPhaseFortyReceipt -> "exact-phase-forty-receipt"
  RequireBrowserStorageServerReplayAndPublicationOwnersExplicit -> "browser-storage-server-replay-and-publication-owners-explicit"
  RequireQualifiedPhaseFortyOneGatePass -> "qualified-phase-forty-one-gate-pass"

phaseFortyTwoRequirementSlug :: PhaseFortyTwoRequirement -> Text
phaseFortyTwoRequirementSlug requirement = case requirement of
  RequirePureGenericUiBrowserInterpreterSemantics -> "pure-generic-ui-browser-interpreter-semantics"
  RequireAcquiredUiBrowserInterpreterSupervisor -> "acquired-ui-browser-interpreter-supervisor"
  RequireDirectOfflineSerialUiBrowserInterpreterMatrix -> "direct-offline-serial-ui-browser-interpreter-matrix"
  RequireIndependentUiBrowserInterpreterOracle -> "independent-ui-browser-interpreter-oracle"
  RequireUiBrowserInterpreterPositiveControls -> "ui-browser-interpreter-positive-controls"
  RequireExactUiBrowserInterpreterPairedNegatives -> "exact-ui-browser-interpreter-paired-negatives"
  RequireAppliedUiBrowserInterpreterProductionMutants -> "applied-ui-browser-interpreter-production-mutants"
  RequireExactUiBrowserInterpreterSourceDiscovery -> "exact-ui-browser-interpreter-source-discovery"
  RequirePostAcquisitionUiBrowserInterpreterChallenge -> "post-acquisition-ui-browser-interpreter-challenge"
  RequireUiBrowserInterpreterProcessObservation -> "ui-browser-interpreter-process-observation"
  RequireNoPbBrowserNodePythonNetworkHostHardwareOrParallelism -> "no-pb-browser-node-python-network-host-hardware-or-parallelism"
  RequireFreshUiBrowserInterpreterBuildRootAndStableSource -> "fresh-ui-browser-interpreter-build-root-and-stable-source"
  RequireQualifiedUiBrowserInterpreterHarness -> "qualified-ui-browser-interpreter-harness"
  RequireUiBrowserInterpreterProductsContainedBelowBuild -> "ui-browser-interpreter-products-contained-below-build"
  RequireRetiredUiBrowserInterpreterAuthoritiesAbsent -> "retired-ui-browser-interpreter-authorities-absent"
  RequireExactPhaseFortyOneReceipt -> "exact-phase-forty-one-receipt"
  RequireLiveBrowserServerProviderReleaseAndHaOwnersExplicit -> "live-browser-server-provider-release-and-ha-owners-explicit"
  RequireQualifiedPhaseFortyTwoGatePass -> "qualified-phase-forty-two-gate-pass"

phaseFortyThreeRequirementSlug :: PhaseFortyThreeRequirement -> Text
phaseFortyThreeRequirementSlug requirement = case requirement of
  RequireAuthenticatedScopedUiServerBoundary -> "authenticated-scoped-ui-server-boundary"
  RequireAcquiredUiServerBoundarySupervisor -> "acquired-ui-server-boundary-supervisor"
  RequireDirectOfflineSerialUiServerBoundaryMatrix -> "direct-offline-serial-ui-server-boundary-matrix"
  RequireIndependentUiServerBoundaryOracle -> "independent-ui-server-boundary-oracle"
  RequireUiServerBoundaryPositiveControls -> "ui-server-boundary-positive-controls"
  RequireExactUiServerBoundaryPairedNegatives -> "exact-ui-server-boundary-paired-negatives"
  RequireAppliedUiServerBoundaryProductionMutants -> "applied-ui-server-boundary-production-mutants"
  RequireExactUiServerBoundarySourceDiscovery -> "exact-ui-server-boundary-source-discovery"
  RequirePostAcquisitionUiServerBoundaryChallenge -> "post-acquisition-ui-server-boundary-challenge"
  RequireUiServerBoundaryProcessObservation -> "ui-server-boundary-process-observation"
  RequireNoPbNodeNetworkLiveIdentityProviderHostHardwareOrParallelism -> "no-pb-node-network-live-identity-provider-host-hardware-or-parallelism"
  RequireFreshUiServerBoundaryBuildRootAndStableSource -> "fresh-ui-server-boundary-build-root-and-stable-source"
  RequireQualifiedUiServerBoundaryHarness -> "qualified-ui-server-boundary-harness"
  RequireUiServerBoundaryProductsContainedBelowBuild -> "ui-server-boundary-products-contained-below-build"
  RequireRetiredUiServerBoundaryAuthoritiesAbsent -> "retired-ui-server-boundary-authorities-absent"
  RequireExactPhaseFortyTwoReceipt -> "exact-phase-forty-two-receipt"
  RequireLiveIdentityProviderBrowserDeploymentAndHaOwnersExplicit -> "live-identity-provider-browser-deployment-and-ha-owners-explicit"
  RequireQualifiedPhaseFortyThreeGatePass -> "qualified-phase-forty-three-gate-pass"

phaseFortyFourRequirementSlug :: PhaseFortyFourRequirement -> Text
phaseFortyFourRequirementSlug requirement = case requirement of
  RequireHardwareFreeHaskellUiComposition -> "hardware-free-haskell-ui-composition"
  RequireAcquiredUiLocalCompositionSupervisor -> "acquired-ui-local-composition-supervisor"
  RequireDirectOfflineSerialUiLocalCompositionMatrix -> "direct-offline-serial-ui-local-composition-matrix"
  RequireIndependentUiLocalCompositionOracle -> "independent-ui-local-composition-oracle"
  RequireUiLocalCompositionPositiveControls -> "ui-local-composition-positive-controls"
  RequireExactUiLocalCompositionPairedNegatives -> "exact-ui-local-composition-paired-negatives"
  RequireAppliedUiLocalCompositionProductionMutants -> "applied-ui-local-composition-production-mutants"
  RequireExactUiLocalCompositionSourceDiscovery -> "exact-ui-local-composition-source-discovery"
  RequirePostAcquisitionUiLocalCompositionChallenge -> "post-acquisition-ui-local-composition-challenge"
  RequireUiLocalCompositionProcessObservation -> "ui-local-composition-process-observation"
  RequireNoPbNodeDhallNetworkLiveProviderHostHardwareOrParallelism -> "no-pb-node-dhall-network-live-provider-host-hardware-or-parallelism"
  RequireFreshUiLocalCompositionBuildRootAndStableSource -> "fresh-ui-local-composition-build-root-and-stable-source"
  RequireQualifiedUiLocalCompositionHarness -> "qualified-ui-local-composition-harness"
  RequireUiLocalCompositionProductsContainedBelowBuild -> "ui-local-composition-products-contained-below-build"
  RequireRetiredUiLocalCompositionAuthoritiesAbsent -> "retired-ui-local-composition-authorities-absent"
  RequireExactPhaseFortyThreeReceipt -> "exact-phase-forty-three-receipt"
  RequireLiveWorkflowProviderBrowserDeploymentReleaseAndHaOwnersExplicit -> "live-workflow-provider-browser-deployment-release-and-ha-owners-explicit"
  RequireQualifiedPhaseFortyFourGatePass -> "qualified-phase-forty-four-gate-pass"

phaseFortyFiveRequirementSlug :: PhaseFortyFiveRequirement -> Text
phaseFortyFiveRequirementSlug requirement = case requirement of
  RequireHaskellEncryptedOfflineStateAndRuntimeProjection -> "haskell-encrypted-offline-state-and-runtime-projection"
  RequireAcquiredEncryptedBrowserRuntimeSupervisor -> "acquired-encrypted-browser-runtime-supervisor"
  RequireDirectOfflineSerialEncryptedBrowserRuntimeMatrix -> "direct-offline-serial-encrypted-browser-runtime-matrix"
  RequireIndependentEncryptedBrowserRuntimeOracle -> "independent-encrypted-browser-runtime-oracle"
  RequireEncryptedBrowserRuntimePositiveControls -> "encrypted-browser-runtime-positive-controls"
  RequireExactEncryptedBrowserRuntimePairedNegatives -> "exact-encrypted-browser-runtime-paired-negatives"
  RequireAppliedEncryptedBrowserRuntimeProductionMutants -> "applied-encrypted-browser-runtime-production-mutants"
  RequireExactEncryptedBrowserRuntimeSourceDiscovery -> "exact-encrypted-browser-runtime-source-discovery"
  RequirePostAcquisitionEncryptedBrowserRuntimeChallenge -> "post-acquisition-encrypted-browser-runtime-challenge"
  RequireEncryptedBrowserRuntimeProcessObservation -> "encrypted-browser-runtime-process-observation"
  RequireNoPbBrowserNodePurescriptJavascriptDhallNetworkLiveHostHardwareOrParallelism -> "no-pb-browser-node-purescript-javascript-dhall-network-live-host-hardware-or-parallelism"
  RequireFreshEncryptedBrowserRuntimeBuildRootAndStableSource -> "fresh-encrypted-browser-runtime-build-root-and-stable-source"
  RequireQualifiedEncryptedBrowserRuntimeHarness -> "qualified-encrypted-browser-runtime-harness"
  RequireEncryptedBrowserRuntimeProductsContainedBelowBuild -> "encrypted-browser-runtime-products-contained-below-build"
  RequireRetiredEncryptedBrowserRuntimeAuthoritiesAbsent -> "retired-encrypted-browser-runtime-authorities-absent"
  RequireExactPhaseFortyFourReceipt -> "exact-phase-forty-four-receipt"
  RequireLiveBrowserStorageCryptoLockServiceWorkerReplayReleaseHaAndHardwareOwnersExplicit -> "live-browser-storage-crypto-lock-service-worker-replay-release-ha-and-hardware-owners-explicit"
  RequireQualifiedPhaseFortyFiveGatePass -> "qualified-phase-forty-five-gate-pass"

phaseFortySixRequirementSlug :: PhaseFortySixRequirement -> Text
phaseFortySixRequirementSlug requirement = case requirement of
  RequireHaskellGeneratedBrowserContractsAndBundle -> "haskell-generated-browser-contracts-and-bundle"
  RequireAcquiredUiContractGenerationSupervisor -> "acquired-ui-contract-generation-supervisor"
  RequireDirectOfflineSerialUiContractGenerationMatrix -> "direct-offline-serial-ui-contract-generation-matrix"
  RequireIndependentUiContractGenerationOracle -> "independent-ui-contract-generation-oracle"
  RequireUiContractGenerationPositiveControls -> "ui-contract-generation-positive-controls"
  RequireExactUiContractGenerationPairedNegatives -> "exact-ui-contract-generation-paired-negatives"
  RequireAppliedUiContractGenerationProductionMutants -> "applied-ui-contract-generation-production-mutants"
  RequireExactUiContractGenerationSourceDiscovery -> "exact-ui-contract-generation-source-discovery"
  RequirePostAcquisitionUiContractGenerationChallenge -> "post-acquisition-ui-contract-generation-challenge"
  RequireUiContractGenerationProcessObservation -> "ui-contract-generation-process-observation"
  RequireNoPbBrowserNodePurescriptJavascriptNetworkLiveHostHardwareOrParallelism -> "no-pb-browser-node-purescript-javascript-network-live-host-hardware-or-parallelism"
  RequireFreshUiContractGenerationBuildRootAndStableSource -> "fresh-ui-contract-generation-build-root-and-stable-source"
  RequireQualifiedUiContractGenerationHarness -> "qualified-ui-contract-generation-harness"
  RequireUiContractGenerationProductsContainedBelowBuild -> "ui-contract-generation-products-contained-below-build"
  RequireRetiredUiContractGenerationAuthoritiesAbsent -> "retired-ui-contract-generation-authorities-absent"
  RequireExactPhaseFortyFiveReceipt -> "exact-phase-forty-five-receipt"
  RequireBrowserCompileExecutionProtocolPublicationDeploymentHaAndHardwareOwnersExplicit -> "browser-compile-execution-protocol-publication-deployment-ha-and-hardware-owners-explicit"
  RequireQualifiedPhaseFortySixGatePass -> "qualified-phase-forty-six-gate-pass"

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
