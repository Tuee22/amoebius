{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Dispatch.Internal
  ( dispatchDiagnostic
  , checkPhaseZeroSnapshot
  , discoverRepositoryRoot
  , runValidateCommand
  , validatePhase
  ) where

import Amoebius.Validation.BootstrapQualification.Internal
  ( acquireQualifiedBootstrapProtocol
  , bootstrapQualificationCheck
  )
import Amoebius.Validation.BootstrapTrust.Internal
  ( acquireGenesisTrust
  )
import Amoebius.Validation.ArtifactCalculusRun.Internal
  ( AcquiredArtifactCalculusRun
  , acquireArtifactCalculusRefreshRun
  , acquireArtifactCalculusRun
  , acquiredArtifactCalculusRunCheck
  )
import Amoebius.Validation.BudgetCalculusRun.Internal
  ( AcquiredBudgetCalculusRun
  , acquireBudgetCalculusRefreshRun
  , acquireBudgetCalculusRun
  , acquiredBudgetCalculusRunCheck
  )
import Amoebius.Validation.LiftCalculusRun.Internal
  ( AcquiredLiftCalculusRun
  , acquireLiftCalculusRefreshRun
  , acquireLiftCalculusRun
  , acquiredLiftCalculusRunCheck
  )
import Amoebius.Validation.WorkflowCalculusRun.Internal
  ( AcquiredWorkflowCalculusRun
  , acquireWorkflowCalculusRefreshRun
  , acquireWorkflowCalculusRun
  , acquiredWorkflowCalculusRunCheck
  )
import Amoebius.Validation.EvidenceCalculusRun.Internal
  ( AcquiredEvidenceCalculusRun
  , acquireEvidenceCalculusRefreshRun
  , acquireEvidenceCalculusRun
  , acquiredEvidenceCalculusRunCheck
  )
import Amoebius.Validation.ScopeIndexRun.Internal
  ( AcquiredScopeIndexRun
  , acquireScopeIndexRefreshRun
  , acquireScopeIndexRun
  , acquiredScopeIndexRunCheck
  )
import Amoebius.Validation.ResourceIndexRun.Internal
  ( AcquiredResourceIndexRun
  , acquireResourceIndexRefreshRun
  , acquireResourceIndexRun
  , acquiredResourceIndexRunCheck
  )
import Amoebius.Validation.CalculusCompositionRun.Internal
  ( AcquiredCalculusCompositionRun
  , acquireCalculusCompositionRefreshRun
  , acquireCalculusCompositionRun
  , acquiredCalculusCompositionRunCheck
  )
import Amoebius.Validation.FormalModelKernelRun.Internal
  ( AcquiredFormalModelKernelRun
  , acquireFormalModelKernelRefreshRun
  , acquireFormalModelKernelRun
  , acquiredFormalModelKernelRunCheck
  )
import Amoebius.Validation.ExplicitStateCheckerRun.Internal
  ( AcquiredExplicitStateCheckerRun
  , acquireExplicitStateCheckerRefreshRun
  , acquireExplicitStateCheckerRun
  , acquiredExplicitStateCheckerRunCheck
  )
import Amoebius.Validation.SymbolicCheckerRun.Internal
  ( AcquiredSymbolicCheckerRun
  , acquireSymbolicCheckerRefreshRun
  , acquireSymbolicCheckerRun
  , acquiredSymbolicCheckerRunCheck
  )
import Amoebius.Validation.RefinementCheckerRun.Internal
  ( AcquiredRefinementCheckerRun
  , acquireRefinementCheckerRefreshRun
  , acquireRefinementCheckerRun
  , acquiredRefinementCheckerRunCheck
  )
import Amoebius.Validation.CompileFailHarnessRun.Internal
  ( AcquiredCompileFailHarnessRun
  , acquireCompileFailHarnessRefreshRun
  , acquireCompileFailHarnessRun
  , acquiredCompileFailHarnessRunCheck
  )
import Amoebius.Validation.DeterministicSimulationRun.Internal
  ( AcquiredDeterministicSimulationRun
  , acquireDeterministicSimulationRefreshRun
  , acquireDeterministicSimulationRun
  , acquiredDeterministicSimulationRunCheck
  )
import Amoebius.Validation.GatewayMigrationModelRun.Internal
  ( AcquiredGatewayMigrationModelRun
  , acquireGatewayMigrationModelRefreshRun
  , acquireGatewayMigrationModelRun
  , acquiredGatewayMigrationModelRunCheck
  )
import Amoebius.Validation.DslFormalModelRun.Internal
  ( AcquiredDslFormalModelRun
  , acquireDslFormalModelRefreshRun
  , acquireDslFormalModelRun
  , acquiredDslFormalModelRunCheck
  )
import Amoebius.Validation.ReconcileCoreRun.Internal
  ( AcquiredReconcileCoreRun
  , acquireReconcileCoreRefreshRun
  , acquireReconcileCoreRun
  , acquiredReconcileCoreRunCheck
  )
import Amoebius.Validation.ExtensionDeclarationRun.Internal
  ( AcquiredExtensionDeclarationRun
  , acquireExtensionDeclarationRefreshRun
  , acquireExtensionDeclarationRun
  , acquiredExtensionDeclarationRunCheck
  )
import Amoebius.Validation.ExtensionLawsRun.Internal
  ( AcquiredExtensionLawsRun
  , acquireExtensionLawsRefreshRun
  , acquireExtensionLawsRun
  , acquiredExtensionLawsRunCheck
  )
import Amoebius.Validation.ExtensionCompositionRun.Internal
  ( AcquiredExtensionCompositionRun
  , acquireExtensionCompositionRefreshRun
  , acquireExtensionCompositionRun
  , acquiredExtensionCompositionRunCheck
  )
import Amoebius.Validation.ExtensionSecurityRun.Internal
  ( AcquiredExtensionSecurityRun
  , acquireExtensionSecurityRefreshRun
  , acquireExtensionSecurityRun
  , acquiredExtensionSecurityRunCheck
  )
import Amoebius.Validation.ConformanceGateRun.Internal
  ( AcquiredConformanceGateRun
  , acquireConformanceGateRefreshRun
  , acquireConformanceGateRun
  , acquiredConformanceGateRunCheck
  )
import Amoebius.Validation.DhallSchemaRun.Internal
  ( AcquiredDhallSchemaRun
  , acquireDhallSchemaRefreshRun
  , acquireDhallSchemaRun
  , acquiredDhallSchemaRunCheck
  )
import Amoebius.Validation.GadtDecodeRun.Internal
  ( AcquiredGadtDecodeRun
  , acquireGadtDecodeRefreshRun
  , acquireGadtDecodeRun
  , acquiredGadtDecodeRunCheck
  )
import Amoebius.Validation.IllegalStateCoveringRun.Internal
  ( AcquiredIllegalStateCoveringRun
  , acquireIllegalStateCoveringRefreshRun
  , acquireIllegalStateCoveringRun
  , acquiredIllegalStateCoveringRunCheck
  )
import Amoebius.Validation.StorageGeometryRun.Internal
  ( AcquiredStorageGeometryRun
  , acquireStorageGeometryRefreshRun
  , acquireStorageGeometryRun
  , acquiredStorageGeometryRunCheck
  )
import Amoebius.Validation.ExecutionAcceleratorRun.Internal
  ( AcquiredExecutionAcceleratorRun
  , acquireExecutionAcceleratorRefreshRun
  , acquireExecutionAcceleratorRun
  , acquiredExecutionAcceleratorRunCheck
  )
import Amoebius.Validation.CapabilityBindRun.Internal
  ( AcquiredCapabilityBindRun
  , acquireCapabilityBindRefreshRun
  , acquireCapabilityBindRun
  , acquiredCapabilityBindRunCheck
  )
import Amoebius.Validation.ProvisionSealRun.Internal
  ( AcquiredProvisionSealRun
  , acquireProvisionSealRefreshRun
  , acquireProvisionSealRun
  , acquiredProvisionSealRunCheck
  )
import Amoebius.Validation.InferenceAcceleratorRun.Internal
  ( AcquiredInferenceAcceleratorRun
  , acquireInferenceAcceleratorRefreshRun
  , acquireInferenceAcceleratorRun
  , acquiredInferenceAcceleratorRunCheck
  )
import Amoebius.Validation.RenderManifestRun.Internal
  ( AcquiredRenderManifestRun
  , acquireRenderManifestRefreshRun
  , acquireRenderManifestRun
  , acquiredRenderManifestRunCheck
  )
import Amoebius.Validation.ChainBoundaryRun.Internal
  ( AcquiredChainBoundaryRun
  , acquireChainBoundaryRefreshRun
  , acquireChainBoundaryRun
  , acquiredChainBoundaryRunCheck
  )
import Amoebius.Validation.ImageRecipeRun.Internal
  ( AcquiredImageRecipeRun
  , acquireImageRecipeRefreshRun
  , acquireImageRecipeRun
  , acquiredImageRecipeRunCheck
  )
import Amoebius.Validation.TransactionVocabularyRun.Internal
  ( AcquiredTransactionVocabularyRun
  , acquireTransactionVocabularyRefreshRun
  , acquireTransactionVocabularyRun
  , acquiredTransactionVocabularyRunCheck
  )
import Amoebius.Validation.UiProgramSchemaRun.Internal
  ( AcquiredUiProgramSchemaRun
  , acquireUiProgramSchemaRefreshRun
  , acquireUiProgramSchemaRun
  , acquiredUiProgramSchemaRunCheck
  )
import Amoebius.Validation.UiAuthorizationRun.Internal
  ( AcquiredUiAuthorizationRun
  , acquireUiAuthorizationRefreshRun
  , acquireUiAuthorizationRun
  , acquiredUiAuthorizationRunCheck
  )
import Amoebius.Validation.UiEffectBindingRun.Internal
  ( AcquiredUiEffectBindingRun
  , acquireUiEffectBindingRefreshRun
  , acquireUiEffectBindingRun
  , acquiredUiEffectBindingRunCheck
  )
import Amoebius.Validation.UiPlanCompilerRun.Internal
  ( AcquiredUiPlanCompilerRun
  , acquireUiPlanCompilerRefreshRun
  , acquireUiPlanCompilerRun
  , acquiredUiPlanCompilerRunCheck
  )
import Amoebius.Validation.OfflineLanguagePlanRun.Internal
  ( AcquiredOfflineLanguagePlanRun
  , acquireOfflineLanguagePlanRefreshRun
  , acquireOfflineLanguagePlanRun
  , acquiredOfflineLanguagePlanRunCheck
  )
import Amoebius.Validation.UiBrowserInterpreterRun.Internal
  ( AcquiredUiBrowserInterpreterRun
  , acquireUiBrowserInterpreterRefreshRun
  , acquireUiBrowserInterpreterRun
  , acquiredUiBrowserInterpreterRunCheck
  )
import Amoebius.Validation.UiServerBoundaryRun.Internal
  ( AcquiredUiServerBoundaryRun
  , acquireUiServerBoundaryRefreshRun
  , acquireUiServerBoundaryRun
  , acquiredUiServerBoundaryRunCheck
  )
import Amoebius.Validation.UiLocalCompositionRun.Internal
  ( AcquiredUiLocalCompositionRun
  , acquireUiLocalCompositionRefreshRun
  , acquireUiLocalCompositionRun
  , acquiredUiLocalCompositionRunCheck
  )
import Amoebius.Validation.EncryptedBrowserRuntimeRun.Internal
  ( AcquiredEncryptedBrowserRuntimeRun
  , acquireEncryptedBrowserRuntimeRefreshRun
  , acquireEncryptedBrowserRuntimeRun
  , acquiredEncryptedBrowserRuntimeRunCheck
  )
import Amoebius.Validation.UiContractGenerationRun.Internal
  ( AcquiredUiContractGenerationRun
  , acquireUiContractGenerationRefreshRun
  , acquireUiContractGenerationRun
  , acquiredUiContractGenerationRunCheck
  )
import Amoebius.Validation.Documentation.Internal (checkDocuments)
import Amoebius.Validation.Evidence.Internal
  ( PublishedCandidateEvidence
  , PredecessorEvidence
  , acquireImmediatePredecessorEvidence
  , acquiredCandidateDigest
  , acquiredCandidateLegacyClosureCheck
  , acquiredCandidatePassCriterionCheck
  , captureDispatchCandidateEvidence
  , captureFinalizedArtifactCalculusCandidateEvidence
  , captureFinalizedBudgetCalculusCandidateEvidence
  , captureFinalizedLiftCalculusCandidateEvidence
  , captureFinalizedWorkflowCalculusCandidateEvidence
  , captureFinalizedEvidenceCalculusCandidateEvidence
  , captureFinalizedScopeIndexCandidateEvidence
  , captureFinalizedResourceIndexCandidateEvidence
  , captureFinalizedCalculusCompositionCandidateEvidence
  , captureFinalizedFormalModelKernelCandidateEvidence
  , captureFinalizedExplicitStateCheckerCandidateEvidence
  , captureFinalizedSymbolicCheckerCandidateEvidence
  , captureFinalizedRefinementCheckerCandidateEvidence
  , captureFinalizedCompileFailHarnessCandidateEvidence
  , captureFinalizedDeterministicSimulationCandidateEvidence
  , captureFinalizedGatewayMigrationModelCandidateEvidence
  , captureFinalizedDslFormalModelCandidateEvidence
  , captureFinalizedReconcileCoreCandidateEvidence
  , captureFinalizedExtensionDeclarationCandidateEvidence
  , captureFinalizedExtensionLawsCandidateEvidence
  , captureFinalizedExtensionCompositionCandidateEvidence
  , captureFinalizedExtensionSecurityCandidateEvidence
  , captureFinalizedConformanceGateCandidateEvidence
  , captureFinalizedDhallSchemaCandidateEvidence
  , captureFinalizedGadtDecodeCandidateEvidence
  , captureFinalizedIllegalStateCoveringCandidateEvidence
  , captureFinalizedStorageGeometryCandidateEvidence
  , captureFinalizedExecutionAcceleratorCandidateEvidence
  , captureFinalizedCapabilityBindCandidateEvidence
  , captureFinalizedProvisionSealCandidateEvidence
  , captureFinalizedInferenceAcceleratorCandidateEvidence
  , captureFinalizedRenderManifestCandidateEvidence
  , captureFinalizedChainBoundaryCandidateEvidence
  , captureFinalizedImageRecipeCandidateEvidence
  , captureFinalizedTransactionVocabularyCandidateEvidence
  , captureFinalizedUiProgramSchemaCandidateEvidence
  , captureFinalizedUiAuthorizationCandidateEvidence
  , captureFinalizedUiEffectBindingCandidateEvidence
  , captureFinalizedUiPlanCompilerCandidateEvidence
  , captureFinalizedOfflineLanguagePlanCandidateEvidence
  , captureFinalizedUiBrowserInterpreterCandidateEvidence
  , captureFinalizedUiServerBoundaryCandidateEvidence
  , captureFinalizedUiLocalCompositionCandidateEvidence
  , captureFinalizedEncryptedBrowserRuntimeCandidateEvidence
  , captureFinalizedUiContractGenerationCandidateEvidence
  , captureFinalizedDispatchCandidateEvidence
  , captureFinalizedRepositoryLayoutCandidateEvidence
  , captureFinalizedToolchainSpikeCandidateEvidence
  , installPublishedCandidateEvidenceReceipt
  , publishedCandidatePath
  , writeAcquiredCandidateEvidence
  )
import Amoebius.Validation.GatePass.Internal (verifyPublishedGatePass)
import Amoebius.Validation.Legacy.Internal (legacyCheck)
import Amoebius.Validation.PhaseContract.Internal (checkPhaseContractsForPhase)
import Amoebius.Validation.PhaseRunner.Internal
  ( PhaseRunner (ArtifactCalculusRunner, BudgetCalculusRunner, LiftCalculusRunner, WorkflowCalculusRunner, EvidenceCalculusRunner, ScopeIndexRunner, ResourceIndexRunner, CalculusCompositionRunner, FormalModelKernelRunner, ExplicitStateCheckerRunner, SymbolicCheckerRunner, RefinementCheckerRunner, CompileFailHarnessRunner, DeterministicSimulationRunner, GatewayMigrationModelRunner, DslFormalModelRunner, ReconcileCoreRunner, ExtensionDeclarationRunner, ExtensionLawsRunner, ExtensionCompositionRunner, ExtensionSecurityRunner, ConformanceGateRunner, DhallSchemaRunner, GadtDecodeRunner, IllegalStateCoveringRunner, StorageGeometryRunner, ExecutionAcceleratorRunner, CapabilityBindRunner, ProvisionSealRunner, InferenceAcceleratorRunner, RenderManifestRunner, ChainBoundaryRunner, ImageRecipeRunner, TransactionVocabularyRunner, UiProgramSchemaRunner, UiAuthorizationRunner, UiEffectBindingRunner, UiPlanCompilerRunner, OfflineLanguagePlanRunner, UiBrowserInterpreterRunner, UiServerBoundaryRunner, UiLocalCompositionRunner, EncryptedBrowserRuntimeRunner, UiContractGenerationRunner, DocumentationSuiteRunner, ToolchainSpikeRunner, RepositoryLayoutRunner)
  , selectPhaseRunner
  )
import Amoebius.Validation.PhaseZeroRun.Internal
  ( AcquiredPhaseZeroRun
  , acquiredPhaseZeroRunCheck
  , assembleAcquiredPhaseZeroRun
  , assembleAcquiredPhaseZeroRefreshRun
  , phaseZeroSnapshotDocuments
  , phaseZeroUnavailablePhaseContractCheck
  )
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , GitExecutable
  , SnapshotProblem (..)
  , SourceClosure
  , SourceSnapshot (snapshotIdentity)
  , acquiredSourceSnapshot
  , classifySnapshot
  , loadGitSnapshot
  , mkGitExecutable
  , renderSnapshotProblem
  , sourceClosureCheck
  )
import Amoebius.Validation.SourceConsumerGraph.Internal
  ( analyzeSourceConsumerGraph
  , sourceConsumerGraphCheck
  )
import Amoebius.Validation.SourceDebtBaseline.Internal
  ( analyzeAcquiredSourceDebt
  , sourceDebtClosureDiagnosticCheck
  )
import Amoebius.Validation.StatusProjection.Internal
  ( ProposedStatusProjection
  , authorizeStatusProjection
  , prepareValidationProjection
  , projectionDigest
  , projectionIsReceiptRefresh
  , projectionPostimageDigest
  , writeAuthorizedStatusProjection
  )
import Amoebius.Validation.RepositoryLayoutRun.Internal
  ( AcquiredRepositoryLayoutRun
  , acquireRepositoryLayoutRefreshRun
  , acquireRepositoryLayoutRun
  , acquiredRepositoryLayoutRunCheck
  )
import Amoebius.Validation.ToolchainSpikeRun.Internal
  ( AcquiredToolchainSpikeRun
  , acquireToolchainSpikeRefreshRun
  , acquireToolchainSpikeRun
  , acquiredToolchainSpikeRunCheck
  )
import Amoebius.Validation.Types
import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Crypto.Hash qualified as Crypto
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Char (ord)
import Data.List (nub, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory
  ( canonicalizePath
  , doesFileExist
  , doesPathExist
  , findExecutable
  , getCurrentDirectory
  )
import System.Environment (getArgs, getExecutablePath)
import System.Exit (ExitCode (ExitFailure, ExitSuccess))
import System.FilePath ((</>), isAbsolute, takeDirectory)
import Text.Read (readMaybe)

maximumDispatchPhaseBytes, maximumDispatchComponents :: Int
maximumDispatchPhaseBytes = 2
maximumDispatchComponents = 7

maximumDispatchRoleBytes, maximumDispatchDigestBytes, maximumDispatchAggregateBytes :: Int
maximumDispatchRoleBytes = 32
maximumDispatchDigestBytes = 64
maximumDispatchAggregateBytes = 640

data DispatchPrefix value
  = DispatchPrefixWithin [value]
  | DispatchPrefixExceeded Int [value]

data DispatchRawProblem
  = DispatchPhaseByteLimit Int Int
  | DispatchComponentLimit Int Int
  | DispatchRoleByteLimit Int Int Int
  | DispatchDigestByteLimit Int Int Int
  | DispatchAggregateByteLimit Int Int
  | DispatchResourceGuardUnavailable Text
  | DispatchPhaseWidth Text
  | DispatchPhaseAlphabet Text
  | DispatchPhaseRange Text
  | DispatchComponentCardinality Int Int
  | DispatchComponentDuplicate Text
  | DispatchComponentUnknown Text
  | DispatchComponentOrder [Text]
  | DispatchDigestWidth Int Text
  | DispatchDigestAlphabet Int Text
  deriving (Eq, Show)

-- | Bounded refusal-only diagnostic over caller-claimed dispatch component
-- identities.  A coherent wire remains incapable of establishing source
-- binding, predecessor gate pass, component execution, or harness
-- qualification.  No Git, filesystem, process, pb, network, hardware, or
-- container action occurs here.
dispatchDiagnostic :: Text -> [(Text, Text)] -> CheckResult
dispatchDiagnostic requestedPhase claimedComponents =
  CheckResult
    { checkName = "dispatch-diagnostic"
    , checkObservations =
        [ observation "dispatch.input-commitment.kind" commitmentKind
        , observation "dispatch.input-commitment.sha256" commitmentDigest
        , observation "dispatch.input.requested-phase" safePhase
        , observation "dispatch.input.component-count" componentCount
        , observation "dispatch.derived.selected-component-count" (Text.pack (show (length selectedComponents)))
        , observation "dispatch.diagnostic-status" "refused"
        ]
          <> selectedObservations
    , checkFindings = mandatoryFindings <> problemFindings <> selectedFindings <> phaseFindings
    }
 where
  analysis = analyzeDispatchRawInput requestedPhase claimedComponents
  commitmentKind = dispatchCommitmentKind analysis
  commitmentDigest = dispatchCommitmentDigest analysis
  safePhase = dispatchSafePhase analysis
  componentCount = dispatchSafeComponentCount analysis
  problems = dispatchProblems analysis
  selectedComponents = selectedRawPhaseZeroComponents
  selectedObservations =
    [ observation
        ("dispatch.component." <> Text.pack (show ordinal) <> ".role")
        (renderRawPhaseZeroComponent component)
    | (ordinal, component) <- zip [(1 :: Int) ..] selectedComponents
    ]
  selectedFindings =
    [ finding
        "DISPATCH-COMPONENT-EXECUTION-UNAVAILABLE"
        (Text.unpack (renderRawPhaseZeroComponent component))
        ( "caller-declared component identities cannot establish execution of the package-hidden Phase-0 composition"
            <> dispatchCommitmentDetail analysis
        )
    | component <- selectedComponents
    ]
  mandatoryFindings =
    dispatchDiagnosticOnlyFindings analysis
      <> dispatchSourceBindingFindings analysis
      <> dispatchPredecessorFindings analysis
      <> dispatchQualificationFindings analysis
  problemFindings = map (dispatchRawProblemFinding analysis) problems
  phaseFindings = dispatchPhaseRouteFindings analysis

data DispatchRawAnalysis = DispatchRawAnalysis
  { dispatchCommitmentKind :: Text
  , dispatchCommitmentDigest :: Text
  , dispatchSafePhase :: Text
  , dispatchSafeComponentCount :: Text
  , dispatchProblems :: [DispatchRawProblem]
  }

analyzeDispatchRawInput :: Text -> [(Text, Text)] -> DispatchRawAnalysis
analyzeDispatchRawInput requestedPhase components =
  case boundedDispatchText maximumDispatchPhaseBytes requestedPhase of
    DispatchPrefixExceeded observed _ ->
      dispatchResourceFailure
        requestedPhase
        components
        "<over-limit>"
        "unavailable"
        ( dispatchGuardedResourceProblem
            "phase-byte-limit"
            (dispatchPhaseByteLimitExceeded observed)
            (DispatchPhaseByteLimit maximumDispatchPhaseBytes observed)
        )
    _ -> case boundedDispatchPrefix maximumDispatchComponents components of
      DispatchPrefixExceeded observed _ ->
        dispatchResourceFailure
          requestedPhase
          components
          requestedPhase
          (Text.pack (show observed) <> "+")
          ( dispatchGuardedResourceProblem
              "component-limit"
              (dispatchComponentLimitExceeded observed)
              (DispatchComponentLimit maximumDispatchComponents observed)
          )
      DispatchPrefixWithin bounded -> analyzeDispatchBounded requestedPhase bounded

analyzeDispatchBounded :: Text -> [(Text, Text)] -> DispatchRawAnalysis
analyzeDispatchBounded requestedPhase components =
  case firstDispatchResourceProblem components of
    Just problem ->
      dispatchResourceFailure
        requestedPhase
        components
        requestedPhase
        (Text.pack (show (length components)))
        problem
    Nothing ->
      DispatchRawAnalysis
        { dispatchCommitmentKind = "complete-input"
        , dispatchCommitmentDigest = dispatchCompleteDigest requestedPhase components
        , dispatchSafePhase = requestedPhase
        , dispatchSafeComponentCount = Text.pack (show (length components))
        , dispatchProblems = dispatchGrammarProblems requestedPhase components
        }

dispatchResourceFailure
  :: Text
  -> [(Text, Text)]
  -> Text
  -> Text
  -> DispatchRawProblem
  -> DispatchRawAnalysis
dispatchResourceFailure requestedPhase components safePhase componentCount problem =
  DispatchRawAnalysis
    { dispatchCommitmentKind = "bounded-preflight-refusal"
    , dispatchCommitmentDigest = dispatchBoundedDigest requestedPhase components problem
    , dispatchSafePhase = safePhase
    , dispatchSafeComponentCount = componentCount
    , dispatchProblems = [problem]
    }

firstDispatchResourceProblem :: [(Text, Text)] -> Maybe DispatchRawProblem
firstDispatchResourceProblem = go 1 0
 where
  go ordinal aggregate remaining = case remaining of
    [] -> Nothing
    (role, digest) : rest ->
      case boundedDispatchText maximumDispatchRoleBytes role of
        DispatchPrefixExceeded observed _ ->
          Just
            ( dispatchGuardedResourceProblem
                "role-byte-limit"
                (dispatchRoleByteLimitExceeded observed)
                (DispatchRoleByteLimit ordinal maximumDispatchRoleBytes observed)
            )
        _ -> case boundedDispatchText maximumDispatchDigestBytes digest of
          DispatchPrefixExceeded observed _ ->
            Just
              ( dispatchGuardedResourceProblem
                  "digest-byte-limit"
                  (dispatchDigestByteLimitExceeded observed)
                  (DispatchDigestByteLimit ordinal maximumDispatchDigestBytes observed)
              )
          _ ->
            let next = aggregate + dispatchTextBytes role + dispatchTextBytes digest
             in if next > maximumDispatchAggregateBytes
                  then
                    Just
                      ( dispatchGuardedResourceProblem
                          "aggregate-byte-limit"
                          (dispatchAggregateByteLimitExceeded next)
                          (DispatchAggregateByteLimit maximumDispatchAggregateBytes next)
                      )
                  else go (ordinal + 1) next rest

dispatchGuardedResourceProblem :: Text -> Bool -> DispatchRawProblem -> DispatchRawProblem
dispatchGuardedResourceProblem label predicate specific
  | predicate = specific
  | otherwise = DispatchResourceGuardUnavailable label

dispatchGrammarProblems :: Text -> [(Text, Text)] -> [DispatchRawProblem]
dispatchGrammarProblems requestedPhase components =
  phaseProblems <> componentProblems
 where
  phaseProblems
    | not (dispatchPhaseWidthValid requestedPhase) = [DispatchPhaseWidth requestedPhase]
    | not (dispatchPhaseAlphabetValid requestedPhase) = [DispatchPhaseAlphabet requestedPhase]
    | not (dispatchPhaseRangeValid requestedPhase) = [DispatchPhaseRange requestedPhase]
    | otherwise = []
  roles = map fst components
  componentProblems
    | not (dispatchComponentCardinalityValid roles) = [DispatchComponentCardinality maximumDispatchComponents (length roles)]
    | Just duplicate <- firstDispatchDuplicate roles = [DispatchComponentDuplicate duplicate]
    | Just unknown <- firstDispatchUnknown roles = [DispatchComponentUnknown unknown]
    | not (dispatchComponentOrderValid roles) = [DispatchComponentOrder roles]
    | Just problem <- firstDispatchDigestProblem components = [problem]
    | otherwise = []

firstDispatchDigestProblem :: [(Text, Text)] -> Maybe DispatchRawProblem
firstDispatchDigestProblem = go 1
 where
  go ordinal remaining = case remaining of
    [] -> Nothing
    (_, digest) : rest
      | not (dispatchDigestWidthValid digest) -> Just (DispatchDigestWidth ordinal digest)
      | not (dispatchDigestAlphabetValid digest) -> Just (DispatchDigestAlphabet ordinal digest)
      | otherwise -> go (ordinal + 1) rest

dispatchDiagnosticOnlyFindings :: DispatchRawAnalysis -> [Finding]
#if defined(VALIDATION_DISPATCH_DIAGNOSTIC_ONLY_DROP_MUTANT)
dispatchDiagnosticOnlyFindings _ = []
#else
dispatchDiagnosticOnlyFindings analysis =
  [ finding
      "DISPATCH-DIAGNOSTIC-ONLY"
      "Amoebius.Validation.Dispatch.dispatchDiagnostic"
      ("caller-supplied dispatch wire cannot mint candidate evidence" <> dispatchCommitmentDetail analysis)
  ]
#endif

dispatchSourceBindingFindings :: DispatchRawAnalysis -> [Finding]
#if defined(VALIDATION_DISPATCH_SOURCE_BINDING_RESIDUE_DROP_MUTANT)
dispatchSourceBindingFindings _ = []
#else
dispatchSourceBindingFindings analysis =
  [ finding
      "DISPATCH-SOURCE-BINDING-UNAVAILABLE"
      "<caller-supplied-dispatch-input>"
      ("no exact local source snapshot is attached" <> dispatchCommitmentDetail analysis)
  ]
#endif

dispatchPredecessorFindings :: DispatchRawAnalysis -> [Finding]
#if defined(VALIDATION_DISPATCH_PREDECESSOR_RESIDUE_DROP_MUTANT)
dispatchPredecessorFindings _ = []
#else
dispatchPredecessorFindings analysis =
  [ finding
      "DISPATCH-PREDECESSOR-PASS-UNAVAILABLE"
      "phase-order"
      ("no predecessor gate pass result is attached" <> dispatchCommitmentDetail analysis)
  ]
#endif

dispatchQualificationFindings :: DispatchRawAnalysis -> [Finding]
#if defined(VALIDATION_DISPATCH_QUALIFICATION_RESIDUE_DROP_MUTANT)
dispatchQualificationFindings _ = []
#else
dispatchQualificationFindings analysis =
  [ finding
      "DISPATCH-QUALIFICATION-UNAVAILABLE"
      "Amoebius.Validation.Gate"
      ("the fixed sabotage corpus has not executed against this exact dispatcher subject" <> dispatchCommitmentDetail analysis)
  ]
#endif

dispatchPhaseRouteFindings :: DispatchRawAnalysis -> [Finding]
dispatchPhaseRouteFindings analysis = case dispatchProblems analysis of
  []
    | dispatchSafePhase analysis == "00" -> []
    | dispatchLaterPhaseBlocked ->
        [ finding
            "DISPATCH-PHASE-BLOCKED"
            ("phase-" <> Text.unpack (dispatchSafePhase analysis))
            ("every later phase requires its immediate predecessor's gate pass" <> dispatchCommitmentDetail analysis)
        ]
    | otherwise -> []
  _ -> []

dispatchLaterPhaseBlocked :: Bool
#if defined(VALIDATION_DISPATCH_LATER_PHASE_BLOCK_BYPASS_MUTANT)
dispatchLaterPhaseBlocked = False
#else
dispatchLaterPhaseBlocked = True
#endif

dispatchRawProblemFinding :: DispatchRawAnalysis -> DispatchRawProblem -> Finding
dispatchRawProblemFinding analysis problem = case problem of
  DispatchPhaseByteLimit maximumValue observed -> resource "DISPATCH-PHASE-BYTE-LIMIT" "<requested-phase>" maximumValue observed
  DispatchComponentLimit maximumValue observed -> resource "DISPATCH-COMPONENT-LIMIT" "<components>" maximumValue observed
  DispatchRoleByteLimit ordinal maximumValue observed -> resource "DISPATCH-ROLE-BYTE-LIMIT" (dispatchOrdinalSubject ordinal) maximumValue observed
  DispatchDigestByteLimit ordinal maximumValue observed -> resource "DISPATCH-DIGEST-BYTE-LIMIT" (dispatchOrdinalSubject ordinal) maximumValue observed
  DispatchAggregateByteLimit maximumValue observed -> resource "DISPATCH-AGGREGATE-BYTE-LIMIT" "<components>" maximumValue observed
  DispatchResourceGuardUnavailable label ->
    grammar
      "DISPATCH-RESOURCE-GUARD-UNAVAILABLE"
      "<dispatch-input>"
      ("the changed subject suppressed the bound-specific predicate; the outer preflight envelope still refused before traversal; guard=" <> label)
  DispatchPhaseWidth _ -> grammar "DISPATCH-PHASE-WIDTH" "<requested-phase>" "expected exactly two ASCII decimal characters"
  DispatchPhaseAlphabet _ -> grammar "DISPATCH-PHASE-ALPHABET" "<requested-phase>" "expected ASCII decimal characters only"
  DispatchPhaseRange _ -> grammar "DISPATCH-PHASE-RANGE" "<requested-phase>" ("expected a phase in the closed range " <> policyDomainLabel)
  DispatchComponentCardinality expected observed -> grammar "DISPATCH-COMPONENT-CARDINALITY" "<components>" ("expected=" <> Text.pack (show expected) <> "; observed=" <> Text.pack (show observed))
  DispatchComponentDuplicate role -> grammar "DISPATCH-COMPONENT-DUPLICATE" (Text.unpack role) "component role occurs more than once"
  DispatchComponentUnknown role -> grammar "DISPATCH-COMPONENT-UNKNOWN" (Text.unpack role) "component role is outside the closed Phase-0 raw composition"
  DispatchComponentOrder roles -> grammar "DISPATCH-COMPONENT-ORDER" "<components>" ("observed=" <> Text.pack (show roles))
  DispatchDigestWidth ordinal _ -> grammar "DISPATCH-DIGEST-WIDTH" (dispatchOrdinalSubject ordinal) "expected exactly 64 lowercase ASCII hexadecimal characters"
  DispatchDigestAlphabet ordinal _ -> grammar "DISPATCH-DIGEST-ALPHABET" (dispatchOrdinalSubject ordinal) "expected exactly 64 lowercase ASCII hexadecimal characters"
 where
  resource code subject maximumValue observed =
    finding code subject ("maximum=" <> Text.pack (show maximumValue) <> "; observed-at-least=" <> Text.pack (show observed) <> dispatchCommitmentDetail analysis)
  grammar code subject detail = finding code subject (detail <> dispatchCommitmentDetail analysis)

dispatchCommitmentDetail :: DispatchRawAnalysis -> Text
dispatchCommitmentDetail analysis =
  "; input-commitment-kind="
    <> dispatchCommitmentKind analysis
    <> "; input-sha256="
    <> dispatchCommitmentDigest analysis

dispatchCompleteDigest :: Text -> [(Text, Text)] -> Text
dispatchCompleteDigest requestedPhase components =
  dispatchSha256
    ( ByteString.concat
        ( "amoebius-dispatch-input-v1\0"
            : dispatchLengthText requestedPhase
            : concatMap (\(role, digest) -> [dispatchLengthText role, dispatchLengthText digest]) components
        )
    )

dispatchBoundedDigest :: Text -> [(Text, Text)] -> DispatchRawProblem -> Text
dispatchBoundedDigest requestedPhase components problem =
  dispatchSha256
    ( ByteString.concat
        ( "amoebius-dispatch-bounded-refusal-v1\0"
            : dispatchBoundedTextCommitment maximumDispatchPhaseBytes requestedPhase
            : dispatchLengthText componentState
            : concatMap dispatchBoundedComponentCommitment boundedComponents
              <> [dispatchLengthText (dispatchRawProblemCommitmentTag problem)]
        )
    )
 where
  componentPrefix = boundedDispatchPrefix maximumDispatchComponents components
  boundedComponents = case componentPrefix of
    DispatchPrefixWithin values -> values
    DispatchPrefixExceeded _ values -> values
  componentState = case componentPrefix of
    DispatchPrefixWithin values -> "within:" <> Text.pack (show (length values))
    DispatchPrefixExceeded observed _ -> "exceeded-at-least:" <> Text.pack (show observed)

dispatchBoundedComponentCommitment :: (Text, Text) -> [ByteString]
dispatchBoundedComponentCommitment (role, digest) =
  [ dispatchBoundedTextCommitment maximumDispatchRoleBytes role
  , dispatchBoundedTextCommitment maximumDispatchDigestBytes digest
  ]

dispatchBoundedTextCommitment :: Int -> Text -> ByteString
dispatchBoundedTextCommitment limit value =
  case boundedDispatchText limit value of
    DispatchPrefixWithin characters ->
      dispatchLengthText ("within:" <> Text.pack characters)
    DispatchPrefixExceeded observed characters ->
      dispatchLengthText
        ( "exceeded-at-least:"
            <> Text.pack (show observed)
            <> ":"
            <> Text.pack characters
        )

dispatchRawProblemCommitmentTag :: DispatchRawProblem -> Text
dispatchRawProblemCommitmentTag problem = case problem of
  DispatchPhaseByteLimit maximumValue observed -> numeric "phase-byte-limit" [maximumValue, observed]
  DispatchComponentLimit maximumValue observed -> numeric "component-limit" [maximumValue, observed]
  DispatchRoleByteLimit ordinal maximumValue observed -> numeric "role-byte-limit" [ordinal, maximumValue, observed]
  DispatchDigestByteLimit ordinal maximumValue observed -> numeric "digest-byte-limit" [ordinal, maximumValue, observed]
  DispatchAggregateByteLimit maximumValue observed -> numeric "aggregate-byte-limit" [maximumValue, observed]
  DispatchResourceGuardUnavailable label -> "resource-guard-unavailable:" <> label
  DispatchPhaseWidth _ -> "phase-width"
  DispatchPhaseAlphabet _ -> "phase-alphabet"
  DispatchPhaseRange _ -> "phase-range"
  DispatchComponentCardinality expected observed -> numeric "component-cardinality" [expected, observed]
  DispatchComponentDuplicate _ -> "component-duplicate"
  DispatchComponentUnknown _ -> "component-unknown"
  DispatchComponentOrder _ -> "component-order"
  DispatchDigestWidth ordinal _ -> numeric "digest-width" [ordinal]
  DispatchDigestAlphabet ordinal _ -> numeric "digest-alphabet" [ordinal]
 where
  numeric label values = label <> ":" <> Text.intercalate ":" (map (Text.pack . show) values)

dispatchLengthText :: Text -> ByteString
dispatchLengthText value =
  let bytes = TextEncoding.encodeUtf8 value
   in ByteString8.pack (show (ByteString.length bytes)) <> ":" <> bytes

dispatchSha256 :: ByteString -> Text
dispatchSha256 = Text.pack . show . Crypto.hashWith Crypto.SHA256

boundedDispatchPrefix :: Int -> [value] -> DispatchPrefix value
boundedDispatchPrefix limit = go 0 []
 where
  go count reversed remaining = case remaining of
    [] -> DispatchPrefixWithin (reverse reversed)
    value : rest
      | count == limit -> DispatchPrefixExceeded (limit + 1) (reverse reversed)
      | otherwise -> go (count + 1) (value : reversed) rest

boundedDispatchText :: Int -> Text -> DispatchPrefix Char
boundedDispatchText limit = boundedDispatchCharacters limit . Text.unpack

boundedDispatchCharacters :: Int -> [Char] -> DispatchPrefix Char
boundedDispatchCharacters limit = go 0 []
 where
  go count reversed characters = case characters of
    [] -> DispatchPrefixWithin (reverse reversed)
    character : rest ->
      let next = count + dispatchUtf8CharacterBytes character
       in if next > limit
            then DispatchPrefixExceeded next (reverse reversed)
            else go next (character : reversed) rest

dispatchUtf8CharacterBytes :: Char -> Int
dispatchUtf8CharacterBytes character
  | code <= 0x7f = 1
  | code <= 0x7ff = 2
  | code <= 0xffff = 3
  | otherwise = 4
 where
  code = ord character

dispatchTextBytes :: Text -> Int
dispatchTextBytes = ByteString.length . TextEncoding.encodeUtf8

dispatchPhaseByteLimitExceeded, dispatchComponentLimitExceeded :: Int -> Bool
#if defined(VALIDATION_DISPATCH_PHASE_BYTE_LIMIT_BYPASS_MUTANT)
dispatchPhaseByteLimitExceeded _ = False
#else
dispatchPhaseByteLimitExceeded observed = observed > maximumDispatchPhaseBytes
#endif
#if defined(VALIDATION_DISPATCH_COMPONENT_LIMIT_BYPASS_MUTANT)
dispatchComponentLimitExceeded _ = False
#else
dispatchComponentLimitExceeded observed = observed > maximumDispatchComponents
#endif

dispatchRoleByteLimitExceeded, dispatchDigestByteLimitExceeded, dispatchAggregateByteLimitExceeded :: Int -> Bool
#if defined(VALIDATION_DISPATCH_ROLE_BYTE_LIMIT_BYPASS_MUTANT)
dispatchRoleByteLimitExceeded _ = False
#else
dispatchRoleByteLimitExceeded observed = observed > maximumDispatchRoleBytes
#endif
#if defined(VALIDATION_DISPATCH_DIGEST_BYTE_LIMIT_BYPASS_MUTANT)
dispatchDigestByteLimitExceeded _ = False
#else
dispatchDigestByteLimitExceeded observed = observed > maximumDispatchDigestBytes
#endif
#if defined(VALIDATION_DISPATCH_AGGREGATE_BYTE_LIMIT_BYPASS_MUTANT)
dispatchAggregateByteLimitExceeded _ = False
#else
dispatchAggregateByteLimitExceeded observed = observed > maximumDispatchAggregateBytes
#endif

dispatchPhaseWidthValid, dispatchPhaseAlphabetValid, dispatchPhaseRangeValid :: Text -> Bool
#if defined(VALIDATION_DISPATCH_PHASE_WIDTH_BYPASS_MUTANT)
dispatchPhaseWidthValid _ = True
#else
dispatchPhaseWidthValid value = Text.length value == 2
#endif
#if defined(VALIDATION_DISPATCH_PHASE_ALPHABET_BYPASS_MUTANT)
dispatchPhaseAlphabetValid _ = True
#else
dispatchPhaseAlphabetValid = Text.all (\character -> character >= '0' && character <= '9')
#endif
#if defined(VALIDATION_DISPATCH_PHASE_RANGE_BYPASS_MUTANT)
dispatchPhaseRangeValid _ = True
#else
dispatchPhaseRangeValid value = value >= "00" && value <= "95"
#endif

dispatchComponentCardinalityValid :: [Text] -> Bool
#if defined(VALIDATION_DISPATCH_COMPONENT_CARDINALITY_BYPASS_MUTANT)
dispatchComponentCardinalityValid _ = True
#else
dispatchComponentCardinalityValid roles = length roles == maximumDispatchComponents
#endif

dispatchComponentOrderValid :: [Text] -> Bool
#if defined(VALIDATION_DISPATCH_COMPONENT_ORDER_BYPASS_MUTANT)
dispatchComponentOrderValid _ = True
#else
dispatchComponentOrderValid roles = roles == map renderRawPhaseZeroComponent rawPhaseZeroComponentUniverse
#endif

dispatchDigestWidthValid, dispatchDigestAlphabetValid :: Text -> Bool
#if defined(VALIDATION_DISPATCH_DIGEST_WIDTH_BYPASS_MUTANT)
dispatchDigestWidthValid _ = True
#else
dispatchDigestWidthValid value = Text.length value == 64
#endif
#if defined(VALIDATION_DISPATCH_DIGEST_ALPHABET_BYPASS_MUTANT)
dispatchDigestAlphabetValid _ = True
#else
dispatchDigestAlphabetValid = Text.all (\character -> character >= '0' && character <= '9' || character >= 'a' && character <= 'f')
#endif

firstDispatchDuplicate :: [Text] -> Maybe Text
firstDispatchDuplicate values = go [] values
 where
  go seen remaining = case remaining of
    [] -> Nothing
    value : rest
      | dispatchDuplicateRejected value seen -> Just value
      | otherwise -> go (value : seen) rest

dispatchDuplicateRejected :: Text -> [Text] -> Bool
#if defined(VALIDATION_DISPATCH_COMPONENT_DUPLICATE_BYPASS_MUTANT)
dispatchDuplicateRejected _ _ = False
#else
dispatchDuplicateRejected value seen = value `elem` seen
#endif

firstDispatchUnknown :: [Text] -> Maybe Text
firstDispatchUnknown values = case filter (dispatchUnknownRejected canonical) values of
  [] -> Nothing
  value : _ -> Just value
 where
  canonical = map renderRawPhaseZeroComponent rawPhaseZeroComponentUniverse

dispatchUnknownRejected :: [Text] -> Text -> Bool
#if defined(VALIDATION_DISPATCH_COMPONENT_UNKNOWN_BYPASS_MUTANT)
dispatchUnknownRejected _ _ = False
#else
dispatchUnknownRejected canonical value = value `notElem` canonical
#endif

dispatchOrdinalSubject :: Int -> FilePath
dispatchOrdinalSubject ordinal = "<component-" <> show ordinal <> ">"

-- | Run the public validation argv against an exact local source capture.
runValidateCommand :: [String] -> IO ExitCode
runValidateCommand arguments =
  case arguments of
    ["phase", ordinal]
      | Just phase <- parseOrdinal ordinal -> do
          capture <- acquireRepository
          case capture of
            Left detail -> emitResult (captureFailure detail)
            Right (git, root) -> validatePhase git root phase >>= emitResult
    _ ->
      emitResult
        CheckResult
          { checkName = "validation-dispatch"
          , checkObservations = [observation "validation.argv" (Text.pack (show arguments))]
          , checkFindings =
              [ finding
                  "DISPATCH-ARGV"
                  "amoebius validate"
                  ("expected exactly: validate phase NN, with a two-digit phase ordinal from " <> policyDomainLabel)
              ]
          }

-- | Git and the repository root are explicit so a test or caller cannot
-- silently substitute PATH lookup or the current working directory.
validatePhase :: FilePath -> FilePath -> Int -> IO CheckResult
validatePhase gitPath root phase
  | phase < policyDomainLower || phase > policyDomainUpper =
      pure
        CheckResult
          { checkName = "validation-phase-dispatch"
          , checkObservations = [observation "validation.requested-phase" (Text.pack (show phase))]
          , checkFindings =
              [ finding
                  "DISPATCH-PHASE-INVALID"
                  ("phase-" <> show phase)
                  ("the phase ordinal must be in the closed repository range " <> policyDomainLabel)
              ]
          }
  | otherwise =
      case mkGitExecutable gitPath of
        Left problem -> pure (snapshotFailure [problem])
        Right git -> validatePhaseLocked git root phase

validatePhaseLocked :: GitExecutable -> FilePath -> Int -> IO CheckResult
validatePhaseLocked git root phase = do
  snapshotResult <- loadGitSnapshot git root
  case snapshotResult of
    Left problems -> pure (snapshotFailure problems)
    Right acquired ->
      case selectPhaseRunner phase of
        Left problem -> finalizeGeneric acquired (CheckResult "phase-runner" [] [problem])
        Right DocumentationSuiteRunner -> validateBootstrap acquired
        Right ToolchainSpikeRunner -> validateToolchain acquired
        Right RepositoryLayoutRunner -> validateRepositoryLayout acquired
        Right ArtifactCalculusRunner -> validateArtifactCalculus acquired
        Right BudgetCalculusRunner -> validateBudgetCalculus acquired
        Right LiftCalculusRunner -> validateLiftCalculus acquired
        Right WorkflowCalculusRunner -> validateWorkflowCalculus acquired
        Right EvidenceCalculusRunner -> validateEvidenceCalculus acquired
        Right ScopeIndexRunner -> validateScopeIndex acquired
        Right ResourceIndexRunner -> validateResourceIndex acquired
        Right CalculusCompositionRunner -> validateCalculusComposition acquired
        Right FormalModelKernelRunner -> validateFormalModelKernel acquired
        Right ExplicitStateCheckerRunner -> validateExplicitStateChecker acquired
        Right SymbolicCheckerRunner -> validateSymbolicChecker acquired
        Right RefinementCheckerRunner -> validateRefinementChecker acquired
        Right CompileFailHarnessRunner -> validateCompileFailHarness acquired
        Right DeterministicSimulationRunner -> validateDeterministicSimulation acquired
        Right GatewayMigrationModelRunner -> validateGatewayMigrationModel acquired
        Right DslFormalModelRunner -> validateDslFormalModel acquired
        Right ReconcileCoreRunner -> validateReconcileCore acquired
        Right ExtensionDeclarationRunner -> validateExtensionDeclaration acquired
        Right ExtensionLawsRunner -> validateExtensionLaws acquired
        Right ExtensionCompositionRunner -> validateExtensionComposition acquired
        Right ExtensionSecurityRunner -> validateExtensionSecurity acquired
        Right ConformanceGateRunner -> validateConformanceGate acquired
        Right DhallSchemaRunner -> validateDhallSchema acquired
        Right GadtDecodeRunner -> validateGadtDecode acquired
        Right IllegalStateCoveringRunner -> validateIllegalStateCovering acquired
        Right StorageGeometryRunner -> validateStorageGeometry acquired
        Right ExecutionAcceleratorRunner -> validateExecutionAccelerator acquired
        Right CapabilityBindRunner -> validateCapabilityBind acquired
        Right ProvisionSealRunner -> validateProvisionSeal acquired
        Right InferenceAcceleratorRunner -> validateInferenceAccelerator acquired
        Right RenderManifestRunner -> validateRenderManifest acquired
        Right ChainBoundaryRunner -> validateChainBoundary acquired
        Right ImageRecipeRunner -> validateImageRecipe acquired
        Right TransactionVocabularyRunner -> validateTransactionVocabulary acquired
        Right UiProgramSchemaRunner -> validateUiProgramSchema acquired
        Right UiAuthorizationRunner -> validateUiAuthorization acquired
        Right UiEffectBindingRunner -> validateUiEffectBinding acquired
        Right UiPlanCompilerRunner -> validateUiPlanCompiler acquired
        Right OfflineLanguagePlanRunner -> validateOfflineLanguagePlan acquired
        Right UiBrowserInterpreterRunner -> validateUiBrowserInterpreter acquired
        Right UiServerBoundaryRunner -> validateUiServerBoundary acquired
        Right UiLocalCompositionRunner -> validateUiLocalComposition acquired
        Right EncryptedBrowserRuntimeRunner -> validateEncryptedBrowserRuntime acquired
        Right UiContractGenerationRunner -> validateUiContractGeneration acquired
 where
  validateBootstrap acquired = do
    trustResult <- acquireGenesisTrust root
    case trustResult of
      Left problems -> pure (statusLifecycleFailure phase problems)
      Right trust -> do
        qualificationResult <- acquireQualifiedBootstrapProtocol root trust acquired
        case qualificationResult of
          Left problems -> pure (bootstrapQualificationCheck (Left problems))
          Right qualification -> do
            let projectionResult = prepareValidationProjection phase acquired
                debtEvidence = analyzeAcquiredSourceDebt acquired
                phaseZeroRun =
                  case projectionResult of
                    Right projection
                      | projectionIsReceiptRefresh projection ->
                          assembleAcquiredPhaseZeroRefreshRun acquired trust qualification debtEvidence
                    _ -> assembleAcquiredPhaseZeroRun acquired trust qualification debtEvidence
                result = acquiredPhaseZeroRunCheck phaseZeroRun
            finalSnapshot <- loadGitSnapshot git root
            finishGateLifecycle
              git
              root
              phase
              acquired
              (Just (FinalizedPhaseZero phaseZeroRun))
              finalSnapshot
              projectionResult
              (bindFinalSourceSnapshot acquired finalSnapshot result)
  validateToolchain acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-01-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-01-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseOneRun <-
          case projectionResult of
            Right projection | projectionIsReceiptRefresh projection ->
              acquireToolchainSpikeRefreshRun root acquired trust
            _ -> acquireToolchainSpikeRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle
          git
          root
          phase
          acquired
          (Just (FinalizedPhaseOne phaseOneRun predecessor))
          finalSnapshot
          projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredToolchainSpikeRunCheck phaseOneRun))
   where
    projectionResult = prepareValidationProjection phase acquired
  validateRepositoryLayout acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-02-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-02-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwoRun <-
          case projectionResult of
            Right projection | projectionIsReceiptRefresh projection ->
              acquireRepositoryLayoutRefreshRun root acquired trust
            _ -> acquireRepositoryLayoutRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle
          git root phase acquired
          (Just (FinalizedPhaseTwo phaseTwoRun predecessor))
          finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredRepositoryLayoutRunCheck phaseTwoRun))
  validateArtifactCalculus acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-03-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-03-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThreeRun <-
          case projectionResult of
            Right projection | projectionIsReceiptRefresh projection ->
              acquireArtifactCalculusRefreshRun root acquired trust
            _ -> acquireArtifactCalculusRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle
          git root phase acquired
          (Just (FinalizedPhaseThree phaseThreeRun predecessor))
          finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredArtifactCalculusRunCheck phaseThreeRun))
  validateBudgetCalculus acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-04-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-04-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseFourRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireBudgetCalculusRefreshRun root acquired trust
          _ -> acquireBudgetCalculusRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseFour phaseFourRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredBudgetCalculusRunCheck phaseFourRun))
  validateLiftCalculus acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-05-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-05-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseFiveRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireLiftCalculusRefreshRun root acquired trust
          _ -> acquireLiftCalculusRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseFive phaseFiveRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredLiftCalculusRunCheck phaseFiveRun))
  validateWorkflowCalculus acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-06-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-06-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseSixRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireWorkflowCalculusRefreshRun root acquired trust
          _ -> acquireWorkflowCalculusRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseSix phaseSixRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredWorkflowCalculusRunCheck phaseSixRun))
  validateEvidenceCalculus acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-07-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-07-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseSevenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireEvidenceCalculusRefreshRun root acquired trust
          _ -> acquireEvidenceCalculusRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseSeven phaseSevenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredEvidenceCalculusRunCheck phaseSevenRun))
  validateScopeIndex acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-08-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-08-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseEightRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireScopeIndexRefreshRun root acquired trust
          _ -> acquireScopeIndexRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseEight phaseEightRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredScopeIndexRunCheck phaseEightRun))
  validateResourceIndex acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-09-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-09-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseNineRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireResourceIndexRefreshRun root acquired trust
          _ -> acquireResourceIndexRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseNine phaseNineRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredResourceIndexRunCheck phaseNineRun))
  validateCalculusComposition acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-10-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-10-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireCalculusCompositionRefreshRun root acquired trust
          _ -> acquireCalculusCompositionRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTen phaseTenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredCalculusCompositionRunCheck phaseTenRun))
  validateFormalModelKernel acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-11-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-11-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseElevenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireFormalModelKernelRefreshRun root acquired trust
          _ -> acquireFormalModelKernelRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseEleven phaseElevenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredFormalModelKernelRunCheck phaseElevenRun))
  validateExplicitStateChecker acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-12-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-12-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwelveRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireExplicitStateCheckerRefreshRun root acquired trust
          _ -> acquireExplicitStateCheckerRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTwelve phaseTwelveRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredExplicitStateCheckerRunCheck phaseTwelveRun))
  validateSymbolicChecker acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-13-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-13-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThirteenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireSymbolicCheckerRefreshRun root acquired trust
          _ -> acquireSymbolicCheckerRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseThirteen phaseThirteenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredSymbolicCheckerRunCheck phaseThirteenRun))
  validateRefinementChecker acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-14-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-14-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseFourteenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireRefinementCheckerRefreshRun root acquired trust
          _ -> acquireRefinementCheckerRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseFourteen phaseFourteenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredRefinementCheckerRunCheck phaseFourteenRun))
  validateCompileFailHarness acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-15-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-15-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseFifteenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireCompileFailHarnessRefreshRun root acquired trust
          _ -> acquireCompileFailHarnessRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseFifteen phaseFifteenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredCompileFailHarnessRunCheck phaseFifteenRun))
  validateDeterministicSimulation acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-16-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-16-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseSixteenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireDeterministicSimulationRefreshRun root acquired trust
          _ -> acquireDeterministicSimulationRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseSixteen phaseSixteenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredDeterministicSimulationRunCheck phaseSixteenRun))
  validateGatewayMigrationModel acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-17-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-17-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseSeventeenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireGatewayMigrationModelRefreshRun root acquired trust
          _ -> acquireGatewayMigrationModelRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseSeventeen phaseSeventeenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredGatewayMigrationModelRunCheck phaseSeventeenRun))
  validateDslFormalModel acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-18-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-18-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseEighteenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireDslFormalModelRefreshRun root acquired trust
          _ -> acquireDslFormalModelRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseEighteen phaseEighteenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredDslFormalModelRunCheck phaseEighteenRun))
  validateReconcileCore acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-19-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-19-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseNineteenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireReconcileCoreRefreshRun root acquired trust
          _ -> acquireReconcileCoreRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseNineteen phaseNineteenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredReconcileCoreRunCheck phaseNineteenRun))
  validateExtensionDeclaration acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-20-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-20-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwentyRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireExtensionDeclarationRefreshRun root acquired trust
          _ -> acquireExtensionDeclarationRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTwenty phaseTwentyRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredExtensionDeclarationRunCheck phaseTwentyRun))
  validateExtensionLaws acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-21-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-21-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwentyOneRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireExtensionLawsRefreshRun root acquired trust
          _ -> acquireExtensionLawsRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTwentyOne phaseTwentyOneRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredExtensionLawsRunCheck phaseTwentyOneRun))
  validateExtensionComposition acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-22-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-22-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwentyTwoRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireExtensionCompositionRefreshRun root acquired trust
          _ -> acquireExtensionCompositionRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTwentyTwo phaseTwentyTwoRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredExtensionCompositionRunCheck phaseTwentyTwoRun))
  validateExtensionSecurity acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-23-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-23-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwentyThreeRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireExtensionSecurityRefreshRun root acquired trust
          _ -> acquireExtensionSecurityRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTwentyThree phaseTwentyThreeRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredExtensionSecurityRunCheck phaseTwentyThreeRun))
  validateConformanceGate acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-24-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-24-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwentyFourRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireConformanceGateRefreshRun root acquired trust
          _ -> acquireConformanceGateRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTwentyFour phaseTwentyFourRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredConformanceGateRunCheck phaseTwentyFourRun))
  validateDhallSchema acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-25-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-25-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwentyFiveRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireDhallSchemaRefreshRun root acquired trust
          _ -> acquireDhallSchemaRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTwentyFive phaseTwentyFiveRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredDhallSchemaRunCheck phaseTwentyFiveRun))
  validateGadtDecode acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-26-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-26-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwentySixRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireGadtDecodeRefreshRun root acquired trust
          _ -> acquireGadtDecodeRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTwentySix phaseTwentySixRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredGadtDecodeRunCheck phaseTwentySixRun))
  validateIllegalStateCovering acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-27-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-27-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwentySevenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireIllegalStateCoveringRefreshRun root acquired trust
          _ -> acquireIllegalStateCoveringRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTwentySeven phaseTwentySevenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredIllegalStateCoveringRunCheck phaseTwentySevenRun))
  validateStorageGeometry acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-28-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-28-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwentyEightRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireStorageGeometryRefreshRun root acquired trust
          _ -> acquireStorageGeometryRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTwentyEight phaseTwentyEightRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredStorageGeometryRunCheck phaseTwentyEightRun))
  validateExecutionAccelerator acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-29-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-29-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseTwentyNineRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireExecutionAcceleratorRefreshRun root acquired trust
          _ -> acquireExecutionAcceleratorRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseTwentyNine phaseTwentyNineRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredExecutionAcceleratorRunCheck phaseTwentyNineRun))
  validateCapabilityBind acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-30-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-30-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThirtyRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireCapabilityBindRefreshRun root acquired trust
          _ -> acquireCapabilityBindRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseThirty phaseThirtyRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredCapabilityBindRunCheck phaseThirtyRun))
  validateProvisionSeal acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-31-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-31-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThirtyOneRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireProvisionSealRefreshRun root acquired trust
          _ -> acquireProvisionSealRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseThirtyOne phaseThirtyOneRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredProvisionSealRunCheck phaseThirtyOneRun))
  validateInferenceAccelerator acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-32-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-32-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThirtyTwoRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireInferenceAcceleratorRefreshRun root acquired trust
          _ -> acquireInferenceAcceleratorRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseThirtyTwo phaseThirtyTwoRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredInferenceAcceleratorRunCheck phaseThirtyTwoRun))
  validateRenderManifest acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-33-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-33-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThirtyThreeRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireRenderManifestRefreshRun root acquired trust
          _ -> acquireRenderManifestRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseThirtyThree phaseThirtyThreeRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredRenderManifestRunCheck phaseThirtyThreeRun))
  validateChainBoundary acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-34-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-34-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThirtyFourRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireChainBoundaryRefreshRun root acquired trust
          _ -> acquireChainBoundaryRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseThirtyFour phaseThirtyFourRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredChainBoundaryRunCheck phaseThirtyFourRun))
  validateImageRecipe acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-35-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-35-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThirtyFiveRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireImageRecipeRefreshRun root acquired trust
          _ -> acquireImageRecipeRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseThirtyFive phaseThirtyFiveRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredImageRecipeRunCheck phaseThirtyFiveRun))
  validateTransactionVocabulary acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-36-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-36-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThirtySixRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireTransactionVocabularyRefreshRun root acquired trust
          _ -> acquireTransactionVocabularyRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseThirtySix phaseThirtySixRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredTransactionVocabularyRunCheck phaseThirtySixRun))
  validateUiProgramSchema acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-37-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-37-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThirtySevenRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireUiProgramSchemaRefreshRun root acquired trust
          _ -> acquireUiProgramSchemaRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseThirtySeven phaseThirtySevenRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredUiProgramSchemaRunCheck phaseThirtySevenRun))
  validateUiAuthorization acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-38-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-38-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThirtyEightRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireUiAuthorizationRefreshRun root acquired trust
          _ -> acquireUiAuthorizationRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseThirtyEight phaseThirtyEightRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredUiAuthorizationRunCheck phaseThirtyEightRun))
  validateUiEffectBinding acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-39-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-39-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseThirtyNineRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireUiEffectBindingRefreshRun root acquired trust
          _ -> acquireUiEffectBindingRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseThirtyNine phaseThirtyNineRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredUiEffectBindingRunCheck phaseThirtyNineRun))
  validateUiPlanCompiler acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-40-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-40-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseFortyRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireUiPlanCompilerRefreshRun root acquired trust
          _ -> acquireUiPlanCompilerRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseForty phaseFortyRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredUiPlanCompilerRunCheck phaseFortyRun))
  validateOfflineLanguagePlan acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-41-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-41-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseFortyOneRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireOfflineLanguagePlanRefreshRun root acquired trust
          _ -> acquireOfflineLanguagePlanRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseFortyOne phaseFortyOneRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredOfflineLanguagePlanRunCheck phaseFortyOneRun))
  validateUiBrowserInterpreter acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-42-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-42-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseFortyTwoRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireUiBrowserInterpreterRefreshRun root acquired trust
          _ -> acquireUiBrowserInterpreterRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseFortyTwo phaseFortyTwoRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredUiBrowserInterpreterRunCheck phaseFortyTwoRun))
  validateUiServerBoundary acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-43-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-43-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseFortyThreeRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireUiServerBoundaryRefreshRun root acquired trust
          _ -> acquireUiServerBoundaryRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseFortyThree phaseFortyThreeRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredUiServerBoundaryRunCheck phaseFortyThreeRun))
  validateUiLocalComposition acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-44-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-44-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseFortyFourRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireUiLocalCompositionRefreshRun root acquired trust
          _ -> acquireUiLocalCompositionRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseFortyFour phaseFortyFourRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredUiLocalCompositionRunCheck phaseFortyFourRun))
  validateEncryptedBrowserRuntime acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-45-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-45-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseFortyFiveRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireEncryptedBrowserRuntimeRefreshRun root acquired trust
          _ -> acquireEncryptedBrowserRuntimeRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseFortyFive phaseFortyFiveRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredEncryptedBrowserRuntimeRunCheck phaseFortyFiveRun))
  validateUiContractGeneration acquired = do
    let opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        projectionResult = prepareValidationProjection phase acquired
    predecessorResult <- acquireImmediatePredecessorEvidence root phase opening
    trustResult <- acquireGenesisTrust root
    case (predecessorResult, trustResult) of
      (Left predecessorProblems, _) -> finalizeGeneric acquired (CheckResult "phase-46-predecessor" [] predecessorProblems)
      (_, Left trustProblems) -> finalizeGeneric acquired (CheckResult "phase-46-genesis-trust" [] trustProblems)
      (Right predecessor, Right trust) -> do
        projectionResult `seq` pure ()
        phaseFortySixRun <- case projectionResult of
          Right projection | projectionIsReceiptRefresh projection -> acquireUiContractGenerationRefreshRun root acquired trust
          _ -> acquireUiContractGenerationRun root acquired trust
        finalSnapshot <- loadGitSnapshot git root
        finishGateLifecycle git root phase acquired (Just (FinalizedPhaseFortySix phaseFortySixRun predecessor)) finalSnapshot projectionResult
          (bindFinalSourceSnapshot acquired finalSnapshot (acquiredUiContractGenerationRunCheck phaseFortySixRun))
  finalizeGeneric acquired result = do
    let projectionResult = prepareValidationProjection phase acquired
    finalSnapshot <- loadGitSnapshot git root
    finishGateLifecycle
      git
      root
      phase
      acquired
      Nothing
      finalSnapshot
      projectionResult
      (bindFinalSourceSnapshot acquired finalSnapshot result)

data FinalizedDispatchRun
  = FinalizedPhaseZero AcquiredPhaseZeroRun
  | FinalizedPhaseOne AcquiredToolchainSpikeRun PredecessorEvidence
  | FinalizedPhaseTwo AcquiredRepositoryLayoutRun PredecessorEvidence
  | FinalizedPhaseThree AcquiredArtifactCalculusRun PredecessorEvidence
  | FinalizedPhaseFour AcquiredBudgetCalculusRun PredecessorEvidence
  | FinalizedPhaseFive AcquiredLiftCalculusRun PredecessorEvidence
  | FinalizedPhaseSix AcquiredWorkflowCalculusRun PredecessorEvidence
  | FinalizedPhaseSeven AcquiredEvidenceCalculusRun PredecessorEvidence
  | FinalizedPhaseEight AcquiredScopeIndexRun PredecessorEvidence
  | FinalizedPhaseNine AcquiredResourceIndexRun PredecessorEvidence
  | FinalizedPhaseTen AcquiredCalculusCompositionRun PredecessorEvidence
  | FinalizedPhaseEleven AcquiredFormalModelKernelRun PredecessorEvidence
  | FinalizedPhaseTwelve AcquiredExplicitStateCheckerRun PredecessorEvidence
  | FinalizedPhaseThirteen AcquiredSymbolicCheckerRun PredecessorEvidence
  | FinalizedPhaseFourteen AcquiredRefinementCheckerRun PredecessorEvidence
  | FinalizedPhaseFifteen AcquiredCompileFailHarnessRun PredecessorEvidence
  | FinalizedPhaseSixteen AcquiredDeterministicSimulationRun PredecessorEvidence
  | FinalizedPhaseSeventeen AcquiredGatewayMigrationModelRun PredecessorEvidence
  | FinalizedPhaseEighteen AcquiredDslFormalModelRun PredecessorEvidence
  | FinalizedPhaseNineteen AcquiredReconcileCoreRun PredecessorEvidence
  | FinalizedPhaseTwenty AcquiredExtensionDeclarationRun PredecessorEvidence
  | FinalizedPhaseTwentyOne AcquiredExtensionLawsRun PredecessorEvidence
  | FinalizedPhaseTwentyTwo AcquiredExtensionCompositionRun PredecessorEvidence
  | FinalizedPhaseTwentyThree AcquiredExtensionSecurityRun PredecessorEvidence
  | FinalizedPhaseTwentyFour AcquiredConformanceGateRun PredecessorEvidence
  | FinalizedPhaseTwentyFive AcquiredDhallSchemaRun PredecessorEvidence
  | FinalizedPhaseTwentySix AcquiredGadtDecodeRun PredecessorEvidence
  | FinalizedPhaseTwentySeven AcquiredIllegalStateCoveringRun PredecessorEvidence
  | FinalizedPhaseTwentyEight AcquiredStorageGeometryRun PredecessorEvidence
  | FinalizedPhaseTwentyNine AcquiredExecutionAcceleratorRun PredecessorEvidence
  | FinalizedPhaseThirty AcquiredCapabilityBindRun PredecessorEvidence
  | FinalizedPhaseThirtyOne AcquiredProvisionSealRun PredecessorEvidence
  | FinalizedPhaseThirtyTwo AcquiredInferenceAcceleratorRun PredecessorEvidence
  | FinalizedPhaseThirtyThree AcquiredRenderManifestRun PredecessorEvidence
  | FinalizedPhaseThirtyFour AcquiredChainBoundaryRun PredecessorEvidence
  | FinalizedPhaseThirtyFive AcquiredImageRecipeRun PredecessorEvidence
  | FinalizedPhaseThirtySix AcquiredTransactionVocabularyRun PredecessorEvidence
  | FinalizedPhaseThirtySeven AcquiredUiProgramSchemaRun PredecessorEvidence
  | FinalizedPhaseThirtyEight AcquiredUiAuthorizationRun PredecessorEvidence
  | FinalizedPhaseThirtyNine AcquiredUiEffectBindingRun PredecessorEvidence
  | FinalizedPhaseForty AcquiredUiPlanCompilerRun PredecessorEvidence
  | FinalizedPhaseFortyOne AcquiredOfflineLanguagePlanRun PredecessorEvidence
  | FinalizedPhaseFortyTwo AcquiredUiBrowserInterpreterRun PredecessorEvidence
  | FinalizedPhaseFortyThree AcquiredUiServerBoundaryRun PredecessorEvidence
  | FinalizedPhaseFortyFour AcquiredUiLocalCompositionRun PredecessorEvidence
  | FinalizedPhaseFortyFive AcquiredEncryptedBrowserRuntimeRun PredecessorEvidence
  | FinalizedPhaseFortySix AcquiredUiContractGenerationRun PredecessorEvidence

statusLifecycleFailure :: Int -> [Finding] -> CheckResult
statusLifecycleFailure phase problems =
  CheckResult
    { checkName = "validation-phase-status-lifecycle"
    , checkObservations =
        [ observation
            "validation.requested-phase"
            (formatOrdinal phase)
        ]
    , checkFindings = problems
    }

finishGateLifecycle
  :: GitExecutable
  -> FilePath
  -> Int
  -> AcquiredSourceSnapshot
  -> Maybe FinalizedDispatchRun
  -> Either [SnapshotProblem] AcquiredSourceSnapshot
  -> Either [Finding] ProposedStatusProjection
  -> CheckResult
  -> IO CheckResult
finishGateLifecycle git root phase opening finalizedRun closing projectionResult gateResult = do
  executablePath <- getExecutablePath
  processArgv <- map Text.pack <$> getArgs
  executableDigestResult <- try (ByteString.readFile executablePath) :: IO (Either IOException ByteString)
  let executableDigest = either (const Nothing) (Just . dispatchSha256) executableDigestResult
      openingDigest = snapshotIdentity (acquiredSourceSnapshot opening)
      projectionFindings = either id (const []) projectionResult
      subjectResult =
        gateResult
          { checkFindings = checkFindings gateResult <> projectionFindings
          }
      candidate = case finalizedRun of
        Just (FinalizedPhaseZero acquiredRun)
          | phase == policyDomainLower ->
            captureFinalizedDispatchCandidateEvidence
              acquiredRun
              closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath
              executableDigest
              processArgv
        Just (FinalizedPhaseOne acquiredRun predecessor)
          | phase == 1 ->
            captureFinalizedToolchainSpikeCandidateEvidence
              acquiredRun
              predecessor
              closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath
              executableDigest
              processArgv
        Just (FinalizedPhaseTwo acquiredRun predecessor)
          | phase == 2 ->
            captureFinalizedRepositoryLayoutCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThree acquiredRun predecessor)
          | phase == 3 ->
            captureFinalizedArtifactCalculusCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseFour acquiredRun predecessor)
          | phase == 4 ->
            captureFinalizedBudgetCalculusCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseFive acquiredRun predecessor)
          | phase == 5 ->
            captureFinalizedLiftCalculusCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseSix acquiredRun predecessor)
          | phase == 6 ->
            captureFinalizedWorkflowCalculusCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseSeven acquiredRun predecessor)
          | phase == 7 ->
            captureFinalizedEvidenceCalculusCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseEight acquiredRun predecessor)
          | phase == 8 ->
            captureFinalizedScopeIndexCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseNine acquiredRun predecessor)
          | phase == 9 ->
            captureFinalizedResourceIndexCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTen acquiredRun predecessor)
          | phase == 10 ->
            captureFinalizedCalculusCompositionCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseEleven acquiredRun predecessor)
          | phase == 11 ->
            captureFinalizedFormalModelKernelCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTwelve acquiredRun predecessor)
          | phase == 12 ->
            captureFinalizedExplicitStateCheckerCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThirteen acquiredRun predecessor)
          | phase == 13 ->
            captureFinalizedSymbolicCheckerCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseFourteen acquiredRun predecessor)
          | phase == 14 ->
            captureFinalizedRefinementCheckerCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseFifteen acquiredRun predecessor)
          | phase == 15 ->
            captureFinalizedCompileFailHarnessCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseSixteen acquiredRun predecessor)
          | phase == 16 ->
            captureFinalizedDeterministicSimulationCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseSeventeen acquiredRun predecessor)
          | phase == 17 ->
            captureFinalizedGatewayMigrationModelCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseEighteen acquiredRun predecessor)
          | phase == 18 ->
            captureFinalizedDslFormalModelCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseNineteen acquiredRun predecessor)
          | phase == 19 ->
            captureFinalizedReconcileCoreCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTwenty acquiredRun predecessor)
          | phase == 20 ->
            captureFinalizedExtensionDeclarationCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTwentyOne acquiredRun predecessor)
          | phase == 21 ->
            captureFinalizedExtensionLawsCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTwentyTwo acquiredRun predecessor)
          | phase == 22 ->
            captureFinalizedExtensionCompositionCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTwentyThree acquiredRun predecessor)
          | phase == 23 ->
            captureFinalizedExtensionSecurityCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTwentyFour acquiredRun predecessor)
          | phase == 24 ->
            captureFinalizedConformanceGateCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTwentyFive acquiredRun predecessor)
          | phase == 25 ->
            captureFinalizedDhallSchemaCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTwentySix acquiredRun predecessor)
          | phase == 26 ->
            captureFinalizedGadtDecodeCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTwentySeven acquiredRun predecessor)
          | phase == 27 ->
            captureFinalizedIllegalStateCoveringCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTwentyEight acquiredRun predecessor)
          | phase == 28 ->
            captureFinalizedStorageGeometryCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseTwentyNine acquiredRun predecessor)
          | phase == 29 ->
            captureFinalizedExecutionAcceleratorCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThirty acquiredRun predecessor)
          | phase == 30 ->
            captureFinalizedCapabilityBindCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThirtyOne acquiredRun predecessor)
          | phase == 31 ->
            captureFinalizedProvisionSealCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThirtyTwo acquiredRun predecessor)
          | phase == 32 ->
            captureFinalizedInferenceAcceleratorCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThirtyThree acquiredRun predecessor)
          | phase == 33 ->
            captureFinalizedRenderManifestCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThirtyFour acquiredRun predecessor)
          | phase == 34 ->
            captureFinalizedChainBoundaryCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThirtyFive acquiredRun predecessor)
          | phase == 35 ->
            captureFinalizedImageRecipeCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThirtySix acquiredRun predecessor)
          | phase == 36 ->
            captureFinalizedTransactionVocabularyCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThirtySeven acquiredRun predecessor)
          | phase == 37 ->
            captureFinalizedUiProgramSchemaCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThirtyEight acquiredRun predecessor)
          | phase == 38 ->
            captureFinalizedUiAuthorizationCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseThirtyNine acquiredRun predecessor)
          | phase == 39 ->
            captureFinalizedUiEffectBindingCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseForty acquiredRun predecessor)
          | phase == 40 ->
            captureFinalizedUiPlanCompilerCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseFortyOne acquiredRun predecessor)
          | phase == 41 ->
            captureFinalizedOfflineLanguagePlanCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseFortyTwo acquiredRun predecessor)
          | phase == 42 ->
            captureFinalizedUiBrowserInterpreterCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseFortyThree acquiredRun predecessor)
          | phase == 43 ->
            captureFinalizedUiServerBoundaryCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseFortyFour acquiredRun predecessor)
          | phase == 44 ->
            captureFinalizedUiLocalCompositionCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseFortyFive acquiredRun predecessor)
          | phase == 45 ->
            captureFinalizedEncryptedBrowserRuntimeCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        Just (FinalizedPhaseFortySix acquiredRun predecessor)
          | phase == 46 ->
            captureFinalizedUiContractGenerationCandidateEvidence
              acquiredRun predecessor closing
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath executableDigest processArgv
        _ ->
            captureDispatchCandidateEvidence
              phase
              openingDigest
              (case closing of
                Left _ -> ""
                Right acquired -> snapshotIdentity (acquiredSourceSnapshot acquired))
              (either (const Nothing) (Just . projectionDigest) projectionResult)
              (either (const Nothing) (Just . projectionPostimageDigest) projectionResult)
              executablePath
              executableDigest
              processArgv
              subjectResult
      lifecycleResult =
        mergeChecks
          (checkName subjectResult)
          [ subjectResult
          , acquiredCandidateLegacyClosureCheck candidate
          , acquiredCandidatePassCriterionCheck candidate
          ]
  writeResult <- try (writeAcquiredCandidateEvidence root candidate) :: IO (Either IOException PublishedCandidateEvidence)
  case writeResult of
    Left problem ->
      pure
        lifecycleResult
          { checkFindings =
              checkFindings lifecycleResult
                <> [ finding
                       "EVIDENCE-CANDIDATE-WRITE"
                       "<candidate-evidence>"
                       (Text.pack (show problem))
                   ]
          }
    Right published -> do
      let writeObservations =
            [ observation "evidence.candidate.path" (Text.pack (publishedCandidatePath published))
            , observation "evidence.candidate.sha256" (acquiredCandidateDigest candidate)
            ]
      passResult <- verifyPublishedGatePass published
      case passResult of
        Left passFindings ->
          pure
            lifecycleResult
              { checkObservations = checkObservations lifecycleResult <> writeObservations
              , checkFindings = checkFindings lifecycleResult <> passFindings
              }
        Right verified -> case projectionResult of
          Left problems ->
            pure
              lifecycleResult
                { checkObservations = checkObservations lifecycleResult <> writeObservations
                , checkFindings = checkFindings lifecycleResult <> problems
                }
          Right projection -> case authorizeStatusProjection verified projection of
            Left problems ->
              pure
                lifecycleResult
                  { checkObservations = checkObservations lifecycleResult <> writeObservations
                  , checkFindings = checkFindings lifecycleResult <> problems
                  }
            Right authorized -> do
              projectionPublication <- writeAuthorizedStatusProjection authorized
              case projectionPublication of
                Left problems ->
                  pure
                    lifecycleResult
                      { checkObservations = checkObservations lifecycleResult <> writeObservations
                      , checkFindings = checkFindings lifecycleResult <> problems
                      }
                Right projectionPath -> do
                  postEmission <- loadGitSnapshot git root
                  let emitted =
                        bindPostEmissionSourceSnapshot
                          opening
                          postEmission
                          lifecycleResult
                            { checkObservations =
                                checkObservations lifecycleResult
                                  <> writeObservations
                                  <> [ observation "status.projection.path" (Text.pack projectionPath)
                                     , observation
                                         "status.projection"
                                         "authorized-not-applied; a human, agent, or CI job may apply the exact verified status-only projection"
                                     ]
                            , checkFindings = checkFindings lifecycleResult
                            }
                  if not (checkPassed emitted)
                    then pure emitted
                    else do
                      receiptResult <-
                        try (installPublishedCandidateEvidenceReceipt published) :: IO (Either IOException FilePath)
                      pure $ case receiptResult of
                        Left problem ->
                          emitted
                            { checkFindings =
                                checkFindings emitted
                                  <> [ finding
                                         "EVIDENCE-RECEIPT-WRITE"
                                         "<predecessor-receipt>"
                                         (Text.pack (show problem))
                                     ]
                            }
                        Right receiptPath ->
                          emitted
                            { checkObservations =
                                checkObservations emitted
                                  <> [observation "evidence.receipt.path" (Text.pack receiptPath)]
                            }

bindPostEmissionSourceSnapshot
  :: AcquiredSourceSnapshot
  -> Either [SnapshotProblem] AcquiredSourceSnapshot
  -> CheckResult
  -> CheckResult
bindPostEmissionSourceSnapshot opening observed result = case observed of
  Left problems ->
    result
      { checkFindings =
          checkFindings result
            <> map snapshotProblemFinding problems
      }
  Right closing
    | snapshotIdentity (acquiredSourceSnapshot opening)
        == snapshotIdentity (acquiredSourceSnapshot closing) ->
        result
          { checkObservations =
              checkObservations result
                <> [ observation
                       "source.snapshot.after-status-projection"
                       (snapshotIdentity (acquiredSourceSnapshot closing))
                   ]
          }
    | otherwise ->
        result
          { checkFindings =
              checkFindings result
                <> [ finding
                       "SOURCE-SNAPSHOT-CHANGED-DURING-STATUS-PROJECTION"
                       "<local-source-snapshot>"
                       "the authored source changed while the emitted-only status projection was written"
                   ]
          }

-- | Pure diagnostic seam. A caller-constructed snapshot can exercise
-- composition, but always carries an explicit refusal and can never represent
-- candidate local-capture evidence.
checkPhaseZeroSnapshot :: SourceSnapshot -> CheckResult
checkPhaseZeroSnapshot snapshot =
  mergeChecks
    "phase-00"
    [ checkPhaseZeroSnapshotCore snapshot
    , syntheticSnapshotRefusal
    ]

-- | A phase whose production subject has not been implemented.  This is an
-- observed absence at the current snapshot, not a policy statement that the
-- phase may never run: it retires when the phase's subject and oracle exist.
bindFinalSourceSnapshot
  :: AcquiredSourceSnapshot
  -> Either [SnapshotProblem] AcquiredSourceSnapshot
  -> CheckResult
  -> CheckResult
bindFinalSourceSnapshot initial final result = case final of
  Left problems ->
    result
      { checkFindings =
          checkFindings result
            <> map snapshotProblemFinding problems
      }
  Right observed
    | snapshotIdentity (acquiredSourceSnapshot initial)
        == snapshotIdentity (acquiredSourceSnapshot observed) ->
        result
          { checkObservations =
              checkObservations result
                <> [observation "source.snapshot.final" (snapshotIdentity (acquiredSourceSnapshot observed))]
          }
    | otherwise ->
        result
          { checkFindings =
              checkFindings result
                <> [ finding
                       "SOURCE-SNAPSHOT-CHANGED-DURING-GATE"
                       "<local-source-snapshot>"
                       "the authored source bytes changed between the opening and closing gate captures"
                   ]
          }

checkPhaseZeroSnapshotCore :: SourceSnapshot -> CheckResult
checkPhaseZeroSnapshotCore snapshot =
  mergeChecks
    "phase-00"
    (map (rawPhaseZeroComponentCheck snapshot closure decodedDocuments) rawPhaseZeroComponentUniverse)
 where
  closure = classifySnapshot snapshot
  decodedDocuments = phaseZeroSnapshotDocuments snapshot

-- | The raw diagnostic composition has one closed selection locus. Every
-- component occurs exactly once here, and each omission mutant changes only
-- one selection decision rather than changing a component or its oracle.
data RawPhaseZeroComponent
  = RawSourceClosure
  | RawSourceDebtBaseline
  | RawSourceConsumerGraph
  | RawLegacy
  | RawPolicyContract
  | RawDocumentation
  | RawPhaseContract
  deriving (Eq, Ord, Enum, Bounded, Show)

rawPhaseZeroComponentUniverse :: [RawPhaseZeroComponent]
rawPhaseZeroComponentUniverse =
  [ RawSourceClosure
  , RawSourceDebtBaseline
  , RawSourceConsumerGraph
  , RawLegacy
  , RawPolicyContract
  , RawDocumentation
  , RawPhaseContract
  ]

renderRawPhaseZeroComponent :: RawPhaseZeroComponent -> Text
renderRawPhaseZeroComponent component = case component of
  RawSourceClosure -> "source-closure"
  RawSourceDebtBaseline -> "source-debt-baseline"
  RawSourceConsumerGraph -> "source-consumer-graph"
  RawLegacy -> "legacy"
  RawPolicyContract -> "policy-contract"
  RawDocumentation -> "documentation"
  RawPhaseContract -> "phase-contract"

selectedRawPhaseZeroComponents :: [RawPhaseZeroComponent]
selectedRawPhaseZeroComponents = filter rawPhaseZeroComponentSelected rawPhaseZeroComponentUniverse

rawPhaseZeroComponentSelected :: RawPhaseZeroComponent -> Bool
rawPhaseZeroComponentSelected component = case component of
  RawSourceClosure ->
#if defined(VALIDATION_DISPATCH_OMIT_SOURCE_CLOSURE_MUTANT)
    False
#else
    True
#endif
  RawSourceDebtBaseline ->
#if defined(VALIDATION_DISPATCH_OMIT_SOURCE_DEBT_BASELINE_MUTANT)
    False
#else
    True
#endif
  RawSourceConsumerGraph ->
#if defined(VALIDATION_DISPATCH_OMIT_SOURCE_CONSUMER_GRAPH_MUTANT)
    False
#else
    True
#endif
  RawLegacy ->
#if defined(VALIDATION_DISPATCH_OMIT_LEGACY_MUTANT)
    False
#else
    True
#endif
  RawPolicyContract ->
#if defined(VALIDATION_DISPATCH_OMIT_POLICY_CONTRACT_MUTANT)
    False
#else
    True
#endif
  RawDocumentation ->
#if defined(VALIDATION_DISPATCH_OMIT_DOCUMENTATION_MUTANT)
    False
#else
    True
#endif
  RawPhaseContract ->
#if defined(VALIDATION_DISPATCH_OMIT_PHASE_CONTRACT_MUTANT)
    False
#else
    True
#endif

rawPhaseZeroComponentCheck
  :: SourceSnapshot
  -> SourceClosure
  -> Either [Finding] [(FilePath, Text)]
  -> RawPhaseZeroComponent
  -> CheckResult
rawPhaseZeroComponentCheck snapshot closure decodedDocuments component = case component of
  RawSourceClosure -> sourceClosureCheck closure
  RawSourceDebtBaseline -> sourceDebtClosureDiagnosticCheck closure
  RawSourceConsumerGraph -> sourceConsumerGraphCheck (analyzeSourceConsumerGraph snapshot)
  RawLegacy -> legacyCheck (Policy.phaseDomainLower policyOrdering) snapshot
  RawPolicyContract -> Policy.checkPolicyContract Policy.canonicalPolicyContract
  RawDocumentation -> case decodedDocuments of
    Left decodeFindings -> CheckResult "documentation-snapshot" [] decodeFindings
    Right documents -> checkDocuments documents
  RawPhaseContract -> case decodedDocuments of
    Left decodeFindings -> phaseZeroUnavailablePhaseContractCheck decodeFindings
    Right documents -> checkPhaseContractsForPhase (Policy.phaseOrdinalNumber (Policy.phaseDomainLower policyOrdering)) documents

syntheticSnapshotRefusal :: CheckResult
syntheticSnapshotRefusal =
  CheckResult
    { checkName = "source-snapshot-diagnostic"
    , checkObservations =
        [ observation
            "source.snapshot.local-capture"
            "caller-supplied diagnostic input; package-hidden local capture absent"
        ]
    , checkFindings = syntheticSnapshotFindings
    }

syntheticSnapshotFindings :: [Finding]
syntheticSnapshotFindings =
  [ finding
      "SOURCE-SNAPSHOT-DIAGNOSTIC-ONLY"
      "<caller-supplied-snapshot>"
      "a pure SourceSnapshot has not crossed the package-hidden local capture boundary and cannot be candidate evidence"
  ]

snapshotFailure :: [SnapshotProblem] -> CheckResult
snapshotFailure problems =
  CheckResult
    { checkName = "source-snapshot-capture"
    , checkObservations = [observation "source.snapshot" "refused before classification"]
    , checkFindings = map snapshotProblemFinding problems
    }

snapshotProblemFinding :: SnapshotProblem -> Finding
snapshotProblemFinding problem = case problem of
  CallerSelectedGitDiagnosticOnly _ ->
    finding
      "GIT-CAPTURE-TOOL-INVALID"
      "Amoebius.Validation.Dispatch"
      (renderSnapshotProblem problem)
  SourceSnapshotAtomicityRequiresExternalObserver ->
    finding
      "SOURCE-SNAPSHOT-LOCAL-CAPTURE-INCOMPLETE"
      "Amoebius.Validation.Dispatch"
      (renderSnapshotProblem problem)
  _ -> finding "SRC-SNAPSHOT" "<git-index>" (renderSnapshotProblem problem)

captureFailure :: Text -> CheckResult
captureFailure detail =
  CheckResult
    { checkName = "validation-capture"
    , checkObservations = [observation "validation.capture" "refused"]
    , checkFindings = [finding "DISPATCH-CAPTURE" "repository" detail]
    }

emitResult :: CheckResult -> IO ExitCode
emitResult result = do
  TextIO.putStrLn ("validation " <> checkName result <> ": " <> verdict)
  mapM_ emitObservation (checkObservations result)
  mapM_ (TextIO.putStrLn . ("REFUSAL\t" <>) . renderFinding) (checkFindings result)
  TextIO.putStrLn ("status\t" <> if checkPassed result then "PASS" else "NOT VALIDATED")
  pure (if checkPassed result then ExitSuccess else ExitFailure 1)
 where
  verdict = if checkPassed result then "PASS" else "REFUSED"
  emitObservation item =
    TextIO.putStrLn ("OBSERVATION\t" <> observationKey item <> "\t" <> observationValue item)

acquireRepository :: IO (Either Text (FilePath, FilePath))
acquireRepository = do
  gitCandidate <- findExecutable "git"
  case gitCandidate of
    Nothing -> pure (Left "Git is absent from the irreducible host floor")
    Just git -> do
      gitResult <- canonicalize git
      rootResult <- discoverRepositoryRoot
      pure ((,) <$> gitResult <*> rootResult)

discoverRepositoryRoot :: IO (Either Text FilePath)
discoverRepositoryRoot = do
  current <- getCurrentDirectory
  executable <- getExecutablePath
  startsResult <- traverse canonicalize [current, takeDirectory executable]
  case sequence startsResult of
    Left detail -> pure (Left detail)
    Right starts -> do
      candidates <- fmap (sort . nub . concat) (traverse repositoryAncestors starts)
      pure $ case candidates of
        [root] -> Right root
        [] -> Left "no ancestor contains both .git and amoebius.cabal"
        roots -> Left ("repository root is ambiguous: " <> Text.intercalate ", " (fmap Text.pack roots))

repositoryAncestors :: FilePath -> IO [FilePath]
repositoryAncestors start = filterM isRepository (ancestors start)
 where
  isRepository candidate = do
    git <- doesPathExist (candidate </> ".git")
    package <- doesFileExist (candidate </> "amoebius.cabal")
    pure (git && package)

ancestors :: FilePath -> [FilePath]
ancestors path = path : if parent == path then [] else ancestors parent
 where
  parent = takeDirectory path

canonicalize :: FilePath -> IO (Either Text FilePath)
canonicalize path = do
  result <- try (canonicalizePath path) :: IO (Either IOException FilePath)
  pure $ case result of
    Left problem -> Left ("cannot canonicalize " <> Text.pack path <> ": " <> Text.pack (show problem))
    Right absolute
      | isAbsolute absolute -> Right absolute
      | otherwise -> Left ("canonical path is not absolute: " <> Text.pack absolute)

parseOrdinal :: String -> Maybe Int
parseOrdinal value
  | length value == 2 && all asciiDigit value = do
      phase <- readMaybe value
      if phase >= policyDomainLower && phase <= policyDomainUpper then Just phase else Nothing
  | otherwise = Nothing
 where
  asciiDigit character = character >= '0' && character <= '9'

formatOrdinal :: Int -> Text
formatOrdinal phase
  | phase >= 0 && phase < 10 = "0" <> Text.pack (show phase)
  | otherwise = Text.pack (show phase)

policyOrdering :: Policy.OrderingContract
policyOrdering = Policy.orderingContract Policy.canonicalPolicyContract

policyDomainLower :: Int
policyDomainLower = Policy.phaseOrdinalNumber (Policy.phaseDomainLower policyOrdering)

policyDomainUpper :: Int
policyDomainUpper = Policy.phaseOrdinalNumber (Policy.phaseDomainUpper policyOrdering)

policyDomainLabel :: Text
policyDomainLabel = formatOrdinal policyDomainLower <> " through " <> formatOrdinal policyDomainUpper
