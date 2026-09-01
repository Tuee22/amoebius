{-# LANGUAGE CPP #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE OverloadedStrings #-}

{- | Package-hidden construction and application of the status-only phase
projection.  Paths, line numbers, and before/after bytes are derived from an
acquired snapshot; no caller supplies an edit or widens the target set.
-}
module Amoebius.Validation.StatusProjection.Internal (
    AppliedStatusProjection,
    AuthorizedStatusProjection,
    ProposedStatusProjection,
    StatusAtomicCutpoint (..),
    JournalCutpoint (..),
    StatusTarget (..),
    applyAuthorizedStatusProjection,
    authorizeStatusProjection,
    prepareStatusProjection,
    projectionDigest,
    projectionPhase,
    projectionPostimageDigest,
    projectionPreimageDigest,
    projectionTargets,
    recoverPendingStatusProjections,
    statusProjectionInternalTestAtomicReplaceAtCutpoint,
    statusProjectionInternalTestAtomicReplaceExact,
    statusProjectionInternalTestDiscoverJournal,
    statusProjectionInternalTestFinalizeJournal,
    statusProjectionInternalTestJournalAtCutpoint,
    statusProjectionInternalTestJournalName,
    statusProjectionInternalTestMarkerReplacement,
    statusProjectionInternalTestRecoveryClassification,
    statusProjectionInternalTestRecoveryRebind,
    statusProjectionInternalTestMixedPhases,
    statusProjectionInternalTestPrepare,
    statusProjectionInternalTestRecoveryStates,
    withStatusProjectionLock,
) where

import Amoebius.Validation.GatePass.Internal (
    VerifiedGatePass,
    recheckVerifiedGatePassPublication,
    verifiedPassPhase,
    verifiedPassProjectionDigest,
    verifiedPassProjectionPostimageDigest,
    verifiedPassSourceDigest,
 )
import Amoebius.Validation.PhaseContract.Internal (
    checkPhaseContractsAfterPass,
 )
import Amoebius.Validation.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Amoebius.Validation.SourceClosure.Internal (
    AcquiredSourceSnapshot,
    GitExecutable,
    GitObjectFormat (..),
    IndexEntry (indexObjectId, indexPath),
    SnapshotProblem,
    SourceSnapshot (..),
    TrackedEntry (..),
    acquiredSourceSnapshot,
    computeBlobObjectId,
    computeSourceSnapshotIdentity,
    loadGitSnapshot,
    renderSnapshotProblem,
 )
import Amoebius.Validation.StatusFrontier qualified as Status
import Amoebius.Validation.Types (
    Finding,
    checkFindings,
    finding,
 )
import Control.Exception (IOException, bracket, finally, onException, try)
import Control.Monad (foldM, forM, unless, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Char (intToDigit, isDigit)
import Data.List (group, sort, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
#if !defined(mingw32_HOST_OS)
import Foreign.C.Error (
    eOK,
    eINTR,
    getErrno,
    resetErrno,
    throwErrno,
    throwErrnoIfMinus1_,
    throwErrnoIfNull,
 )
import Foreign.C.String (CString, withCString)
import Foreign.C.Types (CInt (..), CUInt (..))
import Foreign.Ptr (Ptr, nullPtr)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Storable (peek)
#endif
#if defined(mingw32_HOST_OS)
import System.Directory (
    createDirectory,
    doesDirectoryExist,
    doesFileExist,
    listDirectory,
    pathIsSymbolicLink,
    removeFile,
    renameFile,
 )
#endif
import System.FilePath (
    dropTrailingPathSeparator,
    takeDirectory,
    takeFileName,
    (</>),
 )
import System.IO (SeekMode (AbsoluteSeek), hClose)
#if defined(mingw32_HOST_OS)
import System.IO (
    Handle,
    IOMode (ReadMode),
    hFlush,
    openBinaryTempFile,
    withBinaryFile,
 )
#endif
import System.IO.Error (isAlreadyExistsError, isDoesNotExistError)
#if !defined(mingw32_HOST_OS)
import System.Posix.Files
  ( FileStatus
  , deviceID
  , fileID
  , fileMode
  , fileSize
  , getFdStatus
  , isDirectory
  , isRegularFile
  , ownerReadMode
  , ownerWriteMode
  , setFdMode
  , unionFileModes
  )
import System.Posix.IO
  ( LockRequest (Unlock, WriteLock)
  , OpenFileFlags (cloexec, creat, directory, exclusive, nofollow, nonBlock)
  , OpenMode (ReadOnly, ReadWrite, WriteOnly)
  , closeFd
  , defaultFileFlags
  , dup
  , fdToHandle
  , openFd
  , openFdAt
  , setLock
  )
import System.Posix.IO.ByteString qualified as PosixIOBytes
import System.Posix.Process (getProcessID)
import System.Posix.Types (CMode (..), Fd (..), FileMode)
import System.Posix.Unistd (fileSynchronise)
#endif
import Text.Read (readMaybe)

#if defined(linux_HOST_OS)
foreign import ccall unsafe "renameat2"
    cRenameExchange :: CInt -> CString -> CInt -> CString -> CUInt -> IO CInt
#elif defined(darwin_HOST_OS)
foreign import ccall unsafe "renameatx_np"
    cRenameExchange :: CInt -> CString -> CInt -> CString -> CUInt -> IO CInt
#endif

#if !defined(mingw32_HOST_OS)
data CDirectoryStream
data CDirectoryEntry

foreign import ccall unsafe "unlinkat"
    cUnlinkAt :: CInt -> CString -> CInt -> IO CInt

foreign import ccall unsafe "linkat"
    cLinkAt :: CInt -> CString -> CInt -> CString -> CInt -> IO CInt

foreign import ccall unsafe "mkdirat"
    cMkdirAt :: CInt -> CString -> FileMode -> IO CInt

foreign import ccall unsafe "fdopendir"
    cFdOpenDirectory :: CInt -> IO (Ptr CDirectoryStream)

foreign import ccall unsafe "__hscore_readdir"
    cReadDirectory :: Ptr CDirectoryStream -> Ptr (Ptr CDirectoryEntry) -> IO CInt

foreign import ccall unsafe "__hscore_free_dirent"
    cFreeDirectoryEntry :: Ptr CDirectoryEntry -> IO ()

foreign import ccall unsafe "closedir"
    cCloseDirectory :: Ptr CDirectoryStream -> IO CInt

foreign import ccall unsafe "__hscore_d_name"
    cDirectoryEntryName :: Ptr CDirectoryEntry -> IO CString
#endif

data StatusTarget
    = TrackerPhaseStatus Int
    | PhaseStatus Int
    | SprintHeadingStatus Int Int
    | SprintStatusField Int Int
    deriving (Eq, Ord, Show)

data StatusEdit = StatusEdit
    { editTarget :: StatusTarget
    , editPath :: FilePath
    , editLine :: Int
    , editBeforeLine :: ByteString
    , editAfterLine :: ByteString
    }
    deriving (Eq, Show)

data ProjectionFile = ProjectionFile
    { projectionFilePath :: FilePath
    , projectionFileBefore :: ByteString
    , projectionFileAfter :: ByteString
    }
    deriving (Eq, Show)

data RecoveryFileState
    = RecoveryFileBefore
    | RecoveryFileAfter
    deriving (Eq, Show)

data RecoveryCandidate = RecoveryCandidate
    { recoveryProjection :: ProposedStatusProjection
    , recoveryFileStates :: [RecoveryFileState]
    }
    deriving (Eq, Show)

data RecoveryDisposition
    = RecoveryCanonical [RecoveryCandidate]
    | RecoveryUniqueMixed RecoveryCandidate
    | RecoveryConflict [(Int, [Finding])]
    | RecoveryAmbiguous [RecoveryCandidate]
    deriving (Eq, Show)

data RecoveryAnalysis = RecoveryAnalysis
    { recoveryDisposition :: RecoveryDisposition
    , recoveryDerivationFailures :: [(Int, [Finding])]
    }
    deriving (Eq, Show)

data StatusAtomicCutpoint
    = StatusTemporaryDurable
    | StatusExchangeComplete
    | StatusDirectoriesDurable
    | StatusDisplacedVerified
    | StatusDisplacedUnlinked
    deriving (Eq, Ord, Enum, Bounded, Show)

data JournalCutpoint
    = JournalTemporaryDurable
    | JournalPendingLinked
    | JournalPendingDurable
    | JournalFinalLinked
    | JournalFinalDurable
    | JournalPendingUnlinked
    | JournalFinalizedDurable
    deriving (Eq, Ord, Enum, Bounded, Show)

data JournalOutcome
    = JournalApplied
    | JournalRolledBack
    deriving (Eq, Ord, Show)

#if defined(mingw32_HOST_OS)
data JournalRecord = JournalRecord
    { journalRecordDirectory :: FilePath
    , journalRecordLeaf :: FilePath
    , journalRecordBytes :: ByteString
    }

data PendingJournalMarker = PendingJournalMarker
    { pendingMarkerDirectory :: FilePath
    , pendingMarkerLeaf :: FilePath
    , pendingMarkerLength :: Int
    , pendingMarkerDigest :: ByteString
    }
#else
data JournalRecord = JournalRecord
    { journalRecordDirectory :: FilePath
    , journalRecordLeaf :: FilePath
    , journalRecordBytes :: ByteString
    , journalRecordDirectoryStatus :: FileStatus
    , journalRecordStatus :: FileStatus
    }

data PendingJournalMarker = PendingJournalMarker
    { pendingMarkerDirectory :: FilePath
    , pendingMarkerLeaf :: FilePath
    , pendingMarkerLength :: Int
    , pendingMarkerDigest :: ByteString
    , pendingMarkerDirectoryStatus :: FileStatus
    , pendingMarkerStatus :: FileStatus
    }
#endif

data ProposedStatusProjection = ProposedStatusProjection
    { proposedPhase :: Int
    , proposedRoot :: FilePath
    , proposedPreimageDigest :: Text
    , proposedPostimageDigest :: Text
    , proposedDigest :: Text
    , proposedEdits :: [StatusEdit]
    , proposedFiles :: [ProjectionFile]
    }
    deriving (Eq, Show)

data AuthorizedStatusProjection = AuthorizedStatusProjection
    { authorizedProjectionValue :: ProposedStatusProjection
    , authorizedPassValue :: VerifiedGatePass
    }
    deriving (Eq, Show)

newtype AppliedStatusProjection
    = AppliedStatusProjection AuthorizedStatusProjection
    deriving (Eq, Show)

projectionPhase :: ProposedStatusProjection -> Int
projectionPhase = proposedPhase

projectionPreimageDigest :: ProposedStatusProjection -> Text
projectionPreimageDigest = proposedPreimageDigest

projectionPostimageDigest :: ProposedStatusProjection -> Text
projectionPostimageDigest = proposedPostimageDigest

projectionDigest :: ProposedStatusProjection -> Text
projectionDigest = proposedDigest

projectionTargets :: ProposedStatusProjection -> [StatusTarget]
projectionTargets = map editTarget . proposedEdits

authorizeStatusProjection ::
    VerifiedGatePass ->
    ProposedStatusProjection ->
    Either [Finding] AuthorizedStatusProjection
authorizeStatusProjection verified projection =
    case authorizationProblems of
        [] ->
            Right
                AuthorizedStatusProjection
                    { authorizedProjectionValue = projection
                    , authorizedPassValue = verified
                    }
        problems -> Left problems
  where
    authorizationProblems =
        [ projectionFinding
            "STATUS-PROJECTION-PASS-PHASE"
            "<verified-gate-pass>"
            "the verified gate phase does not match the proposed status transition"
        | verifiedPassPhase verified /= Text.pack (formatOrdinal (proposedPhase projection))
        ]
            <> [ projectionFinding
                    "STATUS-PROJECTION-PASS-SOURCE"
                    "<verified-gate-pass>"
                    "the verified gate source does not match the proposed projection preimage"
               | verifiedPassSourceDigest verified /= proposedPreimageDigest projection
               ]
            <> [ projectionFinding
                    "STATUS-PROJECTION-PASS-DIGEST"
                    "<verified-gate-pass>"
                    "the verified gate did not bind this exact status projection"
               | verifiedPassProjectionDigest verified /= proposedDigest projection
               ]
            <> [ projectionFinding
                    "STATUS-PROJECTION-PASS-POSTIMAGE"
                    "<verified-gate-pass>"
                    "the verified gate did not bind this exact projected whole-source postimage"
               | verifiedPassProjectionPostimageDigest verified /= proposedPostimageDigest projection
               ]

prepareStatusProjection ::
    Int ->
    AcquiredSourceSnapshot ->
    Either [Finding] ProposedStatusProjection
prepareStatusProjection phase =
    prepareStatusProjectionFromSnapshot phase . acquiredSourceSnapshot

prepareStatusProjectionFromSnapshot ::
    Int ->
    SourceSnapshot ->
    Either [Finding] ProposedStatusProjection
prepareStatusProjectionFromSnapshot =
    prepareStatusProjectionWith
        ( \phase entries -> do
            documents <- markdownDocuments entries
            case checkFindings (checkPhaseContractsAfterPass phase documents) of
                [] -> Right ()
                findings -> Left findings
        )

prepareStatusProjectionStructurally ::
    Int ->
    SourceSnapshot ->
    Either [Finding] ProposedStatusProjection
prepareStatusProjectionStructurally = prepareStatusProjectionWith (\_ _ -> Right ())

prepareStatusProjectionWith ::
    (Int -> [TrackedEntry] -> Either [Finding] ()) ->
    Int ->
    SourceSnapshot ->
    Either [Finding] ProposedStatusProjection
prepareStatusProjectionWith postimageCheck phase snapshot = do
    identity <-
        maybe
            (Left [projectionFinding "STATUS-PROJECTION-PHASE" "<phase>" "the closing phase has no typed identity"])
            Right
            (PhaseIdentity.lookupPhaseIdentity phase)
    frontier <-
        maybe
            (Left [projectionFinding "STATUS-PROJECTION-FRONTIER" "<phase>" "the closing phase cannot form a canonical status frontier"])
            Right
            (Status.frontierForGate phase)
    postFrontier <-
        maybe
            (Left [projectionFinding "STATUS-PROJECTION-FRONTIER-ADVANCE" "<phase>" "the closing phase is not the active frontier or cannot advance exactly once"])
            Right
            (Status.frontierAfterPass frontier phase)
    let upper = phaseDomainUpper
        currentPath = PhaseIdentity.phaseIdentityPath identity
        successorIdentity =
            if phase < upper
                then PhaseIdentity.lookupPhaseIdentity (phase + 1)
                else Nothing
        requiredPaths =
            [trackerPath, currentPath]
                <> maybe [] (pure . PhaseIdentity.phaseIdentityPath) successorIdentity
        byteMap =
            Map.fromList
                [ (indexPath (trackedIndex entry), trackedBytes entry)
                | entry <- snapshotEntries snapshot
                ]
        missingPaths = [path | path <- requiredPaths, Map.notMember path byteMap]
    unless
        (null missingPaths)
        ( Left
            [ projectionFinding
                "STATUS-PROJECTION-PREIMAGE-MISSING"
                path
                "a required status-bearing file is absent from the acquired snapshot"
            | path <- missingPaths
            ]
        )
    trackerBytes <- requiredBytes trackerPath byteMap
    currentBytes <- requiredBytes currentPath byteMap
    trackerText <- decodeStatusText trackerPath trackerBytes
    currentText <- decodeStatusText currentPath currentBytes
    trackerEdits <-
        trackerStatusEdits
            trackerText
            [
                ( phase
                , Status.phaseStatusAt frontier phase
                , Status.phaseStatusAt postFrontier phase
                , currentPath
                )
            ]
            >>= \closingEdits -> case successorIdentity of
                Nothing -> Right closingEdits
                Just successor -> do
                    activation <-
                        trackerStatusEdits
                            trackerText
                            [
                                ( phase + 1
                                , Status.phaseStatusAt frontier (phase + 1)
                                , Status.phaseStatusAt postFrontier (phase + 1)
                                , PhaseIdentity.phaseIdentityPath successor
                                )
                            ]
                    Right (closingEdits <> activation)
    currentEdits <-
        phaseFileEdits
            frontier
            phase
            currentPath
            currentText
            (Status.phaseStatusAt frontier phase)
            (Status.phaseStatusAt postFrontier phase)
            Nothing
    successorEdits <- case successorIdentity of
        Nothing -> Right []
        Just successor -> do
            let successorPath = PhaseIdentity.phaseIdentityPath successor
            successorBytes <- requiredBytes successorPath byteMap
            successorText <- decodeStatusText successorPath successorBytes
            phaseFileEdits
                frontier
                (phase + 1)
                successorPath
                successorText
                (Status.phaseStatusAt frontier (phase + 1))
                (Status.phaseStatusAt postFrontier (phase + 1))
                (Just 1)
    let edits = sortEdits (trackerEdits <> currentEdits <> successorEdits)
        targetProblems = projectionTargetProblems phase upper currentText edits
    unless (null targetProblems) (Left targetProblems)
    projectedFiles <- projectFiles byteMap edits
    objectFormat <- snapshotObjectFormat (snapshotEntries snapshot)
    let projectedMap =
            foldr
                (\item -> Map.insert (projectionFilePath item) (projectionFileAfter item))
                byteMap
                projectedFiles
        projectedEntries = map (projectEntry objectFormat projectedMap) (snapshotEntries snapshot)
    let postimageDigest = computeSourceSnapshotIdentity objectFormat projectedEntries
    postimageCheck phase projectedEntries
    let unsigned =
            ProposedStatusProjection
                { proposedPhase = phase
                , proposedRoot = snapshotRoot snapshot
                , proposedPreimageDigest = snapshotIdentity snapshot
                , proposedPostimageDigest = postimageDigest
                , proposedDigest = ""
                , proposedEdits = edits
                , proposedFiles = projectedFiles
                }
        digest = projectionHash unsigned
    Right (unsigned{proposedDigest = digest})

requiredBytes :: FilePath -> Map FilePath ByteString -> Either [Finding] ByteString
requiredBytes path values =
    maybe
        (Left [projectionFinding "STATUS-PROJECTION-PREIMAGE-MISSING" path "required file bytes are absent"])
        Right
        (Map.lookup path values)

trackerStatusEdits ::
    Text ->
    [(Int, Status.PlanStatus, Status.PlanStatus, FilePath)] ->
    Either [Finding] [StatusEdit]
trackerStatusEdits contents changes = traverse one changes
  where
    linesWithNumbers = zip [1 ..] (Text.splitOn "\n" contents)
    one (ordinal, beforeStatus, afterStatus, contractPath) =
        case [ (lineNumber, line)
             | (lineNumber, line) <- linesWithNumbers
             , ("| " <> showText ordinal <> " |") `Text.isPrefixOf` line
             , ("| [Contract](" <> Text.pack (takeFileName contractPath) <> ") |") `Text.isSuffixOf` line
             ] of
            [(lineNumber, line)] ->
                let beforeToken = "| " <> Status.renderTrackerStatus beforeStatus <> " |"
                    afterToken = "| " <> Status.renderTrackerStatus afterStatus <> " |"
                 in if occurrenceCount beforeToken line == 1
                        then
                            Right
                                StatusEdit
                                    { editTarget = TrackerPhaseStatus ordinal
                                    , editPath = trackerPath
                                    , editLine = lineNumber
                                    , editBeforeLine = encode line
                                    , editAfterLine = encode (Text.replace beforeToken afterToken line)
                                    }
                        else
                            Left
                                [ projectionFinding
                                    "STATUS-PROJECTION-TRACKER-PREIMAGE"
                                    trackerPath
                                    ("Phase " <> showText ordinal <> " tracker row does not contain its one exact frontier status")
                                ]
            _ ->
                Left
                    [ projectionFinding
                        "STATUS-PROJECTION-TRACKER-ROW"
                        trackerPath
                        ("Phase " <> showText ordinal <> " must have exactly one canonical tracker row")
                    ]

phaseFileEdits ::
    Status.StatusFrontier ->
    Int ->
    FilePath ->
    Text ->
    Status.PlanStatus ->
    Status.PlanStatus ->
    Maybe Int ->
    Either [Finding] [StatusEdit]
phaseFileEdits frontier ordinal path contents beforeStatus afterStatus onlySprint = do
    phaseEdit <- exactLineEdit (PhaseStatus ordinal) path linesWithNumbers beforePhaseLine afterPhaseLine
    sprintInventory <- sprintHeadings ordinal path linesWithNumbers
    let selected = case onlySprint of
            Nothing -> sprintInventory
            Just sprint -> filter (\(candidate, _, _) -> candidate == sprint) sprintInventory
    unless
        ( not (null selected)
            && maybe
                True
                (\wanted -> length (filter (\(sprint, _, _) -> sprint == wanted) selected) == 1)
                onlySprint
        )
        (Left [projectionFinding "STATUS-PROJECTION-SPRINT-INVENTORY" path "the projected sprint target is absent or duplicated"])
    sprintEdits <- traverse editSprint selected
    Right (phaseEdit : concat sprintEdits)
  where
    linesWithNumbers = zip [1 ..] (Text.splitOn "\n" contents)
    beforePhaseLine = Status.renderPhaseStatusLine beforeStatus
    afterPhaseLine = Status.renderPhaseStatusLine afterStatus
    editSprint (sprint, headingLine, heading) = do
        let beforeSprint = Status.sprintStatusAt frontier ordinal sprint
            actualBefore = case onlySprint of
                Nothing -> beforeSprint
                Just _ -> beforeStatus
            actualAfter = afterStatus
            beforeMarker = Status.renderStatusMarker actualBefore
            afterMarker = Status.renderStatusMarker actualAfter
            beforeSuffix = " " <> beforeMarker
        unless
            (beforeSuffix `Text.isSuffixOf` heading)
            ( Left
                [ projectionFinding
                    "STATUS-PROJECTION-SPRINT-HEADING-PREIMAGE"
                    path
                    ("Sprint " <> showText ordinal <> "." <> showText sprint <> " heading has the wrong frontier marker")
                ]
            )
        let headingEdit =
                StatusEdit
                    { editTarget = SprintHeadingStatus ordinal sprint
                    , editPath = path
                    , editLine = headingLine
                    , editBeforeLine = encode heading
                    , editAfterLine = encode (Text.dropEnd (Text.length beforeSuffix) heading <> " " <> afterMarker)
                    }
            body =
                takeWhile
                    (not . Text.isPrefixOf "## " . snd)
                    (dropWhile ((<= headingLine) . fst) linesWithNumbers)
            expectedStatusLine = "**Status**: " <> Status.renderSprintStatus actualBefore
            replacementStatusLine = "**Status**: " <> Status.renderSprintStatus actualAfter
        statusEdit <-
            exactLineEdit
                (SprintStatusField ordinal sprint)
                path
                body
                expectedStatusLine
                replacementStatusLine
        Right [headingEdit, statusEdit]

sprintHeadings ::
    Int ->
    FilePath ->
    [(Int, Text)] ->
    Either [Finding] [(Int, Int, Text)]
sprintHeadings owner path linesWithNumbers =
    if null parsed || map first parsed /= [1 .. length parsed] || not (null malformed)
        then
            Left
                [ projectionFinding
                    "STATUS-PROJECTION-SPRINT-INVENTORY"
                    path
                    "sprint headings must form one non-empty contiguous canonical inventory"
                ]
        else Right parsed
  where
    candidates =
        [ (lineNumber, line)
        | (lineNumber, line) <- linesWithNumbers
        , ("## Sprint " <> showText owner <> ".") `Text.isPrefixOf` line
        ]
    parsed =
        [ (sprint, lineNumber, line)
        | (lineNumber, line) <- candidates
        , Just sprint <- [parseSprint owner line]
        ]
    malformed = [line | item@(_, line) <- candidates, parseItem item == Nothing]
    parseItem (_, line) = parseSprint owner line
    first (value, _, _) = value

parseSprint :: Int -> Text -> Maybe Int
parseSprint owner line = do
    remainder <- Text.stripPrefix ("## Sprint " <> showText owner <> ".") line
    let (digits, suffix) = Text.span isDigit remainder
    sprint <- readMaybe (Text.unpack digits)
    if digits == showText sprint && sprint > 0 && ": " `Text.isPrefixOf` suffix
        then Just sprint
        else Nothing

exactLineEdit ::
    StatusTarget ->
    FilePath ->
    [(Int, Text)] ->
    Text ->
    Text ->
    Either [Finding] StatusEdit
exactLineEdit target path linesWithNumbers before after =
    case [(lineNumber, line) | (lineNumber, line) <- linesWithNumbers, line == before] of
        [(lineNumber, line)] ->
            Right
                StatusEdit
                    { editTarget = target
                    , editPath = path
                    , editLine = lineNumber
                    , editBeforeLine = encode line
                    , editAfterLine = encode after
                    }
        _ ->
            Left
                [ projectionFinding
                    "STATUS-PROJECTION-LINE-PREIMAGE"
                    path
                    ("status target " <> showText target <> " does not have exactly one expected preimage line")
                ]

projectionTargetProblems :: Int -> Int -> Text -> [StatusEdit] -> [Finding]
projectionTargetProblems phase upper currentPhaseText edits =
    duplicateTargets <> duplicateLoci <> exactSetFinding
  where
    targets = map editTarget edits
    loci = [(editPath edit, editLine edit) | edit <- edits]
    sprintCount = length [() | line <- Text.lines currentPhaseText, ("## Sprint " <> showText phase <> ".") `Text.isPrefixOf` line]
    expected =
        [TrackerPhaseStatus phase, PhaseStatus phase]
            <> concat
                [ [SprintHeadingStatus phase sprint, SprintStatusField phase sprint]
                | sprint <- [1 .. sprintCount]
                ]
            <> if phase < upper
                then
                    [ TrackerPhaseStatus (phase + 1)
                    , PhaseStatus (phase + 1)
                    , SprintHeadingStatus (phase + 1) 1
                    , SprintStatusField (phase + 1) 1
                    ]
                else []
    duplicateTargets =
        [projectionFinding "STATUS-PROJECTION-TARGET-DUPLICATE" "<projection>" ("duplicate target " <> showText target) | target <- duplicates targets]
    duplicateLoci =
        [projectionFinding "STATUS-PROJECTION-LOCUS-DUPLICATE" path ("line " <> showText lineNumber <> " is targeted more than once") | (path, lineNumber) <- duplicates loci]
    exactSetFinding =
        [ projectionFinding
            "STATUS-PROJECTION-TARGET-SET"
            "<projection>"
            ("projection target set differs from the exact frontier transition: expected=" <> showText (sort expected) <> " actual=" <> showText (sort targets))
        | sort targets /= sort expected
        ]

projectFiles ::
    Map FilePath ByteString ->
    [StatusEdit] ->
    Either [Finding] [ProjectionFile]
projectFiles originals edits =
    traverse project (Map.toAscList grouped)
  where
    grouped = Map.fromListWith (<>) [(editPath edit, [edit]) | edit <- edits]
    project (path, pathEdits) = do
        before <- requiredBytes path originals
        after <- applyLineEdits path before pathEdits
        Right (ProjectionFile path before after)

applyLineEdits :: FilePath -> ByteString -> [StatusEdit] -> Either [Finding] ByteString
applyLineEdits path original edits = do
    let originalLines = ByteString.split 10 original
        replacements = Map.fromList [(editLine edit, edit) | edit <- edits]
        lineCount = length originalLines
        outOfRange = [lineNumber | lineNumber <- Map.keys replacements, lineNumber < 1 || lineNumber > lineCount]
    unless
        (null outOfRange)
        (Left [projectionFinding "STATUS-PROJECTION-LINE-RANGE" path ("line is outside the file: " <> showText lineNumber) | lineNumber <- outOfRange])
    projected <- traverse (replaceLine replacements) (zip [1 ..] originalLines)
    Right (ByteString.intercalate (ByteString.singleton 10) projected)
  where
    replaceLine replacements (lineNumber, line) = case Map.lookup lineNumber replacements of
        Nothing -> Right line
        Just edit
            | line == editBeforeLine edit -> Right (editAfterLine edit)
            | otherwise ->
                Left
                    [ projectionFinding
                        "STATUS-PROJECTION-LINE-CHANGED"
                        path
                        ("line " <> showText lineNumber <> " no longer equals the captured preimage")
                    ]

projectEntry :: GitObjectFormat -> Map FilePath ByteString -> TrackedEntry -> TrackedEntry
projectEntry objectFormat projected entry =
    entry
        { trackedIndex =
            (trackedIndex entry)
                { indexObjectId = computeBlobObjectId objectFormat projectedBytes
                }
        , trackedBytes = projectedBytes
        }
  where
    projectedBytes =
        Map.findWithDefault
            (trackedBytes entry)
            (indexPath (trackedIndex entry))
            projected

markdownDocuments :: [TrackedEntry] -> Either [Finding] [(FilePath, Text)]
markdownDocuments entries = traverse decodeEntry markdownEntries
  where
    markdownEntries =
        [ entry
        | entry <- entries
        , ".md" `Text.isSuffixOf` Text.pack (indexPath (trackedIndex entry))
        ]
    decodeEntry entry =
        let path = indexPath (trackedIndex entry)
         in case TextEncoding.decodeUtf8' (trackedBytes entry) of
                Left _ ->
                    Left
                        [ projectionFinding
                            "STATUS-PROJECTION-UTF8"
                            path
                            "tracked Markdown in the projected postimage is not valid UTF-8"
                        ]
                Right contents -> Right (path, contents)

decodeStatusText :: FilePath -> ByteString -> Either [Finding] Text
decodeStatusText path bytes = case TextEncoding.decodeUtf8' bytes of
    Left _ ->
        Left
            [ projectionFinding
                "STATUS-PROJECTION-UTF8"
                path
                "a status-bearing Markdown preimage is not valid UTF-8"
            ]
    Right contents -> Right contents

snapshotObjectFormat :: [TrackedEntry] -> Either [Finding] GitObjectFormat
snapshotObjectFormat entries = case uniqueLengths of
    [40] -> Right GitObjectSha1
    [64] -> Right GitObjectSha256
    _ ->
        Left
            [ projectionFinding
                "STATUS-PROJECTION-OBJECT-FORMAT"
                "<source-snapshot>"
                "tracked object identities do not establish one canonical Git object format"
            ]
  where
    uniqueLengths = Map.keys (Map.fromList [(Text.length (indexObjectId (trackedIndex entry)), ()) | entry <- entries])

projectionHash :: ProposedStatusProjection -> Text
projectionHash projection = hex (SHA256.hash payload)
  where
    payload =
        encodeFields
            ( [ "amoebius-status-projection-v2"
              , encode (showText (proposedPhase projection))
              , encode (Text.pack (proposedRoot projection))
              , encode (proposedPreimageDigest projection)
              , encode (proposedPostimageDigest projection)
              ]
                <> concatMap encodeEdit (proposedEdits projection)
            )
    encodeEdit edit =
        [ encode (showText (editTarget edit))
        , encode (Text.pack (editPath edit))
        , encode (showText (editLine edit))
        , editBeforeLine edit
        , editAfterLine edit
        ]

encodeFields :: [ByteString] -> ByteString
encodeFields = ByteString.concat . map encodeField
  where
    encodeField value = ByteString8.pack (show (ByteString.length value)) <> ":" <> value

{- | Serialize validation processes across the opening capture, gate run,
closing capture, and any status transition.  POSIX record locks are released
by the kernel when a process dies, so a crash cannot strand the lock that is
needed to recover a pending journal on the next invocation.
-}
withStatusProjectionLock ::
    FilePath ->
    IO value ->
    IO (Either [Finding] value)
#if defined(mingw32_HOST_OS)
withStatusProjectionLock _ _ =
  pure
    ( Left
        [ projectionFinding
            "STATUS-PROJECTION-LOCK-UNAVAILABLE"
            "<status-projection-lock>"
            "this build has no crash-releasing status-projection lock implementation"
        ]
    )
#else
withStatusProjectionLock root action = do
  result <-
    tryIOException
      ( withEnsuredDirectoryChain root [".build", "runs"] $ \runsFd ->
          bracket
            (openFdAt (Just runsFd) lockLeaf ReadWrite lockFlags)
            closeFd
            (\descriptor -> do
                setLock descriptor writeLock
                action
                  `finally` ignoreIOException (setLock descriptor unlock)
            )
      )
  pure $ case result of
    Left problem -> Left [ioFinding "STATUS-PROJECTION-LOCK" lockPath problem]
    Right value -> Right value
 where
  lockPath = root </> ".build" </> "runs" </> "status-projection.lock"
  lockLeaf = "status-projection.lock"
  lockFlags =
    defaultFileFlags
      { creat = Just (ownerReadMode `unionFileModes` ownerWriteMode)
      , nofollow = True
      , cloexec = True
      }
  writeLock = (WriteLock, AbsoluteSeek, 0, 0)
  unlock = (Unlock, AbsoluteSeek, 0, 0)
#endif

{- | Recover the only tracked state a killed status writer may leave behind.
The tracked frontier is inspected on every call. Pending files under ignored
@.build@ are diagnostic residue only: their presence, names, and bytes never
select a phase, target, expected byte string, edit, or verdict. Every possible
transition is derived from compiled phase identity and frontier policy against
one fresh tracked-source capture. A unique mixed whole-file transition is
demoted to its preimage; recovery never creates a @Done@ status or reconstructs
pass authority.
-}
recoverPendingStatusProjections ::
    GitExecutable ->
    FilePath ->
    IO (Either [Finding] Int)
recoverPendingStatusProjections git root = do
    discovered <- try (discoverPendingJournalPaths root)
    case discovered of
        Left problem ->
            pure
                ( Left
                    [ ioFinding
                        "STATUS-PROJECTION-RECOVERY-DISCOVERY"
                        (root </> ".build" </> "runs")
                        problem
                    ]
                )
        Right paths -> do
            liveResult <- loadGitSnapshot git root
            case liveResult of
                Left problems -> pure (Left (map snapshotProblemFinding problems))
                Right live -> do
                    let snapshot = acquiredSourceSnapshot live
                    let analysis = analyzeRecoverySnapshot snapshot
                    case recoveryDisposition analysis of
                        RecoveryUniqueMixed candidate ->
                            recoverMixedStatusProjection git root paths candidate
                        RecoveryCanonical _ -> do
                            cleared <- clearPendingJournalMarkers paths
                            pure (0 <$ cleared)
                        RecoveryConflict failures ->
                            pure
                                ( Left
                                    ( projectionFinding
                                        "STATUS-PROJECTION-RECOVERY-NONCANONICAL"
                                        "<tracked-status-frontier>"
                                        "fresh tracked source is not any compiled all-before, all-after, or mixed frontier transition"
                                        : map recoveryDerivationFinding failures
                                    )
                                )
                        RecoveryAmbiguous ambiguous ->
                            pure
                                ( Left
                                    [ projectionFinding
                                        "STATUS-PROJECTION-RECOVERY-AMBIGUOUS"
                                        "<tracked-status-frontier>"
                                        ( "the tracked source matches more than one mixed compiled transition: "
                                            <> Text.intercalate
                                                ","
                                                [ showText (proposedPhase (recoveryProjection candidate))
                                                | candidate <- ambiguous
                                                ]
                                        )
                                    ]
                                )

discoverPendingJournalPaths :: FilePath -> IO [PendingJournalMarker]
#if defined(mingw32_HOST_OS)
discoverPendingJournalPaths _ =
    fail "status-projection-recovery-is-unavailable-without-the-posix-status-lock"
#else
discoverPendingJournalPaths root = do
    withAbsoluteDirectoryFdNoFollow root $ \rootFd -> do
        runs <-
            withOptionalRelativeDirectoryChainAt rootFd [".build", "runs"] $ \runsFd ->
                foldM (discoverPhase runsFd) [] [phaseDomainLower .. phaseDomainUpper]
        pure (maybe [] id runs)
  where
    discoverPhase runsFd accumulated phase = do
        let relative = ["phase-" <> formatOrdinal phase, "status-projections"]
            directory =
                root
                    </> ".build"
                    </> "runs"
                    </> ("phase-" <> formatOrdinal phase)
                    </> "status-projections"
        discovered <-
            withOptionalRelativeDirectoryChainAt runsFd relative $ \directoryFd ->
                discoverPendingJournalMarkersAt directory directoryFd
        let combined = accumulated <> maybe [] id discovered
        when
            (length combined > maximumPendingJournalMarkers)
            (fail "status-projection-pending-journal-aggregate-limit")
        pure combined
#endif

discoverPendingJournalMarkers :: FilePath -> IO [PendingJournalMarker]
#if defined(mingw32_HOST_OS)
discoverPendingJournalMarkers _ =
    fail "status-projection-recovery-is-unavailable-without-the-posix-status-lock"
#else
discoverPendingJournalMarkers directory =
    withAbsoluteDirectoryFdNoFollow directory $ \directoryFd -> do
        discoverPendingJournalMarkersAt directory directoryFd
#endif

#if !defined(mingw32_HOST_OS)
discoverPendingJournalMarkersAt :: FilePath -> Fd -> IO [PendingJournalMarker]
discoverPendingJournalMarkersAt directory directoryFd = do
    entries <- listJournalDirectoryEntriesAt directoryFd
    mapM_ validateRecognizedJournalLeaf entries
    pruneFinalizedJournalMarkersFromEntriesAt directoryFd Nothing entries
    fileSynchronise directoryFd
    directoryStatus <- verifiedDirectoryStatus directoryFd
    forM (sort (filter isPendingJournalLeaf entries)) $ \leaf -> do
        (status, bytes) <- readRegularStatusAt directoryFd leaf (maximumJournalBytes + 1)
        when (ByteString.length bytes > maximumJournalBytes) (fail "status-projection-journal-byte-limit")
        pure
            PendingJournalMarker
                { pendingMarkerDirectory = directory
                , pendingMarkerLeaf = leaf
                , pendingMarkerLength = ByteString.length bytes
                , pendingMarkerDigest = SHA256.hash bytes
                , pendingMarkerDirectoryStatus = directoryStatus
                , pendingMarkerStatus = status
                }
#endif

analyzeRecoverySnapshot :: SourceSnapshot -> RecoveryAnalysis
analyzeRecoverySnapshot =
    analyzeRecoverySnapshotWith prepareStatusProjectionStructurally

analyzeRecoverySnapshotWith ::
    (Int -> SourceSnapshot -> Either [Finding] ProposedStatusProjection) ->
    SourceSnapshot ->
    RecoveryAnalysis
analyzeRecoverySnapshotWith prepare snapshot =
    RecoveryAnalysis
        { recoveryDisposition = disposition
        , recoveryDerivationFailures = failures
        }
  where
    attempts =
        [ (phase, deriveRecoveryCandidateWith prepare phase snapshot)
        | phase <- [phaseDomainLower .. phaseDomainUpper]
        ]
    candidates = [candidate | (_, Right candidate) <- attempts]
    failures = [(phase, problems) | (phase, Left problems) <- attempts]
    mixed = filter isMixedRecoveryCandidate candidates
    disposition = case mixed of
        [candidate] -> RecoveryUniqueMixed candidate
        []
            | null candidates -> RecoveryConflict failures
            | otherwise -> RecoveryCanonical candidates
        ambiguous -> RecoveryAmbiguous ambiguous

recoveryDerivationFinding :: (Int, [Finding]) -> Finding
recoveryDerivationFinding (phase, problems) =
    projectionFinding
        "STATUS-PROJECTION-RECOVERY-DERIVATION"
        "<tracked-status-frontier>"
        ( "phase="
            <> showText phase
            <> "; findings="
            <> showText problems
        )

mixedRecoveryCandidatesWith ::
    (Int -> SourceSnapshot -> Either [Finding] ProposedStatusProjection) ->
    SourceSnapshot ->
    [RecoveryCandidate]
mixedRecoveryCandidatesWith prepare =
    filter isMixedRecoveryCandidate . recoveryCandidatesWith prepare

recoveryCandidatesWith ::
    (Int -> SourceSnapshot -> Either [Finding] ProposedStatusProjection) ->
    SourceSnapshot ->
    [RecoveryCandidate]
recoveryCandidatesWith prepare snapshot =
    [ candidate
    | phase <- [phaseDomainLower .. phaseDomainUpper]
    , Right candidate <- [deriveRecoveryCandidateWith prepare phase snapshot]
    ]

isMixedRecoveryCandidate :: RecoveryCandidate -> Bool
isMixedRecoveryCandidate candidate =
    RecoveryFileBefore `elem` recoveryFileStates candidate
        && RecoveryFileAfter `elem` recoveryFileStates candidate

-- Test-only projections expose no acquired, verified, authorized, applied, or
-- publication token.  They let the independent direct-source oracle exercise
-- the pure recovery classifier against synthetic tracked snapshots.
statusProjectionInternalTestPrepare ::
    Int ->
    SourceSnapshot ->
    Either [Finding] [(FilePath, ByteString, ByteString)]
statusProjectionInternalTestPrepare phase snapshot = do
    projection <- prepareStatusProjectionStructurally phase snapshot
    Right
        [ (projectionFilePath item, projectionFileBefore item, projectionFileAfter item)
        | item <- proposedFiles projection
        ]

statusProjectionInternalTestMixedPhases :: SourceSnapshot -> [Int]
statusProjectionInternalTestMixedPhases snapshot =
    [ proposedPhase (recoveryProjection candidate)
    | candidate <-
        mixedRecoveryCandidatesWith
            prepareStatusProjectionStructurally
            snapshot
    ]

statusProjectionInternalTestRecoveryStates :: SourceSnapshot -> [(Int, [Text])]
statusProjectionInternalTestRecoveryStates snapshot =
    [ ( proposedPhase (recoveryProjection candidate)
      , map renderState (recoveryFileStates candidate)
      )
    | candidate <-
        recoveryCandidatesWith
            prepareStatusProjectionStructurally
            snapshot
    ]
  where
    renderState RecoveryFileBefore = "before"
    renderState RecoveryFileAfter = "after"

statusProjectionInternalTestRecoveryClassification ::
    SourceSnapshot ->
    (Text, [Int], [(Int, Int)])
statusProjectionInternalTestRecoveryClassification snapshot =
    renderRecoveryAnalysis (analyzeRecoverySnapshot snapshot)

renderRecoveryAnalysis :: RecoveryAnalysis -> (Text, [Int], [(Int, Int)])
renderRecoveryAnalysis analysis =
    case recoveryDisposition analysis of
        RecoveryCanonical candidates ->
            ("canonical", map candidatePhase candidates, failures)
        RecoveryUniqueMixed candidate ->
            ("unique-mixed", [candidatePhase candidate], failures)
        RecoveryConflict _ ->
            ("conflict", [], failures)
        RecoveryAmbiguous candidates ->
            ("ambiguous", map candidatePhase candidates, failures)
  where
    candidatePhase = proposedPhase . recoveryProjection
    failures =
        [ (phase, length problems)
        | (phase, problems) <- recoveryDerivationFailures analysis
        ]

statusProjectionInternalTestRecoveryRebind ::
    SourceSnapshot ->
    SourceSnapshot ->
    (Text, Bool)
statusProjectionInternalTestRecoveryRebind opening closing =
    case recoveryDisposition (analyzeRecoverySnapshot opening) of
        RecoveryUniqueMixed expected ->
            case recoveryDisposition (analyzeRecoverySnapshot closing) of
                RecoveryUniqueMixed observed -> ("unique-mixed", observed == expected)
                RecoveryCanonical _ -> ("canonical", False)
                RecoveryConflict _ -> ("conflict", False)
                RecoveryAmbiguous _ -> ("ambiguous", False)
        RecoveryCanonical _ -> ("opening-canonical", False)
        RecoveryConflict _ -> ("opening-conflict", False)
        RecoveryAmbiguous _ -> ("opening-ambiguous", False)

-- The direct-source oracle can exercise the leaf compare-and-exchange
-- primitive without obtaining projection or gate-pass authority.
statusProjectionInternalTestAtomicReplaceExact ::
    FilePath ->
    ByteString ->
    ByteString ->
    IO (Either [Finding] ())
statusProjectionInternalTestAtomicReplaceExact destination expected bytes = do
    scratchResult <- statusExchangeDirectory (takeDirectory destination)
    case scratchResult of
        Left problems -> pure (Left problems)
        Right scratch -> atomicReplaceExact scratch destination expected bytes

statusProjectionInternalTestAtomicReplaceAtCutpoint ::
    StatusAtomicCutpoint ->
    FilePath ->
    ByteString ->
    ByteString ->
    IO (Either [Finding] ())
statusProjectionInternalTestAtomicReplaceAtCutpoint selected destination expected bytes = do
    scratchResult <- statusExchangeDirectory (takeDirectory destination)
    case scratchResult of
        Left problems -> pure (Left problems)
        Right scratch ->
            atomicReplaceExactWith
                ( \observed ->
                    when
                        (observed == selected)
                        (ioError (userError ("status-projection-test-cutpoint:" <> show selected)))
                )
                scratch
                destination
                expected
                bytes

recoverMixedStatusProjection ::
    GitExecutable ->
    FilePath ->
    [PendingJournalMarker] ->
    RecoveryCandidate ->
    IO (Either [Finding] Int)
recoverMixedStatusProjection git root pending candidate = do
    let projection = recoveryProjection candidate
    freshResult <- loadGitSnapshot git root
    case freshResult of
        Left problems -> pure (Left (map snapshotProblemFinding problems))
        Right fresh ->
            case recoveryDisposition (analyzeRecoverySnapshot (acquiredSourceSnapshot fresh)) of
                RecoveryUniqueMixed rebound
                    | rebound == candidate -> do
                        rollbackResult <- rollbackFiles root (proposedFiles projection)
                        case rollbackResult of
                            Left problems -> pure (Left problems)
                            Right () -> do
                                closingResult <- loadGitSnapshot git root
                                case closingResult of
                                    Left problems -> pure (Left (map snapshotProblemFinding problems))
                                    Right closing
                                        | snapshotIdentity (acquiredSourceSnapshot closing)
                                            /= proposedPreimageDigest projection ->
                                            pure
                                                ( Left
                                                    [ projectionFinding
                                                        "STATUS-PROJECTION-RECOVERY-POSTIMAGE"
                                                        "<source-snapshot>"
                                                        "recovery rolled back target files, but a fresh complete capture does not equal the compiled preimage"
                                                    ]
                                                )
                                        | otherwise -> do
                                            cleared <- clearPendingJournalMarkers pending
                                            pure (1 <$ cleared)
                _ ->
                    pure
                        ( Left
                            [ projectionFinding
                                "STATUS-PROJECTION-RECOVERY-STALE"
                                "<tracked-status-frontier>"
                                "the unique mixed transition changed before rollback acquired write authority"
                            ]
                        )

deriveRecoveryCandidateWith ::
    (Int -> SourceSnapshot -> Either [Finding] ProposedStatusProjection) ->
    Int ->
    SourceSnapshot ->
    Either [Finding] RecoveryCandidate
deriveRecoveryCandidateWith prepare phase snapshot = do
    identity <-
        maybe
            (Left [projectionFinding "STATUS-PROJECTION-RECOVERY-PHASE" "<phase>" "the candidate phase has no typed identity"])
            Right
            (PhaseIdentity.lookupPhaseIdentity phase)
    frontier <-
        maybe
            (Left [projectionFinding "STATUS-PROJECTION-RECOVERY-FRONTIER" "<phase>" "the candidate phase has no compiled frontier"])
            Right
            (Status.frontierForGate phase)
    postFrontier <-
        maybe
            (Left [projectionFinding "STATUS-PROJECTION-RECOVERY-ADVANCE" "<phase>" "the candidate phase cannot advance exactly once"])
            Right
            (Status.frontierAfterPass frontier phase)
    let currentPath = PhaseIdentity.phaseIdentityPath identity
        successorIdentity =
            if phase < phaseDomainUpper
                then PhaseIdentity.lookupPhaseIdentity (phase + 1)
                else Nothing
        byteMap =
            Map.fromList
                [ (indexPath (trackedIndex entry), trackedBytes entry)
                | entry <- snapshotEntries snapshot
                ]
    trackerBytes <- requiredBytes trackerPath byteMap
    currentBytes <- requiredBytes currentPath byteMap
    trackerText <- decodeStatusText trackerPath trackerBytes
    currentText <- decodeStatusText currentPath currentBytes
    trackerEdits <-
        trackerRecoveryEdits
            trackerText
            [ (phase, Status.phaseStatusAt frontier phase, Status.phaseStatusAt postFrontier phase, currentPath)
            ]
            >>= \closingEdits -> case successorIdentity of
                Nothing -> Right closingEdits
                Just successor -> do
                    activation <-
                        trackerRecoveryEdits
                            trackerText
                            [
                                ( phase + 1
                                , Status.phaseStatusAt frontier (phase + 1)
                                , Status.phaseStatusAt postFrontier (phase + 1)
                                , PhaseIdentity.phaseIdentityPath successor
                                )
                            ]
                    Right (closingEdits <> activation)
    currentEdits <-
        phaseFileRecoveryEdits
            frontier
            phase
            currentPath
            currentText
            (Status.phaseStatusAt frontier phase)
            (Status.phaseStatusAt postFrontier phase)
            Nothing
    successorEdits <- case successorIdentity of
        Nothing -> Right []
        Just successor -> do
            let successorPath = PhaseIdentity.phaseIdentityPath successor
            successorBytes <- requiredBytes successorPath byteMap
            successorText <- decodeStatusText successorPath successorBytes
            phaseFileRecoveryEdits
                frontier
                (phase + 1)
                successorPath
                successorText
                (Status.phaseStatusAt frontier (phase + 1))
                (Status.phaseStatusAt postFrontier (phase + 1))
                (Just 1)
    restoredFiles <- projectFiles byteMap (sortEdits (trackerEdits <> currentEdits <> successorEdits))
    objectFormat <- snapshotObjectFormat (snapshotEntries snapshot)
    let restoredMap =
            Map.fromList
                [ (projectionFilePath item, projectionFileAfter item)
                | item <- restoredFiles
                ]
        restoredEntries = map (projectEntry objectFormat restoredMap) (snapshotEntries snapshot)
        restoredSnapshot =
            SourceSnapshot
                { snapshotRoot = snapshotRoot snapshot
                , snapshotIdentity = computeSourceSnapshotIdentity objectFormat restoredEntries
                , snapshotEntries = restoredEntries
                }
    derived <- prepare phase restoredSnapshot
    states <- traverse (classifyRecoveryFile byteMap) (proposedFiles derived)
    Right RecoveryCandidate{recoveryProjection = derived, recoveryFileStates = states}

trackerRecoveryEdits ::
    Text ->
    [(Int, Status.PlanStatus, Status.PlanStatus, FilePath)] ->
    Either [Finding] [StatusEdit]
trackerRecoveryEdits contents changes = traverse one changes
  where
    linesWithNumbers = zip [1 ..] (Text.splitOn "\n" contents)
    one (ordinal, beforeStatus, afterStatus, contractPath) =
        case [ (lineNumber, line)
             | (lineNumber, line) <- linesWithNumbers
             , ("| " <> showText ordinal <> " |") `Text.isPrefixOf` line
             , ("| [Contract](" <> Text.pack (takeFileName contractPath) <> ") |") `Text.isSuffixOf` line
             ] of
            [(lineNumber, line)] -> do
                let beforeToken = "| " <> Status.renderTrackerStatus beforeStatus <> " |"
                    afterToken = "| " <> Status.renderTrackerStatus afterStatus <> " |"
                restored <- restoreToken trackerPath line beforeToken afterToken
                Right
                    StatusEdit
                        { editTarget = TrackerPhaseStatus ordinal
                        , editPath = trackerPath
                        , editLine = lineNumber
                        , editBeforeLine = encode line
                        , editAfterLine = encode restored
                        }
            _ -> Left [projectionFinding "STATUS-PROJECTION-RECOVERY-TRACKER" trackerPath "a compiled tracker row is absent or duplicated"]

phaseFileRecoveryEdits ::
    Status.StatusFrontier ->
    Int ->
    FilePath ->
    Text ->
    Status.PlanStatus ->
    Status.PlanStatus ->
    Maybe Int ->
    Either [Finding] [StatusEdit]
phaseFileRecoveryEdits frontier ordinal path contents beforeStatus afterStatus onlySprint = do
    phaseEdit <-
        recoveryExactLineEdit
            (PhaseStatus ordinal)
            path
            linesWithNumbers
            (Status.renderPhaseStatusLine beforeStatus)
            (Status.renderPhaseStatusLine afterStatus)
    sprintInventory <- sprintHeadings ordinal path linesWithNumbers
    let selected = case onlySprint of
            Nothing -> sprintInventory
            Just sprint -> filter (\(candidate, _, _) -> candidate == sprint) sprintInventory
    unless
        ( not (null selected)
            && maybe True (\wanted -> length (filter (\(sprint, _, _) -> sprint == wanted) selected) == 1) onlySprint
        )
        (Left [projectionFinding "STATUS-PROJECTION-RECOVERY-SPRINT-INVENTORY" path "the compiled recovery sprint target is absent or duplicated"])
    sprintEdits <- traverse editSprint selected
    Right (phaseEdit : concat sprintEdits)
  where
    linesWithNumbers = zip [1 ..] (Text.splitOn "\n" contents)
    editSprint (sprint, headingLine, heading) = do
        let beforeSprint = Status.sprintStatusAt frontier ordinal sprint
            actualBefore = maybe beforeSprint (const beforeStatus) onlySprint
            actualAfter = afterStatus
            beforeMarker = Status.renderStatusMarker actualBefore
            afterMarker = Status.renderStatusMarker actualAfter
            beforeSuffix = " " <> beforeMarker
            afterSuffix = " " <> afterMarker
        restoredHeading <- restoreSuffix path heading beforeSuffix afterSuffix
        let headingEdit =
                StatusEdit
                    { editTarget = SprintHeadingStatus ordinal sprint
                    , editPath = path
                    , editLine = headingLine
                    , editBeforeLine = encode heading
                    , editAfterLine = encode restoredHeading
                    }
            body =
                takeWhile
                    (not . Text.isPrefixOf "## " . snd)
                    (dropWhile ((<= headingLine) . fst) linesWithNumbers)
        statusEdit <-
            recoveryExactLineEdit
                (SprintStatusField ordinal sprint)
                path
                body
                ("**Status**: " <> Status.renderSprintStatus actualBefore)
                ("**Status**: " <> Status.renderSprintStatus actualAfter)
        Right [headingEdit, statusEdit]

recoveryExactLineEdit ::
    StatusTarget ->
    FilePath ->
    [(Int, Text)] ->
    Text ->
    Text ->
    Either [Finding] StatusEdit
recoveryExactLineEdit target path linesWithNumbers before after =
    case [(lineNumber, line) | (lineNumber, line) <- linesWithNumbers, line == before || line == after] of
        [(lineNumber, line)] ->
            Right
                StatusEdit
                    { editTarget = target
                    , editPath = path
                    , editLine = lineNumber
                    , editBeforeLine = encode line
                    , editAfterLine = encode before
                    }
        _ -> Left [projectionFinding "STATUS-PROJECTION-RECOVERY-LINE" path ("status target " <> showText target <> " is neither one exact compiled before nor after line")]

restoreToken :: FilePath -> Text -> Text -> Text -> Either [Finding] Text
restoreToken path line before after
    | occurrenceCount before line == 1 && occurrenceCount after line == 0 = Right line
    | occurrenceCount before line == 0 && occurrenceCount after line == 1 = Right (Text.replace after before line)
    | otherwise = Left [projectionFinding "STATUS-PROJECTION-RECOVERY-TOKEN" path "a status token is neither the unique compiled before nor after value"]

restoreSuffix :: FilePath -> Text -> Text -> Text -> Either [Finding] Text
restoreSuffix path line before after
    | before `Text.isSuffixOf` line && not (after `Text.isSuffixOf` line) = Right line
    | after `Text.isSuffixOf` line && not (before `Text.isSuffixOf` line) =
        Right (Text.dropEnd (Text.length after) line <> before)
    | otherwise = Left [projectionFinding "STATUS-PROJECTION-RECOVERY-SUFFIX" path "a sprint heading is neither the compiled before nor after value"]

classifyRecoveryFile ::
    Map FilePath ByteString ->
    ProjectionFile ->
    Either [Finding] RecoveryFileState
classifyRecoveryFile current item = do
    bytes <- requiredBytes (projectionFilePath item) current
    if bytes == projectionFileBefore item
        then Right RecoveryFileBefore
        else
            if bytes == projectionFileAfter item
                then Right RecoveryFileAfter
                else
                    Left
                        [ projectionFinding
                            "STATUS-PROJECTION-RECOVERY-FILE"
                            (projectionFilePath item)
                            "a target file is not one exact compiled whole-file before or after image"
                        ]

clearPendingJournalMarkers :: [PendingJournalMarker] -> IO (Either [Finding] ())
clearPendingJournalMarkers paths = do
    result <- try $ do
        mapM_ clear paths
    pure $ case result of
        Left problem -> Left [ioFinding "STATUS-PROJECTION-RECOVERY-MARKER" "<pending-status-projection>" problem]
        Right () -> Right ()
  where
    clear marker = clearPendingJournalMarker marker

clearPendingJournalMarker :: PendingJournalMarker -> IO ()
#if defined(mingw32_HOST_OS)
clearPendingJournalMarker marker = do
    let path = pendingMarkerDirectory marker </> pendingMarkerLeaf marker
    bytes <- readBoundedRegularPathNoFollow path (pendingMarkerLength marker + 1)
    unless
        ( ByteString.length bytes == pendingMarkerLength marker
            && SHA256.hash bytes == pendingMarkerDigest marker
        )
        (fail "status-projection-recovery-marker-changed")
    removeFile path
    synchroniseDirectory (pendingMarkerDirectory marker)
#else
clearPendingJournalMarker marker =
    withAbsoluteDirectoryFdNoFollow (pendingMarkerDirectory marker) $ \directoryFd -> do
        validatePendingJournalLeaf (pendingMarkerLeaf marker)
        directoryStatus <- verifiedDirectoryStatus directoryFd
        unless
            (sameObjectIdentity directoryStatus (pendingMarkerDirectoryStatus marker))
            (fail "status-projection-recovery-marker-directory-rebound")
        (status, bytes) <-
            readRegularStatusAt
                directoryFd
                (pendingMarkerLeaf marker)
                (pendingMarkerLength marker + 1)
        unless
            ( sameStatusFile status (pendingMarkerStatus marker)
                && ByteString.length bytes == pendingMarkerLength marker
                && SHA256.hash bytes == pendingMarkerDigest marker
            )
            (fail "status-projection-recovery-marker-changed")
        quarantineAndRemoveRegularStatusAt
            directoryFd
            (pendingMarkerLeaf marker)
            status
            bytes
        fileSynchronise directoryFd
#endif

applyAuthorizedStatusProjection ::
    GitExecutable ->
    AuthorizedStatusProjection ->
    IO (Either [Finding] AppliedStatusProjection)
applyAuthorizedStatusProjection git authorized = do
    publication <- recheckVerifiedGatePassPublication (authorizedPassValue authorized)
    case publication of
        Left problems -> pure (Left problems)
        Right () -> applyAfterPublicationCheck
  where
    projection = authorizedProjectionValue authorized

    applyAfterPublicationCheck = do
        livePreimage <- loadGitSnapshot git (proposedRoot projection)
        case livePreimage of
            Left problems -> pure (Left (map snapshotProblemFinding problems))
            Right acquired
                | snapshotIdentity (acquiredSourceSnapshot acquired) /= proposedPreimageDigest projection ->
                    pure
                        ( Left
                            [ projectionFinding
                                "STATUS-PROJECTION-STALE-PREIMAGE"
                                "<source-snapshot>"
                                "a fresh live capture no longer equals the gate-bound projection preimage"
                            ]
                        )
                | otherwise -> do
                    journalResult <- writeJournal (proposedRoot projection) authorized
                    case journalResult of
                        Left problems -> pure (Left problems)
                        Right journal -> do
                            applyResult <- applyFiles (proposedRoot projection) (proposedFiles projection)
                            case applyResult of
                                Left problems -> rollbackAfterFailure git journal projection problems
                                Right () -> do
                                    livePostimage <- loadGitSnapshot git (proposedRoot projection)
                                    case livePostimage of
                                        Left problems -> rollbackAfterFailure git journal projection (map snapshotProblemFinding problems)
                                        Right closing ->
                                            case confirmAppliedStatusProjection closing authorized of
                                                Left problems -> rollbackAfterFailure git journal projection problems
                                                Right applied -> do
                                                    finalized <- finalizeJournal journal JournalApplied
                                                    pure (applied <$ finalized)

rollbackAfterFailure ::
    GitExecutable ->
    JournalRecord ->
    ProposedStatusProjection ->
    [Finding] ->
    IO (Either [Finding] AppliedStatusProjection)
rollbackAfterFailure git journal projection originalProblems = do
    rollbackResult <- rollbackFiles (proposedRoot projection) (proposedFiles projection)
    closing <- loadGitSnapshot git (proposedRoot projection)
    let rollbackProblems = case rollbackResult of
            Left problems -> problems
            Right () -> []
        closingProblems = case closing of
            Left problems -> map snapshotProblemFinding problems
            Right acquired ->
                [ projectionFinding
                    "STATUS-PROJECTION-ROLLBACK-SNAPSHOT"
                    "<source-snapshot>"
                    "status files were rolled back, but the complete live source does not equal the captured preimage"
                | snapshotIdentity (acquiredSourceSnapshot acquired) /= proposedPreimageDigest projection
                ]
    journalResult <-
        if null rollbackProblems && null closingProblems
            then finalizeJournal journal JournalRolledBack
            else pure (Right ())
    let journalProblems = either id (const []) journalResult
    pure (Left (originalProblems <> rollbackProblems <> closingProblems <> journalProblems))

writeJournal ::
    FilePath ->
    AuthorizedStatusProjection ->
    IO (Either [Finding] JournalRecord)
writeJournal root authorized = do
    let directory = journalDirectory root projection
        leaf = journalLeaf projection "journal"
        path = directory </> leaf
        bytes = projectionJournalBytes projection
    result <- try (writeJournalPrepared root projection directory leaf bytes)
    pure $ case result of
        Left problem -> Left [ioFinding "STATUS-PROJECTION-JOURNAL" path problem]
        Right record -> Right record
  where
    projection = authorizedProjectionValue authorized

writeJournalPrepared ::
    FilePath ->
    ProposedStatusProjection ->
    FilePath ->
    FilePath ->
    ByteString ->
    IO JournalRecord
#if defined(mingw32_HOST_OS)
writeJournalPrepared root projection directory leaf bytes = do
    ensureDirectoryChain root [".build", "runs", "phase-" <> formatOrdinal (proposedPhase projection), "status-projections"]
    writeJournalRecordAtWith (\_ -> pure ()) directory leaf bytes
#else
writeJournalPrepared root projection directory leaf bytes =
    withEnsuredDirectoryChain
        root
        [".build", "runs", "phase-" <> formatOrdinal (proposedPhase projection), "status-projections"]
        (\directoryFd -> writeJournalRecordAtFdWith (\_ -> pure ()) directory directoryFd leaf bytes)
#endif

finalizeJournal :: JournalRecord -> JournalOutcome -> IO (Either [Finding] ())
finalizeJournal record outcome = do
    result <- try (finalizeJournalRecordAtWith (\_ -> pure ()) record outcome)
    pure $ case result of
        Left problem ->
            Left
                [ ioFinding
                    "STATUS-PROJECTION-JOURNAL-FINALIZE"
                    (journalRecordDirectory record </> journalRecordLeaf record)
                    problem
                ]
        Right () -> Right ()

journalDirectory :: FilePath -> ProposedStatusProjection -> FilePath
journalDirectory root projection =
    root
        </> ".build"
        </> "runs"
        </> ("phase-" <> formatOrdinal (proposedPhase projection))
        </> "status-projections"

journalLeaf :: ProposedStatusProjection -> String -> FilePath
journalLeaf projection suffix =
    Text.unpack (proposedDigest projection) <> "." <> suffix

journalOutcomeSuffix :: JournalOutcome -> String
journalOutcomeSuffix JournalApplied = "applied"
journalOutcomeSuffix JournalRolledBack = "rolled-back"

journalFinalLeaf :: FilePath -> JournalOutcome -> Maybe FilePath
journalFinalLeaf pending outcome =
    case Text.stripSuffix ".journal" (Text.pack pending) of
        Nothing -> Nothing
        Just stem
            | isPendingJournalLeaf pending ->
                Just (Text.unpack stem <> "." <> journalOutcomeSuffix outcome)
            | otherwise -> Nothing

projectionJournalBytes :: ProposedStatusProjection -> ByteString
projectionJournalBytes projection =
    encodeFields
        ( [ "amoebius-status-projection-journal-v2"
          , encode (proposedDigest projection)
          , encode (showText (proposedPhase projection))
          , encode (Text.pack (proposedRoot projection))
          , encode (proposedPreimageDigest projection)
          , encode (proposedPostimageDigest projection)
          , encode (showText (length (proposedFiles projection)))
          ]
            <> concatMap encodeFile (proposedFiles projection)
        )
  where
    encodeFile item =
        [ encode (Text.pack (projectionFilePath item))
        , projectionFileBefore item
        , projectionFileAfter item
        ]

ensureDirectoryChain :: FilePath -> [FilePath] -> IO ()
#if defined(mingw32_HOST_OS)
ensureDirectoryChain = go
  where
    go _ [] = pure ()
    go parent (component : rest) = do
        let candidate = parent </> component
        present <- doesFileExist candidate
        directoryPresent <- doesDirectoryExist candidate
        if present || directoryPresent
            then do
                linked <- pathIsSymbolicLink candidate
                when linked (fail "status-projection-directory-is-symbolic-link")
                unless directoryPresent (fail "status-projection-path-component-is-not-directory")
            else do
                createDirectory candidate
                synchroniseDirectory parent
                synchroniseDirectory candidate
        go candidate rest
#else
ensureDirectoryChain root components =
    withEnsuredDirectoryChain root components (\_ -> pure ())
#endif

writeJournalRecordAtWith ::
    (JournalCutpoint -> IO ()) ->
    FilePath ->
    FilePath ->
    ByteString ->
    IO JournalRecord
#if defined(mingw32_HOST_OS)
writeJournalRecordAtWith atCutpoint directory leaf bytes = do
    validatePendingJournalLeaf leaf
    let destination = directory </> leaf
    present <- doesFileExist destination
    if present
        then do
            existing <- readBoundedRegularPathNoFollow destination (ByteString.length bytes + 1)
            unless (existing == bytes) (fail "status-projection-journal-collision")
        else do
            (temporary, handle) <- openBinaryTempFile directory ".amoebius-status-journal"
            let cleanup = do
                    ignoreIOException (hClose handle)
                    temporaryPresent <- doesFileExist temporary
                    when temporaryPresent (removeFile temporary)
            ( do
                    ByteString.hPut handle bytes
                    durableClose handle
                    atCutpoint JournalTemporaryDurable
                    raced <- doesFileExist destination
                    when raced (fail "status-projection-journal-raced")
                    renameFile temporary destination
                    atCutpoint JournalPendingLinked
                    synchroniseDirectory directory
                    atCutpoint JournalPendingDurable
                )
                `onException` cleanup
    pure
        JournalRecord
            { journalRecordDirectory = directory
            , journalRecordLeaf = leaf
            , journalRecordBytes = bytes
            }
#else
writeJournalRecordAtWith atCutpoint directory leaf bytes = do
    validatePendingJournalLeaf leaf
    withAbsoluteDirectoryFdNoFollow directory $ \directoryFd ->
        writeJournalRecordAtFdWith atCutpoint directory directoryFd leaf bytes

writeJournalRecordAtFdWith ::
    (JournalCutpoint -> IO ()) ->
    FilePath ->
    Fd ->
    FilePath ->
    ByteString ->
    IO JournalRecord
writeJournalRecordAtFdWith atCutpoint directory directoryFd leaf bytes = do
        validatePendingJournalLeaf leaf
        temporary <-
            createStatusTemporaryAt
                directoryFd
                leaf
                (ownerReadMode `unionFileModes` ownerWriteMode)
                bytes
        let cleanup = removeStatusTemporaryIfExact directoryFd temporary bytes
        ( do
                atCutpoint JournalTemporaryDurable
                linked <-
                    try
                        (linkJournalNoReplaceAt directoryFd temporary directoryFd leaf) :: IO (Either IOException ())
                case linked of
                    Left problem
                        | isAlreadyExistsError problem -> do
                            (temporaryStatus, temporaryBytes) <-
                                readRegularStatusAt directoryFd temporary (ByteString.length bytes + 1)
                            unless (temporaryBytes == bytes) (fail "status-projection-journal-temporary-changed")
                            quarantineAndRemoveRegularStatusAt
                                directoryFd
                                temporary
                                temporaryStatus
                                temporaryBytes
                            validateExistingJournalAt directoryFd leaf bytes
                    Left problem -> cleanup >> ioError problem
                    Right () -> do
                        atCutpoint JournalPendingLinked
                        (temporaryStatus, temporaryBytes) <-
                            readRegularStatusAt directoryFd temporary (ByteString.length bytes + 1)
                        unless (temporaryBytes == bytes) (fail "status-projection-journal-temporary-changed")
                        quarantineAndRemoveRegularStatusAt
                            directoryFd
                            temporary
                            temporaryStatus
                            temporaryBytes
                        atCutpoint JournalPendingDurable
                (status, observed) <- readRegularStatusAt directoryFd leaf (ByteString.length bytes + 1)
                unless (observed == bytes) (fail "status-projection-journal-collision")
                directoryStatus <- verifiedDirectoryStatus directoryFd
                pure
                    JournalRecord
                        { journalRecordDirectory = directory
                        , journalRecordLeaf = leaf
                        , journalRecordBytes = bytes
                        , journalRecordDirectoryStatus = directoryStatus
                        , journalRecordStatus = status
                        }
            )
            `onException` cleanup
#endif

finalizeJournalRecordAtWith ::
    (JournalCutpoint -> IO ()) ->
    JournalRecord ->
    JournalOutcome ->
    IO ()
#if defined(mingw32_HOST_OS)
finalizeJournalRecordAtWith atCutpoint record outcome = do
    let directory = journalRecordDirectory record
        pending = directory </> journalRecordLeaf record
        expected = journalRecordBytes record
    destinationLeaf <-
        maybe
            (fail "status-projection-journal-pending-suffix")
            pure
            (journalFinalLeaf (journalRecordLeaf record) outcome)
    let destination = directory </> destinationLeaf
    pendingBytes <- readBoundedRegularPathNoFollow pending (ByteString.length expected + 1)
    unless (pendingBytes == expected) (fail "status-projection-journal-content-changed")
    destinationPresent <- doesFileExist destination
    if destinationPresent
        then do
            destinationBytes <- readBoundedRegularPathNoFollow destination (ByteString.length expected + 1)
            unless (destinationBytes == expected) (fail "status-projection-final-journal-collision")
        else do
            renameFile pending destination
            atCutpoint JournalFinalLinked
    synchroniseDirectory directory
    atCutpoint JournalFinalDurable
    pendingPresent <- doesFileExist pending
    when pendingPresent (removeFile pending)
    atCutpoint JournalPendingUnlinked
    synchroniseDirectory directory
    pruneFinalizedJournalMarkersPath directory (takeFileName destination)
    atCutpoint JournalFinalizedDurable
#else
finalizeJournalRecordAtWith atCutpoint record outcome = do
    let directory = journalRecordDirectory record
        pending = journalRecordLeaf record
        expected = journalRecordBytes record
    destination <-
        maybe
            (fail "status-projection-journal-pending-suffix")
            pure
            (journalFinalLeaf pending outcome)
    validatePendingJournalLeaf pending
    validateFinalizedJournalLeaf destination
    withAbsoluteDirectoryFdNoFollow directory $ \directoryFd -> do
        directoryStatus <- verifiedDirectoryStatus directoryFd
        unless
            (sameObjectIdentity directoryStatus (journalRecordDirectoryStatus record))
            (fail "status-projection-journal-directory-rebound")
        (pendingStatus, pendingBytes) <-
            readRegularStatusAt directoryFd pending (ByteString.length expected + 1)
        unless
            (sameStatusFile pendingStatus (journalRecordStatus record) && pendingBytes == expected)
            (fail "status-projection-journal-content-changed")
        linked <-
            try
                (linkJournalNoReplaceAt directoryFd pending directoryFd destination) :: IO (Either IOException ())
        case linked of
            Left problem
                | isAlreadyExistsError problem -> do
                    (finalStatus, finalBytes) <-
                        readRegularStatusAt directoryFd destination (ByteString.length expected + 1)
                    unless
                        (sameStatusFile pendingStatus finalStatus && finalBytes == expected)
                        (fail "status-projection-final-journal-collision")
            Left problem -> ioError problem
            Right () -> atCutpoint JournalFinalLinked
        fileSynchronise directoryFd
        atCutpoint JournalFinalDurable
        (reboundStatus, reboundBytes) <-
            readRegularStatusAt directoryFd pending (ByteString.length expected + 1)
        unless
            (sameStatusFile reboundStatus pendingStatus && reboundBytes == expected)
            (fail "status-projection-journal-changed-before-finalization")
        quarantineAndRemoveRegularStatusAt directoryFd pending reboundStatus reboundBytes
        atCutpoint JournalPendingUnlinked
        fileSynchronise directoryFd
        pruneFinalizedJournalMarkersAt directoryFd (Just destination)
        fileSynchronise directoryFd
        atCutpoint JournalFinalizedDurable
#endif

#if !defined(mingw32_HOST_OS)
validateExistingJournalAt :: Fd -> FilePath -> ByteString -> IO ()
validateExistingJournalAt directoryFd leaf expected = do
    (_, observed) <- readRegularStatusAt directoryFd leaf (ByteString.length expected + 1)
    unless (observed == expected) (fail "status-projection-journal-collision")
#endif

validateJournalLeaf :: FilePath -> IO ()
validateJournalLeaf leaf =
    unless
        ( not (null leaf)
            && leaf /= "."
            && leaf /= ".."
            && takeFileName leaf == leaf
            && '\NUL' `notElem` leaf
        )
        (fail "status-projection-journal-leaf-is-not-canonical")

validatePendingJournalLeaf :: FilePath -> IO ()
validatePendingJournalLeaf leaf = do
    validateJournalLeaf leaf
    unless (isPendingJournalLeaf leaf) (fail "status-projection-pending-journal-leaf-is-not-canonical")

validateFinalizedJournalLeaf :: FilePath -> IO ()
validateFinalizedJournalLeaf leaf = do
    validateJournalLeaf leaf
    unless (isFinalizedJournalLeaf leaf) (fail "status-projection-final-journal-leaf-is-not-canonical")

#if defined(mingw32_HOST_OS)
pruneFinalizedJournalMarkersPath :: FilePath -> FilePath -> IO ()
pruneFinalizedJournalMarkersPath directory retained = do
    entries <- listDirectory directory
    let finalized = sort (filter isFinalizedJournalLeaf entries)
        removable = filter (/= retained) finalized
        excess = max 0 (length finalized - maximumFinalizedJournalMarkers)
    mapM_ removeExact (take excess removable)
    synchroniseDirectory directory
  where
    removeExact leaf = do
        validateJournalLeaf leaf
        let path = directory </> leaf
        bytes <- readBoundedRegularPathNoFollow path (maximumJournalBytes + 1)
        when (ByteString.length bytes > maximumJournalBytes) (fail "status-projection-final-journal-byte-limit")
        removeFile path
#endif

#if !defined(mingw32_HOST_OS)
pruneFinalizedJournalMarkersAt :: Fd -> Maybe FilePath -> IO ()
pruneFinalizedJournalMarkersAt directoryFd retained = do
    entries <- listJournalDirectoryEntriesAt directoryFd
    mapM_ validateRecognizedJournalLeaf entries
    pruneFinalizedJournalMarkersFromEntriesAt directoryFd retained entries

pruneFinalizedJournalMarkersFromEntriesAt :: Fd -> Maybe FilePath -> [FilePath] -> IO ()
pruneFinalizedJournalMarkersFromEntriesAt directoryFd retained entries = do
    let finalized = sort (filter isFinalizedJournalLeaf entries)
        removable = maybe finalized (\leaf -> filter (/= leaf) finalized) retained
        excess = max 0 (length finalized - maximumFinalizedJournalMarkers)
    mapM_ removeExact (take excess removable)
  where
    removeExact leaf = do
        unless (isFinalizedJournalLeaf leaf) (fail "status-projection-final-journal-leaf-is-not-canonical")
        (capturedStatus, capturedBytes) <-
            readRegularStatusAt directoryFd leaf (maximumJournalBytes + 1)
        when
            (ByteString.length capturedBytes > maximumJournalBytes)
            (fail "status-projection-final-journal-byte-limit")
        (reboundStatus, reboundBytes) <-
            readRegularStatusAt directoryFd leaf (ByteString.length capturedBytes + 1)
        unless
            (sameStatusFile capturedStatus reboundStatus && capturedBytes == reboundBytes)
            (fail "status-projection-final-journal-changed-before-prune")
        quarantineAndRemoveRegularStatusAt directoryFd leaf reboundStatus reboundBytes

listJournalDirectoryEntriesAt :: Fd -> IO [FilePath]
listJournalDirectoryEntriesAt directoryFd = do
    before <- verifiedDirectoryStatus directoryFd
    entries <- readDirectoryEntriesBounded directoryFd maximumJournalDirectoryEntries
    after <- verifiedDirectoryStatus directoryFd
    unless
        (sameObjectIdentity before after)
        (fail "status-projection-journal-directory-changed-during-listing")
    pure entries

readDirectoryEntriesBounded :: Fd -> Int -> IO [FilePath]
readDirectoryEntriesBounded directoryFd limit =
    bracket
        (openDirectoryStreamAt directoryFd)
        closeDirectoryStream
        (go 0 [])
  where
    go count accumulated stream = do
        next <- readDirectoryLeaf stream
        case next of
            Nothing -> pure (reverse accumulated)
            Just leaf
                | leaf == "." || leaf == ".." -> go count accumulated stream
                | otherwise -> do
                    when
                        (count >= limit)
                        (fail "status-projection-journal-directory-entry-limit")
                    go (count + 1) (leaf : accumulated) stream

readDirectoryLeaf :: Ptr CDirectoryStream -> IO (Maybe FilePath)
readDirectoryLeaf stream =
    alloca $ \entrySlot -> do
        resetErrno
        result <- cReadDirectory stream entrySlot
        if result == 0
            then do
                entry <- peek entrySlot
                if entry == nullPtr
                    then pure Nothing
                    else
                        bracket
                            (pure entry)
                            cFreeDirectoryEntry
                            (\observed -> do
                                name <- cDirectoryEntryName observed
                                raw <- ByteString.packCString name
                                when
                                    (ByteString.elem 0 raw || ByteString.elem 47 raw)
                                    (fail "status-projection-journal-directory-entry-is-not-a-leaf")
                                pure (Just (ByteString8.unpack raw))
                            )
            else do
                problem <- getErrno
                if problem == eINTR
                    then readDirectoryLeaf stream
                    else
                        if problem == eOK
                            then pure Nothing
                            else throwErrno "status-projection-readdir"

openDirectoryStreamAt :: Fd -> IO (Ptr CDirectoryStream)
openDirectoryStreamAt directoryFd = do
    expected <- verifiedDirectoryStatus directoryFd
    enumerationFd <- openFdAt (Just directoryFd) "." ReadOnly directoryReadFlags
    ( do
        observed <- verifiedDirectoryStatus enumerationFd
        unless
            (sameObjectIdentity expected observed)
            (fail "status-projection-enumeration-directory-identity-mismatch")
        throwErrnoIfNull
            "status-projection-fdopendir"
            (cFdOpenDirectory (fdNumber enumerationFd))
      )
        `onException` closeFd enumerationFd

closeDirectoryStream :: Ptr CDirectoryStream -> IO ()
closeDirectoryStream stream =
    throwErrnoIfMinus1_ "status-projection-closedir" (cCloseDirectory stream)

linkJournalNoReplaceAt :: Fd -> FilePath -> Fd -> FilePath -> IO ()
linkJournalNoReplaceAt sourceDirectoryFd source destinationDirectoryFd destination =
    withCString source $ \sourcePath ->
        withCString destination $ \destinationPath ->
            throwErrnoIfMinus1_
                "status-projection-linkat"
                ( cLinkAt
                    (fdNumber sourceDirectoryFd)
                    sourcePath
                    (fdNumber destinationDirectoryFd)
                    destinationPath
                    0
                )
#endif

isFinalizedJournalLeaf :: FilePath -> Bool
isFinalizedJournalLeaf leaf =
    hasCanonicalJournalStem ".applied" leaf
        || hasCanonicalJournalStem ".rolled-back" leaf

isPendingJournalLeaf :: FilePath -> Bool
isPendingJournalLeaf = hasCanonicalJournalStem ".journal"

hasCanonicalJournalStem :: Text -> FilePath -> Bool
hasCanonicalJournalStem suffix leaf =
    case Text.stripSuffix suffix (Text.pack leaf) of
        Just stem ->
            Text.length stem == 64
                && Text.all
                    (\character -> character >= '0' && character <= '9' || character >= 'a' && character <= 'f')
                    stem
        Nothing -> False

validateRecognizedJournalLeaf :: FilePath -> IO ()
validateRecognizedJournalLeaf leaf = do
    validateJournalLeaf leaf
    when
        ( hasJournalSuffix leaf
            && not (isPendingJournalLeaf leaf || isFinalizedJournalLeaf leaf)
        )
        (fail "status-projection-journal-leaf-has-noncanonical-digest")
  where
    hasJournalSuffix candidate =
        any
            (`Text.isSuffixOf` Text.pack candidate)
            [".journal", ".applied", ".rolled-back"]

statusProjectionInternalTestJournalAtCutpoint ::
    JournalCutpoint ->
    FilePath ->
    IO (Either [Finding] ())
statusProjectionInternalTestJournalAtCutpoint selected directory = do
    result <- try $ do
        let leaf = testJournalStem <> ".journal"
            bytes = "amoebius-status-projection-test-journal"
            inject observed =
                when
                    (observed == selected)
                    (ioError (userError ("status-projection-journal-test-cutpoint:" <> show selected)))
        record <- writeJournalRecordAtWith inject directory leaf bytes
        finalizeJournalRecordAtWith inject record JournalApplied
    pure $ case result of
        Left problem -> Left [ioFinding "STATUS-PROJECTION-JOURNAL-TEST" directory problem]
        Right () -> Right ()

statusProjectionInternalTestJournalName :: FilePath -> (Bool, Bool)
statusProjectionInternalTestJournalName leaf =
    (isPendingJournalLeaf leaf, isFinalizedJournalLeaf leaf)

statusProjectionInternalTestDiscoverJournal :: FilePath -> IO (Either [Finding] [FilePath])
statusProjectionInternalTestDiscoverJournal directory = do
    result <- tryIOException (discoverPendingJournalMarkers directory)
    pure $ case result of
        Left problem -> Left [ioFinding "STATUS-PROJECTION-JOURNAL-DISCOVERY-TEST" directory problem]
        Right markers -> Right (map pendingMarkerLeaf markers)

statusProjectionInternalTestFinalizeJournal :: FilePath -> IO (Either [Finding] ())
statusProjectionInternalTestFinalizeJournal directory = do
    result <- tryIOException $ do
        record <-
            writeJournalRecordAtWith
                (\_ -> pure ())
                directory
                (testJournalStem <> ".journal")
                "amoebius-status-projection-test-journal"
        finalizeJournalRecordAtWith (\_ -> pure ()) record JournalApplied
    pure $ case result of
        Left problem -> Left [ioFinding "STATUS-PROJECTION-JOURNAL-FINALIZATION-TEST" directory problem]
        Right () -> Right ()

statusProjectionInternalTestMarkerReplacement :: FilePath -> IO (Either [Finding] ())
statusProjectionInternalTestMarkerReplacement directory = do
    let leaf = testJournalStem <> ".journal"
        original = "captured-marker-bytes"
        replacement = "replaced-marker-bytes"
    prepared <-
        tryIOException $ do
            _ <- writeJournalRecordAtWith (\_ -> pure ()) directory leaf original
            markers <- discoverPendingJournalMarkers directory
            ByteString.writeFile (directory </> leaf) replacement
            pure markers
    case prepared of
        Left problem -> pure (Left [ioFinding "STATUS-PROJECTION-JOURNAL-REPLACEMENT-TEST" directory problem])
        Right markers -> clearPendingJournalMarkers markers

testJournalStem :: FilePath
testJournalStem = replicate 64 'a'

applyFiles :: FilePath -> [ProjectionFile] -> IO (Either [Finding] ())
applyFiles root files = do
    scratchResult <- statusExchangeDirectory root
    case scratchResult of
        Left problems -> pure (Left problems)
        Right scratch -> foldM (applyOne scratch) (Right ()) files
  where
    applyOne scratch result item = case result of
        Left problems -> pure (Left problems)
        Right () ->
            atomicReplaceExact
                scratch
                (root </> projectionFilePath item)
                (projectionFileBefore item)
                (projectionFileAfter item)

rollbackFiles :: FilePath -> [ProjectionFile] -> IO (Either [Finding] ())
rollbackFiles root files = do
    scratchResult <- statusExchangeDirectory root
    case scratchResult of
        Left problems -> pure (Left problems)
        Right scratch -> do
            problems <- foldM (rollbackOne scratch) [] (reverse files)
            pure (if null problems then Right () else Left problems)
  where
    rollbackOne scratch accumulated item = do
        let path = root </> projectionFilePath item
        replaced <- atomicReplaceExact scratch path (projectionFileAfter item) (projectionFileBefore item)
        let currentProblems = either id (const []) replaced
        pure (accumulated <> currentProblems)

statusExchangeDirectory :: FilePath -> IO (Either [Finding] FilePath)
statusExchangeDirectory root = do
    let components = [".build", "runs", "status-projection-exchanges"]
        destination = foldl (</>) root components
    result <- try (ensureDirectoryChain root components)
    pure $ case result of
        Left problem -> Left [ioFinding "STATUS-PROJECTION-EXCHANGE-DIRECTORY" destination problem]
        Right () -> Right destination

atomicReplaceExact :: FilePath -> FilePath -> ByteString -> ByteString -> IO (Either [Finding] ())
atomicReplaceExact = atomicReplaceExactWith (\_ -> pure ())

atomicReplaceExactWith ::
    (StatusAtomicCutpoint -> IO ()) ->
    FilePath ->
    FilePath ->
    ByteString ->
    ByteString ->
    IO (Either [Finding] ())
#if defined(mingw32_HOST_OS)
atomicReplaceExactWith _ _ destination _ _ =
  pure
    ( Left
        [ projectionFinding
            "STATUS-PROJECTION-WRITE-UNAVAILABLE"
            destination
            "atomic compare-and-exchange replacement is unavailable on Windows"
        ]
    )
#else
atomicReplaceExactWith atCutpoint scratchDirectory destination expected bytes = do
    result <- try $
        withAbsoluteDirectoryFdNoFollow (takeDirectory destination) $ \targetDirectoryFd ->
            withAbsoluteDirectoryFdNoFollow scratchDirectory $ \scratchDirectoryFd -> do
                targetDirectoryStatus <- getFdStatus targetDirectoryFd
                scratchDirectoryStatus <- getFdStatus scratchDirectoryFd
                unless (isDirectory targetDirectoryStatus) (fail "status-projection-parent-is-not-directory")
                unless (isDirectory scratchDirectoryStatus) (fail "status-projection-exchange-parent-is-not-directory")
                let leaf = takeFileName destination
                    limit = max (ByteString.length expected) (ByteString.length bytes) + 1
                (capturedStatus, captured) <- readRegularStatusAt targetDirectoryFd leaf limit
                if captured == bytes
                    then pure ()
                    else do
                        unless (captured == expected) (fail "status-projection-target-preimage-changed")
                        temporary <-
                            createStatusTemporaryAt
                                scratchDirectoryFd
                                leaf
                                (fileMode capturedStatus)
                                bytes
                        atCutpoint StatusTemporaryDurable
                        exchangeResult <-
                            try
                                (exchangeStatusPathsAt scratchDirectoryFd temporary targetDirectoryFd leaf) :: IO (Either IOException ())
                        case exchangeResult of
                            Left problem -> do
                                removeStatusTemporaryIfExact scratchDirectoryFd temporary bytes
                                ioError problem
                            Right () -> do
                                atCutpoint StatusExchangeComplete
                                fileSynchronise targetDirectoryFd
                                fileSynchronise scratchDirectoryFd
                                atCutpoint StatusDirectoriesDurable
                                displacedResult <-
                                    try
                                        (readRegularStatusAt scratchDirectoryFd temporary limit) :: IO (Either IOException (FileStatus, ByteString))
                                case displacedResult of
                                    Right (displacedStatus, displaced)
                                        | sameStatusFile capturedStatus displacedStatus
                                            && displaced == expected -> do
                                            atCutpoint StatusDisplacedVerified
                                            quarantineAndRemoveRegularStatusAt
                                                scratchDirectoryFd
                                                temporary
                                                displacedStatus
                                                displaced
                                            atCutpoint StatusDisplacedUnlinked
                                    _ -> do
                                        exchangeStatusPathsAt scratchDirectoryFd temporary targetDirectoryFd leaf
                                        fileSynchronise targetDirectoryFd
                                        fileSynchronise scratchDirectoryFd
                                        removeStatusTemporaryIfExact scratchDirectoryFd temporary bytes
                                        fail "status-projection-target-changed-before-atomic-exchange"
    pure $ case result of
        Left problem -> Left [ioFinding "STATUS-PROJECTION-WRITE" destination problem]
        Right () -> Right ()
#endif

#if defined(mingw32_HOST_OS)
readBoundedRegularPathNoFollow :: FilePath -> Int -> IO ByteString
readBoundedRegularPathNoFollow path limit = do
  linked <- pathIsSymbolicLink path
  when linked (fail "status-projection-journal-is-symbolic-link")
  regular <- doesFileExist path
  unless regular (fail "status-projection-journal-is-not-regular-file")
  withBinaryFile path ReadMode (\handle -> ByteString.hGet handle limit)
#endif

#if !defined(mingw32_HOST_OS)
readRegularStatusAt :: Fd -> FilePath -> Int -> IO (FileStatus, ByteString)
readRegularStatusAt directoryFd leaf limit =
  bracket
    (openFdAt (Just directoryFd) leaf ReadOnly regularStatusReadFlags)
    closeFd
    (\descriptor -> do
        before <- getFdStatus descriptor
        unless (isRegularFile before) (fail "status-projection-target-is-not-regular-file")
        observed <- readBoundedStatusFd descriptor limit
        after <- getFdStatus descriptor
        unless (sameStatusFile before after) (fail "status-projection-target-changed-during-read")
        pure (after, observed)
    )

readBoundedStatusFd :: Fd -> Int -> IO ByteString
readBoundedStatusFd descriptor limit =
  bracket
    (dup descriptor >>= fdToHandle)
    hClose
    (\handle -> ByteString.hGet handle limit)

sameStatusFile :: FileStatus -> FileStatus -> Bool
sameStatusFile left right =
  deviceID left == deviceID right
    && fileID left == fileID right
    && fileSize left == fileSize right
    && fileMode left == fileMode right

createStatusTemporaryAt :: Fd -> FilePath -> FileMode -> ByteString -> IO FilePath
createStatusTemporaryAt directoryFd target mode bytes = do
  process <- getProcessID
  choose process (0 :: Int)
 where
  choose process attempt
    | attempt >= 1024 = fail "status-projection-temporary-name-exhausted"
    | otherwise = do
        let leaf = "." <> target <> ".amoebius-status-projection." <> show process <> "." <> show attempt
        opened <-
          try
            ( openFdAt
                (Just directoryFd)
                leaf
                WriteOnly
                ( statusTemporaryFlags
                    { creat = Just (ownerReadMode `unionFileModes` ownerWriteMode)
                    }
                )
            ) :: IO (Either IOException Fd)
        case opened of
          Left problem
            | isAlreadyExistsError problem -> choose process (attempt + 1)
            | otherwise -> ioError problem
          Right descriptor -> do
            createdStatus <- getFdStatus descriptor
            let cleanup = do
                  ignoreIOException (closeFd descriptor)
                  ignoreIOException
                    (quarantineAndRemoveRegularIdentityAt directoryFd leaf createdStatus)
            ( do
                setFdMode descriptor mode
                writeAllStatusFd descriptor bytes
                fileSynchronise descriptor
                closeFd descriptor
                fileSynchronise directoryFd
                pure leaf
              )
              `onException` cleanup

writeAllStatusFd :: Fd -> ByteString -> IO ()
writeAllStatusFd _ remaining | ByteString.null remaining = pure ()
writeAllStatusFd descriptor remaining = do
  written <- PosixIOBytes.fdWrite descriptor remaining
  when (written <= 0) (fail "status-projection-temporary-write-made-no-progress")
  writeAllStatusFd descriptor (ByteString.drop (fromIntegral written) remaining)

removeStatusTemporaryIfExact :: Fd -> FilePath -> ByteString -> IO ()
removeStatusTemporaryIfExact directoryFd leaf expected = do
  observed <- try (readRegularStatusAt directoryFd leaf (ByteString.length expected + 1)) :: IO (Either IOException (FileStatus, ByteString))
  case observed of
    Right (status, bytes)
      | bytes == expected -> do
          quarantineAndRemoveRegularStatusAt directoryFd leaf status bytes
    _ -> pure ()

exchangeStatusPathsAt :: Fd -> FilePath -> Fd -> FilePath -> IO ()
#if defined(linux_HOST_OS) || defined(darwin_HOST_OS)
exchangeStatusPathsAt leftDirectoryFd left rightDirectoryFd right =
  withCString left $ \leftPath ->
    withCString right $ \rightPath ->
      throwErrnoIfMinus1_
        "status-projection-atomic-exchange"
        (cRenameExchange (fdNumber leftDirectoryFd) leftPath (fdNumber rightDirectoryFd) rightPath 2)
#else
exchangeStatusPathsAt _ _ _ _ = fail "status-projection-atomic-exchange-is-unavailable-on-this-host"
#endif

unlinkStatusPathAt :: Fd -> FilePath -> IO ()
unlinkStatusPathAt directoryFd leaf =
  withCString leaf $ \path ->
    throwErrnoIfMinus1_
      "status-projection-unlinkat"
      (cUnlinkAt (fdNumber directoryFd) path 0)

quarantineAndRemoveRegularStatusAt :: Fd -> FilePath -> FileStatus -> ByteString -> IO ()
quarantineAndRemoveRegularStatusAt directoryFd leaf expectedStatus expectedBytes = do
  quarantine <- moveStatusPathToQuarantineAt directoryFd leaf
  (quarantineStatus, quarantineBytes) <-
    readRegularStatusAt directoryFd quarantine (ByteString.length expectedBytes + 1)
  if sameStatusFile quarantineStatus expectedStatus && quarantineBytes == expectedBytes
    then do
      (reboundStatus, reboundBytes) <-
        readRegularStatusAt directoryFd quarantine (ByteString.length expectedBytes + 1)
      unless
        (sameStatusFile reboundStatus quarantineStatus && reboundBytes == expectedBytes)
        (fail "status-projection-quarantine-changed-before-removal")
      unlinkStatusPathAt directoryFd quarantine
      fileSynchronise directoryFd
    else do
      restored <- tryIOException (renameStatusPathNoReplaceAt directoryFd quarantine leaf)
      case restored of
        Left problem ->
          ioError
            ( userError
                ( "status-projection-quarantine-identity-mismatch-and-restore-failed: "
                    <> show problem
                )
            )
        Right () -> do
          fileSynchronise directoryFd
          fail "status-projection-quarantine-identity-mismatch"

quarantineAndRemoveRegularIdentityAt :: Fd -> FilePath -> FileStatus -> IO ()
quarantineAndRemoveRegularIdentityAt directoryFd leaf expectedStatus = do
  quarantine <- moveStatusPathToQuarantineAt directoryFd leaf
  (quarantineStatus, _) <- readRegularStatusAt directoryFd quarantine 0
  if sameObjectIdentity quarantineStatus expectedStatus
    then do
      (reboundStatus, _) <- readRegularStatusAt directoryFd quarantine 0
      unless
        (sameObjectIdentity reboundStatus expectedStatus)
        (fail "status-projection-quarantine-changed-before-removal")
      unlinkStatusPathAt directoryFd quarantine
      fileSynchronise directoryFd
    else do
      restored <- tryIOException (renameStatusPathNoReplaceAt directoryFd quarantine leaf)
      case restored of
        Left problem ->
          ioError
            ( userError
                ( "status-projection-quarantine-identity-mismatch-and-restore-failed: "
                    <> show problem
                )
            )
        Right () -> do
          fileSynchronise directoryFd
          fail "status-projection-quarantine-identity-mismatch"

moveStatusPathToQuarantineAt :: Fd -> FilePath -> IO FilePath
moveStatusPathToQuarantineAt directoryFd leaf = do
  process <- getProcessID
  choose process (0 :: Int)
 where
  choose process attempt
    | attempt >= 1024 = fail "status-projection-quarantine-name-exhausted"
    | otherwise = do
        let quarantine = "." <> leaf <> ".amoebius-status-quarantine." <> show process <> "." <> show attempt
        moved <- tryIOException (renameStatusPathNoReplaceAt directoryFd leaf quarantine)
        case moved of
          Left problem
            | isAlreadyExistsError problem -> choose process (attempt + 1)
            | otherwise -> ioError problem
          Right () -> do
            fileSynchronise directoryFd
            pure quarantine

renameStatusPathNoReplaceAt :: Fd -> FilePath -> FilePath -> IO ()
#if defined(linux_HOST_OS)
renameStatusPathNoReplaceAt directoryFd source destination =
  renameStatusPathWithFlagsAt directoryFd source destination 1
#elif defined(darwin_HOST_OS)
renameStatusPathNoReplaceAt directoryFd source destination =
  renameStatusPathWithFlagsAt directoryFd source destination 4
#else
renameStatusPathNoReplaceAt _ _ _ =
  fail "status-projection-no-replace-quarantine-is-unavailable-on-this-host"
#endif

#if defined(linux_HOST_OS) || defined(darwin_HOST_OS)
renameStatusPathWithFlagsAt :: Fd -> FilePath -> FilePath -> CUInt -> IO ()
renameStatusPathWithFlagsAt directoryFd source destination flags =
  withCString source $ \sourcePath ->
    withCString destination $ \destinationPath ->
      throwErrnoIfMinus1_
        "status-projection-rename-no-replace"
        (cRenameExchange (fdNumber directoryFd) sourcePath (fdNumber directoryFd) destinationPath flags)
#endif

fdNumber :: Fd -> CInt
fdNumber (Fd descriptor) = descriptor

withEnsuredDirectoryChain :: FilePath -> [FilePath] -> (Fd -> IO value) -> IO value
withEnsuredDirectoryChain root components action =
  withAbsoluteDirectoryFdNoFollow root $ \rootFd ->
    descend rootFd components
 where
  descend directoryFd [] = action directoryFd
  descend directoryFd (component : rest) = do
    validateRelativeDirectoryComponent component
    bracket
      (ensureOpenDirectoryAt directoryFd component)
      closeFd
      (\descriptor -> descend descriptor rest)

  ensureOpenDirectoryAt directoryFd component = do
    opened <- tryIOException (openVerifiedDirectoryAt directoryFd component)
    case opened of
      Right descriptor -> pure descriptor
      Left problem
        | isDoesNotExistError problem -> do
            created <- tryIOException (mkdirDirectoryAt directoryFd component)
            case created of
              Left creationProblem
                | isAlreadyExistsError creationProblem -> pure ()
                | otherwise -> ioError creationProblem
              Right () -> fileSynchronise directoryFd
            descriptor <- openVerifiedDirectoryAt directoryFd component
            fileSynchronise descriptor
            pure descriptor
        | otherwise -> ioError problem

withOptionalRelativeDirectoryChainAt :: Fd -> [FilePath] -> (Fd -> IO value) -> IO (Maybe value)
withOptionalRelativeDirectoryChainAt directoryFd [] action = Just <$> action directoryFd
withOptionalRelativeDirectoryChainAt directoryFd (component : rest) action = do
  validateRelativeDirectoryComponent component
  opened <- tryIOException (openVerifiedDirectoryAt directoryFd component)
  case opened of
    Left problem
      | isDoesNotExistError problem -> pure Nothing
      | otherwise -> ioError problem
    Right childFd ->
      bracket
        (pure childFd)
        closeFd
        (\descriptor -> withOptionalRelativeDirectoryChainAt descriptor rest action)

mkdirDirectoryAt :: Fd -> FilePath -> IO ()
mkdirDirectoryAt directoryFd component =
  withCString component $ \path ->
    throwErrnoIfMinus1_
      "status-projection-mkdirat"
      (cMkdirAt (fdNumber directoryFd) path 0o700)

openVerifiedDirectoryAt :: Fd -> FilePath -> IO Fd
openVerifiedDirectoryAt directoryFd component = do
  before <- verifiedDirectoryStatus directoryFd
  descriptor <- openFdAt (Just directoryFd) component ReadOnly directoryReadFlags
  ( do
      _ <- verifiedDirectoryStatus descriptor
      after <- verifiedDirectoryStatus directoryFd
      unless
        (sameObjectIdentity before after)
        (fail "status-projection-parent-directory-identity-changed")
      pure descriptor
    )
    `onException` closeFd descriptor

verifiedDirectoryStatus :: Fd -> IO FileStatus
verifiedDirectoryStatus descriptor = do
  status <- getFdStatus descriptor
  unless (isDirectory status) (fail "status-projection-path-component-is-not-directory")
  pure status

sameObjectIdentity :: FileStatus -> FileStatus -> Bool
sameObjectIdentity left right =
  deviceID left == deviceID right && fileID left == fileID right

validateRelativeDirectoryComponent :: FilePath -> IO ()
validateRelativeDirectoryComponent component =
  unless
    ( not (null component)
        && component /= "."
        && component /= ".."
        && takeFileName component == component
        && '\NUL' `notElem` component
    )
    (fail "status-projection-directory-component-is-not-canonical")

withAbsoluteDirectoryFdNoFollow :: FilePath -> (Fd -> IO value) -> IO value
withAbsoluteDirectoryFdNoFollow absolute action =
  case absoluteDirectoryComponents absolute of
    Nothing -> fail "status-projection-parent-is-not-an-absolute-canonical-path"
    Just components ->
      bracket
        (openFd "/" ReadOnly directoryReadFlags)
        closeFd
        (\rootFd -> verifiedDirectoryStatus rootFd >> descend rootFd components)
 where
  descend directoryFd [] = action directoryFd
  descend directoryFd (component : rest) =
    bracket
      (openVerifiedDirectoryAt directoryFd component)
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
  validComponent component =
    not (Text.null component)
      && component /= "."
      && component /= ".."
      && not (Text.any (== '\NUL') component)

directoryReadFlags :: OpenFileFlags
directoryReadFlags =
  defaultFileFlags
    { cloexec = True
    , directory = True
    , nofollow = True
    , nonBlock = True
    }

regularStatusReadFlags :: OpenFileFlags
regularStatusReadFlags =
  defaultFileFlags
    { cloexec = True
    , nofollow = True
    , nonBlock = True
    }

statusTemporaryFlags :: OpenFileFlags
statusTemporaryFlags =
  defaultFileFlags
    { cloexec = True
    , exclusive = True
    , nofollow = True
    }
#endif

ignoreIOException :: IO () -> IO ()
ignoreIOException action = do
    _ <- try action :: IO (Either IOException ())
    pure ()

tryIOException :: IO value -> IO (Either IOException value)
tryIOException = try

#if defined(mingw32_HOST_OS)
durableClose :: Handle -> IO ()
durableClose handle = hFlush handle >> hClose handle
#endif

#if defined(mingw32_HOST_OS)
synchroniseDirectory :: FilePath -> IO ()
synchroniseDirectory _ = pure ()
#endif

confirmAppliedStatusProjection ::
    AcquiredSourceSnapshot ->
    AuthorizedStatusProjection ->
    Either [Finding] AppliedStatusProjection
confirmAppliedStatusProjection acquired authorized
    | snapshotIdentity (acquiredSourceSnapshot acquired) == proposedPostimageDigest projection =
        Right (AppliedStatusProjection authorized)
    | otherwise =
        Left
            [ projectionFinding
                "STATUS-PROJECTION-POSTIMAGE-MISMATCH"
                "<source-snapshot>"
                "the closing capture does not equal the exact gate-bound status postimage"
            ]
  where
    projection = authorizedProjectionValue authorized

projectionFinding :: Text -> FilePath -> Text -> Finding
projectionFinding = finding

ioFinding :: Text -> FilePath -> IOException -> Finding
ioFinding code path problem = finding code path (Text.pack (show problem))

snapshotProblemFinding :: SnapshotProblem -> Finding
snapshotProblemFinding problem =
    finding
        "STATUS-PROJECTION-SNAPSHOT"
        "<source-snapshot>"
        (renderSnapshotProblem problem)

sortEdits :: [StatusEdit] -> [StatusEdit]
sortEdits = sortOn (\edit -> (editPath edit, editLine edit, editTarget edit))

duplicates :: (Ord value) => [value] -> [value]
duplicates = foldr repeated [] . group . sort
  where
    repeated (value : _ : _) rest = value : rest
    repeated _ rest = rest

occurrenceCount :: Text -> Text -> Int
occurrenceCount needle value
    | Text.null needle = 0
    | otherwise = go 0 value
  where
    go count remaining = case Text.breakOn needle remaining of
        (_, suffix)
            | Text.null suffix -> count
            | otherwise -> go (count + 1) (Text.drop (Text.length needle) suffix)

encode :: Text -> ByteString
encode = TextEncoding.encodeUtf8

showText :: (Show value) => value -> Text
showText = Text.pack . show

formatOrdinal :: Int -> String
formatOrdinal ordinal
    | ordinal < 10 = '0' : show ordinal
    | otherwise = show ordinal

phaseDomainLower, phaseDomainUpper :: Int
phaseDomainLower =
    Policy.phaseOrdinalNumber
        (Policy.phaseDomainLower (Policy.orderingContract Policy.canonicalPolicyContract))
phaseDomainUpper =
    Policy.phaseOrdinalNumber
        (Policy.phaseDomainUpper (Policy.orderingContract Policy.canonicalPolicyContract))

maximumJournalDirectoryEntries :: Int
maximumJournalDirectoryEntries = 1024

maximumPendingJournalMarkers :: Int
maximumPendingJournalMarkers = 1024

maximumFinalizedJournalMarkers :: Int
maximumFinalizedJournalMarkers = 64

maximumJournalBytes :: Int
maximumJournalBytes = 16 * 1024 * 1024

trackerPath :: FilePath
trackerPath = "DEVELOPMENT_PLAN/README.md"

hex :: ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
  where
    byteHex value = [intToDigit (fromIntegral value `div` 16), intToDigit (fromIntegral value `mod` 16)]
