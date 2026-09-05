{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

{- | Execution-derived candidate evidence used by the production dispatcher.
Constructors are package-hidden: the public Evidence module remains a
refusal-only diagnostic seam over caller-supplied values.
-}
module Amoebius.Validation.Evidence.Internal (
    AcquiredCandidateEvidence,
    CandidateCapture,
    captureArgv,
    captureArchitecture,
    captureCleanupObservation,
    captureContractDigest,
    captureExecutableDigest,
    captureExecutablePath,
    captureHarnessDigest,
    captureLane,
    captureObserverDigest,
    captureOracleDigest,
    capturePhase,
    capturePredecessor,
    captureProjectionDigest,
    captureProjectionPostimageDigest,
    captureQualificationDigest,
    captureResidue,
    captureRows,
    captureRunIdentity,
    captureSourceClosing,
    captureSourceOpening,
    captureSubjectDigest,
    captureSubstrate,
    captureToolchainIdentity,
    GateRow (..),
    GateRowEvidence,
    capturedRow,
    gateRowEvidencePassed,
    PublishedCandidateEvidence,
    PredecessorEvidence,
    predecessorEvidenceMatchesPhase,
    acquiredCandidateBytes,
    acquiredCandidateCapture,
    acquiredCandidateDigest,
    acquiredCandidateLegacyClosureCheck,
    acquiredCandidatePassCriterionCheck,
    acquiredCandidateQualificationCheck,
    acquiredCandidatePhase,
    acquiredCandidatePredecessor,
    acquiredCandidateProjectionDigest,
    acquiredCandidateRows,
    acquiredCandidateSubjectCheck,
    acquiredCandidateSourceClosing,
    acquiredCandidateSourceOpening,
    allGateRows,
    captureDispatchCandidateEvidence,
    captureFinalizedArtifactCalculusCandidateEvidence,
    captureFinalizedBudgetCalculusCandidateEvidence,
    captureFinalizedLiftCalculusCandidateEvidence,
    captureFinalizedWorkflowCalculusCandidateEvidence,
    captureFinalizedEvidenceCalculusCandidateEvidence,
    captureFinalizedScopeIndexCandidateEvidence,
    captureFinalizedResourceIndexCandidateEvidence,
    captureFinalizedCalculusCompositionCandidateEvidence,
    captureFinalizedFormalModelKernelCandidateEvidence,
    captureFinalizedExplicitStateCheckerCandidateEvidence,
    captureFinalizedSymbolicCheckerCandidateEvidence,
    captureFinalizedRefinementCheckerCandidateEvidence,
    captureFinalizedCompileFailHarnessCandidateEvidence,
    captureFinalizedDeterministicSimulationCandidateEvidence,
    captureFinalizedGatewayMigrationModelCandidateEvidence,
    captureFinalizedDslFormalModelCandidateEvidence,
    captureFinalizedReconcileCoreCandidateEvidence,
    captureFinalizedExtensionDeclarationCandidateEvidence,
    captureFinalizedExtensionLawsCandidateEvidence,
    captureFinalizedExtensionCompositionCandidateEvidence,
    captureFinalizedExtensionSecurityCandidateEvidence,
    captureFinalizedConformanceGateCandidateEvidence,
    captureFinalizedDhallSchemaCandidateEvidence,
    captureFinalizedGadtDecodeCandidateEvidence,
    captureFinalizedIllegalStateCoveringCandidateEvidence,
    captureFinalizedStorageGeometryCandidateEvidence,
    captureFinalizedExecutionAcceleratorCandidateEvidence,
    captureFinalizedCapabilityBindCandidateEvidence,
    captureFinalizedProvisionSealCandidateEvidence,
    captureFinalizedInferenceAcceleratorCandidateEvidence,
    captureFinalizedRenderManifestCandidateEvidence,
    captureFinalizedChainBoundaryCandidateEvidence,
    captureFinalizedImageRecipeCandidateEvidence,
    captureFinalizedTransactionVocabularyCandidateEvidence,
    captureFinalizedUiProgramSchemaCandidateEvidence,
    captureFinalizedUiAuthorizationCandidateEvidence,
    captureFinalizedUiEffectBindingCandidateEvidence,
    captureFinalizedUiPlanCompilerCandidateEvidence,
    captureFinalizedOfflineLanguagePlanCandidateEvidence,
    captureFinalizedUiBrowserInterpreterCandidateEvidence,
    captureFinalizedUiServerBoundaryCandidateEvidence,
    captureFinalizedUiLocalCompositionCandidateEvidence,
    captureFinalizedEncryptedBrowserRuntimeCandidateEvidence,
    captureFinalizedUiContractGenerationCandidateEvidence,
    captureFinalizedDispatchCandidateEvidence,
    captureFinalizedRepositoryLayoutCandidateEvidence,
    captureFinalizedToolchainSpikeCandidateEvidence,
    acquireImmediatePredecessorEvidence,
    installPublishedCandidateEvidenceReceipt,
    publishedCandidateEvidence,
    publishedCandidatePath,
    recheckPublishedCandidateEvidence,
    renderGateRow,
    writeAcquiredCandidateEvidence,
) where

import Amoebius.Validation.BootstrapPredicate (bootstrapDigestMatches, bootstrapSnapshotMatches)
import Amoebius.Validation.BootstrapQualification.Internal
  ( BootstrapCase
  , foldQualifiedBootstrapProtocol
  , renderBootstrapCase
  )
import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust
  , genesisTrustArchitecture
  , genesisTrustAssumptionLabel
  , genesisTrustCompilerExecutable
  , genesisTrustDigest
  , genesisTrustToolchainIdentity
  )
import Amoebius.Validation.Legacy.Internal (
    GateCompletionPremises,
    GatePrerequisiteObservation,
    LegacyClosure,
    assembleGateCompletionPremises,
    gatePrerequisitePassed,
    gatePrerequisiteRefused,
    gatePrerequisiteUnverified,
    legacyBootstrapClosureAcquired,
    legacyClosureResult,
 )
import Amoebius.Validation.ArtifactCalculusRun.Internal (
    AcquiredArtifactCalculusRun,
    foldAcquiredArtifactCalculusRun,
 )
import Amoebius.Validation.BudgetCalculusRun.Internal (
    AcquiredBudgetCalculusRun,
    foldAcquiredBudgetCalculusRun,
 )
import Amoebius.Validation.LiftCalculusRun.Internal (
    AcquiredLiftCalculusRun,
    foldAcquiredLiftCalculusRun,
 )
import Amoebius.Validation.WorkflowCalculusRun.Internal (
    AcquiredWorkflowCalculusRun,
    foldAcquiredWorkflowCalculusRun,
 )
import Amoebius.Validation.EvidenceCalculusRun.Internal (
    AcquiredEvidenceCalculusRun,
    foldAcquiredEvidenceCalculusRun,
 )
import Amoebius.Validation.ScopeIndexRun.Internal (
    AcquiredScopeIndexRun,
    foldAcquiredScopeIndexRun,
 )
import Amoebius.Validation.ResourceIndexRun.Internal (
    AcquiredResourceIndexRun,
    foldAcquiredResourceIndexRun,
 )
import Amoebius.Validation.CalculusCompositionRun.Internal (
    AcquiredCalculusCompositionRun,
    foldAcquiredCalculusCompositionRun,
 )
import Amoebius.Validation.FormalModelKernelRun.Internal (
    AcquiredFormalModelKernelRun,
    foldAcquiredFormalModelKernelRun,
 )
import Amoebius.Validation.ExplicitStateCheckerRun.Internal (
    AcquiredExplicitStateCheckerRun,
    foldAcquiredExplicitStateCheckerRun,
 )
import Amoebius.Validation.SymbolicCheckerRun.Internal (
    AcquiredSymbolicCheckerRun,
    foldAcquiredSymbolicCheckerRun,
 )
import Amoebius.Validation.RefinementCheckerRun.Internal (
    AcquiredRefinementCheckerRun,
    foldAcquiredRefinementCheckerRun,
 )
import Amoebius.Validation.CompileFailHarnessRun.Internal (
    AcquiredCompileFailHarnessRun,
    foldAcquiredCompileFailHarnessRun,
 )
import Amoebius.Validation.DeterministicSimulationRun.Internal (
    AcquiredDeterministicSimulationRun,
    foldAcquiredDeterministicSimulationRun,
 )
import Amoebius.Validation.GatewayMigrationModelRun.Internal (
    AcquiredGatewayMigrationModelRun,
    foldAcquiredGatewayMigrationModelRun,
 )
import Amoebius.Validation.DslFormalModelRun.Internal (
    AcquiredDslFormalModelRun,
    foldAcquiredDslFormalModelRun,
 )
import Amoebius.Validation.ReconcileCoreRun.Internal (
    AcquiredReconcileCoreRun,
    foldAcquiredReconcileCoreRun,
 )
import Amoebius.Validation.ExtensionDeclarationRun.Internal (
    AcquiredExtensionDeclarationRun,
    foldAcquiredExtensionDeclarationRun,
 )
import Amoebius.Validation.ExtensionLawsRun.Internal (
    AcquiredExtensionLawsRun,
    foldAcquiredExtensionLawsRun,
 )
import Amoebius.Validation.ExtensionCompositionRun.Internal (
    AcquiredExtensionCompositionRun,
    foldAcquiredExtensionCompositionRun,
 )
import Amoebius.Validation.ExtensionSecurityRun.Internal (
    AcquiredExtensionSecurityRun,
    foldAcquiredExtensionSecurityRun,
 )
import Amoebius.Validation.ConformanceGateRun.Internal (
    AcquiredConformanceGateRun,
    foldAcquiredConformanceGateRun,
 )
import Amoebius.Validation.DhallSchemaRun.Internal (
    AcquiredDhallSchemaRun,
    foldAcquiredDhallSchemaRun,
 )
import Amoebius.Validation.GadtDecodeRun.Internal (
    AcquiredGadtDecodeRun,
    foldAcquiredGadtDecodeRun,
 )
import Amoebius.Validation.IllegalStateCoveringRun.Internal (
    AcquiredIllegalStateCoveringRun,
    foldAcquiredIllegalStateCoveringRun,
 )
import Amoebius.Validation.StorageGeometryRun.Internal (
    AcquiredStorageGeometryRun,
    foldAcquiredStorageGeometryRun,
 )
import Amoebius.Validation.ExecutionAcceleratorRun.Internal (
    AcquiredExecutionAcceleratorRun,
    foldAcquiredExecutionAcceleratorRun,
 )
import Amoebius.Validation.CapabilityBindRun.Internal (
    AcquiredCapabilityBindRun,
    foldAcquiredCapabilityBindRun,
 )
import Amoebius.Validation.ProvisionSealRun.Internal (
    AcquiredProvisionSealRun,
    foldAcquiredProvisionSealRun,
 )
import Amoebius.Validation.InferenceAcceleratorRun.Internal (
    AcquiredInferenceAcceleratorRun,
    foldAcquiredInferenceAcceleratorRun,
 )
import Amoebius.Validation.RenderManifestRun.Internal (
    AcquiredRenderManifestRun,
    foldAcquiredRenderManifestRun,
 )
import Amoebius.Validation.ChainBoundaryRun.Internal (
    AcquiredChainBoundaryRun,
    foldAcquiredChainBoundaryRun,
 )
import Amoebius.Validation.ImageRecipeRun.Internal (
    AcquiredImageRecipeRun,
    foldAcquiredImageRecipeRun,
 )
import Amoebius.Validation.TransactionVocabularyRun.Internal (
    AcquiredTransactionVocabularyRun,
    foldAcquiredTransactionVocabularyRun,
 )
import Amoebius.Validation.UiProgramSchemaRun.Internal (
    AcquiredUiProgramSchemaRun,
    foldAcquiredUiProgramSchemaRun,
 )
import Amoebius.Validation.UiAuthorizationRun.Internal (
    AcquiredUiAuthorizationRun,
    foldAcquiredUiAuthorizationRun,
 )
import Amoebius.Validation.UiEffectBindingRun.Internal (
    AcquiredUiEffectBindingRun,
    foldAcquiredUiEffectBindingRun,
 )
import Amoebius.Validation.UiPlanCompilerRun.Internal (
    AcquiredUiPlanCompilerRun,
    foldAcquiredUiPlanCompilerRun,
 )
import Amoebius.Validation.OfflineLanguagePlanRun.Internal (
    AcquiredOfflineLanguagePlanRun,
    foldAcquiredOfflineLanguagePlanRun,
 )
import Amoebius.Validation.UiBrowserInterpreterRun.Internal (
    AcquiredUiBrowserInterpreterRun,
    foldAcquiredUiBrowserInterpreterRun,
 )
import Amoebius.Validation.UiServerBoundaryRun.Internal (
    AcquiredUiServerBoundaryRun,
    foldAcquiredUiServerBoundaryRun,
 )
import Amoebius.Validation.UiLocalCompositionRun.Internal (
    AcquiredUiLocalCompositionRun,
    foldAcquiredUiLocalCompositionRun,
 )
import Amoebius.Validation.EncryptedBrowserRuntimeRun.Internal (
    AcquiredEncryptedBrowserRuntimeRun,
    foldAcquiredEncryptedBrowserRuntimeRun,
 )
import Amoebius.Validation.UiContractGenerationRun.Internal (
    AcquiredUiContractGenerationRun,
    foldAcquiredUiContractGenerationRun,
 )
import Amoebius.Validation.PhaseZeroRun.Internal (
    AcquiredPhaseZeroRun,
    foldAcquiredPhaseZeroRun,
 )
import Amoebius.Validation.RepositoryLayoutRun.Internal (
    AcquiredRepositoryLayoutRun,
    foldAcquiredRepositoryLayoutRun,
 )
import Amoebius.Validation.ToolchainSpikeRun.Internal (
    AcquiredToolchainSpikeRun,
    foldAcquiredToolchainSpikeRun,
 )
import Amoebius.Validation.PhaseContract.Evidence.Internal
  ( acquiredPhaseContractEvidenceCheck
  )
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.SourceClosure.Internal (
    AcquiredSourceSnapshot,
    SnapshotProblem,
    acquiredSourceSnapshot,
    renderSnapshotProblem,
 )
import Amoebius.Validation.SourceSnapshot.Internal (SourceSnapshot (snapshotIdentity))
import Amoebius.Validation.Types (
    CheckResult (..),
    Finding (..),
    Observation (..),
    checkPassed,
    finding,
    observation,
 )
import Control.Exception (IOException, bracket, onException, try)
import Control.Monad (foldM, unless, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (ToJSON (toJSON), Value (..), decodeStrict', encode, object, (.=))
import Data.Aeson.Key qualified as AesonKey
import Data.Aeson.KeyMap qualified as AesonKeyMap
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (intToDigit)
import Data.Foldable qualified as Foldable
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Exit (ExitCode (..))
import System.Directory (
    canonicalizePath,
    createDirectory,
    doesDirectoryExist,
    doesPathExist,
    makeAbsolute,
    listDirectory,
    pathIsSymbolicLink,
    removeFile,
 )
#if defined(mingw32_HOST_OS)
import System.Directory (renameFile)
#endif
import System.FilePath (
    dropTrailingPathSeparator,
    isAbsolute,
    makeRelative,
    normalise,
    splitDirectories,
    takeDirectory,
    takeExtension,
    takeFileName,
    (</>),
 )
import System.IO (
    Handle,
    hClose,
    hFlush,
    openBinaryTempFile,
 )
#if !defined(mingw32_HOST_OS)
import System.Posix.Files (
    FileStatus,
    createLink,
    deviceID,
    fileID,
    fileSize,
    getFdStatus,
    isDirectory,
    isRegularFile,
 )
import System.Posix.IO
  ( OpenFileFlags (cloexec, directory, nofollow, nonBlock)
  , OpenMode (ReadOnly)
  , closeFd
  , defaultFileFlags
  , dup
  , fdToHandle
  , handleToFd
  , openFd
  , openFdAt
  )
import System.Posix.Types (Fd)
import System.Posix.Unistd (fileSynchronise)
#endif

data GateRow
    = ClaimRow
    | SubjectRow
    | CommandRow
    | OracleRow
    | PositiveControlsRow
    | PairedNegativesRow
    | MutantsRow
    | DiscoveryRow
    | ChallengeRow
    | ObserverRow
    | AuthorityBypassRow
    | FreshnessRow
    | QualificationRow
    | CleanroomRow
    | LegacyClosureRow
    | PredecessorRow
    | ResidueRow
    | PassCriterionRow
    deriving (Bounded, Enum, Eq, Ord, Show)

allGateRows :: [GateRow]
allGateRows = [minBound .. maxBound]

renderGateRow :: GateRow -> Text
renderGateRow row = case row of
    ClaimRow -> "Claim"
    SubjectRow -> "Subject"
    CommandRow -> "Command"
    OracleRow -> "Oracle"
    PositiveControlsRow -> "Positive controls"
    PairedNegativesRow -> "Paired negatives"
    MutantsRow -> "Mutants"
    DiscoveryRow -> "Discovery"
    ChallengeRow -> "Challenge"
    ObserverRow -> "Observer"
    AuthorityBypassRow -> "Authority/bypass"
    FreshnessRow -> "Freshness"
    QualificationRow -> "Qualification"
    CleanroomRow -> "Cleanroom"
    LegacyClosureRow -> "Legacy closure"
    PredecessorRow -> "Predecessor"
    ResidueRow -> "Residue"
    PassCriterionRow -> "Pass criterion"

data RowOutcome
    = RowPassed [Observation]
    | RowRefused [Observation] [Finding]
    | RowUnverified [Observation] Text
    deriving (Eq, Show)

data GateRowEvidence = GateRowEvidence
    { capturedRow :: GateRow
    , capturedOutcome :: RowOutcome
    }
    deriving (Eq, Show)

gateRowEvidencePassed :: GateRowEvidence -> Bool
gateRowEvidencePassed evidence = case capturedOutcome evidence of
    RowPassed observations -> not (null observations) && all validObservation observations
    RowRefused _ _ -> False
    RowUnverified _ _ -> False

data PredecessorEvidence
    = GenesisPredecessor Text
    | ImmediatePredecessor Int Text
    | UnverifiedPredecessor Text
    deriving (Eq, Show)

predecessorEvidenceMatchesPhase :: Int -> PredecessorEvidence -> Bool
predecessorEvidenceMatchesPhase phase predecessor = case (phase, predecessor) of
    (0, GenesisPredecessor digest) -> sha256Text digest
    (_, ImmediatePredecessor predecessorPhase digest) ->
        predecessorPhase == phase - 1 && sha256Text digest
    _ -> False

{- | Every execution identity field is explicit.  'Nothing' means unverified
residue and therefore makes gate verification fail; it is never defaulted.
-}
data CandidateCapture = CandidateCapture
    { candidateCapturePhase :: Int
    , candidateCaptureSourceOpening :: Text
    , candidateCaptureSourceClosing :: Text
    , candidateCaptureContractDigest :: Maybe Text
    , candidateCaptureSubjectDigest :: Maybe Text
    , candidateCaptureOracleDigest :: Maybe Text
    , candidateCaptureHarnessDigest :: Maybe Text
    , candidateCaptureObserverDigest :: Maybe Text
    , candidateCaptureQualificationDigest :: Maybe Text
    , candidateCaptureProjectionDigest :: Maybe Text
    , candidateCaptureProjectionPostimageDigest :: Maybe Text
    , candidateCapturePredecessor :: PredecessorEvidence
    , candidateCaptureExecutablePath :: FilePath
    , candidateCaptureExecutableDigest :: Maybe Text
    , candidateCaptureArgv :: [Text]
    , candidateCaptureToolchainIdentity :: Maybe Text
    , candidateCaptureSubstrate :: Maybe Text
    , candidateCaptureLane :: Maybe Text
    , candidateCaptureArchitecture :: Maybe Text
    , candidateCaptureRunIdentity :: Maybe Text
    , candidateCaptureCleanupObservation :: Maybe Text
    , candidateCaptureRows :: [GateRowEvidence]
    , candidateCaptureResidue :: [Text]
    }
    deriving (Eq, Show)

data AcquiredCandidateEvidence = AcquiredCandidateEvidence
    { acquiredCapture :: CandidateCapture
    , acquiredSchema :: Text
    }
    deriving (Eq, Show)

{- | Publication is part of the gate boundary, not a best-effort side effect.
Only the durable writer below can construct this receipt, and the hidden
gate verifier consumes it instead of an in-memory candidate.
-}
data PublishedCandidateEvidence = PublishedCandidateEvidence
    { publishedEvidenceValue :: AcquiredCandidateEvidence
    , publishedPathValue :: FilePath
    , publishedRootValue :: FilePath
    , publishedRootIdentityValue :: PublicationIdentity
    , publishedDirectoryIdentityValue :: PublicationIdentity
    , publishedFileIdentityValue :: PublicationIdentity
    }
    deriving (Eq, Show)

data PublicationIdentity = PublicationIdentity Integer Integer
    deriving (Eq, Show)

capturePhase :: CandidateCapture -> Int
capturePhase = candidateCapturePhase

captureSourceOpening, captureSourceClosing :: CandidateCapture -> Text
captureSourceOpening = candidateCaptureSourceOpening
captureSourceClosing = candidateCaptureSourceClosing

captureContractDigest, captureSubjectDigest, captureOracleDigest, captureHarnessDigest :: CandidateCapture -> Maybe Text
captureContractDigest = candidateCaptureContractDigest
captureSubjectDigest = candidateCaptureSubjectDigest
captureOracleDigest = candidateCaptureOracleDigest
captureHarnessDigest = candidateCaptureHarnessDigest

captureObserverDigest, captureQualificationDigest, captureProjectionDigest, captureProjectionPostimageDigest :: CandidateCapture -> Maybe Text
captureObserverDigest = candidateCaptureObserverDigest
captureQualificationDigest = candidateCaptureQualificationDigest
captureProjectionDigest = candidateCaptureProjectionDigest
captureProjectionPostimageDigest = candidateCaptureProjectionPostimageDigest

capturePredecessor :: CandidateCapture -> PredecessorEvidence
capturePredecessor = candidateCapturePredecessor

captureExecutablePath :: CandidateCapture -> FilePath
captureExecutablePath = candidateCaptureExecutablePath

captureExecutableDigest :: CandidateCapture -> Maybe Text
captureExecutableDigest = candidateCaptureExecutableDigest

captureArgv :: CandidateCapture -> [Text]
captureArgv = candidateCaptureArgv

captureToolchainIdentity, captureSubstrate, captureLane, captureArchitecture :: CandidateCapture -> Maybe Text
captureToolchainIdentity = candidateCaptureToolchainIdentity
captureSubstrate = candidateCaptureSubstrate
captureLane = candidateCaptureLane
captureArchitecture = candidateCaptureArchitecture

captureRunIdentity, captureCleanupObservation :: CandidateCapture -> Maybe Text
captureRunIdentity = candidateCaptureRunIdentity
captureCleanupObservation = candidateCaptureCleanupObservation

captureRows :: CandidateCapture -> [GateRowEvidence]
captureRows = candidateCaptureRows

captureResidue :: CandidateCapture -> [Text]
captureResidue = candidateCaptureResidue

publishedCandidateEvidence :: PublishedCandidateEvidence -> AcquiredCandidateEvidence
publishedCandidateEvidence = publishedEvidenceValue

publishedCandidatePath :: PublishedCandidateEvidence -> FilePath
publishedCandidatePath = publishedPathValue

captureCandidateEvidence :: CandidateCapture -> AcquiredCandidateEvidence
captureCandidateEvidence captured =
    AcquiredCandidateEvidence
        { acquiredCapture = captured
        , acquiredSchema = "amoebius-validation-candidate-v3"
        }

{- | The current production dispatcher can capture an honest red candidate,
but it cannot manufacture a complete green one.  Row construction and the
generic 'CandidateCapture' constructor stay in this module; the dispatcher
supplies only its acquired lifecycle result and identities that it actually
observed.  Complete row-specific authority will require opaque witnesses from
the independent runner/oracle boundaries rather than another exported record
constructor.
-}
captureDispatchCandidateEvidence ::
    Int ->
    Text ->
    Text ->
    Maybe Text ->
    Maybe Text ->
    FilePath ->
    Maybe Text ->
    [Text] ->
    CheckResult ->
    AcquiredCandidateEvidence
captureDispatchCandidateEvidence phase opening closing projectionDigest projectionPostimageDigest executablePath executableDigest argv result =
    captureCandidateEvidence
        CandidateCapture
            { candidateCapturePhase = phase
            , candidateCaptureSourceOpening = opening
            , candidateCaptureSourceClosing = closing
            , candidateCaptureContractDigest = Nothing
            , candidateCaptureSubjectDigest = Nothing
            , candidateCaptureOracleDigest = Nothing
            , candidateCaptureHarnessDigest = Nothing
            , candidateCaptureObserverDigest = Nothing
            , candidateCaptureQualificationDigest = Nothing
            , candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest
            , candidateCapturePredecessor =
                if phase == policyDomainLower
                    then GenesisPredecessor ""
                    else UnverifiedPredecessor "the immediate predecessor evidence digest is not yet carried by the dispatcher"
            , candidateCaptureExecutablePath = executablePath
            , candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv
            , candidateCaptureToolchainIdentity = Nothing
            , candidateCaptureSubstrate = Nothing
            , candidateCaptureLane = Nothing
            , candidateCaptureArchitecture = Nothing
            , candidateCaptureRunIdentity = Nothing
            , candidateCaptureCleanupObservation = Nothing
            , candidateCaptureRows = map (dispatchGateRow phase result opening closing executableDigest argv) allGateRows
            , candidateCaptureResidue =
                [ "UNVERIFIED: typed contract identity is not yet acquired"
                , "UNVERIFIED: subject identity is not yet acquired"
                , "UNVERIFIED: oracle identity is not yet acquired"
                , "UNVERIFIED: harness identity is not yet acquired"
                , "UNVERIFIED: observer identity is not yet acquired"
                , "UNVERIFIED: qualification identity is not yet acquired"
                , "UNVERIFIED: toolchain, substrate, lane, architecture, run identity, and cleanup observation are not yet acquired"
                ]
                    <> ["UNVERIFIED: status projection could not be prepared" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }

{- | Finalize the finite Phase-0 bootstrap from opaque acquired products.
Every green row below is derived from the acquired snapshot, GenesisTrust, or
the executed clean-plus-mutant protocol; the generic capture API remains
refusal-only.
-}
captureFinalizedDispatchCandidateEvidence ::
    AcquiredPhaseZeroRun ->
    Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text ->
    Maybe Text ->
    FilePath ->
    Maybe Text ->
    [Text] ->
    AcquiredCandidateEvidence
captureFinalizedDispatchCandidateEvidence acquiredRun closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredPhaseZeroRun finalize acquiredRun
  where
    finalize acquired trust qualification _debtEvidence contractEvidence subjectResult =
        case Policy.mkPhaseOrdinal phase of
            Nothing ->
                finalizeCandidateRows
                    bootstrapCandidate
                    CheckResult
                        { checkName = "legacy-closure"
                        , checkObservations = []
                        , checkFindings =
                            [ finding
                                "GATE-LEGACY-CLOSURE-PHASE"
                                "<gate-finalization>"
                                "the candidate phase is outside the compiled policy domain"
                            ]
                        }
            Just candidatePhase ->
                let premises = gateCompletionPremisesFromRows (captureRows (acquiredCapture bootstrapCandidate))
                    closure =
                        legacyBootstrapClosureAcquired
                            candidatePhase
                            acquired
                            premises
                    closureCheck =
                        bindLegacyClosureToCandidateSource
                            opening
                            (snapshotIdentity (acquiredSourceSnapshot acquired))
                            closure
                 in finalizeCandidateRows bootstrapCandidate closureCheck
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = case closing of
            Left _ -> ""
            Right observed -> snapshotIdentity (acquiredSourceSnapshot observed)
        contractDigest = checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence)
        bootstrapCandidate =
            foldQualifiedBootstrapProtocol
                (buildCandidate opening closingIdentity contractDigest trust subjectResult)
                qualification
        buildCandidate openingDigest closingDigest compiledContractDigest genesis subject snapshotDigest subjectSourceDigest oracleDigest harnessDigest transcriptDigest compilerPath runLeaf receipts =
            captureCandidateEvidence
                CandidateCapture
                    { candidateCapturePhase = phase
                    , candidateCaptureSourceOpening = openingDigest
                    , candidateCaptureSourceClosing = closingDigest
                    , candidateCaptureContractDigest = Just compiledContractDigest
                    , candidateCaptureSubjectDigest = Just (checkResultDigest subject)
                    , candidateCaptureOracleDigest = Just oracleDigest
                    , candidateCaptureHarnessDigest = Just harnessDigest
                    , candidateCaptureObserverDigest = Just (digestTexts ["bootstrap-observer", oracleDigest, transcriptDigest])
                    , candidateCaptureQualificationDigest = Just transcriptDigest
                    , candidateCaptureProjectionDigest = projectionDigest
                    , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest
                    , candidateCapturePredecessor = GenesisPredecessor (genesisTrustDigest genesis)
                    , candidateCaptureExecutablePath = executablePath
                    , candidateCaptureExecutableDigest = executableDigest
                    , candidateCaptureArgv = argv
                    , candidateCaptureToolchainIdentity = Just (genesisTrustToolchainIdentity genesis)
                    , candidateCaptureSubstrate = Just "none"
                    , candidateCaptureLane = Just "none"
                    , candidateCaptureArchitecture = Just (genesisTrustArchitecture genesis)
                    , candidateCaptureRunIdentity = Just transcriptDigest
                    , candidateCaptureCleanupObservation = Just ("absent=" <> Text.pack runLeaf)
                    , candidateCaptureRows =
                        bootstrapGateRows
                            phase
                            openingDigest
                            closing
                            compiledContractDigest
                            genesis
                            subject
                            snapshotDigest
                            subjectSourceDigest
                            oracleDigest
                            harnessDigest
                            transcriptDigest
                            compilerPath
                            runLeaf
                            receipts
                            projectionDigest
                            projectionPostimageDigest
                            executableDigest
                            argv
                    , candidateCaptureResidue =
                        [ "status projection identity is absent"
                        | projectionDigest == Nothing || projectionPostimageDigest == Nothing
                        ]
                    }
    phase = policyDomainLower

-- | Finalize Phase 1 from its opaque execution authority and the independently
-- reacquired Phase-0 receipt.  Generic candidates cannot reach this path.
captureFinalizedToolchainSpikeCandidateEvidence ::
    AcquiredToolchainSpikeRun ->
    PredecessorEvidence ->
    Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text ->
    Maybe Text ->
    FilePath ->
    Maybe Text ->
    [Text] ->
    AcquiredCandidateEvidence
captureFinalizedToolchainSpikeCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredToolchainSpikeRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        expectedArgv = ["validate", "phase", "01"]
        contractDigest = checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence)
        baseRows =
            [ GateRowEvidence row (rowOutcomeFromCheck "PHASE-01-ROW" result)
            | (row, result) <- zip allGateRows rowChecks
            ]
        commandOutcome
            | Just digest <- executableDigest
            , sha256Text digest
            , argv == expectedArgv =
                RowPassed
                    [ observation "command.executable.sha256" digest
                    , observation "command.argv" (Text.unwords argv)
                    , observation "command.toolchain.sha256" toolchainId
                    ]
            | otherwise =
                RowRefused
                    [observation "command.argv" (Text.unwords argv)]
                    [finding "PHASE-01-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-1 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed
                | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                    RowPassed
                        [ observation "source.snapshot.opening" opening
                        , observation "source.snapshot.closing" closingIdentity
                        , observation "phase-01.run.sha256" runId
                        ]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 0 digest
                | predecessorEvidenceMatchesPhase 1 predecessor ->
                    RowPassed
                        [ observation "predecessor.phase" "00"
                        , observation "predecessor.receipt.sha256" digest
                        , observation "predecessor.projected-source.sha256" opening
                        ]
            _ -> RowRefused [] [finding "PHASE-01-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-0 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing =
                RowPassed [observation "phase-01.residue" "GenesisTrust and OS execution substrate explicit; later capability claims remain owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-01-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows =
            replaceRowOutcome ResidueRow residueOutcome
                (replaceRowOutcome PredecessorRow predecessorOutcome
                    (replaceRowOutcome FreshnessRow freshnessOutcome
                        (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate =
            captureCandidateEvidence
                CandidateCapture
                    { candidateCapturePhase = 1
                    , candidateCaptureSourceOpening = opening
                    , candidateCaptureSourceClosing = closingIdentity
                    , candidateCaptureContractDigest = Just contractDigest
                    , candidateCaptureSubjectDigest = Just subjectId
                    , candidateCaptureOracleDigest = Just oracleId
                    , candidateCaptureHarnessDigest = Just harnessId
                    , candidateCaptureObserverDigest = Just observerId
                    , candidateCaptureQualificationDigest = Just qualificationId
                    , candidateCaptureProjectionDigest = projectionDigest
                    , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest
                    , candidateCapturePredecessor = predecessor
                    , candidateCaptureExecutablePath = executablePath
                    , candidateCaptureExecutableDigest = executableDigest
                    , candidateCaptureArgv = argv
                    , candidateCaptureToolchainIdentity = Just toolchainId
                    , candidateCaptureSubstrate = Just "none"
                    , candidateCaptureLane = Just "none"
                    , candidateCaptureArchitecture = Just "x86_64"
                    , candidateCaptureRunIdentity = Just runId
                    , candidateCaptureCleanupObservation = Just cleanup
                    , candidateCaptureRows = replacedRows
                    , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
                    }
        prerequisiteRows =
            [ evidence
            | evidence <- replacedRows
            , capturedRow evidence /= LegacyClosureRow
            , capturedRow evidence /= PassCriterionRow
            ]
        legacyResult
            | length rowChecks /= length allGateRows =
                CheckResult "phase-01-legacy-closure" [] [finding "PHASE-01-ROW-INVENTORY" "<phase-01-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult =
                CheckResult
                    "phase-01-legacy-closure"
                    [ observation "legacy.phase-01.closed" "LTD-BOOT-001,LTD-SRC-007,LTD-SRC-009"
                    , observation "legacy.phase-01.snapshot" opening
                    ]
                    []
            | otherwise =
                CheckResult "phase-01-legacy-closure" [] [finding "PHASE-01-LEGACY-CLOSURE" "<phase-01-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-1 subject to pass"]

-- | Finalize Phase 2 only from its package-hidden acquired supervisor and the
-- exact durable Phase-1 receipt. The independently compiled oracle has already
-- executed inside the sealed run; this layer binds its eighteen checks to the
-- generic evidence protocol and closing source observation.
captureFinalizedRepositoryLayoutCandidateEvidence ::
    AcquiredRepositoryLayoutRun ->
    PredecessorEvidence ->
    Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text ->
    Maybe Text ->
    FilePath ->
    Maybe Text ->
    [Text] ->
    AcquiredCandidateEvidence
captureFinalizedRepositoryLayoutCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredRepositoryLayoutRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        expectedArgv = ["validate", "phase", "02"]
        contractDigest = checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence)
        baseRows =
            [ GateRowEvidence row (rowOutcomeFromCheck "PHASE-02-ROW" result)
            | (row, result) <- zip allGateRows rowChecks
            ]
        commandOutcome
            | Just digest <- executableDigest
            , sha256Text digest
            , argv == expectedArgv =
                RowPassed
                    [ observation "command.executable.sha256" digest
                    , observation "command.argv" (Text.unwords argv)
                    , observation "command.toolchain.sha256" toolchainId
                    ]
            | otherwise = RowRefused [] [finding "PHASE-02-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-2 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed
                | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                    RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-02.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 1 digest
                | predecessorEvidenceMatchesPhase 2 predecessor ->
                    RowPassed [observation "predecessor.phase" "01", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-02-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-1 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing =
                RowPassed [observation "phase-02.residue" "only typed later-owned source migrations remain; hardware and live effects are unattempted"]
            | otherwise = RowRefused [] [finding "PHASE-02-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows =
            replaceRowOutcome ResidueRow residueOutcome
                (replaceRowOutcome PredecessorRow predecessorOutcome
                    (replaceRowOutcome FreshnessRow freshnessOutcome
                        (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate =
            captureCandidateEvidence
                CandidateCapture
                    { candidateCapturePhase = 2
                    , candidateCaptureSourceOpening = opening
                    , candidateCaptureSourceClosing = closingIdentity
                    , candidateCaptureContractDigest = Just contractDigest
                    , candidateCaptureSubjectDigest = Just subjectId
                    , candidateCaptureOracleDigest = Just oracleId
                    , candidateCaptureHarnessDigest = Just harnessId
                    , candidateCaptureObserverDigest = Just observerId
                    , candidateCaptureQualificationDigest = Just qualificationId
                    , candidateCaptureProjectionDigest = projectionDigest
                    , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest
                    , candidateCapturePredecessor = predecessor
                    , candidateCaptureExecutablePath = executablePath
                    , candidateCaptureExecutableDigest = executableDigest
                    , candidateCaptureArgv = argv
                    , candidateCaptureToolchainIdentity = Just toolchainId
                    , candidateCaptureSubstrate = Just "none"
                    , candidateCaptureLane = Just "none"
                    , candidateCaptureArchitecture = Just "x86_64"
                    , candidateCaptureRunIdentity = Just runId
                    , candidateCaptureCleanupObservation = Just cleanup
                    , candidateCaptureRows = replacedRows
                    , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
                    }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-02-legacy-closure" [] [finding "PHASE-02-ROW-INVENTORY" "<phase-02-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult =
                CheckResult "phase-02-legacy-closure"
                    [ observation "legacy.phase-02.closed" "LTD-SRC-000,LTD-SRC-008,LTD-META-001,LTD-NAME-001"
                    , observation "legacy.phase-02.snapshot" opening
                    ] []
            | otherwise = CheckResult "phase-02-legacy-closure" [] [finding "PHASE-02-LEGACY-CLOSURE" "<phase-02-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-2 subject to pass"]

-- | Finalize Phase 3 from the opaque serial compiler/mutant supervisor and
-- the exact durable Phase-2 receipt.
captureFinalizedArtifactCalculusCandidateEvidence ::
    AcquiredArtifactCalculusRun ->
    PredecessorEvidence ->
    Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text ->
    Maybe Text ->
    FilePath ->
    Maybe Text ->
    [Text] ->
    AcquiredCandidateEvidence
captureFinalizedArtifactCalculusCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredArtifactCalculusRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        expectedArgv = ["validate", "phase", "03"]
        contractDigest = checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence)
        baseRows =
            [ GateRowEvidence row (rowOutcomeFromCheck "PHASE-03-ROW" result)
            | (row, result) <- zip allGateRows rowChecks
            ]
        commandOutcome
            | Just digest <- executableDigest
            , sha256Text digest
            , argv == expectedArgv =
                RowPassed
                    [ observation "command.executable.sha256" digest
                    , observation "command.argv" (Text.unwords argv)
                    , observation "command.toolchain.sha256" toolchainId
                    ]
            | otherwise = RowRefused [] [finding "PHASE-03-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-3 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed
                | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                    RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-03.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 2 digest
                | predecessorEvidenceMatchesPhase 3 predecessor ->
                    RowPassed [observation "predecessor.phase" "02", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-03-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-2 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing =
                RowPassed [observation "phase-03.residue" "later calculi, effects, runtimes, hardware, and live claims remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-03-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows =
            replaceRowOutcome ResidueRow residueOutcome
                (replaceRowOutcome PredecessorRow predecessorOutcome
                    (replaceRowOutcome FreshnessRow freshnessOutcome
                        (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate =
            captureCandidateEvidence
                CandidateCapture
                    { candidateCapturePhase = 3
                    , candidateCaptureSourceOpening = opening
                    , candidateCaptureSourceClosing = closingIdentity
                    , candidateCaptureContractDigest = Just contractDigest
                    , candidateCaptureSubjectDigest = Just subjectId
                    , candidateCaptureOracleDigest = Just oracleId
                    , candidateCaptureHarnessDigest = Just harnessId
                    , candidateCaptureObserverDigest = Just observerId
                    , candidateCaptureQualificationDigest = Just qualificationId
                    , candidateCaptureProjectionDigest = projectionDigest
                    , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest
                    , candidateCapturePredecessor = predecessor
                    , candidateCaptureExecutablePath = executablePath
                    , candidateCaptureExecutableDigest = executableDigest
                    , candidateCaptureArgv = argv
                    , candidateCaptureToolchainIdentity = Just toolchainId
                    , candidateCaptureSubstrate = Just "none"
                    , candidateCaptureLane = Just "none"
                    , candidateCaptureArchitecture = Just "x86_64"
                    , candidateCaptureRunIdentity = Just runId
                    , candidateCaptureCleanupObservation = Just cleanup
                    , candidateCaptureRows = replacedRows
                    , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
                    }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-03-legacy-closure" [] [finding "PHASE-03-ROW-INVENTORY" "<phase-03-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult =
                CheckResult "phase-03-legacy-closure"
                    [ observation "legacy.phase-03.closed" "none-owned"
                    , observation "legacy.phase-03.snapshot" opening
                    ] []
            | otherwise = CheckResult "phase-03-legacy-closure" [] [finding "PHASE-03-LEGACY-CLOSURE" "<phase-03-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-3 subject to pass"]

captureFinalizedBudgetCalculusCandidateEvidence ::
    AcquiredBudgetCalculusRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedBudgetCalculusCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredBudgetCalculusRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-04-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "04"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-04-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-4 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-04.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 3 digest | predecessorEvidenceMatchesPhase 4 predecessor ->
                RowPassed [observation "predecessor.phase" "03", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-04-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-3 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-04.residue" "composition, live free-space, effects, runtimes, and hardware remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-04-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 4, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-04-legacy-closure" [] [finding "PHASE-04-ROW-INVENTORY" "<phase-04-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult = CheckResult "phase-04-legacy-closure" [observation "legacy.phase-04.closed" "none-owned", observation "legacy.phase-04.snapshot" opening] []
            | otherwise = CheckResult "phase-04-legacy-closure" [] [finding "PHASE-04-LEGACY-CLOSURE" "<phase-04-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-4 subject to pass"]

captureFinalizedLiftCalculusCandidateEvidence ::
    AcquiredLiftCalculusRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedLiftCalculusCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredLiftCalculusRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-05-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "05"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-05-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-5 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-05.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 4 digest | predecessorEvidenceMatchesPhase 5 predecessor ->
                RowPassed [observation "predecessor.phase" "04", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-05-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-4 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-05.residue" "workflow obligations, composition integration, effects, runtimes, and hardware remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-05-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 5, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-05-legacy-closure" [] [finding "PHASE-05-ROW-INVENTORY" "<phase-05-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult = CheckResult "phase-05-legacy-closure" [observation "legacy.phase-05.closed" "none-owned", observation "legacy.phase-05.snapshot" opening] []
            | otherwise = CheckResult "phase-05-legacy-closure" [] [finding "PHASE-05-LEGACY-CLOSURE" "<phase-05-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-5 subject to pass"]

captureFinalizedWorkflowCalculusCandidateEvidence ::
    AcquiredWorkflowCalculusRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedWorkflowCalculusCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredWorkflowCalculusRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-06-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "06"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-06-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-6 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-06.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 5 digest | predecessorEvidenceMatchesPhase 6 predecessor ->
                RowPassed [observation "predecessor.phase" "05", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-06-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-5 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-06.residue" "evidence binding, calculus composition, live effects, runtimes, and hardware remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-06-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 6, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-06-legacy-closure" [] [finding "PHASE-06-ROW-INVENTORY" "<phase-06-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult = CheckResult "phase-06-legacy-closure" [observation "legacy.phase-06.closed" "none-owned", observation "legacy.phase-06.snapshot" opening] []
            | otherwise = CheckResult "phase-06-legacy-closure" [] [finding "PHASE-06-LEGACY-CLOSURE" "<phase-06-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-6 subject to pass"]

captureFinalizedEvidenceCalculusCandidateEvidence ::
    AcquiredEvidenceCalculusRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedEvidenceCalculusCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredEvidenceCalculusRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-07-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "07"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-07-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-7 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-07.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 6 digest | predecessorEvidenceMatchesPhase 7 predecessor ->
                RowPassed [observation "predecessor.phase" "06", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-07-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-6 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-07.residue" "oracle correctness, finite-sampling limits, calculus composition, effects, runtimes, and hardware remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-07-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 7, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-07-legacy-closure" [] [finding "PHASE-07-ROW-INVENTORY" "<phase-07-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult = CheckResult "phase-07-legacy-closure" [observation "legacy.phase-07.closed" "none-owned", observation "legacy.phase-07.snapshot" opening] []
            | otherwise = CheckResult "phase-07-legacy-closure" [] [finding "PHASE-07-LEGACY-CLOSURE" "<phase-07-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-7 subject to pass"]

captureFinalizedScopeIndexCandidateEvidence ::
    AcquiredScopeIndexRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedScopeIndexCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredScopeIndexRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-08-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "08"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-08-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-8 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-08.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 7 digest | predecessorEvidenceMatchesPhase 8 predecessor ->
                RowPassed [observation "predecessor.phase" "07", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-08-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-7 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-08.residue" "persisted-value re-entry, resource indexing, composition, effects, runtimes, and hardware remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-08-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 8, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-08-legacy-closure" [] [finding "PHASE-08-ROW-INVENTORY" "<phase-08-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult = CheckResult "phase-08-legacy-closure" [observation "legacy.phase-08.closed" "none-owned", observation "legacy.phase-08.snapshot" opening] []
            | otherwise = CheckResult "phase-08-legacy-closure" [] [finding "PHASE-08-LEGACY-CLOSURE" "<phase-08-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-8 subject to pass"]

captureFinalizedResourceIndexCandidateEvidence ::
    AcquiredResourceIndexRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedResourceIndexCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredResourceIndexRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-09-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "09"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-09-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-9 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-09.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 8 digest | predecessorEvidenceMatchesPhase 9 predecessor ->
                RowPassed [observation "predecessor.phase" "08", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-09-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-8 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-09.residue" "composition, decode, binding, rendering, effects, runtimes, hardware, and cleanup remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-09-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 9, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-09-legacy-closure" [] [finding "PHASE-09-ROW-INVENTORY" "<phase-09-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult = CheckResult "phase-09-legacy-closure" [observation "legacy.phase-09.closed" "none-owned", observation "legacy.phase-09.snapshot" opening] []
            | otherwise = CheckResult "phase-09-legacy-closure" [] [finding "PHASE-09-LEGACY-CLOSURE" "<phase-09-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-9 subject to pass"]

captureFinalizedCalculusCompositionCandidateEvidence ::
    AcquiredCalculusCompositionRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedCalculusCompositionCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredCalculusCompositionRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-10-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "10"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-10-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-10 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-10.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 9 digest | predecessorEvidenceMatchesPhase 10 predecessor ->
                RowPassed [observation "predecessor.phase" "09", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-10-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-9 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-10.residue" "formal models, extension declarations and laws, decode, effects, runtimes, hardware, and cleanup remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-10-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 10, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-10-legacy-closure" [] [finding "PHASE-10-ROW-INVENTORY" "<phase-10-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult = CheckResult "phase-10-legacy-closure" [observation "legacy.phase-10.closed" "none-owned", observation "legacy.phase-10.snapshot" opening] []
            | otherwise = CheckResult "phase-10-legacy-closure" [] [finding "PHASE-10-LEGACY-CLOSURE" "<phase-10-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-10 subject to pass"]

captureFinalizedFormalModelKernelCandidateEvidence ::
    AcquiredFormalModelKernelRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedFormalModelKernelCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredFormalModelKernelRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-11-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "11"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-11-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-11 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-11.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 10 digest | predecessorEvidenceMatchesPhase 11 predecessor ->
                RowPassed [observation "predecessor.phase" "10", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-11-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-10 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-11.residue" "checker algorithms, concrete protocol models, runtime fidelity, live effects, and hardware remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-11-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 11, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-11-legacy-closure" [] [finding "PHASE-11-ROW-INVENTORY" "<phase-11-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult = CheckResult "phase-11-legacy-closure" [observation "legacy.phase-11.closed" "retired serialized oracles, mutant descriptors, and Python gate absent", observation "legacy.phase-11.snapshot" opening] []
            | otherwise = CheckResult "phase-11-legacy-closure" [] [finding "PHASE-11-LEGACY-CLOSURE" "<phase-11-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-11 subject to pass"]

captureFinalizedExplicitStateCheckerCandidateEvidence ::
    AcquiredExplicitStateCheckerRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedExplicitStateCheckerCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredExplicitStateCheckerRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-12-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "12"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-12-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-12 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-12.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 11 digest | predecessorEvidenceMatchesPhase 12 predecessor ->
                RowPassed [observation "predecessor.phase" "11", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-12-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-11 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-12.residue" "symbolic and refinement checking, reusable compile-fail machinery, simulation, concrete models, runtimes, and hardware remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-12-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 12, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-12-legacy-closure" [] [finding "PHASE-12-ROW-INVENTORY" "<phase-12-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult = CheckResult "phase-12-legacy-closure" [observation "legacy.phase-12.closed" "retired serialized oracles and Python gate absent", observation "legacy.phase-12.snapshot" opening] []
            | otherwise = CheckResult "phase-12-legacy-closure" [] [finding "PHASE-12-LEGACY-CLOSURE" "<phase-12-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-12 subject to pass"]

captureFinalizedSymbolicCheckerCandidateEvidence ::
    AcquiredSymbolicCheckerRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedSymbolicCheckerCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredSymbolicCheckerRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-13-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "13"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-13-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-13 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-13.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 12 digest | predecessorEvidenceMatchesPhase 13 predecessor ->
                RowPassed [observation "predecessor.phase" "12", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-13-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-12 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-13.residue" "refinement, reusable compile-fail machinery, simulation, concrete models, runtimes, and hardware remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-13-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 13, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-13-legacy-closure" [] [finding "PHASE-13-ROW-INVENTORY" "<phase-13-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows && checkPassed subjectResult = CheckResult "phase-13-legacy-closure" [observation "legacy.phase-13.closed" "retired serialized oracles and Python gate absent", observation "legacy.phase-13.snapshot" opening] []
            | otherwise = CheckResult "phase-13-legacy-closure" [] [finding "PHASE-13-LEGACY-CLOSURE" "<phase-13-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-13 subject to pass"]

captureFinalizedRefinementCheckerCandidateEvidence ::
    AcquiredRefinementCheckerRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedRefinementCheckerCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredRefinementCheckerRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-14-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "14"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-14-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-14 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-14.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 13 digest | predecessorEvidenceMatchesPhase 14 predecessor ->
                RowPassed [observation "predecessor.phase" "13", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-14-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-13 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-14.residue" "reusable compile-fail machinery, simulation, concrete models, runtimes, and hardware remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-14-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 14, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-14-legacy-closure" [] [finding "PHASE-14-ROW-INVENTORY" "<phase-14-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-14-legacy-closure" [observation "legacy.phase-14.closed" "retired serialized oracles and Python checker/gate absent", observation "legacy.phase-14.snapshot" opening] []
            | otherwise = CheckResult "phase-14-legacy-closure" [] [finding "PHASE-14-LEGACY-CLOSURE" "<phase-14-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-14 subject to pass"]

captureFinalizedCompileFailHarnessCandidateEvidence ::
    AcquiredCompileFailHarnessRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedCompileFailHarnessCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredCompileFailHarnessRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-15-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "15"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-15-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-15 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-15.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 14 digest | predecessorEvidenceMatchesPhase 15 predecessor ->
                RowPassed [observation "predecessor.phase" "14", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-15-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-14 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-15.residue" "deterministic simulation, concrete models, runtimes, and hardware remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-15-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 15, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-15-legacy-closure" [] [finding "PHASE-15-ROW-INVENTORY" "<phase-15-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-15-legacy-closure" [observation "legacy.phase-15.closed" "retired serialized manifest/surfaces and Python harness/gate absent", observation "legacy.phase-15.snapshot" opening] []
            | otherwise = CheckResult "phase-15-legacy-closure" [] [finding "PHASE-15-LEGACY-CLOSURE" "<phase-15-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-15 subject to pass"]

captureFinalizedDeterministicSimulationCandidateEvidence ::
    AcquiredDeterministicSimulationRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedDeterministicSimulationCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredDeterministicSimulationRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-16-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "16"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-16-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-16 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-16.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 15 digest | predecessorEvidenceMatchesPhase 16 predecessor ->
                RowPassed [observation "predecessor.phase" "15", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-16-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-15 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-16.residue" "model fidelity remains ASSUMED; concrete models, runtimes, host, hardware, and live substrate remain explicitly owner-scoped"]
            | otherwise = RowRefused [] [finding "PHASE-16-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 16, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-16-legacy-closure" [] [finding "PHASE-16-ROW-INVENTORY" "<phase-16-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-16-legacy-closure" [observation "legacy.phase-16.closed" "retired JSON/TSV oracles, Python gate, and materialized mutant absent", observation "legacy.phase-16.snapshot" opening] []
            | otherwise = CheckResult "phase-16-legacy-closure" [] [finding "PHASE-16-LEGACY-CLOSURE" "<phase-16-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-16 subject to pass"]

captureFinalizedGatewayMigrationModelCandidateEvidence ::
    AcquiredGatewayMigrationModelRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedGatewayMigrationModelCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredGatewayMigrationModelRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-17-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "17"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-17-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-17 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-17.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 16 digest | predecessorEvidenceMatchesPhase 17 predecessor ->
                RowPassed [observation "predecessor.phase" "16", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-17-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-16 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-17.residue" "runtime fidelity remains UNVERIFIED; decomposition lemma remains OPEN; live gateway effects remain Phase-75-owned"]
            | otherwise = RowRefused [] [finding "PHASE-17-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 17, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-17-legacy-closure" [] [finding "PHASE-17-ROW-INVENTORY" "<phase-17-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-17-legacy-closure" [observation "legacy.phase-17.closed" "retired serialized gateway oracles and Python gate absent", observation "legacy.phase-17.snapshot" opening] []
            | otherwise = CheckResult "phase-17-legacy-closure" [] [finding "PHASE-17-LEGACY-CLOSURE" "<phase-17-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-17 subject to pass"]

captureFinalizedDslFormalModelCandidateEvidence ::
    AcquiredDslFormalModelRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedDslFormalModelCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredDslFormalModelRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-18-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "18"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-18-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-18 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-18.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 17 digest | predecessorEvidenceMatchesPhase 18 predecessor ->
                RowPassed [observation "predecessor.phase" "17", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-18-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-17 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-18.residue" "runtime and effectful correspondence remain UNVERIFIED; decoder/render/chain projections remain later-phase-owned"]
            | otherwise = RowRefused [] [finding "PHASE-18-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 18, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-18-legacy-closure" [] [finding "PHASE-18-ROW-INVENTORY" "<phase-18-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-18-legacy-closure" [observation "legacy.phase-18.closed" "retired serialized DSL-formal oracles and Python gate absent", observation "legacy.phase-18.snapshot" opening] []
            | otherwise = CheckResult "phase-18-legacy-closure" [] [finding "PHASE-18-LEGACY-CLOSURE" "<phase-18-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-18 subject to pass"]

captureFinalizedReconcileCoreCandidateEvidence ::
    AcquiredReconcileCoreRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedReconcileCoreCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredReconcileCoreRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-19-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "19"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-19-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-19 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-19.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 18 digest | predecessorEvidenceMatchesPhase 19 predecessor ->
                RowPassed [observation "predecessor.phase" "18", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-19-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-18 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-19.residue" "modeled environment fidelity is ASSUMED; effectful runtime, host, service, cluster, and hardware correspondence remain UNVERIFIED"]
            | otherwise = RowRefused [] [finding "PHASE-19-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 19, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-19-legacy-closure" [] [finding "PHASE-19-ROW-INVENTORY" "<phase-19-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-19-legacy-closure" [observation "legacy.phase-19.closed" "retired serialized reconcile oracles and test-local mutant absent", observation "legacy.phase-19.snapshot" opening] []
            | otherwise = CheckResult "phase-19-legacy-closure" [] [finding "PHASE-19-LEGACY-CLOSURE" "<phase-19-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-19 subject to pass"]

captureFinalizedExtensionDeclarationCandidateEvidence ::
    AcquiredExtensionDeclarationRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedExtensionDeclarationCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredExtensionDeclarationRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-20-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "20"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-20-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-20 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-20.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 19 digest | predecessorEvidenceMatchesPhase 20 predecessor ->
                RowPassed [observation "predecessor.phase" "19", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-20-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-19 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-20.residue" "extension laws, conformance verdicts, decode, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-20-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 20, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-20-legacy-closure" [] [finding "PHASE-20-ROW-INVENTORY" "<phase-20-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-20-legacy-closure" [observation "legacy.phase-20.closed" "retired Python gate, serialized declaration oracles, and test-local mutant absent", observation "legacy.phase-20.snapshot" opening] []
            | otherwise = CheckResult "phase-20-legacy-closure" [] [finding "PHASE-20-LEGACY-CLOSURE" "<phase-20-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-20 subject to pass"]

captureFinalizedExtensionLawsCandidateEvidence ::
    AcquiredExtensionLawsRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedExtensionLawsCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredExtensionLawsRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-21-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "21"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-21-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-21 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-21.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 20 digest | predecessorEvidenceMatchesPhase 21 predecessor ->
                RowPassed [observation "predecessor.phase" "20", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-21-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-20 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-21.residue" "compositional and security laws, conformance verdicts, decode, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-21-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 21, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-21-legacy-closure" [] [finding "PHASE-21-ROW-INVENTORY" "<phase-21-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-21-legacy-closure" [observation "legacy.phase-21.closed" "retired Python gate, serialized extension-law oracles, and test-local mutant absent", observation "legacy.phase-21.snapshot" opening] []
            | otherwise = CheckResult "phase-21-legacy-closure" [] [finding "PHASE-21-LEGACY-CLOSURE" "<phase-21-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-21 subject to pass"]

captureFinalizedExtensionCompositionCandidateEvidence ::
    AcquiredExtensionCompositionRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedExtensionCompositionCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredExtensionCompositionRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-22-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "22"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-22-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-22 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-22.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 21 digest | predecessorEvidenceMatchesPhase 22 predecessor ->
                RowPassed [observation "predecessor.phase" "21", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-22-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-21 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-22.residue" "security laws, generated conformance verdicts, universal closure proofs, decode, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-22-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 22, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-22-legacy-closure" [] [finding "PHASE-22-ROW-INVENTORY" "<phase-22-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-22-legacy-closure" [observation "legacy.phase-22.closed" "retired Python gate, serialized composition-law oracles, and test-local mutant absent", observation "legacy.phase-22.snapshot" opening] []
            | otherwise = CheckResult "phase-22-legacy-closure" [] [finding "PHASE-22-LEGACY-CLOSURE" "<phase-22-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-22 subject to pass"]



captureFinalizedExtensionSecurityCandidateEvidence ::
    AcquiredExtensionSecurityRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedExtensionSecurityCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredExtensionSecurityRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-23-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "23"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-23-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-23 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-23.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 22 digest | predecessorEvidenceMatchesPhase 23 predecessor ->
                RowPassed [observation "predecessor.phase" "22", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-23-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-22 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-23.residue" "production cryptography, wall-clock timing, persisted-value re-entry, compositional security closure, generated conformance verdicts, decode, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-23-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 23, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-23-legacy-closure" [] [finding "PHASE-23-ROW-INVENTORY" "<phase-23-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-23-legacy-closure" [observation "legacy.phase-23.closed" "retired Python gate, serialized security-law oracles, and test-local mutant absent", observation "legacy.phase-23.snapshot" opening] []
            | otherwise = CheckResult "phase-23-legacy-closure" [] [finding "PHASE-23-LEGACY-CLOSURE" "<phase-23-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-23 subject to pass"]




captureFinalizedConformanceGateCandidateEvidence ::
    AcquiredConformanceGateRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedConformanceGateCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredConformanceGateRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-24-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "24"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-24-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-24 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-24.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 23 digest | predecessorEvidenceMatchesPhase 24 predecessor ->
                RowPassed [observation "predecessor.phase" "23", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-24-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-23 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-24.residue" "transaction instances, observer authenticity, executable semantic harness generation, universal closure, collision absence, decode, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-24-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 24, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-24-legacy-closure" [] [finding "PHASE-24-ROW-INVENTORY" "<phase-24-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-24-legacy-closure" [observation "legacy.phase-24.closed" "retired Python gate, serialized conformance authorities, and test-local mutant absent", observation "legacy.phase-24.snapshot" opening] []
            | otherwise = CheckResult "phase-24-legacy-closure" [] [finding "PHASE-24-LEGACY-CLOSURE" "<phase-24-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-24 subject to pass"]





captureFinalizedDhallSchemaCandidateEvidence ::
    AcquiredDhallSchemaRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedDhallSchemaCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredDhallSchemaRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-25-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "25"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-25-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-25 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-25.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 24 digest | predecessorEvidenceMatchesPhase 25 predecessor ->
                RowPassed [observation "predecessor.phase" "24", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-25-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-24 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-25.residue" "binding, indexed decode, whole-deployment feasibility, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-25-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 25, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-25-legacy-closure" [] [finding "PHASE-25-ROW-INVENTORY" "<phase-25-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-25-legacy-closure" [observation "legacy.phase-25.closed" "LTD-SRC-002 and retired Python/serialized Dhall authorities absent", observation "legacy.phase-25.snapshot" opening] []
            | otherwise = CheckResult "phase-25-legacy-closure" [] [finding "PHASE-25-LEGACY-CLOSURE" "<phase-25-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-25 subject to pass"]

captureFinalizedGadtDecodeCandidateEvidence ::
    AcquiredGadtDecodeRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedGadtDecodeCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredGadtDecodeRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-26-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "26"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-26-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-26 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-26.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 25 digest | predecessorEvidenceMatchesPhase 26 predecessor ->
                RowPassed [observation "predecessor.phase" "25", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-26-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-25 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-26.residue" "capacity feasibility, binding, provisioning, rendering, effects, runtimes, host, service, cluster, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-26-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 26, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-26-legacy-closure" [] [finding "PHASE-26-ROW-INVENTORY" "<phase-26-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-26-legacy-closure" [observation "legacy.phase-26.closed" "LTD-SRC-003 and retired Python/serialized Proto authorities absent", observation "legacy.phase-26.snapshot" opening] []
            | otherwise = CheckResult "phase-26-legacy-closure" [] [finding "PHASE-26-LEGACY-CLOSURE" "<phase-26-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-26 subject to pass"]

captureFinalizedIllegalStateCoveringCandidateEvidence ::
    AcquiredIllegalStateCoveringRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedIllegalStateCoveringCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredIllegalStateCoveringRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-27-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "27"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-27-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-27 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-27.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 26 digest | predecessorEvidenceMatchesPhase 27 predecessor ->
                RowPassed [observation "predecessor.phase" "26", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-27-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-26 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-27.residue" "provision folds, rendering, effects, runtimes, host, service, cluster, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-27-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 27, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-27-legacy-closure" [] [finding "PHASE-27-ROW-INVENTORY" "<phase-27-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-27-legacy-closure" [observation "legacy.phase-27.closed" "LTD-DOC-001 and retired Markdown/serialized covering authorities absent", observation "legacy.phase-27.snapshot" opening] []
            | otherwise = CheckResult "phase-27-legacy-closure" [] [finding "PHASE-27-LEGACY-CLOSURE" "<phase-27-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-27 subject to pass"]

captureFinalizedStorageGeometryCandidateEvidence ::
    AcquiredStorageGeometryRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedStorageGeometryCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredStorageGeometryRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-28-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "28"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-28-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-28 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-28.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 27 digest | predecessorEvidenceMatchesPhase 28 predecessor ->
                RowPassed [observation "predecessor.phase" "27", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-28-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-27 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-28.residue" "binding, whole-deployment provisioning, rendering, effects, runtime storage, live scaling, host, service, cluster, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-28-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 28, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-28-legacy-closure" [] [finding "PHASE-28-ROW-INVENTORY" "<phase-28-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-28-legacy-closure" [observation "legacy.phase-28.closed" "retired Python/serialized storage-geometry authorities absent", observation "legacy.phase-28.snapshot" opening] []
            | otherwise = CheckResult "phase-28-legacy-closure" [] [finding "PHASE-28-LEGACY-CLOSURE" "<phase-28-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-28 subject to pass"]

captureFinalizedExecutionAcceleratorCandidateEvidence ::
    AcquiredExecutionAcceleratorRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedExecutionAcceleratorCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredExecutionAcceleratorRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-29-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "29"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-29-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-29 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-29.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 28 digest | predecessorEvidenceMatchesPhase 29 predecessor ->
                RowPassed [observation "predecessor.phase" "28", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-29-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-28 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-29.residue" "binding, provision seal, rendering, effects, runtime fidelity, live scaling, host, service, cluster, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-29-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 29, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-29-legacy-closure" [] [finding "PHASE-29-ROW-INVENTORY" "<phase-29-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-29-legacy-closure" [observation "legacy.phase-29.closed" "retired Python/serialized/test-local-mutant execution-accelerator authorities absent", observation "legacy.phase-29.snapshot" opening] []
            | otherwise = CheckResult "phase-29-legacy-closure" [] [finding "PHASE-29-LEGACY-CLOSURE" "<phase-29-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-29 subject to pass"]

captureFinalizedCapabilityBindCandidateEvidence ::
    AcquiredCapabilityBindRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedCapabilityBindCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredCapabilityBindRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-30-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "30"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-30-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-30 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-30.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 29 digest | predecessorEvidenceMatchesPhase 30 predecessor ->
                RowPassed [observation "predecessor.phase" "29", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-30-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-29 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-30.residue" "provision seal, availability relation, rendering, effects, runtime fidelity, live services, cluster, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-30-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 30, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-30-legacy-closure" [] [finding "PHASE-30-ROW-INVENTORY" "<phase-30-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-30-legacy-closure" [observation "legacy.phase-30.closed" "retired Python/serialized/test-local-mutant capability-bind authorities absent", observation "legacy.phase-30.snapshot" opening] []
            | otherwise = CheckResult "phase-30-legacy-closure" [] [finding "PHASE-30-LEGACY-CLOSURE" "<phase-30-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-30 subject to pass"]

captureFinalizedProvisionSealCandidateEvidence ::
    AcquiredProvisionSealRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedProvisionSealCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredProvisionSealRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-31-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "31"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-31-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-31 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-31.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 30 digest | predecessorEvidenceMatchesPhase 31 predecessor ->
                RowPassed [observation "predecessor.phase" "30", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-31-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-30 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-31.residue" "availability relation, rendering, effects, runtime fidelity, live services, cluster, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-31-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 31, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-31-legacy-closure" [] [finding "PHASE-31-ROW-INVENTORY" "<phase-31-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-31-legacy-closure" [observation "legacy.phase-31.closed" "retired Python/serialized/test-local-mutant provision-seal authorities absent", observation "legacy.phase-31.snapshot" opening] []
            | otherwise = CheckResult "phase-31-legacy-closure" [] [finding "PHASE-31-LEGACY-CLOSURE" "<phase-31-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-31 subject to pass"]


captureFinalizedInferenceAcceleratorCandidateEvidence ::
    AcquiredInferenceAcceleratorRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedInferenceAcceleratorCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredInferenceAcceleratorRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-32-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "32"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-32-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-32 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-32.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 31 digest | predecessorEvidenceMatchesPhase 32 predecessor ->
                RowPassed [observation "predecessor.phase" "31", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-32-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-31 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-32.residue" "rendering, effects, runtime fidelity, live engine observation, host, service, cluster, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-32-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 32, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-32-legacy-closure" [] [finding "PHASE-32-ROW-INVENTORY" "<phase-32-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-32-legacy-closure" [observation "legacy.phase-32.closed" "retired Python/serialized/test-local-mutant inference-accelerator authorities absent", observation "legacy.phase-32.snapshot" opening] []
            | otherwise = CheckResult "phase-32-legacy-closure" [] [finding "PHASE-32-LEGACY-CLOSURE" "<phase-32-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-32 subject to pass"]



captureFinalizedRenderManifestCandidateEvidence ::
    AcquiredRenderManifestRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedRenderManifestCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredRenderManifestRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-33-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "33"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-33-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-33 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-33.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 32 digest | predecessorEvidenceMatchesPhase 33 predecessor ->
                RowPassed [observation "predecessor.phase" "32", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-33-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-32 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-33.residue" "typed actions, dry-run planning, runtime fidelity, live apiserver enforcement, cluster, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-33-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 33, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-33-legacy-closure" [] [finding "PHASE-33-ROW-INVENTORY" "<phase-33-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-33-legacy-closure" [observation "legacy.phase-33.closed" "retired Python/serialized/test-local-mutant render-manifest authorities absent", observation "legacy.phase-33.snapshot" opening] []
            | otherwise = CheckResult "phase-33-legacy-closure" [] [finding "PHASE-33-LEGACY-CLOSURE" "<phase-33-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-33 subject to pass"]


captureFinalizedChainBoundaryCandidateEvidence ::
    AcquiredChainBoundaryRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedChainBoundaryCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredChainBoundaryRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-34-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "34"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-34-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-34 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-34.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 33 digest | predecessorEvidenceMatchesPhase 34 predecessor ->
                RowPassed [observation "predecessor.phase" "33", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-34-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-33 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-34.residue" "live interpreter, runtime fidelity, live services, cluster admission, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-34-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 34, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-34-legacy-closure" [] [finding "PHASE-34-ROW-INVENTORY" "<phase-34-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-34-legacy-closure" [observation "legacy.phase-34.closed" "retired Python/shell/serialized/test-local-mutant chain-boundary authorities absent", observation "legacy.phase-34.snapshot" opening] []
            | otherwise = CheckResult "phase-34-legacy-closure" [] [finding "PHASE-34-LEGACY-CLOSURE" "<phase-34-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-34 subject to pass"]


captureFinalizedImageRecipeCandidateEvidence ::
    AcquiredImageRecipeRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedImageRecipeCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredImageRecipeRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-35-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "35"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-35-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-35 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-35.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 34 digest | predecessorEvidenceMatchesPhase 35 predecessor ->
                RowPassed [observation "predecessor.phase" "34", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-35-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-34 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-35.residue" "base resolution, engine execution, image build, registry publication, runtime probes, cluster behavior, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-35-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 35, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-35-legacy-closure" [] [finding "PHASE-35-ROW-INVENTORY" "<phase-35-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-35-legacy-closure" [observation "legacy.phase-35.closed" "retired Dhall/Python/serialized/test-local-mutant image-recipe authorities absent", observation "legacy.phase-35.snapshot" opening] []
            | otherwise = CheckResult "phase-35-legacy-closure" [] [finding "PHASE-35-LEGACY-CLOSURE" "<phase-35-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-35 subject to pass"]

captureFinalizedTransactionVocabularyCandidateEvidence ::
    AcquiredTransactionVocabularyRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedTransactionVocabularyCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredTransactionVocabularyRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-36-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "36"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-36-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-36 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-36.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 35 digest | predecessorEvidenceMatchesPhase 36 predecessor ->
                RowPassed [observation "predecessor.phase" "35", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-36-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-35 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-36.residue" "live database connections, executor roles, row-policy enforcement, destructive retention lifecycle, runtime services, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-36-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 36, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-36-legacy-closure" [] [finding "PHASE-36-ROW-INVENTORY" "<phase-36-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-36-legacy-closure" [observation "legacy.phase-36.closed" "retired Python/serialized/materialized-mutant transaction-vocabulary authorities absent", observation "legacy.phase-36.snapshot" opening] []
            | otherwise = CheckResult "phase-36-legacy-closure" [] [finding "PHASE-36-LEGACY-CLOSURE" "<phase-36-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-36 subject to pass"]

captureFinalizedUiProgramSchemaCandidateEvidence ::
    AcquiredUiProgramSchemaRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedUiProgramSchemaCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredUiProgramSchemaRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-37-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "37"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-37-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-37 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-37.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 36 digest | predecessorEvidenceMatchesPhase 37 predecessor ->
                RowPassed [observation "predecessor.phase" "36", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-37-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-36 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-37.residue" "authorization, handler binding, client/server planning, browser interpretation, runtime services, provider enforcement, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-37-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 37, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-37-legacy-closure" [] [finding "PHASE-37-ROW-INVENTORY" "<phase-37-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-37-legacy-closure" [observation "legacy.phase-37.closed" "retired Python/serialized/materialized-mutant UI-program-schema authorities absent", observation "legacy.phase-37.snapshot" opening] []
            | otherwise = CheckResult "phase-37-legacy-closure" [] [finding "PHASE-37-LEGACY-CLOSURE" "<phase-37-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-37 subject to pass"]

captureFinalizedUiAuthorizationCandidateEvidence ::
    AcquiredUiAuthorizationRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedUiAuthorizationCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredUiAuthorizationRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult =
        finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-38-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "38"] =
                RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-38-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-38 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening ->
                RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-38.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 37 digest | predecessorEvidenceMatchesPhase 38 predecessor ->
                RowPassed [observation "predecessor.phase" "37", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-38-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-37 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-38.residue" "handler binding, client/server planning, browser interpretation, live identity truth, runtime/provider enforcement, tenant-isolation observation, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-38-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 38, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-38-legacy-closure" [] [finding "PHASE-38-ROW-INVENTORY" "<phase-38-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-38-legacy-closure" [observation "legacy.phase-38.closed" "retired Python/serialized/materialized-mutant UI-authorization authorities absent", observation "legacy.phase-38.snapshot" opening] []
            | otherwise = CheckResult "phase-38-legacy-closure" [] [finding "PHASE-38-LEGACY-CLOSURE" "<phase-38-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-38 subject to pass"]

captureFinalizedUiEffectBindingCandidateEvidence ::
    AcquiredUiEffectBindingRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedUiEffectBindingCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredUiEffectBindingRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult = finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-39-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "39"] = RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-39-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-39 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening -> RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-39.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 38 digest | predecessorEvidenceMatchesPhase 39 predecessor -> RowPassed [observation "predecessor.phase" "38", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-39-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-38 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-39.residue" "plan compilation, handler execution, browser interpretation, live provider enforcement, tenant-isolation observation, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-39-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 39, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-39-legacy-closure" [] [finding "PHASE-39-ROW-INVENTORY" "<phase-39-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-39-legacy-closure" [observation "legacy.phase-39.closed" "retired Python/serialized/materialized-mutant UI-effect-binding authorities absent", observation "legacy.phase-39.snapshot" opening] []
            | otherwise = CheckResult "phase-39-legacy-closure" [] [finding "PHASE-39-LEGACY-CLOSURE" "<phase-39-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-39 subject to pass"]


captureFinalizedUiPlanCompilerCandidateEvidence ::
    AcquiredUiPlanCompilerRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedUiPlanCompilerCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredUiPlanCompilerRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult = finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-40-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "40"] = RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-40-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-40 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening -> RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-40.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 39 digest | predecessorEvidenceMatchesPhase 40 predecessor -> RowPassed [observation "predecessor.phase" "39", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-40-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-39 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-40.residue" "browser and server interpretation, offline pairing, publication, live authority enforcement, tenant-isolation observation, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-40-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 40, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-40-legacy-closure" [] [finding "PHASE-40-ROW-INVENTORY" "<phase-40-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-40-legacy-closure" [observation "legacy.phase-40.closed" "retired Python/serialized/materialized-mutant UI-plan-compiler authorities absent", observation "legacy.phase-40.snapshot" opening] []
            | otherwise = CheckResult "phase-40-legacy-closure" [] [finding "PHASE-40-LEGACY-CLOSURE" "<phase-40-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-40 subject to pass"]

captureFinalizedOfflineLanguagePlanCandidateEvidence ::
    AcquiredOfflineLanguagePlanRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedOfflineLanguagePlanCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredOfflineLanguagePlanRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult = finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-41-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "41"] = RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-41-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-41 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening -> RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-41.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 40 digest | predecessorEvidenceMatchesPhase 41 predecessor -> RowPassed [observation "predecessor.phase" "40", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-41-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-40 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-41.residue" "browser persistence, encrypted storage, server replay, publication, live authority enforcement, tenant-isolation observation, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-41-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 41, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-41-legacy-closure" [] [finding "PHASE-41-ROW-INVENTORY" "<phase-41-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-41-legacy-closure" [observation "legacy.phase-41.closed" "retired Python/serialized/materialized-mutant offline-language-plan authorities absent", observation "legacy.phase-41.snapshot" opening] []
            | otherwise = CheckResult "phase-41-legacy-closure" [] [finding "PHASE-41-LEGACY-CLOSURE" "<phase-41-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-41 subject to pass"]

captureFinalizedUiBrowserInterpreterCandidateEvidence ::
    AcquiredUiBrowserInterpreterRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedUiBrowserInterpreterCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredUiBrowserInterpreterRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult = finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-42-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "42"] = RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-42-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-42 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening -> RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-42.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 41 digest | predecessorEvidenceMatchesPhase 42 predecessor -> RowPassed [observation "predecessor.phase" "41", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-42-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-41 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-42.residue" "browser execution and accessibility fidelity, CSP and OS network enforcement, server/provider authority, publication, release, HA, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-42-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 42, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-42-legacy-closure" [] [finding "PHASE-42-ROW-INVENTORY" "<phase-42-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-42-legacy-closure" [observation "legacy.phase-42.closed" "retired browser/Node/Python/serialized/materialized-mutant UI-browser authorities absent", observation "legacy.phase-42.snapshot" opening] []
            | otherwise = CheckResult "phase-42-legacy-closure" [] [finding "PHASE-42-LEGACY-CLOSURE" "<phase-42-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-42 subject to pass"]

captureFinalizedUiServerBoundaryCandidateEvidence ::
    AcquiredUiServerBoundaryRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedUiServerBoundaryCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredUiServerBoundaryRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult = finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-43-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "43"] = RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-43-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-43 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening -> RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-43.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 42 digest | predecessorEvidenceMatchesPhase 43 predecessor -> RowPassed [observation "predecessor.phase" "42", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-43-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-42 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-43.residue" "live identity/provider, browser/OS enforcement, deployment, redundancy, HA, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-43-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 43, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-43-legacy-closure" [] [finding "PHASE-43-ROW-INVENTORY" "<phase-43-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-43-legacy-closure" [observation "legacy.phase-43.closed" "retired Node/Python/serialized/materialized-mutant UI-server authorities absent", observation "legacy.phase-43.snapshot" opening] []
            | otherwise = CheckResult "phase-43-legacy-closure" [] [finding "PHASE-43-LEGACY-CLOSURE" "<phase-43-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-43 subject to pass"]

captureFinalizedUiLocalCompositionCandidateEvidence ::
    AcquiredUiLocalCompositionRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedUiLocalCompositionCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredUiLocalCompositionRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult = finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-44-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "44"] = RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-44-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-44 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening -> RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-44.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 43 digest | predecessorEvidenceMatchesPhase 44 predecessor -> RowPassed [observation "predecessor.phase" "43", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-44-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-43 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-44.residue" "live workflow/provider adapters, browser/server execution, identity, deployment, release, replica loss, HA, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-44-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 44, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-44-legacy-closure" [] [finding "PHASE-44-ROW-INVENTORY" "<phase-44-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-44-legacy-closure" [observation "legacy.phase-44.closed" "retired Node/Python/serialized/materialized-mutant local-composition authorities absent", observation "legacy.phase-44.snapshot" opening] []
            | otherwise = CheckResult "phase-44-legacy-closure" [] [finding "PHASE-44-LEGACY-CLOSURE" "<phase-44-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-44 subject to pass"]

captureFinalizedEncryptedBrowserRuntimeCandidateEvidence ::
    AcquiredEncryptedBrowserRuntimeRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedEncryptedBrowserRuntimeCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredEncryptedBrowserRuntimeRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult = finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-45-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "45"] = RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-45-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-45 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening -> RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-45.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 44 digest | predecessorEvidenceMatchesPhase 45 predecessor -> RowPassed [observation "predecessor.phase" "44", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-45-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-44 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-45.residue" "IndexedDB, OPFS, Web Locks, BroadcastChannel, service-worker, WebCrypto, cross-tab, storage, release, replay-server, HA, and hardware fidelity remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-45-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 45, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-45-legacy-closure" [] [finding "PHASE-45-ROW-INVENTORY" "<phase-45-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-45-legacy-closure" [observation "legacy.phase-45.closed" "retired Python/PureScript/JavaScript/serialized/materialized-mutant encrypted-browser-runtime authorities absent", observation "legacy.phase-45.snapshot" opening] []
            | otherwise = CheckResult "phase-45-legacy-closure" [] [finding "PHASE-45-LEGACY-CLOSURE" "<phase-45-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-45 subject to pass"]


captureFinalizedUiContractGenerationCandidateEvidence ::
    AcquiredUiContractGenerationRun -> PredecessorEvidence -> Either [SnapshotProblem] AcquiredSourceSnapshot ->
    Maybe Text -> Maybe Text -> FilePath -> Maybe Text -> [Text] -> AcquiredCandidateEvidence
captureFinalizedUiContractGenerationCandidateEvidence acquiredRun predecessor closing projectionDigest projectionPostimageDigest executablePath executableDigest argv =
    foldAcquiredUiContractGenerationRun finalize acquiredRun
  where
    finalize acquired _trust contractEvidence rowChecks subjectId oracleId harnessId observerId qualificationId runId toolchainId cleanup _subjectResult = finalizeCandidateRows initialCandidate legacyResult
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = either (const "") (snapshotIdentity . acquiredSourceSnapshot) closing
        baseRows = [GateRowEvidence row (rowOutcomeFromCheck "PHASE-46-ROW" result) | (row, result) <- zip allGateRows rowChecks]
        commandOutcome
            | Just digest <- executableDigest, sha256Text digest, argv == ["validate", "phase", "46"] = RowPassed [observation "command.executable.sha256" digest, observation "command.argv" (Text.unwords argv), observation "command.toolchain.sha256" toolchainId]
            | otherwise = RowRefused [] [finding "PHASE-46-COMMAND" "<process-argv>" "the direct source-bound executable identity or exact Phase-46 argv is invalid"]
        freshnessOutcome = case closing of
            Right observed | snapshotIdentity (acquiredSourceSnapshot observed) == opening -> RowPassed [observation "source.snapshot.opening" opening, observation "source.snapshot.closing" closingIdentity, observation "phase-46.run.sha256" runId]
            Right _ -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
            Left problems -> RowRefused [] [finding "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE" "<local-source-snapshot>" (renderSnapshotProblem problem) | problem <- problems]
        predecessorOutcome = case predecessor of
            ImmediatePredecessor 45 digest | predecessorEvidenceMatchesPhase 46 predecessor -> RowPassed [observation "predecessor.phase" "45", observation "predecessor.receipt.sha256" digest, observation "predecessor.projected-source.sha256" opening]
            _ -> RowRefused [] [finding "PHASE-46-PREDECESSOR" "<predecessor-receipt>" "the acquired receipt is not the exact Phase-45 predecessor"]
        residueOutcome
            | projectionDigest /= Nothing && projectionPostimageDigest /= Nothing = RowPassed [observation "phase-46.residue" "PureScript compilation, browser bundle execution, protocol use, browser fidelity, publication, deployment, HA, and hardware remain later-owned"]
            | otherwise = RowRefused [] [finding "PHASE-46-RESIDUE" "<status-projection>" "the exact status projection identities are absent"]
        replacedRows = replaceRowOutcome ResidueRow residueOutcome (replaceRowOutcome PredecessorRow predecessorOutcome (replaceRowOutcome FreshnessRow freshnessOutcome (replaceRowOutcome CommandRow commandOutcome baseRows)))
        initialCandidate = captureCandidateEvidence CandidateCapture
            { candidateCapturePhase = 46, candidateCaptureSourceOpening = opening, candidateCaptureSourceClosing = closingIdentity
            , candidateCaptureContractDigest = Just (checkResultDigest (acquiredPhaseContractEvidenceCheck contractEvidence))
            , candidateCaptureSubjectDigest = Just subjectId, candidateCaptureOracleDigest = Just oracleId
            , candidateCaptureHarnessDigest = Just harnessId, candidateCaptureObserverDigest = Just observerId
            , candidateCaptureQualificationDigest = Just qualificationId, candidateCaptureProjectionDigest = projectionDigest
            , candidateCaptureProjectionPostimageDigest = projectionPostimageDigest, candidateCapturePredecessor = predecessor
            , candidateCaptureExecutablePath = executablePath, candidateCaptureExecutableDigest = executableDigest
            , candidateCaptureArgv = argv, candidateCaptureToolchainIdentity = Just toolchainId
            , candidateCaptureSubstrate = Just "none", candidateCaptureLane = Just "none", candidateCaptureArchitecture = Just "x86_64"
            , candidateCaptureRunIdentity = Just runId, candidateCaptureCleanupObservation = Just cleanup
            , candidateCaptureRows = replacedRows
            , candidateCaptureResidue = ["status projection identity is absent" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }
        prerequisiteRows = [evidence | evidence <- replacedRows, capturedRow evidence /= LegacyClosureRow, capturedRow evidence /= PassCriterionRow]
        legacyResult
            | length rowChecks /= length allGateRows = CheckResult "phase-46-legacy-closure" [] [finding "PHASE-46-ROW-INVENTORY" "<phase-46-gate>" "the acquired runner did not supply exactly eighteen row checks"]
            | all gateRowEvidencePassed prerequisiteRows = CheckResult "phase-46-legacy-closure" [observation "legacy.phase-46.closed" "retired root-package/Python/PureScript/JavaScript/serialized/materialized-mutant UI-contract authorities absent", observation "legacy.phase-46.snapshot" opening] []
            | otherwise = CheckResult "phase-46-legacy-closure" [] [finding "PHASE-46-LEGACY-CLOSURE" "<phase-46-gate>" "legacy closure requires every non-circular prerequisite and the acquired Phase-46 subject to pass"]

replaceRowOutcome :: GateRow -> RowOutcome -> [GateRowEvidence] -> [GateRowEvidence]
replaceRowOutcome target outcome =
    map (\existing -> if capturedRow existing == target then GateRowEvidence target outcome else existing)

bootstrapGateRows
    :: Int
    -> Text
    -> Either [SnapshotProblem] AcquiredSourceSnapshot
    -> Text
    -> GenesisTrust
    -> CheckResult
    -> Text
    -> Text
    -> Text
    -> Text
    -> Text
    -> FilePath
    -> FilePath
    -> [(Maybe BootstrapCase, Text, Text, ExitCode, ExitCode, Text, Text)]
    -> Maybe Text
    -> Maybe Text
    -> Maybe Text
    -> [Text]
    -> [GateRowEvidence]
bootstrapGateRows phase opening closing contractDigest trust subject snapshotDigest subjectSourceDigest oracleDigest harnessDigest transcriptDigest compilerPath runLeaf receipts projectionDigest projectionPostimageDigest executableDigest argv =
    [GateRowEvidence row (outcome row) | row <- allGateRows]
  where
    expectedArgv = ["validate", "phase", formatOrdinal phase]
    cleanReceipts = [receipt | receipt@(Nothing, _, _, _, _, _, _) <- receipts]
    mutantReceipts = [receipt | receipt@(Just _, _, _, _, _, _, _) <- receipts]
    qualificationInventory = map (fmap renderBootstrapCase . receiptCaseOf) receipts
    expectedInventory = Nothing : map Just ["digest-equality-bypass", "snapshot-freshness-bypass", "bootstrap-path-bypass"]
    qualificationGreen =
        qualificationInventory == expectedInventory
            && compilerPath == genesisTrustCompilerExecutable trust
            && all receiptCompiled receipts
            && all receiptCleanPassed cleanReceipts
            && all receiptMutantKilled mutantReceipts
    projectionPresent = projectionDigest /= Nothing && projectionPostimageDigest /= Nothing
    outcome row = case row of
        ClaimRow ->
            RowPassed
                [ observation "claim.capability" "documentation_suite"
                , observation "claim.scope" "finite-bootstrap-seed"
                , observation "claim.contract.sha256" contractDigest
                ]
        SubjectRow -> rowOutcomeFromCheck "GATE-BOOTSTRAP-SUBJECT" subject
        CommandRow
            | Just digest <- executableDigest
            , bootstrapDigestMatches (Text.unpack digest) (Text.unpack digest)
            , argv == expectedArgv ->
                RowPassed
                    [ observation "command.executable.sha256" digest
                    , observation "command.argv" (Text.unwords argv)
                    , observation "command.genesis-trust.sha256" (genesisTrustDigest trust)
                    ]
            | otherwise ->
                RowRefused
                    [observation "command.argv" (Text.unwords argv)]
                    [bootstrapRowFinding "GATE-COMMAND" "the running executable digest or exact process argv is invalid"]
        OracleRow ->
            RowPassed
                [ observation "oracle.source.sha256" oracleDigest
                , observation "oracle.independence" "tracked BootstrapMutationDriver source is distinct from the production predicate and harness"
                ]
        PositiveControlsRow
            | length cleanReceipts == 1 && all receiptCleanPassed cleanReceipts ->
                RowPassed [observation "bootstrap.control.clean" "compiled-and-passed"]
            | otherwise -> RowRefused [] [bootstrapRowFinding "BOOTSTRAP-CONTROL" "the exact clean control did not compile and pass"]
        PairedNegativesRow
            | length mutantReceipts == 3 && all receiptMutantKilled mutantReceipts ->
                RowPassed
                    [ observation
                        ("bootstrap.negative." <> maybe "missing" renderBootstrapCase selected)
                        (Text.pack (show runExit) <> ":" <> Text.stripEnd runStderr)
                    | (selected, _, _, _, runExit, _, runStderr) <- mutantReceipts
                    ]
            | otherwise -> RowRefused [] [bootstrapRowFinding "BOOTSTRAP-NEGATIVES" "one or more paired negative executions was absent or passed"]
        MutantsRow
            | qualificationGreen && all mutantChanged mutantReceipts ->
                RowPassed
                    [ observation ("bootstrap.mutant." <> maybe "missing" renderBootstrapCase selected) (sourceDigest <> ":" <> binaryDigest)
                    | (selected, sourceDigest, binaryDigest, _, _, _, _) <- mutantReceipts
                    ]
            | otherwise -> RowRefused [] [bootstrapRowFinding "BOOTSTRAP-MUTANTS" "the exact changed-production source/binary matrix did not kill every mutant"]
        DiscoveryRow
            | qualificationInventory == expectedInventory && snapshotDigest == opening ->
                RowPassed
                    [ observation "bootstrap.discovery.inventory" "clean,digest-equality-bypass,snapshot-freshness-bypass,bootstrap-path-bypass"
                    , observation "bootstrap.discovery.snapshot.sha256" snapshotDigest
                    ]
            | otherwise -> RowRefused [] [bootstrapRowFinding "BOOTSTRAP-DISCOVERY" "the executed case inventory or acquired snapshot binding is incomplete"]
        ChallengeRow
            | qualificationGreen ->
                RowPassed [observation "bootstrap.challenge" "three independently expected bypass attempts were rejected"]
            | otherwise -> RowRefused [] [bootstrapRowFinding "BOOTSTRAP-CHALLENGE" "the independent challenge did not reject every bypass"]
        ObserverRow ->
            RowPassed
                [ observation "bootstrap.observer.sha256" (digestTexts ["bootstrap-observer", oracleDigest, transcriptDigest])
                , observation "bootstrap.transcript.sha256" transcriptDigest
                ]
        AuthorityBypassRow
            | not (bootstrapDigestMatches (replicate 64 'a') (replicate 64 'b'))
            , not (bootstrapSnapshotMatches (replicate 64 'a') (replicate 64 'b')) ->
                RowPassed
                    [ observation "bootstrap.authority" (genesisTrustAssumptionLabel trust)
                    , observation "bootstrap.authority-bypass" "digest-and-snapshot-forgery-rejected"
                    ]
            | otherwise -> RowRefused [] [bootstrapRowFinding "BOOTSTRAP-AUTHORITY" "a direct digest or snapshot forgery was accepted"]
        FreshnessRow -> case closing of
            Right observed
                | bootstrapSnapshotMatches
                    (Text.unpack opening)
                    (Text.unpack (snapshotIdentity (acquiredSourceSnapshot observed))) ->
                    RowPassed
                        [ observation "source.snapshot.opening" opening
                        , observation "source.snapshot.closing" (snapshotIdentity (acquiredSourceSnapshot observed))
                        ]
                | otherwise -> RowRefused [] [bootstrapRowFinding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "opening and closing source identities differ"]
            Left problems ->
                RowRefused
                    []
                    [ finding
                        "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE"
                        "<local-source-snapshot>"
                        (renderSnapshotProblem problem)
                    | problem <- problems
                    ]
        QualificationRow
            | qualificationGreen -> RowPassed [observation "qualification.protocol.sha256" transcriptDigest]
            | otherwise -> RowRefused [] [bootstrapRowFinding "BOOTSTRAP-QUALIFICATION" "the finite qualification protocol is not green"]
        CleanroomRow ->
            RowPassed
                [ observation "bootstrap.cleanroom" ("generated-leaf-absent=" <> Text.pack runLeaf)
                , observation "bootstrap.harness.sha256" harnessDigest
                ]
        LegacyClosureRow -> RowUnverified [] "legacy closure is derived after the sixteen non-circular rows"
        PredecessorRow ->
            RowPassed
                [ observation "predecessor" "genesis-trust-root"
                , observation "predecessor.genesis-trust.sha256" (genesisTrustDigest trust)
                ]
        ResidueRow
            | projectionPresent ->
                RowPassed [observation "phase-00.residue" "none; later obligations are explicitly owner-scoped"]
            | otherwise -> RowRefused [] [bootstrapRowFinding "BOOTSTRAP-RESIDUE" "the verified status projection identities are absent"]
        PassCriterionRow -> RowUnverified [] "the pass criterion is derived after legacy closure"

    receiptCaseOf (selected, _, _, _, _, _, _) = selected
    receiptCompiled (_, _, binaryDigest, compileExit, _, _, _) = compileExit == ExitSuccess && sha256Text binaryDigest
    receiptCleanPassed receipt@(_, _, _, _, runExit, runStdout, runStderr) =
        receiptCompiled receipt
            && runExit == ExitSuccess
            && Text.null runStdout
            && Text.null runStderr
    receiptMutantKilled receipt@(selected, _, _, _, runExit, runStdout, runStderr) =
        receiptCompiled receipt
            && runExit == ExitFailure 1
            && Text.null runStdout
            && runStderr == maybe "" ((<> "\n") . renderBootstrapCase) selected
    mutantChanged (_, sourceDigest, binaryDigest, _, _, _, _) =
        sourceDigest /= subjectSourceDigest
            && sha256Text sourceDigest
            && sha256Text binaryDigest

rowOutcomeFromCheck :: Text -> CheckResult -> RowOutcome
rowOutcomeFromCheck code result
    | checkPassed result && not (null (checkObservations result)) = RowPassed (checkObservations result)
    | checkPassed result = RowRefused [] [bootstrapRowFinding code "a passing check supplied no observation"]
    | otherwise = RowRefused (checkObservations result) (checkFindings result)

bootstrapRowFinding :: Text -> Text -> Finding
bootstrapRowFinding code = finding code "<finite-bootstrap-gate>"

checkResultDigest :: CheckResult -> Text
checkResultDigest result =
    digestTexts
        ( ["check", checkName result]
            <> concatMap observationFields (checkObservations result)
            <> concatMap findingFields (checkFindings result)
        )
  where
    observationFields item = ["observation", observationKey item, observationValue item]
    findingFields item = ["finding", findingCode item, Text.pack (findingSubject item), findingDetail item]

digestTexts :: [Text] -> Text
digestTexts fields =
    hex
        ( SHA256.hash
            (ByteString.concat (map frame fields))
        )
  where
    frame field =
        let bytes = TextEncoding.encodeUtf8 field
         in ByteString8.pack (show (ByteString.length bytes)) <> ":" <> bytes <> ";"

bindLegacyClosureToCandidateSource :: Text -> Text -> LegacyClosure -> CheckResult
bindLegacyClosureToCandidateSource candidateSource acquiredSource closure =
    let result = legacyClosureResult closure
     in result
            { checkFindings =
                checkFindings result
                    <> [ finding
                            "GATE-LEGACY-CLOSURE-SNAPSHOT"
                            "<gate-finalization>"
                            "the legacy closure receipt and candidate name different opening source snapshots"
                       | candidateSource /= acquiredSource
                       ]
            }

gateCompletionPremisesFromRows :: [GateRowEvidence] -> GateCompletionPremises
gateCompletionPremisesFromRows rows =
    assembleGateCompletionPremises
        [ gatePrerequisiteFromRow evidence
        | evidence <- rows
        , gateCompletionPrerequisiteRow (capturedRow evidence)
        ]

gateCompletionPrerequisiteRow :: GateRow -> Bool
gateCompletionPrerequisiteRow row =
    row /= LegacyClosureRow && row /= PassCriterionRow

gatePrerequisiteFromRow :: GateRowEvidence -> GatePrerequisiteObservation
gatePrerequisiteFromRow evidence =
    case capturedOutcome evidence of
        RowPassed _
            | gateRowEvidencePassed evidence -> gatePrerequisitePassed name
            | otherwise -> gatePrerequisiteUnverified name
        RowRefused _ _ -> gatePrerequisiteRefused name
        RowUnverified _ _ -> gatePrerequisiteUnverified name
  where
    name = renderGateRow (capturedRow evidence)

{- | The constructor is private to this module.  In particular there is no
exported function accepting a caller-authored pass-criterion result.
-}
newtype PassCriterionEvidence = PassCriterionEvidence GateRowEvidence

finalizeCandidateRows :: AcquiredCandidateEvidence -> CheckResult -> AcquiredCandidateEvidence
finalizeCandidateRows candidate closureCheck =
    candidate
        { acquiredCapture =
            captured
                { candidateCaptureRows = finalizedRows
                }
        }
  where
    captured = acquiredCapture candidate
    legacyRows =
        map
            (replaceGateRow LegacyClosureRow (legacyClosureGateRow closureCheck))
            (captureRows captured)
    PassCriterionEvidence passCriterion = derivePassCriterionEvidence legacyRows
    finalizedRows = map (replaceGateRow PassCriterionRow passCriterion) legacyRows

replaceGateRow :: GateRow -> GateRowEvidence -> GateRowEvidence -> GateRowEvidence
replaceGateRow target replacement existing
    | capturedRow existing == target = replacement
    | otherwise = existing

legacyClosureGateRow :: CheckResult -> GateRowEvidence
legacyClosureGateRow result
    | checkPassed result
        && not (null (checkObservations result))
        && all validObservation (checkObservations result) =
        GateRowEvidence LegacyClosureRow (RowPassed (checkObservations result))
    | null (checkFindings result) =
        GateRowEvidence
            LegacyClosureRow
            ( RowRefused
                (checkObservations result)
                [ finding
                    "GATE-LEGACY-CLOSURE-OBSERVATION"
                    "<gate-finalization>"
                    "a passing legacy closure requires at least one well-formed observation"
                ]
            )
    | otherwise =
        GateRowEvidence
            LegacyClosureRow
            (RowRefused (checkObservations result) (checkFindings result))

derivePassCriterionEvidence :: [GateRowEvidence] -> PassCriterionEvidence
derivePassCriterionEvidence rows =
    PassCriterionEvidence (GateRowEvidence PassCriterionRow outcome)
  where
    prerequisiteRows = filter ((/= PassCriterionRow) . capturedRow) rows
    expectedRows = filter (/= PassCriterionRow) allGateRows
    inventoryExact = map capturedRow prerequisiteRows == expectedRows
    refusedRows =
        [ renderGateRow (capturedRow evidence)
        | evidence <- prerequisiteRows
        , rowDefinitelyRefused evidence
        ]
    unverifiedRows =
        [ renderGateRow (capturedRow evidence)
        | evidence <- prerequisiteRows
        , not (rowDefinitelyRefused evidence)
        , not (gateRowEvidencePassed evidence)
        ]
    blockedObservation =
        [ observation
            "gate.pass-criterion.blocked-rows"
            (Text.intercalate "," (refusedRows <> unverifiedRows))
        ]
    outcome
        | not inventoryExact =
            RowRefused
                []
                [ finding
                    "GATE-PASS-CRITERION-INVENTORY"
                    "<gate-finalization>"
                    "the pass criterion did not receive the exact ordered seventeen-row prerequisite inventory"
                ]
        | null refusedRows && null unverifiedRows =
            RowPassed
                [ observation
                    "gate.pass-criterion"
                    "all seventeen prerequisite rows passed in this finalized candidate"
                ]
        | not (null refusedRows) =
            RowRefused
                blockedObservation
                [ finding
                    "GATE-PASS-CRITERION-REFUSED"
                    "<gate-finalization>"
                    ( "one or more prerequisite rows refused: "
                        <> Text.intercalate "," refusedRows
                    )
                ]
        | otherwise =
            RowUnverified
                blockedObservation
                ( "one or more prerequisite rows remain unverified: "
                    <> Text.intercalate "," unverifiedRows
                )

rowDefinitelyRefused :: GateRowEvidence -> Bool
rowDefinitelyRefused evidence = case capturedOutcome evidence of
    RowRefused _ _ -> True
    RowPassed _ -> False
    RowUnverified _ _ -> False

dispatchGateRow :: Int -> CheckResult -> Text -> Text -> Maybe Text -> [Text] -> GateRow -> GateRowEvidence
dispatchGateRow phase result opening closing executableDigest argv row =
    GateRowEvidence row outcome
  where
    outcome = case row of
        SubjectRow
            | checkPassed result -> RowPassed (checkObservations result)
            | otherwise -> RowRefused (checkObservations result) (checkFindings result)
        CommandRow -> case (executableDigest, argv == expectedArgv) of
            (Just digest, True) ->
                RowUnverified
                    [ observation "command.executable.sha256" digest
                    , observation "command.argv" (Text.unwords argv)
                    ]
                    "the process command was observed, but authenticated pinned/offline toolchain and build provenance are absent"
            (Nothing, _) -> RowUnverified [] "the running executable bytes could not be read"
            (_, False) ->
                RowRefused
                    [ observation "command.argv" (Text.unwords argv)
                    ]
                    [ finding
                        "GATE-COMMAND-ARGV"
                        "<process-argv>"
                        "the observed process argv is not the exact validation command"
                    ]
        FreshnessRow
            | opening == closing ->
                RowUnverified
                    [ observation "source.snapshot.opening" opening
                    , observation "source.snapshot.closing" closing
                    ]
                    "opening and closing authored-source bytes match, but fresh run-root, cache, prior-evidence, and ignored-input exclusion are unverified"
            | otherwise -> RowRefused [] [finding "SOURCE-SNAPSHOT-CHANGED-DURING-GATE" "<local-source-snapshot>" "opening and closing source identities differ"]
        PredecessorRow
            | phase == policyDomainLower -> RowPassed [observation "predecessor" "typed genesis"]
            | otherwise -> RowUnverified [] "the immediate predecessor pass is not attached"
        _ -> RowUnverified [] "this gate row has no execution-derived production binding yet"
    expectedArgv = ["validate", "phase", formatOrdinal phase]

acquiredCandidatePhase :: AcquiredCandidateEvidence -> Int
acquiredCandidatePhase = capturePhase . acquiredCapture

acquiredCandidateCapture :: AcquiredCandidateEvidence -> CandidateCapture
acquiredCandidateCapture = acquiredCapture

acquiredCandidateSourceOpening :: AcquiredCandidateEvidence -> Text
acquiredCandidateSourceOpening = captureSourceOpening . acquiredCapture

acquiredCandidateSourceClosing :: AcquiredCandidateEvidence -> Text
acquiredCandidateSourceClosing = captureSourceClosing . acquiredCapture

acquiredCandidateProjectionDigest :: AcquiredCandidateEvidence -> Maybe Text
acquiredCandidateProjectionDigest = captureProjectionDigest . acquiredCapture

acquiredCandidatePredecessor :: AcquiredCandidateEvidence -> PredecessorEvidence
acquiredCandidatePredecessor = capturePredecessor . acquiredCapture

acquiredCandidateRows :: AcquiredCandidateEvidence -> [GateRowEvidence]
acquiredCandidateRows = captureRows . acquiredCapture

acquiredCandidateSubjectCheck :: AcquiredCandidateEvidence -> CheckResult
acquiredCandidateSubjectCheck =
    acquiredCandidateRowCheck
        SubjectRow
        "gate-subject"
        "GATE-SUBJECT-UNVERIFIED"

{- | Read-only projections for the dispatcher result.  They reconstruct a
diagnostic @CheckResult@ from the sealed row; they cannot alter the
candidate or create row authority.
-}
acquiredCandidateLegacyClosureCheck :: AcquiredCandidateEvidence -> CheckResult
acquiredCandidateLegacyClosureCheck =
    acquiredCandidateRowCheck
        LegacyClosureRow
        "legacy-closure"
        "GATE-LEGACY-CLOSURE-UNVERIFIED"

acquiredCandidatePassCriterionCheck :: AcquiredCandidateEvidence -> CheckResult
acquiredCandidatePassCriterionCheck =
    acquiredCandidateRowCheck
        PassCriterionRow
        "gate-pass-criterion"
        "GATE-PASS-CRITERION-UNVERIFIED"

acquiredCandidateQualificationCheck :: AcquiredCandidateEvidence -> CheckResult
acquiredCandidateQualificationCheck =
    acquiredCandidateRowCheck
        QualificationRow
        "gate-qualification"
        "GATE-QUALIFICATION-UNVERIFIED"

acquiredCandidateRowCheck :: GateRow -> Text -> Text -> AcquiredCandidateEvidence -> CheckResult
acquiredCandidateRowCheck expected resultName unverifiedCode candidate =
    case filter ((== expected) . capturedRow) (acquiredCandidateRows candidate) of
        [evidence] -> case capturedOutcome evidence of
            RowPassed observations -> CheckResult resultName observations []
            RowRefused observations findings -> CheckResult resultName observations findings
            RowUnverified observations detail ->
                CheckResult
                    resultName
                    observations
                    [finding unverifiedCode "<gate-finalization>" detail]
        matches ->
            CheckResult
                resultName
                []
                [ finding
                    "GATE-FINALIZED-ROW-INVENTORY"
                    "<gate-finalization>"
                    ( "expected exactly one "
                        <> renderGateRow expected
                        <> " row but observed "
                        <> Text.pack (show (length matches))
                    )
                ]

instance ToJSON GateRowEvidence where
    toJSON evidence =
        object
            [ "name" .= renderGateRow (capturedRow evidence)
            , "outcome" .= outcomeName (capturedOutcome evidence)
            , "observations" .= outcomeObservations (capturedOutcome evidence)
            , "findings" .= outcomeFindings (capturedOutcome evidence)
            , "unverified" .= outcomeResidue (capturedOutcome evidence)
            ]

instance ToJSON AcquiredCandidateEvidence where
    toJSON evidence =
        object
            [ "schema" .= acquiredSchema evidence
            , "phase" .= formatOrdinal (capturePhase captured)
            , "sourceOpeningDigest" .= captureSourceOpening captured
            , "sourceClosingDigest" .= captureSourceClosing captured
            , "contractDigest" .= captureContractDigest captured
            , "subjectDigest" .= captureSubjectDigest captured
            , "oracleDigest" .= captureOracleDigest captured
            , "harnessDigest" .= captureHarnessDigest captured
            , "observerDigest" .= captureObserverDigest captured
            , "qualificationDigest" .= captureQualificationDigest captured
            , "projectionDigest" .= captureProjectionDigest captured
            , "projectionPostimageDigest" .= captureProjectionPostimageDigest captured
            , "predecessor" .= predecessorJson (capturePredecessor captured)
            , "command"
                .= object
                    [ "executablePath" .= captureExecutablePath captured
                    , "executableDigest" .= captureExecutableDigest captured
                    , "argv" .= captureArgv captured
                    ]
            , "toolchainIdentity" .= captureToolchainIdentity captured
            , "substrate" .= captureSubstrate captured
            , "lane" .= captureLane captured
            , "architecture" .= captureArchitecture captured
            , "runIdentity" .= captureRunIdentity captured
            , "cleanupObservation" .= captureCleanupObservation captured
            , "rows" .= captureRows captured
            , "residue" .= captureResidue captured
            , "gateResult" .= gateResult captured
            ]
      where
        captured = acquiredCapture evidence

outcomeName :: RowOutcome -> Text
outcomeName outcome = case outcome of
    RowPassed _ -> "green"
    RowRefused _ _ -> "red"
    RowUnverified _ _ -> "unverified"

outcomeObservations :: RowOutcome -> [Value]
outcomeObservations outcome = case outcome of
    RowPassed values -> map observationJson values
    RowRefused values _ -> map observationJson values
    RowUnverified values _ -> map observationJson values

outcomeFindings :: RowOutcome -> [Value]
outcomeFindings outcome = case outcome of
    RowPassed _ -> []
    RowRefused _ values -> map findingJson values
    RowUnverified _ _ -> []

outcomeResidue :: RowOutcome -> Maybe Text
outcomeResidue outcome = case outcome of
    RowUnverified _ detail -> Just detail
    _ -> Nothing

predecessorJson :: PredecessorEvidence -> Value
predecessorJson predecessor = case predecessor of
    GenesisPredecessor digest ->
        object
            [ "kind" .= ("genesis-trust" :: Text)
            , "trustDigest" .= digest
            ]
    ImmediatePredecessor phase digest ->
        object
            [ "kind" .= ("immediate-predecessor" :: Text)
            , "phase" .= formatOrdinal phase
            , "evidenceDigest" .= digest
            ]
    UnverifiedPredecessor detail ->
        object
            [ "kind" .= ("unverified" :: Text)
            , "detail" .= detail
            ]

gateResult :: CandidateCapture -> Text
gateResult captured
    | map capturedRow (captureRows captured) == allGateRows
        && all gateRowEvidencePassed (captureRows captured)
        && null (captureResidue captured) =
        "candidate-green; sealed gate verification required"
    | otherwise = "candidate-refused-or-unverified"

observationJson :: Observation -> Value
observationJson item = object ["key" .= observationKey item, "value" .= observationValue item]

findingJson :: Finding -> Value
findingJson item =
    object
        [ "code" .= findingCode item
        , "subject" .= findingSubject item
        , "detail" .= findingDetail item
        ]

acquiredCandidateBytes :: AcquiredCandidateEvidence -> ByteString
acquiredCandidateBytes = LazyByteString.toStrict . encode

acquiredCandidateDigest :: AcquiredCandidateEvidence -> Text
acquiredCandidateDigest = hex . SHA256.hash . acquiredCandidateBytes

writeAcquiredCandidateEvidence :: FilePath -> AcquiredCandidateEvidence -> IO PublishedCandidateEvidence
writeAcquiredCandidateEvidence repositoryRoot evidence = do
    when
        (Policy.mkPhaseOrdinal (acquiredCandidatePhase evidence) == Nothing)
        (fail "candidate-phase-outside-compiled-domain")
    absoluteRoot <- makeAbsolute repositoryRoot >>= canonicalizePath
    directory <-
        ensureDirectoryChain
            absoluteRoot
            [ canonicalGeneratedRoot
            , "runs"
            , "phase-" <> Text.unpack (formatOrdinal (acquiredCandidatePhase evidence))
            , "candidates"
            ]
    encoded <- boundedCandidateBytes evidence
    let destination = directory </> Text.unpack (hex (SHA256.hash encoded)) <> ".json"
    unless
        (isAbsolute directory && isContained absoluteRoot directory)
        (fail "candidate-output-escaped-repository-build-root")
    present <- doesPathExist destination
    if present
        then pure ()
        else writeNewCandidateAtomically directory destination encoded
    rootIdentity <- publicationDirectoryIdentity absoluteRoot
    (directoryIdentity, fileIdentity) <-
        readExactCandidateDurably directory destination encoded Nothing Nothing
    reboundRootIdentity <- publicationDirectoryIdentity absoluteRoot
    unless (rootIdentity == reboundRootIdentity) (fail "candidate-repository-root-identity-changed")
    pure
        PublishedCandidateEvidence
            { publishedEvidenceValue = evidence
            , publishedPathValue = destination
            , publishedRootValue = absoluteRoot
            , publishedRootIdentityValue = rootIdentity
            , publishedDirectoryIdentityValue = directoryIdentity
            , publishedFileIdentityValue = fileIdentity
            }

-- | Install the exact already-published candidate bytes into the durable
-- predecessor store. The dispatcher calls this only after the hidden gate
-- verifier has accepted the publication. Content addressing and exact rereads
-- make a raced or replaced receipt refuse.
installPublishedCandidateEvidenceReceipt :: PublishedCandidateEvidence -> IO FilePath
installPublishedCandidateEvidenceReceipt published = do
    let evidence = publishedCandidateEvidence published
        root = publishedRootValue published
        digest = acquiredCandidateDigest evidence
        encoded = acquiredCandidateBytes evidence
    directory <-
        ensureDirectoryChain
            root
            [ canonicalGeneratedRoot
            , "evidence-store"
            , "phase-" <> Text.unpack (formatOrdinal (acquiredCandidatePhase evidence))
            ]
    let destination = directory </> Text.unpack digest <> ".json"
    present <- doesPathExist destination
    unless present (writeNewCandidateAtomically directory destination encoded)
    _ <- readExactCandidateDurably directory destination encoded Nothing Nothing
    pure destination

-- | Re-acquire one deterministic member of the durable verified-receipt
-- equivalence class for the immediate predecessor.
-- The returned constructor is hidden, so downstream candidate construction
-- cannot substitute a caller-authored digest. Every file in the selected
-- predecessor directory is fail-closed: malformed or detached content makes
-- acquisition refuse rather than being ignored. A verified predecessor pass
-- is monotonic across later source snapshots: the current gate owns current-
-- source compatibility and may project that pass onto its opening snapshot.
acquireImmediatePredecessorEvidence ::
    FilePath ->
    Int ->
    Text ->
    IO (Either [Finding] PredecessorEvidence)
acquireImmediatePredecessorEvidence root phase _opening
    | phase <= policyDomainLower =
        pure (Left [receiptFinding "EVIDENCE-PREDECESSOR-PHASE" "a numbered predecessor exists only above Phase 00"])
    | otherwise = do
        absoluteRoot <- makeAbsolute root >>= canonicalizePath
        let predecessorPhase = phase - 1
            directory =
                absoluteRoot
                    </> canonicalGeneratedRoot
                    </> "evidence-store"
                    </> ("phase-" <> Text.unpack (formatOrdinal predecessorPhase))
        present <- doesDirectoryExist directory
        if not present
            then pure (Left [receiptFinding "EVIDENCE-PREDECESSOR-MISSING" "the durable predecessor receipt directory is absent"])
            else do
                leaves <- listDirectory directory
                acquired <- traverse (acquireReceiptFile absoluteRoot predecessorPhase directory) (sort leaves)
                let problems = concat [items | Left items <- acquired]
                    matches = [digest | Right (Just digest) <- acquired]
                pure $ case (problems, matches) of
                    (items@(_ : _), _) -> Left items
                    ([], []) -> Left [receiptFinding "EVIDENCE-PREDECESSOR-MISSING" "the immediate predecessor directory contains no verified receipt"]
                    ([], digests) -> Right (ImmediatePredecessor predecessorPhase (minimum digests))

acquireReceiptFile ::
    FilePath ->
    Int ->
    FilePath ->
    FilePath ->
    IO (Either [Finding] (Maybe Text))
acquireReceiptFile root predecessorPhase directory leaf
    | takeExtension leaf /= ".json" =
        pure (Left [receiptFinding "EVIDENCE-PREDECESSOR-ENTRY" "the receipt directory contains a non-JSON entry"])
    | otherwise = do
        let path = directory </> leaf
            claimedDigest = Text.pack (takeFileNameWithoutJson leaf)
        bytesResult <- try (ByteString.readFile path) :: IO (Either IOException ByteString)
        case bytesResult of
            Left problem -> pure (Left [receiptFinding "EVIDENCE-PREDECESSOR-READ" (Text.pack (show problem))])
            Right bytes -> do
                let actualDigest = hex (SHA256.hash bytes)
                    decoded = decodeStrict' bytes :: Maybe Value
                    candidatePath =
                        root
                            </> canonicalGeneratedRoot
                            </> "runs"
                            </> ("phase-" <> Text.unpack (formatOrdinal predecessorPhase))
                            </> "candidates"
                            </> leaf
                candidateBytesResult <- try (ByteString.readFile candidatePath) :: IO (Either IOException ByteString)
                pure $ case (actualDigest == claimedDigest, decoded, candidateBytesResult) of
                    (False, _, _) -> Left [receiptFinding "EVIDENCE-PREDECESSOR-CONTENT-ADDRESS" "the receipt filename does not match its exact bytes"]
                    (_, Nothing, _) -> Left [receiptFinding "EVIDENCE-PREDECESSOR-SCHEMA" "the receipt is not valid JSON"]
                    (_, _, Left _) -> Left [receiptFinding "EVIDENCE-PREDECESSOR-CANDIDATE" "the receipt has no matching original candidate publication"]
                    (_, _, Right candidateBytes)
                        | candidateBytes /= bytes -> Left [receiptFinding "EVIDENCE-PREDECESSOR-CANDIDATE" "the receipt bytes differ from the original candidate publication"]
                    (_, Just value, Right _) ->
                        case receiptValueProblems predecessorPhase value of
                            problems@(_ : _) -> Left problems
                            [] -> Right (Just actualDigest)

receiptValueProblems :: Int -> Value -> [Finding]
receiptValueProblems phase value =
    [receiptFinding "EVIDENCE-PREDECESSOR-SCHEMA" detail | detail <- schemaProblems]
  where
    rows = jsonArrayField "rows" value
    residue = jsonArrayField "residue" value
    digestFields =
        [ "contractDigest"
        , "subjectDigest"
        , "oracleDigest"
        , "harnessDigest"
        , "observerDigest"
        , "qualificationDigest"
        , "projectionDigest"
        , "projectionPostimageDigest"
        , "toolchainIdentity"
        , "runIdentity"
        ]
    schemaProblems =
        ["schema is not amoebius-validation-candidate-v3" | jsonTextField "schema" value /= Just "amoebius-validation-candidate-v3"]
            <> ["phase does not match the receipt directory" | jsonTextField "phase" value /= Just (formatOrdinal phase)]
            <> ["candidate gateResult is not green" | jsonTextField "gateResult" value /= Just "candidate-green; sealed gate verification required"]
            <> ["opening and closing source digests are absent or unequal" | not (sameSource value)]
            <> ["one or more required identity digests are malformed" | any (maybe True (not . sha256Text) . (`jsonTextField` value)) digestFields]
            <> ["receipt residue is absent or nonempty" | residue /= Just []]
            <> ["gate rows are not the exact ordered green inventory" | maybe True (not . validStoredRows) rows]

sameSource :: Value -> Bool
sameSource value =
    case (jsonTextField "sourceOpeningDigest" value, jsonTextField "sourceClosingDigest" value) of
        (Just opening, Just closing) -> sha256Text opening && opening == closing
        _ -> False

validStoredRows :: [Value] -> Bool
validStoredRows rows =
    length rows == length allGateRows
        && zipWith validRow allGateRows rows == replicate (length allGateRows) True
  where
    validRow expected row =
        jsonTextField "name" row == Just (renderGateRow expected)
            && jsonTextField "outcome" row == Just "green"
            && maybe False (not . null) (jsonArrayField "observations" row)

jsonTextField :: Text -> Value -> Maybe Text
jsonTextField key (Object objectValue) =
    case AesonKeyMap.lookup (AesonKey.fromText key) objectValue of
        Just (String value) -> Just value
        _ -> Nothing
jsonTextField _ _ = Nothing

jsonArrayField :: Text -> Value -> Maybe [Value]
jsonArrayField key (Object objectValue) =
    case AesonKeyMap.lookup (AesonKey.fromText key) objectValue of
        Just (Array values) -> Just (Foldable.toList values)
        _ -> Nothing
jsonArrayField _ _ = Nothing

takeFileNameWithoutJson :: FilePath -> FilePath
takeFileNameWithoutJson leaf = reverse (drop 5 (reverse leaf))

receiptFinding :: Text -> Text -> Finding
receiptFinding code = finding code "<predecessor-receipt>"

{- | Re-acquire the publication boundary before gate verification.  The
receipt constructor is hidden, but verification still checks its absolute,
canonical, content-addressed path and exact regular-file bytes instead of
trusting the in-memory value returned by the writer.
-}
recheckPublishedCandidateEvidence ::
    PublishedCandidateEvidence ->
    IO (Either [Finding] AcquiredCandidateEvidence)
recheckPublishedCandidateEvidence published = do
    result <- try $ do
        let evidence = publishedCandidateEvidence published
            path = publishedCandidatePath published
            root = publishedRootValue published
            expected = acquiredCandidateBytes evidence
            expectedName = Text.unpack (acquiredCandidateDigest evidence) <> ".json"
            expectedPhaseDirectory = "phase-" <> Text.unpack (formatOrdinal (acquiredCandidatePhase evidence))
            reversedParts = reverse (splitDirectories (normalise path))
        unless (isAbsolute path) (fail "candidate-publication-path-is-not-absolute")
        unless
            ( case reversedParts of
                fileName : "candidates" : phaseDirectory : "runs" : generatedRoot : _ ->
                    fileName == expectedName
                        && phaseDirectory == expectedPhaseDirectory
                        && generatedRoot == canonicalGeneratedRoot
                _ -> False
            )
            (fail "candidate-publication-path-does-not-match-content-address")
        unless (isAbsolute root && isContained root path) (fail "candidate-publication-path-escaped-repository-root")
        canonicalRoot <- canonicalizePath root
        unless (normalise canonicalRoot == normalise root) (fail "candidate-publication-root-is-not-canonical")
        canonical <- canonicalizePath path
        unless (normalise canonical == normalise path) (fail "candidate-publication-path-is-not-canonical")
        rootIdentity <- publicationDirectoryIdentity root
        unless
            (rootIdentity == publishedRootIdentityValue published)
            (fail "candidate-publication-root-identity-changed")
        _ <-
            readExactCandidateDurably
                (takeDirectory path)
                path
                expected
                (Just (publishedDirectoryIdentityValue published))
                (Just (publishedFileIdentityValue published))
        pure evidence
    pure $ case result of
        Left problem ->
            Left
                [ finding
                    "GATE-PASS-PUBLICATION"
                    (publishedCandidatePath published)
                    (Text.pack (show (problem :: IOException)))
                ]
        Right evidence -> Right evidence

boundedCandidateBytes :: AcquiredCandidateEvidence -> IO ByteString
boundedCandidateBytes evidence = do
    let prefix = LazyByteString.take (fromIntegral maximumCandidateEvidenceBytes + 1) (encode evidence)
    when
        (LazyByteString.length prefix > fromIntegral maximumCandidateEvidenceBytes)
        (fail "candidate-evidence-byte-limit")
    pure (LazyByteString.toStrict prefix)

readExactCandidateDurably ::
    FilePath ->
    FilePath ->
    ByteString ->
    Maybe PublicationIdentity ->
    Maybe PublicationIdentity ->
    IO (PublicationIdentity, PublicationIdentity)
#if defined(mingw32_HOST_OS)
readExactCandidateDurably _ _ _ _ _ =
  fail "candidate-durable-publication-is-unavailable-on-windows"
#else
readExactCandidateDurably directoryPath path expected expectedDirectoryIdentity expectedFileIdentity = do
  unless (normalise (takeDirectory path) == normalise directoryPath) (fail "candidate-output-parent-mismatch")
  first <- readOnce
  second <- readOnce
  unless (first == second) (fail "candidate-publication-identity-changed-during-recheck")
  pure second
 where
  readOnce =
    withAbsoluteDirectoryFdNoFollow directoryPath $ \directoryFd -> do
      directoryStatus <- getFdStatus directoryFd
      unless (isDirectory directoryStatus) (fail "candidate-output-parent-is-not-directory")
      let directoryIdentity = publicationIdentity directoryStatus
      maybe
        (pure ())
        (\expectedIdentity -> unless (directoryIdentity == expectedIdentity) (fail "candidate-output-parent-identity-changed"))
        expectedDirectoryIdentity
      bracket
        (openFdAt (Just directoryFd) (takeFileName path) ReadOnly regularCandidateReadFlags)
        closeFd
        (\fileFd -> do
            before <- getFdStatus fileFd
            unless (isRegularFile before) (fail "candidate-output-is-not-regular-file")
            let fileIdentity = publicationIdentity before
                expectedSize = fromIntegral (ByteString.length expected)
            maybe
              (pure ())
              (\expectedIdentity -> unless (fileIdentity == expectedIdentity) (fail "candidate-output-file-identity-changed"))
              expectedFileIdentity
            unless (fileSize before == expectedSize) (fail "candidate-output-size-mismatch")
            observed <- readBoundedFd fileFd (ByteString.length expected + 1)
            unless (observed == expected) (fail "candidate-output-postimage-mismatch")
            after <- getFdStatus fileFd
            unless
              ( isRegularFile after
                  && publicationIdentity after == fileIdentity
                  && fileSize after == expectedSize
              )
              (fail "candidate-output-file-changed-during-read")
            fileSynchronise fileFd
            fileSynchronise directoryFd
            pure (directoryIdentity, fileIdentity)
        )
#endif

publicationDirectoryIdentity :: FilePath -> IO PublicationIdentity
#if defined(mingw32_HOST_OS)
publicationDirectoryIdentity _ = fail "candidate-directory-identity-is-unavailable-on-windows"
#else
publicationDirectoryIdentity path =
  withAbsoluteDirectoryFdNoFollow path $ \descriptor -> do
    status <- getFdStatus descriptor
    unless (isDirectory status) (fail "candidate-publication-path-is-not-a-directory")
    pure (publicationIdentity status)
#endif

#if !defined(mingw32_HOST_OS)
publicationIdentity :: FileStatus -> PublicationIdentity
publicationIdentity status =
  PublicationIdentity
    (fromIntegral (deviceID status))
    (fromIntegral (fileID status))

withAbsoluteDirectoryFdNoFollow :: FilePath -> (Fd -> IO value) -> IO value
withAbsoluteDirectoryFdNoFollow absolute action =
  case absoluteDirectoryComponents absolute of
    Nothing -> fail "candidate-publication-directory-is-not-an-absolute-canonical-path"
    Just components ->
      bracket
        (openFd "/" ReadOnly directoryReadFlags)
        closeFd
        (\rootFd -> descend rootFd components)
 where
  descend directoryFd [] = action directoryFd
  descend directoryFd (component : rest) =
    bracket
      (openFdAt (Just directoryFd) component ReadOnly directoryReadFlags)
      closeFd
      (\childFd -> descend childFd rest)

absoluteDirectoryComponents :: FilePath -> Maybe [FilePath]
absoluteDirectoryComponents path =
  case Text.pack (dropTrailingPathSeparator path) of
    "/" -> Just []
    value -> case Text.splitOn "/" value of
      "" : components
        | all validComponent components -> Just (map Text.unpack components)
      _ -> Nothing
 where
  validComponent component = not (Text.null component) && component /= "." && component /= ".."

directoryReadFlags :: OpenFileFlags
directoryReadFlags =
  defaultFileFlags
    { cloexec = True
    , directory = True
    , nofollow = True
    , nonBlock = True
    }

regularCandidateReadFlags :: OpenFileFlags
regularCandidateReadFlags =
  defaultFileFlags
    { cloexec = True
    , nofollow = True
    , nonBlock = True
    }

readBoundedFd :: Fd -> Int -> IO ByteString
readBoundedFd descriptor limit =
  bracket
    (dup descriptor >>= fdToHandle)
    hClose
    (\handle -> ByteString.hGet handle limit)
#endif

writeNewCandidateAtomically :: FilePath -> FilePath -> ByteString -> IO ()
writeNewCandidateAtomically directory destination bytes = do
    (temporary, handle) <- openBinaryTempFile directory ".amoebius-candidate"
    let cleanup = do
            ignoreIOException (hClose handle)
            present <- doesPathExist temporary
            when present (removeFile temporary)
    ( do
            ByteString.hPut handle bytes
            durableClose handle
            installCandidateNoReplace temporary destination
            synchroniseDirectory directory
        )
        `onException` cleanup

installCandidateNoReplace :: FilePath -> FilePath -> IO ()
#if defined(mingw32_HOST_OS)
installCandidateNoReplace temporary destination = do
  raced <- doesPathExist destination
  when raced (fail "candidate-output-raced")
  renameFile temporary destination
#else
installCandidateNoReplace temporary destination = do
  createLink temporary destination
  removeFile temporary
#endif

ignoreIOException :: IO () -> IO ()
ignoreIOException action = do
    _ <- try action :: IO (Either IOException ())
    pure ()

durableClose :: Handle -> IO ()
#if defined(mingw32_HOST_OS)
durableClose handle = hFlush handle >> hClose handle
#else
durableClose handle = do
  hFlush handle
  descriptor <- handleToFd handle
  (fileSynchronise descriptor >> closeFd descriptor)
    `onException` (ignoreIOException (closeFd descriptor))
#endif

synchroniseDirectory :: FilePath -> IO ()
#if defined(mingw32_HOST_OS)
synchroniseDirectory _ = pure ()
#else
synchroniseDirectory directory = do
  descriptor <- openFd directory ReadOnly defaultFileFlags
  (fileSynchronise descriptor >> closeFd descriptor)
    `onException` (ignoreIOException (closeFd descriptor))
#endif

ensureDirectoryChain :: FilePath -> [FilePath] -> IO FilePath
ensureDirectoryChain root = foldM ensure root
  where
    ensure parent component = do
        let candidate = normalise (parent </> component)
        present <- doesPathExist candidate
        if present
            then do
                linked <- pathIsSymbolicLink candidate
                when linked (fail "candidate-output-directory-is-symbolic-link")
                directory <- doesDirectoryExist candidate
                unless directory (fail "candidate-output-component-is-not-directory")
            else do
                createDirectory candidate
                synchroniseDirectory parent
                synchroniseDirectory candidate
        canonical <- canonicalizePath candidate
        unless
            (isContained root canonical || canonical == normalise (root </> canonicalGeneratedRoot))
            (fail "candidate-output-directory-escaped-repository")
        pure canonical

isContained :: FilePath -> FilePath -> Bool
isContained root path =
    case splitDirectories (makeRelative (normalise root) (normalise path)) of
        generatedRoot : "runs" : _ | generatedRoot == canonicalGeneratedRoot -> True
        generatedRoot : "evidence-store" : _ | generatedRoot == canonicalGeneratedRoot -> True
        _ -> False

canonicalGeneratedRoot :: FilePath
canonicalGeneratedRoot =
    Policy.generationRootPath
        (Policy.generationRoot (Policy.generationContract Policy.canonicalPolicyContract))

policyDomainLower :: Int
policyDomainLower =
    Policy.phaseOrdinalNumber
        (Policy.phaseDomainLower (Policy.orderingContract Policy.canonicalPolicyContract))

maximumCandidateEvidenceBytes :: Int
maximumCandidateEvidenceBytes = 16 * 1024 * 1024

formatOrdinal :: Int -> Text
formatOrdinal ordinal
    | ordinal >= 0 && ordinal < 10 = "0" <> Text.pack (show ordinal)
    | otherwise = Text.pack (show ordinal)

hex :: ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
  where
    byteHex value = [intToDigit (fromIntegral value `div` 16), intToDigit (fromIntegral value `mod` 16)]

validObservation :: Observation -> Bool
validObservation item =
    not (unsafeText (observationKey item))
        && not (unsafeObservationValue (observationValue item))

-- | Observation keys occupy one TSV field. Values are the raw payload and may
-- deliberately contain tabs (for example, the source-snapshot path rows), but
-- they may not terminate/inject a record or carry an empty/NUL payload. JSON
-- publication escapes the admitted tabs without changing their bytes.
unsafeObservationValue :: Text -> Bool
unsafeObservationValue value =
    Text.null (Text.strip value)
        || Text.any (`elem` ['\r', '\n', '\0']) value

unsafeText :: Text -> Bool
unsafeText value =
    Text.null (Text.strip value)
        || Text.any (`elem` ['\t', '\r', '\n', '\0']) value

sha256Text :: Text -> Bool
sha256Text value =
    Text.length value == 64
        && Text.all
            ( \character ->
                (character >= '0' && character <= '9')
                    || (character >= 'a' && character <= 'f')
            )
            value
