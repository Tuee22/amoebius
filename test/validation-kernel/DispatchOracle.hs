{-# LANGUAGE OverloadedStrings #-}

module DispatchOracle
  ( runDispatchOracle
  ) where

-- Component diagnostic only. This pins the public dispatcher's current
-- refusal barriers so deleting or disconnecting one cannot silently turn
-- structural checks into a candidate. It uses only synthetic and disposable
-- indexed snapshots; it performs no hardware, container, live-system, phase
-- validation, or promotion.

import Amoebius.Validation.Dispatch (checkPhaseZeroSnapshot, phaseZeroReadinessBlockers, validatePhase)
import Amoebius.Validation.SourceClosure
  ( IndexEntry (..)
  , IndexMode (RegularFile)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  )
import Amoebius.Validation.Types (CheckResult (..), Finding (..))
import Control.Exception (bracket)
import Control.Monad (unless)
import Data.ByteString qualified as ByteString
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory
  ( canonicalizePath
  , createDirectory
  , createDirectoryIfMissing
  , findExecutable
  , getCurrentDirectory
  , removeFile
  , removePathForcibly
  )
import System.Exit (ExitCode (ExitSuccess))
import System.FilePath ((</>))
import System.IO (hClose, openTempFile)
import System.Process (readProcessWithExitCode)

runDispatchOracle :: IO ()
runDispatchOracle = do
  later <- validatePhase "/not-used/git" "/not-used/repository" 1
  outside <- validatePhase "/not-used/git" "/not-used/repository" 96
  publicPhaseZeroProblems <- exercisePublicPhaseZero
  let readinessFindings = checkFindings phaseZeroReadinessBlockers
      readinessSubjects = Set.fromList (map findingIdentity readinessFindings)
      requiredReadinessSubjects =
        Set.fromList
          [ ("QUALIFICATION-NOT-EXECUTED", "Amoebius.Validation.Gate")
          , ("POLICY-CONTRACT-UNQUALIFIED", "Amoebius.Validation.PolicyContract")
          , ("PB-GRAMMAR-UNIMPLEMENTED", "Amoebius.Validation.SourceClosure")
          , ("SOURCE-CONSUMER-GRAPH-MISSING", "Amoebius.Validation.SourceClosure")
          , ("AUTHORED-ROOT-WALK-UNPINNED", "Amoebius.Validation.SourceClosure")
          , ("PHASE-CONTRACT-SEMANTICS-MISSING", "Amoebius.Validation.PhaseContract")
          , ("LEGACY-OWNER-ANALYZERS-MISSING", "Amoebius.Validation.Legacy")
          , ("INDEPENDENT-REVIEW-MISSING", "phase-00-oracles")
          , ("CLEANROOM-OBSERVER-MISSING", "phase-00-cleanroom")
          , ("EVIDENCE-INTEGRATION-MISSING", "Amoebius.Validation.Dispatch")
          , ("EVIDENCE-SCHEMA-INCOMPLETE", "Amoebius.Validation.Evidence")
          , ("SOURCE-DIGEST-SCHEME-MISMATCH", "Amoebius.Validation.SourceClosure")
          , ("GIT-ACQUISITION-UNAUTHENTICATED", "Amoebius.Validation.Dispatch")
          ]
      utf8Result = checkPhaseZeroSnapshot (syntheticSnapshot "README.md" "# Synthetic document\n")
      invalidUtf8Result = checkPhaseZeroSnapshot (syntheticSnapshot "README.md" (ByteString.pack [255]))
      problems =
        [ "Phase 0 readiness refusal code/subject inventory changed: " <> show readinessSubjects
        | readinessSubjects /= requiredReadinessSubjects
        ]
          <> [ "Phase 0 readiness refusal inventory contains duplicate identities: " <> show readinessFindings
             | length readinessFindings /= Set.size requiredReadinessSubjects
             ]
          <> expectEqual "UTF-8 snapshot composition name" "phase-00" (checkName utf8Result)
          <> expectEqual "decode-failure snapshot composition name" "phase-00" (checkName invalidUtf8Result)
          <> readinessCompositionProblems "UTF-8 snapshot branch" readinessFindings utf8Result
          <> readinessCompositionProblems "document-decode-failure branch" readinessFindings invalidUtf8Result
          <> expectCodeCount "UTF-8 snapshot branch does not report a decode failure" "DOC-SNAPSHOT-UTF8" 0 utf8Result
          <> expectCodeCount "document-decode-failure branch reports its exact decode failure" "DOC-SNAPSHOT-UTF8" 1 invalidUtf8Result
          <> ["Phase 1 public dispatch was not blocked" | not (hasCode "DISPATCH-PHASE-BLOCKED" later)]
          <> ["out-of-domain public dispatch was not refused" | not (hasCode "DISPATCH-PHASE-INVALID" outside)]
          <> publicPhaseZeroProblems
  unless
    (null problems)
    (fail ("DispatchOracle component diagnostic failures:\n  " <> Text.unpack (Text.intercalate "\n  " (map Text.pack problems))))

syntheticSnapshot :: FilePath -> ByteString.ByteString -> SourceSnapshot
syntheticSnapshot path bytes =
  SourceSnapshot
    { snapshotRoot = "/synthetic/dispatch-oracle"
    , snapshotIdentity = Text.replicate 64 "d"
    , snapshotEntries =
        [ TrackedEntry
            { trackedIndex = IndexEntry path RegularFile (Text.replicate 40 "a")
            , trackedBytes = bytes
            }
        ]
    }

readinessCompositionProblems :: String -> [Finding] -> CheckResult -> [String]
readinessCompositionProblems label blockers result =
  [ label <> ": readiness finding did not occur exactly once: " <> show blocker <> "; observed " <> show observedCount
  | blocker <- blockers
  , let observedCount = countOccurrences blocker (checkFindings result)
  , observedCount /= 1
  ]

exercisePublicPhaseZero :: IO [String]
exercisePublicPhaseZero = do
  locatedGit <- findExecutable "git"
  case locatedGit of
    Nothing -> pure ["public Phase-0 seam diagnostic could not locate Git"]
    Just executable -> do
      absoluteGit <- canonicalizePath executable
      current <- getCurrentDirectory
      let corpusRoot = current </> ".build" </> "test-corpora"
      createDirectoryIfMissing True corpusRoot
      bracket
        (newGeneratedDirectory corpusRoot)
        removePathForcibly
        (exerciseGeneratedRepository absoluteGit)

newGeneratedDirectory :: FilePath -> IO FilePath
newGeneratedDirectory root = do
  (reserved, handle) <- openTempFile root "dispatch-oracle"
  hClose handle
  removeFile reserved
  createDirectory reserved
  pure reserved

exerciseGeneratedRepository :: FilePath -> FilePath -> IO [String]
exerciseGeneratedRepository git repository = do
  command git ["-C", repository, "init", "--quiet"]
  ByteString.writeFile (repository </> "README.md") "# Generated dispatch oracle\n"
  objectId <- Text.strip . Text.pack <$> commandOutput git ["-C", repository, "hash-object", "-w", "README.md"]
  command git ["-C", repository, "update-index", "--add", "--cacheinfo", "100644," <> Text.unpack objectId <> ",README.md"]
  command git ["-C", repository, "update-index", "--refresh"]
  result <- validatePhase git repository 0
  let readinessFindings = checkFindings phaseZeroReadinessBlockers
  pure
    ( expectEqual "public Phase-0 seam composition name" "phase-00" (checkName result)
        <> readinessCompositionProblems "public Phase-0 validate seam" readinessFindings result
    )

command :: FilePath -> [String] -> IO ()
command executable arguments = do
  (status, _, errors) <- readProcessWithExitCode executable arguments ""
  unless (status == ExitSuccess) (fail ("generated Git command failed: " <> unwords arguments <> ": " <> errors))

commandOutput :: FilePath -> [String] -> IO String
commandOutput executable arguments = do
  (status, output, errors) <- readProcessWithExitCode executable arguments ""
  unless (status == ExitSuccess) (fail ("generated Git command failed: " <> unwords arguments <> ": " <> errors))
  pure output

findingIdentity :: Finding -> (Text, FilePath)
findingIdentity item = (findingCode item, findingSubject item)

countOccurrences :: Eq value => value -> [value] -> Int
countOccurrences expected = length . filter (== expected)

expectCodeCount :: String -> Text -> Int -> CheckResult -> [String]
expectCodeCount label code expected result =
  expectEqual label expected (length (filter ((== code) . findingCode) (checkFindings result)))

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected actual
  | expected == actual = []
  | otherwise = [label <> ": expected " <> show expected <> ", observed " <> show actual]

hasCode :: Text -> CheckResult -> Bool
hasCode code = any ((== code) . findingCode) . checkFindings
