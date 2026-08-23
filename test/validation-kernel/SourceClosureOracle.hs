{-# LANGUAGE OverloadedStrings #-}

module SourceClosureOracle
  ( runSourceClosureOracle
  ) where

-- Component diagnostics only. These independently stated examples are not
-- human review, harness qualification, phase validation, or promotion evidence.

import Amoebius.Validation.SourceClosure
import Amoebius.Validation.Types (CheckResult (..), Finding (..))
import Control.Exception (bracket)
import Control.Monad (unless)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory
  ( createDirectory
  , createDirectoryIfMissing
  , findExecutable
  , getCurrentDirectory
  , removeFile
  , removePathForcibly
  )
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO (hClose, openTempFile)
import System.Process (readProcessWithExitCode)

runSourceClosureOracle :: IO ()
runSourceClosureOracle = do
  workspaceProblems <- workspaceGuardProblems
  finishDiagnostics
    "SourceClosureOracle"
    ( indexParserProblems
        <> admittedClassificationProblems
        <> registeredRootProblems
        <> unregisteredClassificationProblems
        <> pbRoleProblems
        <> snapshotAggregationProblems
        <> workspaceProblems
    )

indexParserProblems :: [String]
indexParserProblems =
  concat
    [ expectEqual
        "stage-zero parser accepts and path-sorts a complete NUL listing"
        ( Right
            [ IndexEntry "README.md" RegularFile objectA
            , IndexEntry "bin/tool" ExecutableFile objectB
            , IndexEntry "link" SymbolicLink objectC
            ]
        )
        ( parseLsFilesStage
            ( indexRecord "100755" objectB "0" "bin/tool"
                <> indexRecord "120000" objectC "0" "link"
                <> indexRecord "100644" objectA "0" "README.md"
            )
        )
    , expectEqual "empty index refuses" (Left [EmptyIndex]) (parseLsFilesStage ByteString.empty)
    , expectEqual
        "missing final NUL refuses"
        (Left [MissingNulTerminator])
        (parseLsFilesStage (ByteString.dropEnd 1 (indexRecord "100644" objectA "0" "README.md")))
    , expectLeftContains
        "record without header/path tab"
        (== MalformedIndexRecord 1 "missing header/path tab")
        (parseLsFilesStage ("100644 " <> objectBytes objectA <> " 0\0"))
    , expectLeftContains
        "record with malformed header arity"
        (== MalformedIndexRecord 1 "expected mode, object id, and stage")
        (parseLsFilesStage ("100644 " <> objectBytes objectA <> "\tREADME.md\0"))
    , expectLeftContains
        "unsupported index mode"
        (== UnsupportedIndexMode 1 "100600")
        (parseLsFilesStage (indexRecord "100600" objectA "0" "README.md"))
    , expectLeftContains
        "non-stage-zero index entry"
        (== NonStageZeroEntry 1 "2")
        (parseLsFilesStage (indexRecord "100644" objectA "2" "README.md"))
    , expectLeftContains
        "invalid object id"
        (== InvalidObjectId 1 "abc")
        (parseLsFilesStage (indexRecord "100644" "abc" "0" "README.md"))
    , expectLeftContains
        "parent-traversing tracked path"
        (== InvalidTrackedPath 1 "../README.md")
        (parseLsFilesStage (indexRecord "100644" objectA "0" "../README.md"))
    , expectLeftContains
        "empty tracked path"
        (== InvalidTrackedPath 1 "")
        (parseLsFilesStage (indexRecord "100644" objectA "0" ""))
    , expectLeftContains
        "non-UTF8 tracked path"
        (== InvalidTrackedPath 1 "path is not UTF-8")
        ( parseLsFilesStage
            ("100644 " <> objectBytes objectA <> " 0\t" <> ByteString.pack [255] <> "\0")
        )
    , expectLeftContains
        "duplicate tracked path"
        (== DuplicateTrackedPath "README.md")
        ( parseLsFilesStage
            ( indexRecord "100644" objectA "0" "README.md"
                <> indexRecord "100644" objectB "0" "README.md"
            )
        )
    , expectEqual
        "tagged stage parser binds flags to exact sorted index entries"
        ( Right
            [ ('h', IndexEntry "README.md" RegularFile objectA)
            , ('S', IndexEntry "bin/tool" ExecutableFile objectB)
            ]
        )
        ( parseLsFilesTaggedStage
            ( taggedStageRecord 'S' "100755" objectB "0" "bin/tool"
                <> taggedStageRecord 'h' "100644" objectA "0" "README.md"
            )
        )
    , expectLeftContains
        "empty tagged stage observation lacks its required NUL"
        (== MissingIndexFlagNulTerminator AssumeUnchangedObservation)
        (parseLsFilesTaggedStage ByteString.empty)
    , expectLeftContains
        "tagged stage observation without final NUL refuses"
        (== MissingIndexFlagNulTerminator AssumeUnchangedObservation)
        ( parseLsFilesTaggedStage
            (ByteString.dropEnd 1 (taggedStageRecord 'H' "100644" objectA "0" "README.md"))
        )
    , expectLeftContains
        "empty path-only flag observation lacks its required NUL"
        (== MissingIndexFlagNulTerminator AssumeUnchangedObservation)
        (parseLsFilesTaggedPaths AssumeUnchangedObservation ByteString.empty)
    ]

admittedClassificationProblems :: [String]
admittedClassificationProblems =
  concatMap check admitted
 where
  admitted =
    [ ("Haskell product source", tracked "src/Main.hs" RegularFile "module Main where\n", HaskellSource)
    , ("Haskell test source", tracked "test/Spec.hs" RegularFile "module Spec where\n", HaskellSource)
    , ("Haskell probe source", tracked "probe/Probe.hs" RegularFile "module Probe where\n", HaskellSource)
    , ("governed Markdown", tracked "documents/rule.md" RegularFile "# Rule\n", DocumentationInput)
    , ("root README", tracked "README.md" RegularFile "# Repository\n", DocumentationInput)
    , ("licence input", tracked "LICENSE.txt" RegularFile "licence text\n", DocumentationInput)
    , ("Cabal declaration", tracked "amoebius.cabal" RegularFile "name: amoebius\n", ProjectDeclaration)
    , ("project declaration", tracked "cabal.project" RegularFile "packages: .\n", ProjectDeclaration)
    , ("repository metadata", tracked ".gitignore" RegularFile ".build/\n", ProjectDeclaration)
    ]
  check (label, entry, expectedClass) =
    let classified = classifyEntry entry
     in expectEqual (label <> " class") expectedClass (classifiedAs classified)
          <> expectEqual (label <> " has no rejection reason") [] (classificationReasons classified)

registeredRootProblems :: [String]
registeredRootProblems =
  concatMap check registered
    <> expectEqual
      "all nine registered source roots are represented"
      (Set.fromList [minBound .. maxBound])
      (registeredSourceIds (classifySnapshot (snapshot (map (\(_, entry, _) -> entry) registered))))
    <> concat
      [ expectEqual
          ("debt id rendering " <> show identifier)
          expected
          (renderSourceDebtId identifier)
      | (identifier, expected) <- renderedDebtIds
      ]
 where
  registered =
    [ ("tools root", tracked "tools/check.py" RegularFile "print('legacy')\n", SourceTools)
    , ("Dhall suffix", tracked "schema/config.dhall" RegularFile "{}\n", SourceDhall)
    , ("Proto root", tracked "proto/api.proto" RegularFile "syntax = \"proto3\";\n", SourceProto)
    , ("UI root", tracked "ui/app.js" RegularFile "const app = 1;\n", SourceUi)
    , ("Pulumi root", tracked "pulumi/main.py" RegularFile "print('legacy')\n", SourcePulumi)
    , ("non-Haskell test root", tracked "test/legacy.py" RegularFile "print('legacy')\n", SourceTest)
    , ("non-Haskell probe root", tracked "probe/legacy.py" RegularFile "print('legacy')\n", SourceProbe)
    , ("out-of-grammar pb root", tracked "pb/pb/admin.py" RegularFile "adminclient\n", SourcePb)
    , ("top-level vendor root", tracked "vendor/pkg/Legacy.hs" RegularFile "module Legacy where\n", SourceVendor)
    ]
  check (label, entry, identifier) =
    let classified = classifyEntry entry
     in expectEqual (label <> " class") (RegisteredLegacy identifier) (classifiedAs classified)
  renderedDebtIds =
    [ (SourceTools, "LTD-SRC-001")
    , (SourceDhall, "LTD-SRC-002")
    , (SourceProto, "LTD-SRC-003")
    , (SourceUi, "LTD-SRC-004")
    , (SourcePulumi, "LTD-SRC-005")
    , (SourceTest, "LTD-SRC-006")
    , (SourceProbe, "LTD-SRC-007")
    , (SourcePb, "LTD-SRC-008")
    , (SourceVendor, "LTD-SRC-009")
    ]

unregisteredClassificationProblems :: [String]
unregisteredClassificationProblems = concatMap check cases
 where
  cases =
    [ ("unregistered foreign source", tracked "src/helper.py" RegularFile "print('no')\n", [])
    , ("Haskell outside an admitted source root", tracked "rogue.hs" RegularFile "module Rogue where\n", [])
    , ("Markdown outside a governed or provenance root", tracked "random/authority.md" RegularFile "# Rogue\n", [])
    , ("Cabal file outside an admitted package root", tracked "random/rogue.cabal" RegularFile "name: rogue\n", [])
    , ("generated output tracked", tracked ".build/Generated.hs" RegularFile "module Generated where\n", [])
    , ("executable Haskell", tracked "src/Exec.hs" ExecutableFile "module Exec where\n", [ExecutableModeFacet])
    , ("shebang-disguised Markdown", tracked "README.md" RegularFile "#!/bin/sh\necho no\n", [ShebangFacet "#!/bin/sh"])
    , ("tracked symbolic link", tracked "documents/link.md" SymbolicLink "target.md", [SymbolicLinkFacet "target.md"])
    , ("binary documentation", tracked "documents/blob.md" RegularFile (ByteString.pack [0, 1, 2]), [BinaryContentFacet])
    , ("foreign signature in Haskell", tracked "src/Disguised.hs" RegularFile "def disguised():\n", [ForeignSourceSignatureFacet "python-def"])
    , ("foreign signature in metadata", tracked "cabal.project" RegularFile "const disguised = true\n", [ForeignSourceSignatureFacet "javascript-const"])
    ]
  check (label, entry, requiredFacets) =
    let classified = classifyEntry entry
        result = sourceClosureCheck (classifySnapshot (snapshot [entry]))
        path = indexPath (trackedIndex entry)
     in expectEqual (label <> " class") UnregisteredBehavioralSource (classifiedAs classified)
          <> concatMap (\facet -> expectTrue (label <> " facet " <> show facet) (facet `elem` classificationFacets classified)) requiredFacets
          <> expectFindingAt label "SRC-UNREGISTERED" path result

pbRoleProblems :: [String]
pbRoleProblems =
  concatMap checkRole boundedModules
    <> concatMap checkPbClass boundedModules
    <> concat
      [ expectLeft "unknown pb Python module" (classifyPbPythonRoles "pb/pb/admin.py" "adminclient\n")
      , expectLeft "pb CLI missing exec handoff" (classifyPbPythonRoles "pb/pb/cli.py" "")
      , expectLeft "pb CLI adds command parsing" (classifyPbPythonRoles "pb/pb/cli.py" "import click\nos.execv\n")
      , expectLeft "pb post-handoff gate authority" (classifyPbPythonRoles "pb/pb/process.py" "run_phase_gate\n")
      , expectLeft "pb toolchain widens into Docker" (classifyPbPythonRoles "pb/pb/bootstrap_toolchain.py" "ghc cabal docker\n")
      , expectEqual
          "pb metadata remains frozen debt until Phase 0 closes the boundary"
          (RegisteredLegacy SourcePb)
          (classifiedAs (classifyEntry (tracked "pb/pyproject.toml" RegularFile validPyproject)))
      , expectEqual
          "pytest metadata widens pb into registered debt"
          (RegisteredLegacy SourcePb)
          (classifiedAs (classifyEntry (tracked "pb/pyproject.toml" RegularFile (validPyproject <> "[tool.pytest.ini_options]\n"))))
      ]
 where
  boundedModules =
    [ ("package marker", "pb/pb/__init__.py", "", [PbPackageMarker])
    , ("binary build/handoff", "pb/pb/bootstrap.py", "build handoff os.execv\n", [PbBinaryBuild, PbOpaqueExecHandoff])
    , ("toolchain ensure", "pb/pb/bootstrap_toolchain.py", "ghc cabal\n", [PbToolchainEnsure])
    , ("opaque CLI handoff", "pb/pb/cli.py", "os.execv\n", [PbOpaqueExecHandoff])
    , ("platform toolchain selection", "pb/pb/prereqs.py", "sys.platform\n", [PbPlatformToolchainSelection])
    , ("process handoff", "pb/pb/process.py", "os.execv\n", [PbOpaqueExecHandoff])
    ]
  checkRole (label, path, bytes, expectedRoles) = expectEqual (label <> " roles") (Right expectedRoles) (classifyPbPythonRoles path bytes)
  checkPbClass (label, path, bytes, _) =
    expectEqual
      (label <> " remains source debt until external process qualification")
      (RegisteredLegacy SourcePb)
      (classifiedAs (classifyEntry (tracked path RegularFile bytes)))

snapshotAggregationProblems :: [String]
snapshotAggregationProblems =
  concat
    [ expectEqual
        "snapshot identity is preserved"
        snapshotId
        (closureSnapshotIdentity duplicateClosure)
    , expectEqual
        "duplicate in-memory paths refuse closure"
        [DuplicateTrackedPath "src/Duplicate.hs"]
        (closureProblems duplicateClosure)
    , expectFindingAt
        "duplicate snapshot finding"
        "SRC-SNAPSHOT"
        "<git-index>"
        (sourceClosureCheck duplicateClosure)
    , expectEqual
        "registered debt retains exact observed path set"
        (Just ["tools/b.py", "tools/a.py"])
        (Map.lookup SourceTools (closureRegisteredDebt debtClosure))
    , expectEqual "registered debt path count is exact" 2 (sourceDebtPathCount SourceTools debtClosure)
    , expectTrue
        "adding a path changes the frozen family fingerprint"
        ( sourceDebtFingerprint SourceTools debtClosure
            /= sourceDebtFingerprint
              SourceTools
              (classifySnapshot (snapshot [tracked "tools/a.py" RegularFile "a\n"]))
        )
    ]
 where
  duplicateEntry = tracked "src/Duplicate.hs" RegularFile "module Duplicate where\n"
  duplicateClosure = classifySnapshot (snapshot [duplicateEntry, duplicateEntry])
  debtClosure =
    classifySnapshot
      ( snapshot
          [ tracked "tools/a.py" RegularFile "a\n"
          , tracked "tools/b.py" RegularFile "b\n"
          ]
      )

workspaceGuardProblems :: IO [String]
workspaceGuardProblems = do
  relativeProblems <- pure (expectEqual "relative Git executable refuses" (Left (GitExecutableNotAbsolute "git")) (mkGitExecutable "git"))
  gitPath <- findExecutable "git"
  case gitPath of
    Nothing -> pure (relativeProblems <> ["generated workspace diagnostic could not locate Git"])
    Just executable ->
      case mkGitExecutable executable of
        Left problem -> pure (relativeProblems <> ["located Git executable was refused: " <> show problem])
        Right git -> do
          current <- getCurrentDirectory
          let corpusRoot = current </> ".build" </> "test-corpora"
          createDirectoryIfMissing True corpusRoot
          generatedProblems <- bracket (newGeneratedDirectory corpusRoot) removePathForcibly (exerciseWorkspace git executable)
          pure (relativeProblems <> generatedProblems)

newGeneratedDirectory :: FilePath -> IO FilePath
newGeneratedDirectory root = do
  (reserved, handle) <- openTempFile root "source-closure-oracle"
  hClose handle
  removeFile reserved
  createDirectory reserved
  pure reserved

exerciseWorkspace :: GitExecutable -> FilePath -> FilePath -> IO [String]
exerciseWorkspace git executable repository = do
  command executable ["-C", repository, "init", "--quiet"]
  let trackedPath = repository </> "tracked.txt"
  ByteString.writeFile trackedPath "indexed bytes\n"
  objectId <- Text.strip . Text.pack <$> commandOutput executable ["-C", repository, "hash-object", "-w", "tracked.txt"]
  command executable ["-C", repository, "update-index", "--add", "--cacheinfo", "100644," <> Text.unpack objectId <> ",tracked.txt"]
  command executable ["-C", repository, "update-index", "--refresh"]
  clean <- checkCandidateWorkspace git repository
  cleanSnapshot <- loadGitSnapshot git repository
  command executable ["-C", repository, "update-index", "--assume-unchanged", "tracked.txt"]
  assumeUnchangedSnapshot <- loadGitSnapshot git repository
  command executable ["-C", repository, "update-index", "--no-assume-unchanged", "tracked.txt"]
  command executable ["-C", repository, "update-index", "--skip-worktree", "tracked.txt"]
  skipWorktreeSnapshot <- loadGitSnapshot git repository
  command executable ["-C", repository, "update-index", "--no-skip-worktree", "tracked.txt"]
  ByteString.writeFile trackedPath "changed bytes\n"
  changed <- checkCandidateWorkspace git repository
  ByteString.writeFile trackedPath "indexed bytes\n"
  command executable ["-C", repository, "update-index", "--refresh"]
  ByteString.writeFile (repository </> "untracked.txt") "untracked\n"
  untracked <- checkCandidateWorkspace git repository
  pure
    ( expectEqual "clean generated workspace" [] clean
        <> exactAcquiredEntryProblems repository objectId cleanSnapshot
        <> expectLeftContains
          "assume-unchanged snapshot refuses"
          (\problem -> case problem of
              AssumeUnchangedTrackedPaths ["tracked.txt"] -> True
              _ -> False
          )
          assumeUnchangedSnapshot
        <> expectLeftContains
          "skip-worktree snapshot refuses"
          (\problem -> case problem of
              SkipWorktreeTrackedPaths ["tracked.txt"] -> True
              _ -> False
          )
          skipWorktreeSnapshot
        <> expectEqual "tracked divergence is exact" [TrackedWorktreeDivergence ["tracked.txt"]] changed
        <> expectEqual "untracked path is exact" [UntrackedNonIgnoredPaths ["untracked.txt"]] untracked
    )

exactAcquiredEntryProblems :: FilePath -> Text -> Either [SnapshotProblem] SourceSnapshot -> [String]
exactAcquiredEntryProblems repository expectedObjectId result =
  case result of
    Left refused -> ["clean snapshot acquisition refused exact indexed regular file as " <> show refused]
    Right acquired ->
      expectEqual "acquired snapshot root is the requested repository" repository (snapshotRoot acquired)
        <> expectEqual "acquired snapshot contains exactly one indexed entry" 1 (length (snapshotEntries acquired))
        <> case snapshotEntries acquired of
          [entry] ->
            expectEqual "acquired indexed path is exact" "tracked.txt" (indexPath (trackedIndex entry))
              <> expectEqual "acquired indexed mode is exact" RegularFile (indexMode (trackedIndex entry))
              <> expectEqual "acquired indexed object ID is exact" expectedObjectId (indexObjectId (trackedIndex entry))
              <> expectEqual "acquired indexed bytes are exact" "indexed bytes\n" (trackedBytes entry)
          _ -> []

command :: FilePath -> [String] -> IO ()
command executable arguments = do
  (status, _, errors) <- readProcessWithExitCode executable arguments ""
  unless (status == ExitSuccess) (fail ("generated Git command failed: " <> unwords arguments <> ": " <> errors))

commandOutput :: FilePath -> [String] -> IO String
commandOutput executable arguments = do
  (status, output, errors) <- readProcessWithExitCode executable arguments ""
  unless (status == ExitSuccess) (fail ("generated Git command failed: " <> unwords arguments <> ": " <> errors))
  pure output

validPyproject :: ByteString
validPyproject =
  "[build-system]\n"
    <> "[project]\n"
    <> "[project.scripts]\n"
    <> "pb = \"pb.cli\"\n"

snapshot :: [TrackedEntry] -> SourceSnapshot
snapshot entries =
  SourceSnapshot
    { snapshotRoot = "/immutable/oracle"
    , snapshotIdentity = snapshotId
    , snapshotEntries = entries
    }

tracked :: FilePath -> IndexMode -> ByteString -> TrackedEntry
tracked path mode bytes =
  TrackedEntry
    { trackedIndex = IndexEntry path mode objectA
    , trackedBytes = bytes
    }

indexRecord :: ByteString -> Text -> ByteString -> ByteString -> ByteString
indexRecord mode objectId stage path = mode <> " " <> objectBytes objectId <> " " <> stage <> "\t" <> path <> "\0"

taggedStageRecord :: Char -> ByteString -> Text -> ByteString -> ByteString -> ByteString
taggedStageRecord tag mode objectId stage path =
  ByteString8.singleton tag <> " " <> indexRecord mode objectId stage path

objectBytes :: Text -> ByteString
objectBytes = ByteString8.pack . Text.unpack

objectA, objectB, objectC, snapshotId :: Text
objectA = Text.replicate 40 "a"
objectB = Text.replicate 40 "b"
objectC = Text.replicate 40 "c"
snapshotId = Text.replicate 64 "d"

expectLeft :: Show right => String -> Either left right -> [String]
expectLeft _ (Left _) = []
expectLeft label (Right accepted) = [label <> ": malformed input was accepted as " <> show accepted]

expectLeftContains :: Show right => String -> (SnapshotProblem -> Bool) -> Either [SnapshotProblem] right -> [String]
expectLeftContains label predicate result = case result of
  Left problems | any predicate problems -> []
  Left problems -> [label <> ": expected problem was absent from " <> show problems]
  Right accepted -> [label <> ": malformed input was accepted as " <> show accepted]

expectFindingAt :: String -> Text -> FilePath -> CheckResult -> [String]
expectFindingAt label code subject result =
  [ label <> ": expected " <> Text.unpack code <> " at " <> subject <> ", observed " <> show (checkFindings result)
  | not (any (\item -> findingCode item == code && findingSubject item == subject) (checkFindings result))
  ]

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
  | expected == actual = []
  | otherwise = [label <> ": expected " <> show expected <> ", observed " <> show actual]

expectTrue :: String -> Bool -> [String]
expectTrue _ True = []
expectTrue label False = [label]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless
    (null problems)
    (fail (name <> " component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack problems))))
