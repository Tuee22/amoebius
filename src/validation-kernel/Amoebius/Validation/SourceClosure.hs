{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.SourceClosure
  ( ClassifiedPath (..)
  , GitExecutable
  , IndexEntry (..)
  , IndexMode (..)
  , PbSemanticRole (..)
  , SnapshotProblem (..)
  , SourceClass (..)
  , SourceClosure
  , SourceDebtId (..)
  , SourceFacet (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
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
  , registeredSourceIds
  , renderSnapshotProblem
  , renderSourceDebtId
  , sourceDebtFingerprint
  , sourceDebtPathCount
  , sourceClosureCheck
  ) where

import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar)
import Control.Exception (IOException, displayException, finally, try)
import Control.Monad (foldM)
import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as ByteString8
import qualified Crypto.Hash.SHA256 as SHA256
import Data.Char (intToDigit, isHexDigit)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.Encoding.Error as TextError
import System.Exit (ExitCode (..))
import System.Environment (getEnvironment)
import System.FilePath
  ( dropTrailingPathSeparator
  , isAbsolute
  , normalise
  , takeFileName
  )
import System.IO (Handle, hClose)
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
-- Git binary and repository root must be explicit absolute paths.  No worktree
-- byte is read, and an unmerged entry or unsupported index mode refuses the
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
                              secondListing <-
                                runGit
                                  git
                                  root
                                  ["ls-files", "--cached", "--full-name", "--stage", "-z"]
                                  ByteString.empty
                              let indexProblems = case secondListing of
                                    Left problem -> [problem]
                                    Right secondRaw
                                      | secondRaw == raw -> []
                                      | otherwise -> [IndexChangedDuringAcquisition]
                                  finalProblems = workspaceProblems <> indexProblems
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
  | under "pb" path = RegisteredLegacy SourcePb
  | admittedHaskellPath path = HaskellSource
  | admittedDocumentationPath path = DocumentationInput
  | admittedLicencePath path = DocumentationInput
  | isProjectDeclaration path = ProjectDeclaration
  | otherwise = UnregisteredBehavioralSource

inGeneratedRoot :: FilePath -> Bool
inGeneratedRoot path =
  any (`under` path) [".build", ".data", ".test_data"]

probeAdmitted :: FilePath -> Bool
probeAdmitted path =
  hasSuffix ".hs" path
    || path == "probe/probe.cabal"

testAdmitted :: FilePath -> Bool
testAdmitted = hasSuffix ".hs"

admittedHaskellPath :: FilePath -> Bool
admittedHaskellPath path =
  hasSuffix ".hs" path
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
  TrackedWorktreeDivergence paths ->
    "tracked worktree/index divergence: " <> Text.intercalate "," (map Text.pack paths)
  UntrackedNonIgnoredPaths paths ->
    "untracked non-ignored paths: " <> Text.intercalate "," (map Text.pack paths)
  IndexChangedDuringAcquisition -> "Git index changed during snapshot acquisition"
  InvalidWorkspacePath detail -> "invalid workspace path observation: " <> detail
  where
    recordDetail number detail = "index record " <> Text.pack (show number) <> ": " <> detail

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
  status <- waitForProcess processHandle
  written <- takeMVar inputResult
  output <- takeMVar outputResult
  errors <- takeMVar errorResult
  either ioError pure written
  outputBytes <- either ioError pure output
  errorBytes <- either ioError pure errors
  pure (ProcessBytes status outputBytes errorBytes)

requirePipe :: String -> Maybe Handle -> IO Handle
requirePipe name Nothing = ioError (userError ("Git " <> name <> " pipe was not created"))
requirePipe _ (Just handle) = pure handle

writePipe :: Handle -> ByteString -> IO (Either IOException ())
writePipe handle bytes = try (ByteString.hPut handle bytes `finally` hClose handle)

readPipe :: Handle -> IO (Either IOException ByteString)
readPipe handle = try (ByteString.hGetContents handle `finally` hClose handle)
