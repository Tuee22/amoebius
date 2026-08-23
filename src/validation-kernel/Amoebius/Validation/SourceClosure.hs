{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.SourceClosure
  ( ClassifiedPath (..)
  , GitExecutable
  , IndexEntry (..)
  , IndexFlagObservation (..)
  , IndexMode (..)
  , PbSemanticRole (..)
  , SnapshotProblem (..)
  , SourceClass (..)
  , SourceClosure
  , SourceDebtId (..)
  , SourceFacet (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , WorktreeEntryKind (..)
  , classifyEntry
  , classifyPbPythonRoles
  , classifySnapshot
  , checkCandidateWorkspace
  , closurePaths
  , closureProblems
  , closureRegisteredDebt
  , closureSnapshotIdentity
  , loadGitSnapshot
  , mkGitExecutable
  , parseLsFilesStage
  , parseLsFilesTaggedStage
  , parseLsFilesTaggedPaths
  , registeredSourceIds
  , renderSnapshotProblem
  , renderSourceDebtId
  , sourceDebtFingerprint
  , sourceDebtPathCount
  , sourceClosureCheck
  ) where

import Amoebius.Validation.PolicyContract qualified as Policy
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar)
import Control.Exception (IOException, bracket, displayException, finally, onException, try)
import Control.Monad (foldM, forM)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as ByteString8
import qualified Crypto.Hash.SHA256 as SHA256
import Data.Char (intToDigit, isHexDigit)
import Data.List (sort, sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.Encoding.Error as TextError
import System.Directory
  ( doesDirectoryExist
  , doesPathExist
  , listDirectory
  , pathIsSymbolicLink
  )
import System.Exit (ExitCode (..))
import System.Environment (getEnvironment)
import System.FilePath
  ( dropTrailingPathSeparator
  , isAbsolute
  , normalise
  , takeDirectory
  , takeFileName
  , (</>)
  )
import System.IO (Handle, hClose)
import System.IO.Error (isDoesNotExistError)
#if !defined(mingw32_HOST_OS)
import System.Posix.Files qualified as Posix
import System.Posix.IO qualified as PosixIO
import System.Posix.Types (Fd)
#endif
import System.Process
  ( CreateProcess (..)
  , StdStream (CreatePipe)
  , createProcess
  , proc
  , waitForProcess
  )

-- | A Git executable accepted only through 'mkGitExecutable'.  Hiding the
-- constructor prevents an acquisition path from silently falling back to PATH.
newtype GitExecutable = GitExecutable FilePath
  deriving (Eq, Ord, Show)

data IndexMode
  = RegularFile
  | ExecutableFile
  | SymbolicLink
  deriving (Eq, Ord, Show)

-- | The two independent, NUL-delimited index-visibility observations used
-- during acquisition.  They are distinct because @git ls-files -v@ exposes
-- assume-unchanged through a lower-case tag, while @git ls-files -t@ exposes
-- skip-worktree through the @S@ tag.
data IndexFlagObservation
  = AssumeUnchangedObservation
  | SkipWorktreeObservation
  deriving (Eq, Ord, Show)

data WorktreeEntryKind
  = WorktreeRegularFile
  | WorktreeSymbolicLink
  | WorktreeDirectory
  | WorktreeOther
  deriving (Eq, Ord, Show)

data IndexEntry = IndexEntry
  { indexPath :: FilePath
  , indexMode :: IndexMode
  , indexObjectId :: Text
  }
  deriving (Eq, Ord, Show)

data TrackedEntry = TrackedEntry
  { trackedIndex :: IndexEntry
  , trackedBytes :: ByteString
  }
  deriving (Eq, Ord, Show)

-- | The identity is Git's hash of a canonical manifest containing mode, object
-- id, and path for every stage-zero entry.  Blob bytes are nevertheless loaded
-- and retained: classification never consults the mutable worktree.
data SourceSnapshot = SourceSnapshot
  { snapshotRoot :: FilePath
  , snapshotIdentity :: Text
  , snapshotEntries :: [TrackedEntry]
  }
  deriving (Eq, Show)

data WorktreeEntryObservation = WorktreeEntryObservation
  { worktreeObservedKind :: WorktreeEntryKind
  , worktreeObservedExecutable :: Bool
  , worktreeObservedBytes :: ByteString
  , worktreeObservedStatus :: WorktreeStatusFingerprint
  }
  deriving (Eq, Ord, Show)

data WorktreeStatusFingerprint = WorktreeStatusFingerprint
  { statusDevice :: Text
  , statusFileIdentity :: Text
  , statusMode :: Text
  , statusSize :: Text
  , statusModified :: Text
  , statusChanged :: Text
  }
  deriving (Eq, Ord, Show)

data WorktreeAcquisitionObservation = WorktreeAcquisitionObservation
  { acquisitionTrackedEntries :: Map FilePath WorktreeEntryObservation
  , acquisitionAuthoredPaths :: Map FilePath WorktreeEntryKind
  }
  deriving (Eq, Show)

data SnapshotProblem
  = GitExecutableNotAbsolute FilePath
  | RepositoryRootNotAbsolute FilePath
  | RepositoryRootMismatch FilePath FilePath
  | GitProcessFailure [String] Int Text
  | GitProcessIoFailure [String] Text
  | EmptyIndex
  | MissingNulTerminator
  | MalformedIndexRecord Int Text
  | UnsupportedIndexMode Int Text
  | NonStageZeroEntry Int Text
  | InvalidObjectId Int Text
  | InvalidTrackedPath Int Text
  | DuplicateTrackedPath FilePath
  | MissingLoadedBlob Text
  | InvalidSnapshotIdentity Text
  | MissingIndexFlagNulTerminator IndexFlagObservation
  | MalformedIndexFlagRecord IndexFlagObservation Int Text
  | DuplicateIndexFlagPath IndexFlagObservation FilePath
  | IndexFlagInventoryMismatch IndexFlagObservation [FilePath] [FilePath]
  | AssumeUnchangedTrackedPaths [FilePath]
  | SkipWorktreeTrackedPaths [FilePath]
  | TrackedWorktreePathMissing FilePath
  | TrackedWorktreeExecutableModeUnavailable FilePath
  | TrackedWorktreeKindMismatch FilePath IndexMode WorktreeEntryKind
  | TrackedWorktreeExecutableMismatch FilePath Bool Bool
  | TrackedWorktreeBytesMismatch FilePath
  | TrackedWorktreeEntryRace FilePath
  | TrackedWorktreeIoFailure FilePath Text
  | InvalidWorktreeSymlinkTarget FilePath
  | TrackedWorktreeChangedDuringAcquisition [FilePath]
  | AuthoredRootInventoryIoFailure FilePath Text
  | InvalidAuthoredRootPath FilePath
  | AuthoredRootAncestorKindMismatch FilePath WorktreeEntryKind
  | UnexpectedAuthoredRootMaterial [FilePath]
  | AuthoredRootChangedDuringAcquisition [FilePath] [FilePath] [FilePath]
  | TrackedWorktreeDivergence [FilePath]
  | UntrackedNonIgnoredPaths [FilePath]
  | IndexChangedDuringAcquisition
  | InvalidWorkspacePath Text
  deriving (Eq, Ord, Show)

data SourceDebtId
  = SourceTools
  | SourceDhall
  | SourceProto
  | SourceUi
  | SourcePulumi
  | SourceTest
  | SourceProbe
  | SourcePb
  | SourceVendor
  deriving (Eq, Ord, Enum, Bounded, Show)

data PbSemanticRole
  = PbPlatformToolchainSelection
  | PbToolchainEnsure
  | PbBinaryBuild
  | PbOpaqueExecHandoff
  | PbPackageMarker
  | PbPackageMetadata
  deriving (Eq, Ord, Enum, Bounded, Show)

-- | Every path has exactly one primary class.  Evidence which may overlap --
-- for example, executable mode plus a shebang -- is represented by 'SourceFacet'
-- rather than by assigning a second class.
data SourceClass
  = HaskellSource
  | DocumentationInput
  | ProjectDeclaration
  | PbBootstrapSource
  | RegisteredLegacy SourceDebtId
  | UnregisteredBehavioralSource
  deriving (Eq, Ord, Show)

data SourceFacet
  = ExecutableModeFacet
  | ShebangFacet Text
  | SymbolicLinkFacet Text
  | BinaryContentFacet
  | ForeignSourceSignatureFacet Text
  | PbRoleFacet PbSemanticRole
  deriving (Eq, Ord, Show)

data ClassifiedPath = ClassifiedPath
  { classifiedEntry :: TrackedEntry
  , classifiedAs :: SourceClass
  , classificationFacets :: [SourceFacet]
  , classificationReasons :: [Text]
  }
  deriving (Eq, Ord, Show)

data SourceClosure = SourceClosure
  { closureSnapshotIdentity :: Text
  , closurePaths :: [ClassifiedPath]
  , closureRegisteredDebt :: Map SourceDebtId [FilePath]
  , closureProblems :: [SnapshotProblem]
  }
  deriving (Eq, Show)

mkGitExecutable :: FilePath -> Either SnapshotProblem GitExecutable
mkGitExecutable executable
  | isAbsolute executable = Right (GitExecutable executable)
  | otherwise = Left (GitExecutableNotAbsolute executable)

-- | Acquire the complete stage-zero index and each referenced blob.  Both the
-- Git binary and repository root must be explicit absolute paths.  The blobs
-- remain classification authority, while independent worktree reads must match
-- them exactly; an unmerged entry or unsupported index mode refuses the
-- snapshot rather than being omitted.
loadGitSnapshot :: GitExecutable -> FilePath -> IO (Either [SnapshotProblem] SourceSnapshot)
loadGitSnapshot git root
  | not (isAbsolute root) = pure (Left [RepositoryRootNotAbsolute root])
  | otherwise = do
      topResult <- runGit git root ["rev-parse", "--show-toplevel"] ByteString.empty
      case topResult of
        Left problem -> pure (Left [problem])
        Right topBytes ->
          case decodeOneLine topBytes of
            Left detail -> pure (Left [GitProcessIoFailure ["rev-parse", "--show-toplevel"] detail])
            Right top
              | canonicalPath top /= canonicalPath root ->
                  pure (Left [RepositoryRootMismatch root top])
              | otherwise -> do
                  workspaceProblems <- checkCandidateWorkspace git root
                  if null workspaceProblems
                    then loadIndex git root
                    else pure (Left workspaceProblems)

loadIndex :: GitExecutable -> FilePath -> IO (Either [SnapshotProblem] SourceSnapshot)
loadIndex git root = do
  listing <-
    runGit
      git
      root
      ["ls-files", "--cached", "--full-name", "--stage", "-z"]
      ByteString.empty
  case listing of
    Left problem -> pure (Left [problem])
    Right raw ->
      case parseLsFilesStage raw of
        Left problems -> pure (Left problems)
        Right entries -> do
          blobs <- loadBlobs git root entries
          case blobs of
            Left problems -> pure (Left problems)
            Right byObject ->
              case traverse (attachLoadedBlob byObject) entries of
                Left problem -> pure (Left [problem])
                Right tracked -> do
                  beforeResult <- observeAcquisitionBoundary git root entries tracked
                  case beforeResult of
                    Left problems -> pure (Left problems)
                    Right before -> do
                      let manifest = renderIndexManifest entries
                      identityResult <- runGit git root ["hash-object", "--stdin"] manifest
                      case identityResult of
                        Left problem -> pure (Left [problem])
                        Right identityBytes ->
                          case decodeOneLine identityBytes of
                            Left detail -> pure (Left [InvalidSnapshotIdentity detail])
                            Right identityPath
                              | not (validObjectId (Text.pack identityPath)) ->
                                  pure (Left [InvalidSnapshotIdentity (Text.pack identityPath)])
                              | otherwise -> do
                                  workspaceProblems <- checkCandidateWorkspace git root
                                  afterResult <- observeAcquisitionBoundary git root entries tracked
                                  finalIndexProblems <- observeFinalIndexVisibility git root entries
                                  let (afterProblems, boundaryProblems) = case afterResult of
                                        Left problems -> (problems, [])
                                        Right after -> ([], compareAcquisitionBoundaries before after)
                                      finalProblems =
                                        workspaceProblems
                                          <> afterProblems
                                          <> boundaryProblems
                                          <> finalIndexProblems
                                  pure $
                                    if null finalProblems
                                      then
                                        Right
                                          SourceSnapshot
                                            { snapshotRoot = root
                                            , snapshotIdentity = Text.pack identityPath
                                            , snapshotEntries = tracked
                                            }
                                      else Left finalProblems

attachLoadedBlob :: Map Text ByteString -> IndexEntry -> Either SnapshotProblem TrackedEntry
attachLoadedBlob byObject entry =
  case Map.lookup (indexObjectId entry) byObject of
    Nothing -> Left (MissingLoadedBlob (indexObjectId entry))
    Just bytes -> Right (TrackedEntry entry bytes)

-- | Observe every acquisition boundary which Git's ordinary dirty-worktree
-- summary can conceal: index visibility flags, raw worktree bytes/kinds/modes,
-- and recursively discovered material outside the four explicitly excluded
-- state/control roots.
observeAcquisitionBoundary
  :: GitExecutable
  -> FilePath
  -> [IndexEntry]
  -> [TrackedEntry]
  -> IO (Either [SnapshotProblem] WorktreeAcquisitionObservation)
observeAcquisitionBoundary git root entries tracked = do
  flagProblems <- observeIndexVisibility git root entries
  trackedResult <- observeTrackedWorktree root tracked
  authoredResult <- inventoryAuthoredPaths root
  let (trackedObservationProblems, trackedValues) = case trackedResult of
        Left foundProblems -> (foundProblems, Nothing)
        Right values -> ([], Just values)
      (authoredObservationProblems, authoredValues) = case authoredResult of
        Left foundProblems -> (foundProblems, Nothing)
        Right values ->
          let expectedLeaves = Set.fromList (map indexPath entries)
              expectedAncestors = Set.fromList (concatMap (trackedPathParents . indexPath) entries)
              expectedPaths = expectedLeaves `Set.union` expectedAncestors
              unexpected = Set.toAscList (Map.keysSet values `Set.difference` expectedPaths)
              wrongAncestors =
                [ AuthoredRootAncestorKindMismatch path observedKind
                | path <- Set.toAscList expectedAncestors
                , Just observedKind <- [Map.lookup path values]
                , observedKind /= WorktreeDirectory
                ]
              foundProblems =
                wrongAncestors
                  <> [UnexpectedAuthoredRootMaterial unexpected | not (null unexpected)]
           in (foundProblems, Just values)
      allProblems = flagProblems <> trackedObservationProblems <> authoredObservationProblems
  pure $ case (allProblems, trackedValues, authoredValues) of
    ([], Just trackedObservation, Just authoredObservation) ->
      Right
        WorktreeAcquisitionObservation
          { acquisitionTrackedEntries = trackedObservation
          , acquisitionAuthoredPaths = authoredObservation
          }
    _ -> Left allProblems

compareAcquisitionBoundaries
  :: WorktreeAcquisitionObservation
  -> WorktreeAcquisitionObservation
  -> [SnapshotProblem]
compareAcquisitionBoundaries before after = trackedProblems <> authoredProblems
 where
  beforeTracked = acquisitionTrackedEntries before
  afterTracked = acquisitionTrackedEntries after
  changedTracked =
    Set.toAscList
      ( Set.fromList
          [ path
          | path <- Set.toAscList (Map.keysSet beforeTracked `Set.union` Map.keysSet afterTracked)
          , Map.lookup path beforeTracked /= Map.lookup path afterTracked
          ]
      )
  trackedProblems = [TrackedWorktreeChangedDuringAcquisition changedTracked | not (null changedTracked)]
  beforeAuthored = acquisitionAuthoredPaths before
  afterAuthored = acquisitionAuthoredPaths after
  commonAuthored = Map.keysSet beforeAuthored `Set.intersection` Map.keysSet afterAuthored
  added = Set.toAscList (Map.keysSet afterAuthored `Set.difference` Map.keysSet beforeAuthored)
  removed = Set.toAscList (Map.keysSet beforeAuthored `Set.difference` Map.keysSet afterAuthored)
  changed =
    [ path
    | path <- Set.toAscList commonAuthored
    , Map.lookup path beforeAuthored /= Map.lookup path afterAuthored
    ]
  authoredProblems =
    [ AuthoredRootChangedDuringAcquisition added removed changed
    | not (null added) || not (null removed) || not (null changed)
    ]

observeIndexVisibility :: GitExecutable -> FilePath -> [IndexEntry] -> IO [SnapshotProblem]
observeIndexVisibility git root entries = do
  assumeResult <-
    runGit
      git
      root
      ["ls-files", "--cached", "--full-name", "-v", "-z"]
      ByteString.empty
  skipResult <-
    runGit
      git
      root
      ["ls-files", "--cached", "--full-name", "-t", "-z"]
      ByteString.empty
  let expected = sort (map indexPath entries)
  pure
    ( taggedObservationProblems AssumeUnchangedObservation expected isAssumeUnchanged assumeResult
        <> taggedObservationProblems SkipWorktreeObservation expected isSkipWorktree skipResult
    )

-- | Make the final index observation one tagged stage listing.  The @-v@ tag
-- retains @S@ for skip-worktree and lower-cases every assume-unchanged tag, so
-- this one NUL-delimited stream binds both visibility flags to the exact mode,
-- object id, stage, and path inventory observed at the end of acquisition.
observeFinalIndexVisibility :: GitExecutable -> FilePath -> [IndexEntry] -> IO [SnapshotProblem]
observeFinalIndexVisibility git root expected = do
  result <-
    runGit
      git
      root
      ["ls-files", "--cached", "--full-name", "--stage", "-v", "-z"]
      ByteString.empty
  pure $ case result of
    Left problem -> [problem]
    Right raw -> case parseLsFilesTaggedStage raw of
      Left problems -> problems
      Right tagged ->
        let actual = map snd tagged
            expectedPaths = sort (map indexPath expected)
            actualPaths = sort (map indexPath actual)
            inventoryProblems =
              [ IndexFlagInventoryMismatch AssumeUnchangedObservation expectedPaths actualPaths
              | expectedPaths /= actualPaths
              ]
            indexProblems = [IndexChangedDuringAcquisition | expected /= actual]
            assumeUnchanged = sort [indexPath entry | (tag, entry) <- tagged, isAssumeUnchanged tag]
            skipWorktree = sort [indexPath entry | (tag, entry) <- tagged, isSkipWorktree tag]
            flagProblems =
              [AssumeUnchangedTrackedPaths assumeUnchanged | not (null assumeUnchanged)]
                <> [SkipWorktreeTrackedPaths skipWorktree | not (null skipWorktree)]
         in inventoryProblems <> indexProblems <> flagProblems

taggedObservationProblems
  :: IndexFlagObservation
  -> [FilePath]
  -> (Char -> Bool)
  -> Either SnapshotProblem ByteString
  -> [SnapshotProblem]
taggedObservationProblems _ _ _ (Left problem) = [problem]
taggedObservationProblems observationKind expected isFlagged (Right bytes) =
  case parseLsFilesTaggedPaths observationKind bytes of
    Left problems -> problems
    Right tagged ->
      let actual = sort (map snd tagged)
          inventoryProblems =
            [IndexFlagInventoryMismatch observationKind expected actual | expected /= actual]
          flagged = sort [path | (tag, path) <- tagged, isFlagged tag]
          flagProblems = case observationKind of
            AssumeUnchangedObservation -> [AssumeUnchangedTrackedPaths flagged | not (null flagged)]
            SkipWorktreeObservation -> [SkipWorktreeTrackedPaths flagged | not (null flagged)]
       in inventoryProblems <> flagProblems

isAssumeUnchanged :: Char -> Bool
isAssumeUnchanged tag = tag >= 'a' && tag <= 'z'

isSkipWorktree :: Char -> Bool
isSkipWorktree tag = tag == 'S' || tag == 's'

observeTrackedWorktree
  :: FilePath
  -> [TrackedEntry]
  -> IO (Either [SnapshotProblem] (Map FilePath WorktreeEntryObservation))
observeTrackedWorktree root entries = do
  results <- forM entries (observeTrackedEntry root)
  let problems = concat [items | Left items <- results]
      observations = [item | Right item <- results]
  pure $
    if null problems
      then Right (Map.fromList observations)
      else Left problems

observeTrackedEntry
  :: FilePath
  -> TrackedEntry
  -> IO (Either [SnapshotProblem] (FilePath, WorktreeEntryObservation))
observeTrackedEntry root entry = do
  let indexed = trackedIndex entry
      path = indexPath indexed
      absolute = root </> path
  result <- readWorktreeEntry root path absolute
  pure $ case result of
    Left problem -> Left [problem]
    Right observed ->
      let comparisonProblems = compareTrackedEntry entry observed
       in if null comparisonProblems then Right (path, observed) else Left comparisonProblems

readWorktreeEntry :: FilePath -> FilePath -> FilePath -> IO (Either SnapshotProblem WorktreeEntryObservation)
#if defined(mingw32_HOST_OS)
readWorktreeEntry _root path _absolute = pure (Left (TrackedWorktreeExecutableModeUnavailable path))
#else
readWorktreeEntry root path absolute = do
  initialResult <- try (Posix.getSymbolicLinkStatus absolute) :: IO (Either IOException Posix.FileStatus)
  case initialResult of
    Left problem
      | isDoesNotExistError problem -> pure (Left (TrackedWorktreePathMissing path))
      | otherwise -> pure (Left (TrackedWorktreeIoFailure path (Text.pack (displayException problem))))
    Right before -> do
      observedResult <-
        try (readPresentWorktreeEntry root path absolute before)
          :: IO (Either IOException (Either SnapshotProblem WorktreeEntryObservation))
      pure $ case observedResult of
        Left problem
          | isDoesNotExistError problem -> Left (TrackedWorktreeEntryRace path)
          | otherwise -> Left (TrackedWorktreeIoFailure path (Text.pack (displayException problem)))
        Right result -> result

readPresentWorktreeEntry
  :: FilePath
  -> FilePath
  -> FilePath
  -> Posix.FileStatus
  -> IO (Either SnapshotProblem WorktreeEntryObservation)
readPresentWorktreeEntry root path absolute before
  | Posix.isSymbolicLink before = readWorktreeSymbolicLink path absolute before
  | Posix.isRegularFile before = readWorktreeRegularFile root path absolute before
  | otherwise = readWorktreeNonFile path absolute before

readWorktreeSymbolicLink
  :: FilePath
  -> FilePath
  -> Posix.FileStatus
  -> IO (Either SnapshotProblem WorktreeEntryObservation)
readWorktreeSymbolicLink path absolute before = do
  target <- Posix.readSymbolicLink absolute
  after <- Posix.getSymbolicLinkStatus absolute
  pure $
    if not (Posix.isSymbolicLink after) || statusFingerprint before /= statusFingerprint after
      then Left (TrackedWorktreeEntryRace path)
      else case encodeFilesystemPath target of
        Nothing -> Left (InvalidWorktreeSymlinkTarget path)
        Just bytes ->
          Right
            WorktreeEntryObservation
              { worktreeObservedKind = WorktreeSymbolicLink
              , worktreeObservedExecutable = False
              , worktreeObservedBytes = bytes
              , worktreeObservedStatus = statusFingerprint after
              }

readWorktreeRegularFile
  :: FilePath
  -> FilePath
  -> FilePath
  -> Posix.FileStatus
  -> IO (Either SnapshotProblem WorktreeEntryObservation)
readWorktreeRegularFile root path absolute before =
  withTrackedParentDirectoryFd root path $ \parentFd leaf ->
    bracket
      (PosixIO.openFdAt (Just parentFd) leaf PosixIO.ReadOnly regularReadFlags)
      PosixIO.closeFd
      (\fd -> do
          opened <- Posix.getFdStatus fd
          if not (Posix.isRegularFile opened) || statusFingerprint opened /= statusFingerprint before
            then pure (Left (TrackedWorktreeEntryRace path))
            else do
              bytes <- readStrictFd fd
              afterFd <- Posix.getFdStatus fd
              afterPath <- Posix.getSymbolicLinkStatus absolute
              let expectedStatus = statusFingerprint before
                  stable =
                    Posix.isRegularFile afterFd
                      && Posix.isRegularFile afterPath
                      && statusFingerprint opened == expectedStatus
                      && statusFingerprint afterFd == expectedStatus
                      && statusFingerprint afterPath == expectedStatus
              pure $
                if not stable
                  then Left (TrackedWorktreeEntryRace path)
                  else
                    Right
                      WorktreeEntryObservation
                        { worktreeObservedKind = WorktreeRegularFile
                        , worktreeObservedExecutable = rawOwnerExecutable afterFd
                        , worktreeObservedBytes = bytes
                        , worktreeObservedStatus = statusFingerprint afterFd
                        }
      )

withTrackedParentDirectoryFd
  :: FilePath
  -> FilePath
  -> (Fd -> FilePath -> IO value)
  -> IO value
withTrackedParentDirectoryFd root path action =
  case reverse (map Text.unpack (Text.splitOn "/" (Text.pack path))) of
    [] -> ioError (userError "tracked path has no final component")
    leaf : reversedParents ->
      bracket
        (PosixIO.openFd root PosixIO.ReadOnly directoryReadFlags)
        PosixIO.closeFd
        (\rootFd -> descend rootFd (reverse reversedParents) leaf)
 where
  descend parentFd [] leaf = action parentFd leaf
  descend parentFd (component : rest) leaf =
    bracket
      (PosixIO.openFdAt (Just parentFd) component PosixIO.ReadOnly directoryReadFlags)
      PosixIO.closeFd
      (\childFd -> descend childFd rest leaf)

directoryReadFlags :: PosixIO.OpenFileFlags
directoryReadFlags =
  PosixIO.defaultFileFlags
    { PosixIO.cloexec = True
    , PosixIO.directory = True
    , PosixIO.nofollow = True
    , PosixIO.nonBlock = True
    }

regularReadFlags :: PosixIO.OpenFileFlags
regularReadFlags =
  PosixIO.defaultFileFlags
    { PosixIO.cloexec = True
    , PosixIO.nofollow = True
    , PosixIO.nonBlock = True
    }

readStrictFd :: Fd -> IO ByteString
readStrictFd fd =
  bracket (duplicateFdHandle fd) hClose (go [])
 where
  go chunks handle = do
    chunk <- ByteString.hGetSome handle (64 * 1024)
    if ByteString.null chunk
      then pure (ByteString.concat (reverse chunks))
      else go (chunk : chunks) handle

duplicateFdHandle :: Fd -> IO Handle
duplicateFdHandle fd = do
  duplicate <- PosixIO.dup fd
  PosixIO.fdToHandle duplicate `onException` PosixIO.closeFd duplicate

readWorktreeNonFile
  :: FilePath
  -> FilePath
  -> Posix.FileStatus
  -> IO (Either SnapshotProblem WorktreeEntryObservation)
readWorktreeNonFile path absolute before = do
  after <- Posix.getSymbolicLinkStatus absolute
  let beforeKind = worktreeKind before
  pure $
    if worktreeKind after /= beforeKind || statusFingerprint before /= statusFingerprint after
      then Left (TrackedWorktreeEntryRace path)
      else
        Right
          WorktreeEntryObservation
            { worktreeObservedKind = beforeKind
            , worktreeObservedExecutable = False
            , worktreeObservedBytes = ByteString.empty
            , worktreeObservedStatus = statusFingerprint after
            }

worktreeKind :: Posix.FileStatus -> WorktreeEntryKind
worktreeKind status
  | Posix.isRegularFile status = WorktreeRegularFile
  | Posix.isSymbolicLink status = WorktreeSymbolicLink
  | Posix.isDirectory status = WorktreeDirectory
  | otherwise = WorktreeOther

rawOwnerExecutable :: Posix.FileStatus -> Bool
rawOwnerExecutable status =
  Posix.fileMode status `Posix.intersectFileModes` Posix.ownerExecuteMode
    /= Posix.nullFileMode

statusFingerprint :: Posix.FileStatus -> WorktreeStatusFingerprint
statusFingerprint status =
  WorktreeStatusFingerprint
    { statusDevice = renderStatusField (Posix.deviceID status)
    , statusFileIdentity = renderStatusField (Posix.fileID status)
    , statusMode = renderStatusField (Posix.fileMode status)
    , statusSize = renderStatusField (Posix.fileSize status)
    , statusModified = renderStatusField (Posix.modificationTimeHiRes status)
    , statusChanged = renderStatusField (Posix.statusChangeTimeHiRes status)
    }

renderStatusField :: Show value => value -> Text
renderStatusField = Text.pack . show
#endif

compareTrackedEntry :: TrackedEntry -> WorktreeEntryObservation -> [SnapshotProblem]
compareTrackedEntry entry observed = kindProblems <> executableProblems <> byteProblems
 where
  indexed = trackedIndex entry
  path = indexPath indexed
  expectedMode = indexMode indexed
  expectedKind = case expectedMode of
    RegularFile -> WorktreeRegularFile
    ExecutableFile -> WorktreeRegularFile
    SymbolicLink -> WorktreeSymbolicLink
  expectedExecutable = expectedMode == ExecutableFile
  actualKind = worktreeObservedKind observed
  kindProblems = [TrackedWorktreeKindMismatch path expectedMode actualKind | actualKind /= expectedKind]
  executableProblems =
    [ TrackedWorktreeExecutableMismatch path expectedExecutable (worktreeObservedExecutable observed)
    | actualKind == WorktreeRegularFile
    , worktreeObservedExecutable observed /= expectedExecutable
    ]
  byteProblems =
    [ TrackedWorktreeBytesMismatch path
    | actualKind `elem` [WorktreeRegularFile, WorktreeSymbolicLink]
    , worktreeObservedBytes observed /= trackedBytes entry
    ]

inventoryAuthoredPaths :: FilePath -> IO (Either [SnapshotProblem] (Map FilePath WorktreeEntryKind))
inventoryAuthoredPaths root = fmap (fmap Map.fromList) (walkAuthoredDirectory root "")

walkAuthoredDirectory
  :: FilePath
  -> FilePath
  -> IO (Either [SnapshotProblem] [(FilePath, WorktreeEntryKind)])
walkAuthoredDirectory root relativeDirectory = do
  let absoluteDirectory = if null relativeDirectory then root else root </> relativeDirectory
      subject = if null relativeDirectory then "." else relativeDirectory
  listingResult <- try (listDirectory absoluteDirectory) :: IO (Either IOException [FilePath])
  case listingResult of
    Left problem -> pure (Left [AuthoredRootInventoryIoFailure subject (Text.pack (displayException problem))])
    Right names -> do
      children <- forM (sort names) (walkAuthoredChild root relativeDirectory)
      pure (combineInventoryResults children)

walkAuthoredChild
  :: FilePath
  -> FilePath
  -> FilePath
  -> IO (Either [SnapshotProblem] [(FilePath, WorktreeEntryKind)])
walkAuthoredChild root parent name = do
  let relative = if null parent then name else parent </> name
      absolute = root </> relative
  if null parent && name `elem` excludedRepositoryRoots
    then pure (Right [])
    else
      if not (validFilesystemPath relative)
        then pure (Left [InvalidAuthoredRootPath relative])
        else do
          kindResult <-
            try
              ( do
                  link <- pathIsSymbolicLink absolute
                  directory <- if link then pure False else doesDirectoryExist absolute
                  exists <- if link || directory then pure True else doesPathExist absolute
                  pure (link, directory, exists)
              ) :: IO (Either IOException (Bool, Bool, Bool))
          case kindResult of
            Left problem -> pure (Left [AuthoredRootInventoryIoFailure relative (Text.pack (displayException problem))])
            Right (_, _, False) -> pure (Left [AuthoredRootInventoryIoFailure relative "path disappeared during recursive inventory"])
            Right (True, _, _) -> pure (Right [(relative, WorktreeSymbolicLink)])
            Right (_, True, _) -> fmap (fmap ((relative, WorktreeDirectory) :)) (walkAuthoredDirectory root relative)
            Right (_, _, _) -> pure (Right [(relative, WorktreeRegularFile)])

combineInventoryResults
  :: [Either [SnapshotProblem] [(FilePath, WorktreeEntryKind)]]
  -> Either [SnapshotProblem] [(FilePath, WorktreeEntryKind)]
combineInventoryResults results =
  let problems = concat [items | Left items <- results]
      paths = concat [items | Right items <- results]
   in if null problems then Right paths else Left problems

excludedRepositoryRoots :: [FilePath]
excludedRepositoryRoots = [".git", ".build", ".data", ".test_data"]

trackedPathParents :: FilePath -> [FilePath]
trackedPathParents path = go (takeDirectory path)
 where
  go parent
    | null parent || parent == "." || parent == path = []
    | otherwise = parent : go (takeDirectory parent)

validFilesystemPath :: FilePath -> Bool
validFilesystemPath path =
  safeTrackedPath path
    && all (not . surrogateCodePoint) path
    && all safeFilesystemCharacter path

safeFilesystemCharacter :: Char -> Bool
safeFilesystemCharacter character =
  character >= ' '
    && character /= '\DEL'
    && character /= '\\'

encodeFilesystemPath :: FilePath -> Maybe ByteString
encodeFilesystemPath path
  | all (not . surrogateCodePoint) path = Just (TextEncoding.encodeUtf8 (Text.pack path))
  | otherwise = Nothing

surrogateCodePoint :: Char -> Bool
surrogateCodePoint character = character >= '\xD800' && character <= '\xDFFF'

-- | Refuse bytes which are visible in the worktree but absent from the index
-- snapshot.  Ignored paths are deliberately not returned: generated roots are
-- residue/clean-room concerns and never become authored classifier input.
checkCandidateWorkspace :: GitExecutable -> FilePath -> IO [SnapshotProblem]
checkCandidateWorkspace _ root | not (isAbsolute root) = pure [RepositoryRootNotAbsolute root]
checkCandidateWorkspace git root = do
  changedResult <-
    runGit
      git
      root
      ["diff-files", "--name-only", "--ignore-submodules=none", "-z", "--"]
      ByteString.empty
  untrackedResult <-
    runGit
      git
      root
      ["ls-files", "--others", "--exclude-standard", "-z"]
      ByteString.empty
  pure (pathResult TrackedWorktreeDivergence changedResult <> pathResult UntrackedNonIgnoredPaths untrackedResult)
  where
    pathResult constructor result = case result of
      Left problem -> [problem]
      Right bytes -> case decodeNulPathList bytes of
        Left problem -> [problem]
        Right [] -> []
        Right paths -> [constructor paths]

loadBlobs
  :: GitExecutable
  -> FilePath
  -> [IndexEntry]
  -> IO (Either [SnapshotProblem] (Map Text ByteString))
loadBlobs git root entries =
  foldM loadOne (Right Map.empty) (Set.toAscList objectIds)
  where
    objectIds = Set.fromList (map indexObjectId entries)
    loadOne (Left problems) _ = pure (Left problems)
    loadOne (Right loaded) objectId = do
      bytes <- runGit git root ["cat-file", "blob", Text.unpack objectId] ByteString.empty
      pure $ case bytes of
        Left problem -> Left [problem]
        Right value -> Right (Map.insert objectId value loaded)

-- | Parse the raw, NUL-delimited output of @git ls-files --stage -z@.  This is
-- deliberately exported so oracle tests can exercise malformed records without
-- invoking Git.
parseLsFilesStage :: ByteString -> Either [SnapshotProblem] [IndexEntry]
parseLsFilesStage raw =
  case ByteString.unsnoc raw of
    Nothing -> Left [EmptyIndex]
    Just (_, terminator)
      | terminator /= 0 -> Left [MissingNulTerminator]
      | otherwise ->
          let records = dropFinalSegment (ByteString.split 0 raw)
              parsed = zipWith parseIndexRecord [1 ..] records
              recordProblems = [problem | Left problem <- parsed]
              entries = [entry | Right entry <- parsed]
              duplicateProblems = map DuplicateTrackedPath (duplicates (map indexPath entries))
              problems = recordProblems <> duplicateProblems
           in if null problems
                then Right (sortOn indexPath entries)
                else Left problems

-- | Parse @git ls-files -v/-t -z@ without trusting line delimiters or a locale.
-- Each record is exactly one ASCII status tag, one space, one UTF-8 repository
-- path, and one NUL terminator.  The caller independently compares the returned
-- path inventory with the stage-zero listing.
parseLsFilesTaggedPaths
  :: IndexFlagObservation
  -> ByteString
  -> Either [SnapshotProblem] [(Char, FilePath)]
parseLsFilesTaggedPaths observationKind raw =
  case ByteString.unsnoc raw of
    Just (_, terminator)
      | terminator == 0 ->
          let records = dropFinalSegment (ByteString.split 0 raw)
              parsed = zipWith (parseTaggedPathRecord observationKind) [1 ..] records
              parseProblems = [problem | Left problem <- parsed]
              tagged = [value | Right value <- parsed]
              duplicateProblems =
                [ DuplicateIndexFlagPath observationKind path
                | path <- duplicates (map snd tagged)
                ]
              problems = parseProblems <> duplicateProblems
           in if null problems then Right (sortOn snd tagged) else Left problems
    _ -> Left [MissingIndexFlagNulTerminator observationKind]

-- | Parse the final @git ls-files --stage -v -z@ observation.  Unlike a
-- path-only tagged listing, each record binds its visibility tag to the exact
-- stage-zero index entry which produced it.
parseLsFilesTaggedStage :: ByteString -> Either [SnapshotProblem] [(Char, IndexEntry)]
parseLsFilesTaggedStage raw =
  case ByteString.unsnoc raw of
    Just (_, terminator)
      | terminator == 0 ->
          let records = dropFinalSegment (ByteString.split 0 raw)
              parsed = zipWith parseTaggedStageRecord [1 ..] records
              recordProblems = [problem | Left problem <- parsed]
              tagged = [value | Right value <- parsed]
              duplicateProblems =
                [ DuplicateIndexFlagPath AssumeUnchangedObservation path
                | path <- duplicates (map (indexPath . snd) tagged)
                ]
              problems = recordProblems <> duplicateProblems
           in if null problems
                then Right (sortOn (indexPath . snd) tagged)
                else Left problems
    _ -> Left [MissingIndexFlagNulTerminator AssumeUnchangedObservation]

parseTaggedStageRecord :: Int -> ByteString -> Either SnapshotProblem (Char, IndexEntry)
parseTaggedStageRecord number record =
  case ByteString8.uncons record of
    Nothing -> malformed "empty tagged stage record"
    Just (tag, withSpace) ->
      case ByteString8.uncons withSpace of
        Just (' ', stageRecord)
          | validIndexTag AssumeUnchangedObservation tag -> do
              entry <- parseIndexRecord number stageRecord
              Right (tag, entry)
          | otherwise -> malformed ("unsupported ls-files tag " <> Text.singleton tag)
        _ -> malformed "tagged stage record lacks its status/index space"
 where
  malformed detail = Left (MalformedIndexFlagRecord AssumeUnchangedObservation number detail)

parseTaggedPathRecord
  :: IndexFlagObservation
  -> Int
  -> ByteString
  -> Either SnapshotProblem (Char, FilePath)
parseTaggedPathRecord observationKind number record =
  case ByteString8.uncons record of
    Nothing -> malformed "empty tagged record"
    Just (tag, withSpace) ->
      case ByteString8.uncons withSpace of
        Just (' ', pathBytes)
          | validIndexTag observationKind tag ->
              case TextEncoding.decodeUtf8' pathBytes of
                Left _ -> malformed "tagged path is not UTF-8"
                Right value ->
                  let path = Text.unpack value
                   in if safeTrackedPath path
                        then Right (tag, path)
                        else malformed ("invalid tagged path " <> Text.pack path)
          | otherwise -> malformed ("unsupported ls-files tag " <> Text.singleton tag)
        _ -> malformed "tagged record lacks its status/path space"
 where
  malformed detail = Left (MalformedIndexFlagRecord observationKind number detail)

validIndexTag :: IndexFlagObservation -> Char -> Bool
validIndexTag observationKind tag = case observationKind of
  AssumeUnchangedObservation ->
    tag `elem` ['H', 'S', 'M', 'R', 'C', 'K']
      || tag `elem` ['h', 's', 'm', 'r', 'c', 'k']
  SkipWorktreeObservation -> tag `elem` ['H', 'S', 'M', 'R', 'C', 'K']

decodeNulPathList :: ByteString -> Either SnapshotProblem [FilePath]
decodeNulPathList bytes = case ByteString.unsnoc bytes of
  Nothing -> Right []
  Just (_, terminator)
    | terminator /= 0 -> Left (InvalidWorkspacePath "Git path list lacks its final NUL")
    | otherwise -> traverse decodePath (dropFinalSegment (ByteString.split 0 bytes))
  where
    decodePath rawPath = case TextEncoding.decodeUtf8' rawPath of
      Left _ -> Left (InvalidWorkspacePath "Git path is not UTF-8")
      Right value
        | safeTrackedPath (Text.unpack value) -> Right (Text.unpack value)
        | otherwise -> Left (InvalidWorkspacePath value)

dropFinalSegment :: [value] -> [value]
dropFinalSegment values = case reverse values of
  [] -> []
  _ : reversedRest -> reverse reversedRest

parseIndexRecord :: Int -> ByteString -> Either SnapshotProblem IndexEntry
parseIndexRecord number record = do
  let (header, withTab) = ByteString.break (== 9) record
  pathBytes <-
    if ByteString.null withTab
      then Left (MalformedIndexRecord number "missing header/path tab")
      else Right (ByteString.drop 1 withTab)
  (modeBytes, objectBytes, stageBytes) <-
    case ByteString8.words header of
      [modeValue, objectValue, stageValue] -> Right (modeValue, objectValue, stageValue)
      _ -> Left (MalformedIndexRecord number "expected mode, object id, and stage")
  mode <- parseIndexMode number modeBytes
  if stageBytes /= "0"
    then Left (NonStageZeroEntry number (decodeLenient stageBytes))
    else pure ()
  objectId <- decodeAsciiField number objectBytes
  if validObjectId objectId
    then pure ()
    else Left (InvalidObjectId number objectId)
  path <-
    case TextEncoding.decodeUtf8' pathBytes of
      Left _ -> Left (InvalidTrackedPath number "path is not UTF-8")
      Right value -> Right (Text.unpack value)
  if safeTrackedPath path
    then Right (IndexEntry path mode objectId)
    else Left (InvalidTrackedPath number (Text.pack path))

parseIndexMode :: Int -> ByteString -> Either SnapshotProblem IndexMode
parseIndexMode _ "100644" = Right RegularFile
parseIndexMode _ "100755" = Right ExecutableFile
parseIndexMode _ "120000" = Right SymbolicLink
parseIndexMode number value = Left (UnsupportedIndexMode number (decodeLenient value))

decodeAsciiField :: Int -> ByteString -> Either SnapshotProblem Text
decodeAsciiField number value =
  case TextEncoding.decodeUtf8' value of
    Left _ -> Left (MalformedIndexRecord number "non-ASCII object id")
    Right decoded
      | Text.all (\character -> fromEnum character < 128) decoded -> Right decoded
      | otherwise -> Left (MalformedIndexRecord number "non-ASCII object id")

validObjectId :: Text -> Bool
validObjectId value =
  Text.length value `elem` [40, 64]
    && Text.all isHexDigit value

safeTrackedPath :: FilePath -> Bool
safeTrackedPath path =
  not (null path)
    && not (isAbsolute path)
    && all safeFilesystemCharacter path
    && all validPart (Text.splitOn "/" (Text.pack path))
  where
    validPart part = not (Text.null part) && part /= "." && part /= ".."

renderIndexManifest :: [IndexEntry] -> ByteString
renderIndexManifest = ByteString.concat . map renderOne
  where
    renderOne entry =
      modeBytes (indexMode entry)
        <> " "
        <> TextEncoding.encodeUtf8 (indexObjectId entry)
        <> "\t"
        <> TextEncoding.encodeUtf8 (Text.pack (indexPath entry))
        <> "\0"
    modeBytes RegularFile = "100644"
    modeBytes ExecutableFile = "100755"
    modeBytes SymbolicLink = "120000"

classifySnapshot :: SourceSnapshot -> SourceClosure
classifySnapshot snapshot =
  SourceClosure
    { closureSnapshotIdentity = snapshotIdentity snapshot
    , closurePaths = paths
    , closureRegisteredDebt = debt
    , closureProblems = duplicateProblems
    }
  where
    paths = map classifyEntry (snapshotEntries snapshot)
    duplicateProblems = map DuplicateTrackedPath (duplicates (map pathOf (snapshotEntries snapshot)))
    pathOf = indexPath . trackedIndex
    debt =
      foldl'
        (\current item -> case classifiedAs item of
            RegisteredLegacy identifier ->
              Map.insertWith (<>) identifier [pathOf (classifiedEntry item)] current
            _ -> current
        )
        Map.empty
        paths

-- | Pure, total classification of one supplied tracked entry.  Root migrations
-- and format migrations are intentionally ordered so an entry cannot be charged
-- to two legacy rows.
classifyEntry :: TrackedEntry -> ClassifiedPath
classifyEntry entry =
  ClassifiedPath
    { classifiedEntry = entry
    , classifiedAs = finalClass
    , classificationFacets = facets
    , classificationReasons = reasons
    }
  where
    path = indexPath (trackedIndex entry)
    bytes = trackedBytes entry
    initial = primaryClass path bytes
    facets = entryFacets entry <> pbFacets path bytes
    structuralReasons = disallowedStructure initial facets
    signatureReasons = disallowedSignature initial path bytes facets
    reasons = primaryReasons initial path bytes <> structuralReasons <> signatureReasons
    finalClass
      | isRegistered initial = initial
      | null structuralReasons && null signatureReasons = initial
      | otherwise = UnregisteredBehavioralSource

primaryClass :: FilePath -> ByteString -> SourceClass
primaryClass path _bytes
  | inGeneratedRoot path = UnregisteredBehavioralSource
  | under "vendor" path = RegisteredLegacy SourceVendor
  | hasSuffix ".dhall" path || under "dhall" path = RegisteredLegacy SourceDhall
  | hasSuffix ".proto" path || under "proto" path = RegisteredLegacy SourceProto
  | path == "package.json" || under "ui" path = RegisteredLegacy SourceUi
  | under "pulumi" path = RegisteredLegacy SourcePulumi
  | under "probe" path && not (probeAdmitted path) = RegisteredLegacy SourceProbe
  | under "test" path && not (testAdmitted path) = RegisteredLegacy SourceTest
  | under "tools" path = RegisteredLegacy SourceTools
  -- The current pb tree remains a frozen Phase-0 migration family until the
  -- deny-by-default AST/import/effect audit and qualified external adapter
  -- observer exist. Lexical diagnostics never authorize the exception.
  | under canonicalPbRoot path = RegisteredLegacy SourcePb
  | admittedHaskellPath path = HaskellSource
  | admittedDocumentationPath path = DocumentationInput
  | admittedLicencePath path = DocumentationInput
  | isProjectDeclaration path = ProjectDeclaration
  | otherwise = UnregisteredBehavioralSource

inGeneratedRoot :: FilePath -> Bool
inGeneratedRoot path =
  case Policy.trackedGeneratedArtifact (Policy.generationContract Policy.canonicalPolicyContract) of
    Policy.TrackedGeneratedArtifactForbidden ->
      any (`under` path) [canonicalGeneratedRoot, ".data", ".test_data"]

canonicalPbRoot :: FilePath
canonicalPbRoot = Policy.pbRoot (Policy.pbContract Policy.canonicalPolicyContract)

canonicalGeneratedRoot :: FilePath
canonicalGeneratedRoot =
  Policy.generationRootPath (Policy.generationRoot (Policy.generationContract Policy.canonicalPolicyContract))

canonicalHaskellSuffix :: FilePath
canonicalHaskellSuffix =
  Policy.behavioralSourceSuffix (Policy.sourceBehavioralLanguage (Policy.sourceContract Policy.canonicalPolicyContract))

probeAdmitted :: FilePath -> Bool
probeAdmitted path =
  hasSuffix canonicalHaskellSuffix path
    || path == "probe/probe.cabal"

testAdmitted :: FilePath -> Bool
testAdmitted = hasSuffix canonicalHaskellSuffix

admittedHaskellPath :: FilePath -> Bool
admittedHaskellPath path =
  hasSuffix canonicalHaskellSuffix path
    && any (`under` path) ["src", "app", "test", "probe"]

admittedDocumentationPath :: FilePath -> Bool
admittedDocumentationPath path =
  hasSuffix ".md" path
    && ( path `elem` ["README.md", "AGENTS.md", "CLAUDE.md"]
           || any (`under` path) ["documents", "DEVELOPMENT_PLAN"]
           || under "src/vendor" path
       )

admittedLicencePath :: FilePath -> Bool
admittedLicencePath path =
  isLicence path
    && (takeFileName path == path || under "src/vendor" path)

-- | Negative-only lexical diagnostic for the migration footprint. A 'Right'
-- result does not admit a path as PbBootstrapSource: production classification
-- keeps every current pb path in LTD-SRC-008 until the deny-by-default AST,
-- resolved-call/effect audit, and external adapter observer are implemented.
classifyPbPythonRoles :: FilePath -> ByteString -> Either [Text] [PbSemanticRole]
classifyPbPythonRoles path bytes =
  case Map.lookup path allowedPbModules of
    Nothing -> Left ["Python module has no bounded bootstrap role"]
    Just roles ->
      let generic = forbiddenPbTokens bytes
          specific = roleProblems path bytes
          problems = generic <> specific
       in if null problems then Right roles else Left problems

allowedPbModules :: Map FilePath [PbSemanticRole]
allowedPbModules =
  Map.fromList
    [ ("pb/pb/__init__.py", [PbPackageMarker])
    , ("pb/pb/bootstrap.py", [PbBinaryBuild, PbOpaqueExecHandoff])
    , ("pb/pb/bootstrap_toolchain.py", [PbToolchainEnsure])
    , ("pb/pb/cli.py", [PbOpaqueExecHandoff])
    , ("pb/pb/prereqs.py", [PbPlatformToolchainSelection])
    , ("pb/pb/process.py", [PbOpaqueExecHandoff])
    ]

forbiddenPbTokens :: ByteString -> [Text]
forbiddenPbTokens bytes =
  [ "forbidden pb semantic token: " <> token
  | token <-
      [ "pb.admin"
      , "adminclient"
      , "test_all"
      , "check_code"
      , "pytest"
      , "coverage."
      , "run_phase_gate"
      , "bootstrap_execution_envelope"
      ]
  , token `Text.isInfixOf` lowerText bytes
  ]

roleProblems :: FilePath -> ByteString -> [Text]
roleProblems path bytes
  | path == "pb/pb/cli.py" =
      missingAny ["execv", "execve", ".become", "os.exec"] bytes
        <> presentTokens ["click", "argparse", "@cli.", "--help", "--version"] bytes
  | path == "pb/pb/bootstrap.py" =
      missingTokens ["build", "handoff"] bytes
        <> missingAny ["execv", ".become", "os.exec"] bytes
  | path == "pb/pb/bootstrap_toolchain.py" =
      presentTokens ["kubectl", "kind", "helm", "pulumi", "docker"] bytes
        <> missingAny ["ghc", "cabal", "ghcup"] bytes
  | path == "pb/pb/prereqs.py" =
      presentTokens
        [ "host_floor"
        , "\"kubectl\""
        , "\"kind\""
        , "\"helm\""
        , "\"pulumi\""
        , "\"docker\""
        , "ensure_toolchain"
        , "ensure_build_toolchain"
        , "urllib.request"
        ]
        bytes
  | path == "pb/pb/__init__.py" = presentTokens ["__version__", "click", "argparse"] bytes
  | otherwise = []

pbMetadataProblems :: ByteString -> [Text]
pbMetadataProblems bytes =
  missingTokens ["[build-system]", "[project]", "[project.scripts]", "pb ="] bytes
    <> presentTokens
      [ "[tool.pytest"
      , "[tool.coverage"
      , "group.dev.dependencies"
      , "test_all"
      , "admin"
      ]
      bytes

missingTokens :: [Text] -> ByteString -> [Text]
missingTokens tokens bytes =
  ["required pb token absent: " <> token | token <- tokens, not (token `Text.isInfixOf` lowerText bytes)]

missingAny :: [Text] -> ByteString -> [Text]
missingAny tokens bytes
  | any (`Text.isInfixOf` lowerText bytes) tokens = []
  | otherwise = ["required pb exec handoff absent"]

presentTokens :: [Text] -> ByteString -> [Text]
presentTokens tokens bytes =
  ["forbidden pb surface token: " <> token | token <- tokens, token `Text.isInfixOf` lowerText bytes]

pbFacets :: FilePath -> ByteString -> [SourceFacet]
pbFacets path bytes
  | path == "pb/pyproject.toml" = [PbRoleFacet PbPackageMetadata]
  | hasSuffix ".py" path =
      case classifyPbPythonRoles path bytes of
        Left _ -> []
        Right roles -> map PbRoleFacet roles
  | otherwise = []

entryFacets :: TrackedEntry -> [SourceFacet]
entryFacets entry = modeFacets <> shebangFacets <> contentFacets
  where
    bytes = trackedBytes entry
    modeFacets = case indexMode (trackedIndex entry) of
      RegularFile -> []
      ExecutableFile -> [ExecutableModeFacet]
      SymbolicLink -> [SymbolicLinkFacet (decodeLenient bytes)]
    shebangFacets = maybe [] (pure . ShebangFacet) (shebang bytes)
    contentFacets
      | ByteString.elem 0 bytes = [BinaryContentFacet]
      | otherwise = maybe [] (pure . ForeignSourceSignatureFacet) (foreignSourceSignature bytes)

disallowedStructure :: SourceClass -> [SourceFacet] -> [Text]
disallowedStructure sourceClass facets
  | isRegistered sourceClass = []
  | otherwise =
      concat
        [ ["tracked executable mode is not an authored-source role" | ExecutableModeFacet `elem` facets]
        , ["tracked symbolic links are not admitted source" | any isSymlinkFacet facets]
        , ["tracked binary bytes are not admitted source" | BinaryContentFacet `elem` facets]
        , ["a shebang may not disguise an authored source role" | any isShebangFacet facets && sourceClass /= PbBootstrapSource]
        ]

disallowedSignature :: SourceClass -> FilePath -> ByteString -> [SourceFacet] -> [Text]
disallowedSignature sourceClass _path bytes facets
  | isRegistered sourceClass = []
  | sourceClass == UnregisteredBehavioralSource = ["path has no admitted authored-source class"]
  | not (textual bytes) = ["authored text is not valid UTF-8"]
  | sourceClass == HaskellSource && any isForeignSignatureFacet facets =
      [".hs bytes begin with a foreign-language source signature"]
  | sourceClass `elem` [DocumentationInput, ProjectDeclaration]
      && any isForeignSignatureFacet facets =
      ["an admitted non-code input begins with a behavioral-source signature"]
  | otherwise = []

primaryReasons :: SourceClass -> FilePath -> ByteString -> [Text]
primaryReasons (RegisteredLegacy SourcePb) path bytes =
  case if hasSuffix ".py" path then classifyPbPythonRoles path bytes else Left (pbMetadataProblems bytes) of
    Left [] -> ["pb path is outside the bounded bootstrap grammar"]
    Left problems -> problems
    Right _ -> []
primaryReasons UnregisteredBehavioralSource _ _ = ["no closed-grammar class matched"]
primaryReasons _ _ _ = []

sourceClosureCheck :: SourceClosure -> CheckResult
sourceClosureCheck closure =
  CheckResult
    { checkName = "source-closure"
    , checkObservations =
        [ observation "source.snapshot" (closureSnapshotIdentity closure)
        , observation "source.path-count" (Text.pack (show (length (closurePaths closure))))
        ]
          <> concatMap pathObservation (closurePaths closure)
          <> concatMap debtObservations (Map.toAscList (closureRegisteredDebt closure))
    , checkFindings =
        map snapshotFinding (closureProblems closure)
          <> concatMap pathFindings (closurePaths closure)
    }
  where
    pathObservation item =
      let entry = trackedIndex (classifiedEntry item)
          path = Text.pack (indexPath entry)
       in [ observation
          ("source.path." <> path)
          ( renderSourceClass (classifiedAs item)
              <> "\t"
              <> renderIndexMode (indexMode entry)
              <> "\t"
              <> indexObjectId entry
              <> "\t"
              <> Text.intercalate "," (map renderSourceFacet (classificationFacets item))
          )
          ]
    debtObservations (identifier, paths) =
      [ observation
          ("source.debt." <> renderSourceDebtId identifier <> "." <> Text.pack path)
          (Text.pack path)
      | path <- sortOn id paths
      ]
    pathFindings item
      | classifiedAs item /= UnregisteredBehavioralSource = []
      | otherwise =
          [ finding
              "SRC-UNREGISTERED"
              (indexPath (trackedIndex (classifiedEntry item)))
              (Text.intercalate "; " (classificationReasons item))
          ]

registeredSourceIds :: SourceClosure -> Set SourceDebtId
registeredSourceIds = Map.keysSet . closureRegisteredDebt

-- | Bind one registered migration family to the exact paths, modes, and Git
-- object identities observed in the immutable source snapshot. This is an
-- inventory fingerprint, not correctness evidence. Legacy compares it with a
-- separately reviewed Haskell baseline so a new or modified file cannot ride
-- an already-open family row.
sourceDebtFingerprint :: SourceDebtId -> SourceClosure -> Text
sourceDebtFingerprint identifier closure =
  hex (SHA256.hash manifest)
 where
  members =
    sortOn
      (indexPath . trackedIndex . classifiedEntry)
      [ item
      | item <- closurePaths closure
      , classifiedAs item == RegisteredLegacy identifier
      ]
  manifest =
    TextEncoding.encodeUtf8 (renderSourceDebtId identifier <> "\0")
      <> ByteString.concat (map renderMember members)
  renderMember item =
    let entry = trackedIndex (classifiedEntry item)
     in TextEncoding.encodeUtf8
          ( Text.pack (indexPath entry)
              <> "\0"
              <> renderIndexMode (indexMode entry)
              <> "\0"
              <> indexObjectId entry
              <> "\0"
          )

sourceDebtPathCount :: SourceDebtId -> SourceClosure -> Int
sourceDebtPathCount identifier closure =
  length
    [ ()
    | item <- closurePaths closure
    , classifiedAs item == RegisteredLegacy identifier
    ]

renderSourceDebtId :: SourceDebtId -> Text
renderSourceDebtId SourceTools = "LTD-SRC-001"
renderSourceDebtId SourceDhall = "LTD-SRC-002"
renderSourceDebtId SourceProto = "LTD-SRC-003"
renderSourceDebtId SourceUi = "LTD-SRC-004"
renderSourceDebtId SourcePulumi = "LTD-SRC-005"
renderSourceDebtId SourceTest = "LTD-SRC-006"
renderSourceDebtId SourceProbe = "LTD-SRC-007"
renderSourceDebtId SourcePb = "LTD-SRC-008"
renderSourceDebtId SourceVendor = "LTD-SRC-009"

renderSourceClass :: SourceClass -> Text
renderSourceClass HaskellSource = "haskell"
renderSourceClass DocumentationInput = "documentation"
renderSourceClass ProjectDeclaration = "project-declaration"
renderSourceClass PbBootstrapSource = "pb-bootstrap"
renderSourceClass (RegisteredLegacy identifier) = "registered:" <> renderSourceDebtId identifier
renderSourceClass UnregisteredBehavioralSource = "unregistered"

renderIndexMode :: IndexMode -> Text
renderIndexMode RegularFile = "100644"
renderIndexMode ExecutableFile = "100755"
renderIndexMode SymbolicLink = "120000"

renderSourceFacet :: SourceFacet -> Text
renderSourceFacet ExecutableModeFacet = "executable"
renderSourceFacet (ShebangFacet value) = "shebang=" <> value
renderSourceFacet (SymbolicLinkFacet value) = "symlink=" <> value
renderSourceFacet BinaryContentFacet = "binary"
renderSourceFacet (ForeignSourceSignatureFacet value) = "foreign-signature=" <> value
renderSourceFacet (PbRoleFacet role) = "pb-role=" <> Text.pack (show role)

renderSnapshotProblem :: SnapshotProblem -> Text
renderSnapshotProblem problem = case problem of
  GitExecutableNotAbsolute path -> "Git executable is not absolute: " <> Text.pack path
  RepositoryRootNotAbsolute path -> "repository root is not absolute: " <> Text.pack path
  RepositoryRootMismatch expected actual ->
    "repository root mismatch: expected " <> Text.pack expected <> ", Git reported " <> Text.pack actual
  GitProcessFailure arguments status stderrText ->
    "Git failed (" <> Text.pack (show status) <> ") for " <> Text.pack (unwords arguments) <> ": " <> stderrText
  GitProcessIoFailure arguments detail ->
    "Git I/O failed for " <> Text.pack (unwords arguments) <> ": " <> detail
  EmptyIndex -> "Git index is empty"
  MissingNulTerminator -> "Git index listing lacks its final NUL"
  MalformedIndexRecord number detail -> recordDetail number detail
  UnsupportedIndexMode number mode -> recordDetail number ("unsupported mode " <> mode)
  NonStageZeroEntry number stage -> recordDetail number ("non-stage-zero entry " <> stage)
  InvalidObjectId number objectId -> recordDetail number ("invalid object id " <> objectId)
  InvalidTrackedPath number path -> recordDetail number ("invalid path " <> path)
  DuplicateTrackedPath path -> "duplicate tracked path: " <> Text.pack path
  MissingLoadedBlob objectId -> "loaded blob map omitted index object " <> objectId
  InvalidSnapshotIdentity detail -> "invalid snapshot identity: " <> detail
  MissingIndexFlagNulTerminator observationKind ->
    "index-flag observation lacks its final NUL: " <> renderIndexFlagObservation observationKind
  MalformedIndexFlagRecord observationKind number detail ->
    "index-flag observation "
      <> renderIndexFlagObservation observationKind
      <> " record "
      <> Text.pack (show number)
      <> ": "
      <> detail
  DuplicateIndexFlagPath observationKind path ->
    "index-flag observation "
      <> renderIndexFlagObservation observationKind
      <> " duplicated path: "
      <> Text.pack path
  IndexFlagInventoryMismatch observationKind expected actual ->
    "index-flag observation "
      <> renderIndexFlagObservation observationKind
      <> " path inventory mismatch: expected="
      <> renderPaths expected
      <> ", actual="
      <> renderPaths actual
  AssumeUnchangedTrackedPaths paths ->
    "tracked paths carry assume-unchanged: " <> renderPaths paths
  SkipWorktreeTrackedPaths paths ->
    "tracked paths carry skip-worktree: " <> renderPaths paths
  TrackedWorktreePathMissing path ->
    "tracked worktree path is missing or sparse: " <> Text.pack path
  TrackedWorktreeExecutableModeUnavailable path ->
    "raw owner-executable-mode observation is unavailable for tracked worktree path: " <> Text.pack path
  TrackedWorktreeKindMismatch path expected actual ->
    "tracked worktree kind mismatch at "
      <> Text.pack path
      <> ": index="
      <> renderIndexMode expected
      <> ", worktree="
      <> renderWorktreeEntryKind actual
  TrackedWorktreeExecutableMismatch path expected actual ->
    "tracked worktree executable-mode mismatch at "
      <> Text.pack path
      <> ": expected="
      <> Text.pack (show expected)
      <> ", actual="
      <> Text.pack (show actual)
  TrackedWorktreeBytesMismatch path ->
    "tracked worktree bytes differ from the acquired index blob: " <> Text.pack path
  TrackedWorktreeEntryRace path ->
    "tracked worktree path changed kind, mode, target, size, or timestamp while it was read: " <> Text.pack path
  TrackedWorktreeIoFailure path detail ->
    "tracked worktree observation failed at " <> Text.pack path <> ": " <> detail
  InvalidWorktreeSymlinkTarget path ->
    "tracked worktree symlink target is not valid UTF-8 at: " <> Text.pack path
  TrackedWorktreeChangedDuringAcquisition paths ->
    "tracked worktree observation changed during acquisition: " <> renderPaths paths
  AuthoredRootInventoryIoFailure path detail ->
    "authored-root recursive inventory failed at " <> Text.pack path <> ": " <> detail
  InvalidAuthoredRootPath path ->
    "authored-root recursive inventory encountered a non-UTF-8 or unsafe path: " <> Text.pack path
  AuthoredRootAncestorKindMismatch path actual ->
    "authored-root tracked ancestor is not a directory at "
      <> Text.pack path
      <> ": worktree="
      <> renderWorktreeEntryKind actual
  UnexpectedAuthoredRootMaterial paths ->
    "untracked or ignored material exists beneath authored roots: " <> renderPaths paths
  AuthoredRootChangedDuringAcquisition added removed changed ->
    "authored-root inventory changed during acquisition: added="
      <> renderPaths added
      <> ", removed="
      <> renderPaths removed
      <> ", changed-kind="
      <> renderPaths changed
  TrackedWorktreeDivergence paths ->
    "tracked worktree/index divergence: " <> renderPaths paths
  UntrackedNonIgnoredPaths paths ->
    "untracked non-ignored paths: " <> renderPaths paths
  IndexChangedDuringAcquisition -> "Git index changed during snapshot acquisition"
  InvalidWorkspacePath detail -> "invalid workspace path observation: " <> detail
  where
    recordDetail number detail = "index record " <> Text.pack (show number) <> ": " <> detail

renderIndexFlagObservation :: IndexFlagObservation -> Text
renderIndexFlagObservation observationKind = case observationKind of
  AssumeUnchangedObservation -> "assume-unchanged"
  SkipWorktreeObservation -> "skip-worktree"

renderWorktreeEntryKind :: WorktreeEntryKind -> Text
renderWorktreeEntryKind kind = case kind of
  WorktreeRegularFile -> "regular-file"
  WorktreeSymbolicLink -> "symbolic-link"
  WorktreeDirectory -> "directory"
  WorktreeOther -> "other"

renderPaths :: [FilePath] -> Text
renderPaths = Text.pack . show

snapshotFinding :: SnapshotProblem -> Finding
snapshotFinding problem = finding "SRC-SNAPSHOT" "<git-index>" (renderSnapshotProblem problem)

isRegistered :: SourceClass -> Bool
isRegistered (RegisteredLegacy _) = True
isRegistered _ = False

isSymlinkFacet :: SourceFacet -> Bool
isSymlinkFacet (SymbolicLinkFacet _) = True
isSymlinkFacet _ = False

isShebangFacet :: SourceFacet -> Bool
isShebangFacet (ShebangFacet _) = True
isShebangFacet _ = False

isForeignSignatureFacet :: SourceFacet -> Bool
isForeignSignatureFacet (ForeignSourceSignatureFacet _) = True
isForeignSignatureFacet _ = False

under :: FilePath -> FilePath -> Bool
under root path = Text.pack (root <> "/") `Text.isPrefixOf` Text.pack path

hasSuffix :: String -> FilePath -> Bool
hasSuffix suffix = Text.isSuffixOf (Text.pack suffix) . Text.pack

isLicence :: FilePath -> Bool
isLicence path =
  let name = Text.toUpper (Text.pack (takeFileName path))
   in any (matchesLicenceName name) ["LICENSE", "LICENCE", "COPYING", "NOTICE"]

matchesLicenceName :: Text -> Text -> Bool
matchesLicenceName name base = name == base || (base <> ".") `Text.isPrefixOf` name

isProjectDeclaration :: FilePath -> Bool
isProjectDeclaration path =
  path `elem`
    [ "amoebius.cabal"
    , "cabal.project"
    , "probe/probe.cabal"
    , ".gitignore"
    , ".dockerignore"
    , ".gitattributes"
    , ".editorconfig"
    ]

hex :: ByteString -> Text
hex = Text.pack . concatMap byteHex . ByteString.unpack
 where
  byteHex value =
    [ intToDigit (fromIntegral value `div` 16)
    , intToDigit (fromIntegral value `mod` 16)
    ]

shebang :: ByteString -> Maybe Text
shebang bytes
  | "#!" `ByteString.isPrefixOf` bytes =
      Just (decodeLenient (ByteString.takeWhile (\byte -> byte /= 10 && byte /= 13) bytes))
  | otherwise = Nothing

foreignSourceSignature :: ByteString -> Maybe Text
foreignSourceSignature bytes =
  let line = Text.toLower (firstSignificantLine bytes)
      signatures =
        [ ("from ", "python-from")
        , ("def ", "python-def")
        , ("set -e", "shell-set-e")
        , ("#!/", "shebang")
        , ("function ", "javascript-function")
        , ("const ", "javascript-const")
        , ("{\"", "json-object")
        , ("<?xml", "xml-document")
        , ("syntax =", "proto-schema")
        ]
   in snd <$> firstMatch line signatures

firstSignificantLine :: ByteString -> Text
firstSignificantLine bytes =
  case filter (not . Text.null) (map Text.strip (Text.lines (decodeLenient bytes))) of
    [] -> ""
    line : _ -> line

firstMatch :: Text -> [(Text, Text)] -> Maybe (Text, Text)
firstMatch _ [] = Nothing
firstMatch value (candidate : rest)
  | fst candidate `Text.isPrefixOf` value = Just candidate
  | otherwise = firstMatch value rest

textual :: ByteString -> Bool
textual bytes = not (ByteString.elem 0 bytes) && either (const False) (const True) (TextEncoding.decodeUtf8' bytes)

lowerText :: ByteString -> Text
lowerText = Text.toLower . decodeLenient

decodeLenient :: ByteString -> Text
decodeLenient = TextEncoding.decodeUtf8With TextError.lenientDecode

decodeOneLine :: ByteString -> Either Text FilePath
decodeOneLine bytes =
  case TextEncoding.decodeUtf8' (dropLineEnd bytes) of
    Left _ -> Left "Git output is not UTF-8"
    Right value
      | Text.null value -> Left "Git returned an empty line"
      | Text.any (== '\n') value || Text.any (== '\r') value -> Left "Git returned more than one line"
      | otherwise -> Right (Text.unpack value)

dropLineEnd :: ByteString -> ByteString
dropLineEnd = ByteString.reverse . ByteString.dropWhile (\byte -> byte == 10 || byte == 13) . ByteString.reverse

canonicalPath :: FilePath -> FilePath
canonicalPath = dropTrailingPathSeparator . normalise

duplicates :: Ord value => [value] -> [value]
duplicates values =
  Map.keys (Map.filter (> (1 :: Int)) (Map.fromListWith (+) [(value, 1 :: Int) | value <- values]))

data ProcessBytes = ProcessBytes ExitCode ByteString ByteString

runGit :: GitExecutable -> FilePath -> [String] -> ByteString -> IO (Either SnapshotProblem ByteString)
runGit (GitExecutable executable) root arguments input = do
  inheritedEnvironment <- getEnvironment
  let gitArguments =
        [ "--no-optional-locks"
        , "-c"
        , "core.fsmonitor=false"
        , "-c"
        , "core.untrackedCache=false"
        , "-c"
        , "core.excludesFile="
        , "-C"
        , root
        ]
          <> arguments
      gitEnvironment =
        [ ("GIT_OPTIONAL_LOCKS", "0")
        , ("GIT_TERMINAL_PROMPT", "0")
        , ("GIT_NO_REPLACE_OBJECTS", "1")
        , ("LC_ALL", "C")
        ]
          <> filter retainedEnvironment inheritedEnvironment
      command =
        (proc executable gitArguments)
          { std_in = CreatePipe
          , std_out = CreatePipe
          , std_err = CreatePipe
          , env = Just gitEnvironment
          }
  result <- try (captureProcess command input) :: IO (Either IOException ProcessBytes)
  pure $ case result of
    Left problem -> Left (GitProcessIoFailure arguments (Text.pack (displayException problem)))
    Right (ProcessBytes ExitSuccess output _) -> Right output
    Right (ProcessBytes (ExitFailure status) _ stderrBytes) ->
      Left (GitProcessFailure arguments status (decodeLenient stderrBytes))
  where
    retainedEnvironment (name, _) = take 4 name /= "GIT_" && name /= "LC_ALL"

captureProcess :: CreateProcess -> ByteString -> IO ProcessBytes
captureProcess command input = do
  (inputHandle, outputHandle, errorHandle, processHandle) <- createProcess command
  stdin <- requirePipe "stdin" inputHandle
  stdout <- requirePipe "stdout" outputHandle
  stderr <- requirePipe "stderr" errorHandle
  inputResult <- newEmptyMVar
  outputResult <- newEmptyMVar
  errorResult <- newEmptyMVar
  _ <- forkIO (writePipe stdin input >>= putMVar inputResult)
  _ <- forkIO (readPipe stdout >>= putMVar outputResult)
  _ <- forkIO (readPipe stderr >>= putMVar errorResult)
  written <- takeMVar inputResult
  either ioError pure written
  output <- takeMVar outputResult
  errors <- takeMVar errorResult
  outputBytes <- either ioError pure output
  errorBytes <- either ioError pure errors
  -- Reap only after stdin has been closed and both output pipes have reached
  -- EOF.  Waiting first can deadlock a non-threaded runtime: Git's
  -- @hash-object --stdin@ waits for EOF while the Haskell writer has not yet
  -- been scheduled, or a verbose child blocks on an undrained output pipe.
  status <- waitForProcess processHandle
  pure (ProcessBytes status outputBytes errorBytes)

requirePipe :: String -> Maybe Handle -> IO Handle
requirePipe name Nothing = ioError (userError ("Git " <> name <> " pipe was not created"))
requirePipe _ (Just handle) = pure handle

writePipe :: Handle -> ByteString -> IO (Either IOException ())
writePipe handle bytes = try (ByteString.hPut handle bytes `finally` hClose handle)

readPipe :: Handle -> IO (Either IOException ByteString)
readPipe handle = try (ByteString.hGetContents handle `finally` hClose handle)
