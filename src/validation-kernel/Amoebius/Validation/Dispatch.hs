{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Dispatch
  ( discoverRepositoryRoot
  , phaseZeroReadinessBlockers
  , runValidateCommand
  , validatePhase
  ) where

import Amoebius.Validation.Documentation (checkDocuments)
import Amoebius.Validation.Legacy (legacyCheck)
import Amoebius.Validation.PhaseContract (checkPhaseContracts)
import Amoebius.Validation.SourceClosure
  ( IndexEntry (indexPath)
  , SnapshotProblem
  , SourceSnapshot (snapshotEntries)
  , TrackedEntry (trackedBytes, trackedIndex)
  , loadGitSnapshot
  , mkGitExecutable
  , renderSnapshotProblem
  )
import Amoebius.Validation.Types
import Control.Exception (IOException, try)
import Control.Monad (filterM)
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
import System.Environment (getExecutablePath)
import System.Exit (ExitCode (ExitFailure, ExitSuccess))
import System.FilePath ((</>), isAbsolute, takeDirectory, takeExtension)
import Text.Read (readMaybe)

-- | Run the public validation argv.  The only success exit is a complete
-- candidate; a structural check, missing custody boundary, unsupported phase,
-- or malformed command returns a distinct non-zero refusal.
runValidateCommand :: [String] -> IO ExitCode
runValidateCommand arguments =
  case arguments of
    ["phase", ordinal]
      | Just phase <- parseOrdinal ordinal -> do
          acquisition <- acquireRepository
          case acquisition of
            Left detail -> emitResult (acquisitionFailure detail)
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
                  "expected exactly: validate phase NN, with a two-digit phase ordinal from 00 through 95"
              ]
          }

-- | Candidate-authority seam.  Git and the repository root are explicit so a
-- test or caller cannot silently substitute PATH lookup or the current working
-- directory after acquisition.
validatePhase :: FilePath -> FilePath -> Int -> IO CheckResult
validatePhase gitPath root phase
  | phase < 0 || phase > 95 =
      pure
        CheckResult
          { checkName = "validation-phase-dispatch"
          , checkObservations = [observation "validation.requested-phase" (Text.pack (show phase))]
          , checkFindings =
              [ finding
                  "DISPATCH-PHASE-INVALID"
                  ("phase-" <> show phase)
                  "the phase ordinal must be in the closed repository range 00 through 95"
              ]
          }
  | phase /= 0 =
      pure
        CheckResult
          { checkName = "validation-phase-dispatch"
          , checkObservations = [observation "validation.requested-phase" (formatOrdinal phase)]
          , checkFindings =
              [ finding
                  "DISPATCH-PHASE-BLOCKED"
                  ("phase-" <> Text.unpack (formatOrdinal phase))
                  "only Phase 0 is active; every later phase requires its immediate predecessor's external human approval"
              ]
          }
  | otherwise =
      case mkGitExecutable gitPath of
        Left problem -> pure (snapshotFailure [problem])
        Right git -> do
          snapshotResult <- loadGitSnapshot git root
          pure $ case snapshotResult of
            Left problems -> snapshotFailure problems
            Right snapshot -> phaseZeroChecks snapshot

phaseZeroChecks :: SourceSnapshot -> CheckResult
phaseZeroChecks snapshot =
  case snapshotDocuments snapshot of
    Left decodeFindings ->
      mergeChecks
        "phase-00"
        [ legacyCheck 0 snapshot
        , CheckResult "documentation-snapshot" [] decodeFindings
        , phaseZeroReadinessBlockers
        ]
    Right documents ->
      mergeChecks
        "phase-00"
        [ legacyCheck 0 snapshot
        , checkDocuments documents
        , checkPhaseContracts documents
        , phaseZeroReadinessBlockers
        ]

-- These are deliberate, executable refusal rows.  They prevent structural
-- component checks from being mislabeled as a qualified Phase-0 candidate.
-- Each row retires only when its separately reviewed implementation supplies
-- the raw evidence named here; no caller flag can turn it green.  In
-- particular, Gate.checkQualificationReport is a pure consistency check over
-- caller-supplied values and cannot retire the execution blocker.
phaseZeroReadinessBlockers :: CheckResult
phaseZeroReadinessBlockers =
  CheckResult
    { checkName = "phase-00-readiness"
    , checkObservations =
        [ observation "readiness.harness-qualification" "report consistency checker present; execution not implemented"
        , observation "readiness.policy-contract" "typed cross-cutting policy and prose-correspondence review not integrated"
        , observation "readiness.pb-source-grammar" "deny-by-default Python AST/import/effect audit not implemented"
        , observation "readiness.source-consumer-graph" "tracked non-Haskell content has no semantic parser/consumer/effect graph"
        , observation "readiness.worktree-index-observer" "assume-unchanged and skip-worktree flags plus independent byte/mode comparison are not checked"
        , observation "readiness.phase-contract-semantics" "phase-specific semantic contract audit not implemented"
        , observation "readiness.legacy-predicate-dispatch" "non-source legacy IDs have no executable per-ID dispatch"
        , observation "readiness.independent-review" "reviewer and custody receipt absent"
        , observation "readiness.cleanroom-residue" "external observer absent"
        , observation "readiness.candidate-integration" "evidence writer not connected to dispatcher"
        , observation "readiness.evidence-schema" "command, toolchain, substrate, run, and cleanup fields are not represented by a closed typed schema"
        , observation "readiness.source-digest-scheme" "Git object-format identity and candidate SHA-256 provenance have no defined binding"
        , observation "readiness.git-acquisition" "PATH-selected Git is not externally authenticated"
        ]
    , checkFindings =
        [ finding
            "QUALIFICATION-NOT-EXECUTED"
            "Amoebius.Validation.Gate"
            "the fixed sabotage corpus has not been executed against the exact dispatcher/harness build"
        , finding
            "POLICY-CONTRACT-MISSING"
            "Amoebius.Validation.PolicyContract"
            "cross-cutting source, registry, ordering, and authority decisions are not yet integrated as one reviewed typed contract"
        , finding
            "PB-GRAMMAR-UNIMPLEMENTED"
            "Amoebius.Validation.SourceClosure"
            "the pb exception remains debt until a deny-by-default Python AST/import/call/effect audit and external adapter observer exist"
        , finding
            "SOURCE-CONSUMER-GRAPH-MISSING"
            "Amoebius.Validation.SourceClosure"
            "first-line content signatures cannot prove that admitted documentation or metadata is not consumed as executable behavior"
        , finding
            "WORKTREE-INDEX-OBSERVER-INCOMPLETE"
            "Amoebius.Validation.SourceClosure"
            "candidate acquisition does not reject assume-unchanged/skip-worktree flags or independently compare every tracked worktree byte and mode with the index"
        , finding
            "PHASE-CONTRACT-SEMANTICS-MISSING"
            "Amoebius.Validation.PhaseContract"
            "fixed table shape is implemented, but phase-specific subject/oracle/control/mutant/residue semantics are not"
        , finding
            "LEGACY-PREDICATE-DISPATCH-MISSING"
            "Amoebius.Validation.Legacy"
            "canonical row inventory is enforced, but every non-source legacy ID lacks an independently reviewed executable closure binding"
        , finding
            "INDEPENDENT-REVIEW-MISSING"
            "phase-00-oracles"
            "component diagnostics have no independent human reviewer or custody receipt"
        , finding
            "CLEANROOM-OBSERVER-MISSING"
            "phase-00-cleanroom"
            "fresh-run input closure and external residue have no implemented independent observer"
        , finding
            "EVIDENCE-INTEGRATION-MISSING"
            "Amoebius.Validation.Dispatch"
            "the dispatcher cannot emit candidate evidence until qualification and cleanroom checks are connected"
        , finding
            "EVIDENCE-SCHEMA-INCOMPLETE"
            "Amoebius.Validation.Evidence"
            "the candidate schema does not yet require typed exact-command, toolchain, substrate/lane/architecture, run-identity, or cleanup observations"
        , finding
            "SOURCE-DIGEST-SCHEME-MISMATCH"
            "Amoebius.Validation.SourceClosure"
            "snapshot identity follows the repository Git object format while candidate provenance requires SHA-256; no reviewed conversion or dual binding exists"
        , finding
            "GIT-ACQUISITION-UNAUTHENTICATED"
            "Amoebius.Validation.Dispatch"
            "the Git executable is selected from PATH and has no externally established tool identity"
        ]
    }

snapshotDocuments :: SourceSnapshot -> Either [Finding] [(FilePath, Text)]
snapshotDocuments snapshot =
  if null problems then Right documents else Left problems
 where
  markdownEntries =
    [ entry
    | entry <- snapshotEntries snapshot
    , takeExtension (indexPath (trackedIndex entry)) == ".md"
    ]
  decoded = fmap decodeEntry markdownEntries
  documents = [document | Right document <- decoded]
  problems = [problem | Left problem <- decoded]
  decodeEntry entry =
    let path = indexPath (trackedIndex entry)
     in case TextEncoding.decodeUtf8' (trackedBytes entry) of
          Left _ -> Left (finding "DOC-SNAPSHOT-UTF8" path "tracked Markdown blob is not UTF-8")
          Right contents -> Right (path, contents)

snapshotFailure :: [SnapshotProblem] -> CheckResult
snapshotFailure problems =
  CheckResult
    { checkName = "source-snapshot-acquisition"
    , checkObservations = [observation "source.snapshot" "refused before classification"]
    , checkFindings =
        [ finding "SRC-SNAPSHOT" "<git-index>" (renderSnapshotProblem problem)
        | problem <- problems
        ]
    }

acquisitionFailure :: Text -> CheckResult
acquisitionFailure detail =
  CheckResult
    { checkName = "validation-acquisition"
    , checkObservations = [observation "validation.acquisition" "refused"]
    , checkFindings = [finding "DISPATCH-ACQUISITION" "repository" detail]
    }

emitResult :: CheckResult -> IO ExitCode
emitResult result = do
  TextIO.putStrLn ("validation " <> checkName result <> ": " <> verdict)
  mapM_ emitObservation (checkObservations result)
  mapM_ (TextIO.putStrLn . ("REFUSAL\t" <>) . renderFinding) (checkFindings result)
  TextIO.putStrLn "status\tNOT VALIDATED"
  pure (if checkPassed result then ExitSuccess else ExitFailure 1)
 where
  verdict = if checkPassed result then "CANDIDATE" else "REFUSED"
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
      if phase <= 95 then Just phase else Nothing
  | otherwise = Nothing
 where
  asciiDigit character = character >= '0' && character <= '9'

formatOrdinal :: Int -> Text
formatOrdinal phase
  | phase >= 0 && phase < 10 = "0" <> Text.pack (show phase)
  | otherwise = Text.pack (show phase)
