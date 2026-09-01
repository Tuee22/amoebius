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
    captureFinalizedDispatchCandidateEvidence,
    publishedCandidateEvidence,
    publishedCandidatePath,
    recheckPublishedCandidateEvidence,
    renderGateRow,
    writeAcquiredCandidateEvidence,
) where

import Amoebius.Validation.Gate.Internal qualified as Gate
import Amoebius.Validation.Legacy.Internal (
    GateCompletionPremises,
    GatePrerequisiteObservation,
    LegacyClosure,
    assembleGateCompletionPremises,
    gatePrerequisitePassed,
    gatePrerequisiteRefused,
    gatePrerequisiteUnverified,
    legacyClosureAcquired,
    legacyClosureResult,
 )
import Amoebius.Validation.PhaseZeroRun.Internal (
    AcquiredPhaseZeroRun,
    foldAcquiredPhaseZeroRun,
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
import Data.Aeson (ToJSON (toJSON), Value, encode, object, (.=))
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (intToDigit)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (
    canonicalizePath,
    createDirectory,
    doesDirectoryExist,
    doesPathExist,
    makeAbsolute,
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
    = GenesisPredecessor
    | ImmediatePredecessor Int Text
    | UnverifiedPredecessor Text
    deriving (Eq, Show)

predecessorEvidenceMatchesPhase :: Int -> PredecessorEvidence -> Bool
predecessorEvidenceMatchesPhase phase predecessor = case (phase, predecessor) of
    (0, GenesisPredecessor) -> True
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
        , acquiredSchema = "amoebius-validation-candidate-v2"
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
                    then GenesisPredecessor
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
                , qualificationResidue
                , "UNVERIFIED: toolchain, substrate, lane, architecture, run identity, and cleanup observation are not yet acquired"
                ]
                    <> ["UNVERIFIED: status projection could not be prepared" | projectionDigest == Nothing || projectionPostimageDigest == Nothing]
            }

{- | Production Phase-0 finalization accepts one opaque acquired run.  That
product binds its source/compiler/qualification/debt inputs to a subject
recomputed by their package-hidden owner, so neither the subject nor its
opening identity can be supplied by this function's caller.  Finalization
seals the actual outcomes of the sixteen non-circular rows into
@GateCompletionPremises@, runs the legacy inventory once, and derives @Pass
criterion@ from the resulting seventeen rows.
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
    finalize acquired compilerAttempt qualificationAuthority debtEvidence contractEvidence subjectResult =
        case Policy.mkPhaseOrdinal phase of
            Nothing ->
                finalizeCandidateRows
                    qualifiedBaseCandidate
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
                let premises = gateCompletionPremisesFromRows (captureRows (acquiredCapture qualifiedBaseCandidate))
                    closure =
                        legacyClosureAcquired
                            candidatePhase
                            acquired
                            compilerAttempt
                            debtEvidence
                            contractEvidence
                            premises
                    closureCheck =
                        bindLegacyClosureToCandidateSource
                            opening
                            (snapshotIdentity (acquiredSourceSnapshot acquired))
                            closure
                 in finalizeCandidateRows qualifiedBaseCandidate closureCheck
      where
        opening = snapshotIdentity (acquiredSourceSnapshot acquired)
        closingIdentity = case closing of
            Left _ -> ""
            Right observed -> snapshotIdentity (acquiredSourceSnapshot observed)
        baseCandidate =
            captureDispatchCandidateEvidence
                phase
                opening
                closingIdentity
                projectionDigest
                projectionPostimageDigest
                executablePath
                executableDigest
                argv
                subjectResult
        qualifiedBaseCandidate =
            applyQualificationAuthority
                qualificationAuthority
                (applyClosingSnapshotOutcome closing baseCandidate)
    phase = policyDomainLower

applyClosingSnapshotOutcome ::
    Either [SnapshotProblem] AcquiredSourceSnapshot ->
    AcquiredCandidateEvidence ->
    AcquiredCandidateEvidence
applyClosingSnapshotOutcome closing candidate =
    case closing of
        Right _ -> candidate
        Left problems ->
            candidate
                { acquiredCapture =
                    captured
                        { candidateCaptureRows =
                            map
                                (replaceGateRow FreshnessRow refusedFreshness)
                                (captureRows captured)
                        }
                }
          where
            captured = acquiredCapture candidate
            refusedFreshness =
                GateRowEvidence
                    FreshnessRow
                    (RowRefused [] closingFindings)
            closingFindings =
                case problems of
                    [] ->
                        [ finding
                            "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE"
                            "<local-source-snapshot>"
                            "the closing source-snapshot acquisition refused without a diagnostic"
                        ]
                    _ ->
                        [ finding
                            "SOURCE-SNAPSHOT-CLOSING-UNAVAILABLE"
                            "<local-source-snapshot>"
                            (renderSnapshotProblem problem)
                        | problem <- problems
                        ]
qualificationResidue :: Text
qualificationResidue = "UNVERIFIED: qualification identity is not yet acquired"

applyQualificationAuthority ::
    Either Gate.QualificationProblem Gate.QualifiedValidationProtocol ->
    AcquiredCandidateEvidence ->
    AcquiredCandidateEvidence
applyQualificationAuthority authority candidate =
    candidate
        { acquiredCapture =
            captured
                { candidateCaptureQualificationDigest = qualificationDigest
                , candidateCaptureRows = map (replaceGateRow QualificationRow qualificationRow) (captureRows captured)
                , candidateCaptureResidue = filter (/= qualificationResidue) (captureResidue captured)
                }
        }
  where
    captured = acquiredCapture candidate
    (qualificationDigest, qualificationRow) = case authority of
        Left problem -> refusedQualification problem
        Right protocol ->
            case Gate.bindQualifiedValidationProtocolToCandidate
                (captureSourceOpening captured)
                (captureExecutablePath captured)
                (captureExecutableDigest captured)
                protocol of
                Left problem -> refusedQualification problem
                Right digest ->
                    ( Just digest
                    , GateRowEvidence
                        QualificationRow
                        (RowPassed [observation "qualification.protocol.sha256" digest])
                    )
    refusedQualification problem =
        ( Nothing
        , GateRowEvidence
            QualificationRow
            ( RowRefused
                []
                [ finding
                    (Gate.qualificationProblemCode problem)
                    (Gate.qualificationProblemSubject problem)
                    (Gate.qualificationProblemDetail problem)
                ]
            )
        )

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
                        "the observed process argv is not the exact source-bound validation command"
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
    GenesisPredecessor -> object ["kind" .= ("genesis" :: Text)]
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
        && not (unsafeText (observationValue item))

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
