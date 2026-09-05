{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden, hardware-free Phase-6 authority. Compiler and linker
-- children are synchronous and never use @pb@, a network, or hardware.
module Amoebius.Validation.WorkflowCalculusRun.Internal
  ( AcquiredWorkflowCalculusRun
  , acquireWorkflowCalculusRun
  , acquireWorkflowCalculusRefreshRun
  , acquiredWorkflowCalculusRunCheck
  , foldAcquiredWorkflowCalculusRun
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust, genesisTrustCheck, genesisTrustCompilerExecutable, genesisTrustToolchainIdentity )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence, acquirePhaseContractEvidenceFor
  , acquireRecordedPhaseContractEvidence, acquiredPhaseContractEvidenceCheck )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot, IndexEntry (indexPath), SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedIndex), acquiredSourceSnapshot )
import Amoebius.Validation.Types (CheckResult (..), finding, mergeChecks, observation)
import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (isInfixOf, isPrefixOf, isSuffixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  ( createDirectory, createDirectoryIfMissing, doesDirectoryExist, getHomeDirectory
  , listDirectory, removeFile )
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)

data Matrix = Matrix
  { cleanBuild, cleanRun :: Receipt
  , dropBuild, dropRun, doubleBuild, doubleRun, conditionBuild, conditionRun, parallelBuild, parallelRun :: Receipt
  , terminalLegal, terminalIllegal, terminalRelaxed :: Receipt
  , transferLegal, transferIllegal, transferOptional :: Receipt
  , removalLegal, removalIllegal, removalRelaxed :: Receipt
  }

data AcquiredWorkflowCalculusRun = AcquiredWorkflowCalculusRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredWorkflowCalculusRunCheck :: AcquiredWorkflowCalculusRun -> CheckResult
acquiredWorkflowCalculusRunCheck (AcquiredWorkflowCalculusRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredWorkflowCalculusRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredWorkflowCalculusRun -> value
foldAcquiredWorkflowCalculusRun consume (AcquiredWorkflowCalculusRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireWorkflowCalculusRun, acquireWorkflowCalculusRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredWorkflowCalculusRun
acquireWorkflowCalculusRun = acquire False
acquireWorkflowCalculusRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredWorkflowCalculusRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "workflow-calculus-package-database"
        [observation "workflow-calculus.package-db" (Text.pack path) | path <- databases]
        [finding "WORKFLOW-CALCULUS-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  let receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 6 acquired
      compiler = compilerCheck [cleanBuild matrix, dropBuild matrix, doubleBuild matrix, conditionBuild matrix, parallelBuild matrix]
      oracle = oracleCheck (cleanRun matrix)
      positive = positiveCheck matrix
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts
      observer = observerCheck receipts
      freshness = CheckResult "workflow-calculus-freshness" [observation "workflow-calculus.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = CheckResult "workflow-calculus-cleanroom" [observation "workflow-calculus.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "WORKFLOW-CALCULUS-CLEANROOM" runRoot "generated products escaped the phase run root" | not (pathBelow (root </> ".build/runs/phase-06/work") runRoot)]
      qualification = mergeChecks "workflow-calculus-qualification" [compiler, oracle, positive, negatives, mutants]
      prerequisite = mergeChecks "workflow-calculus-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler, oracle, positive, negatives, mutants, discovery, authority, observer, freshness, cleanroom]
      rows = phaseRows prerequisite compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom
      result = mergeChecks "workflow-calculus" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "workflow-subject" [checkDigest compiler]
      oracleId = ids "workflow-oracle" [receiptDigest (cleanRun matrix)]
      harnessId = ids "workflow-harness" (map receiptDigest receipts)
      observerId = ids "workflow-observer" [checkDigest observer]
      qualificationId = ids "workflow-qualification" [checkDigest qualification]
      acquiredRunId = ids "workflow-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "workflow-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredWorkflowCalculusRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  cb <- program "clean" Nothing; cr <- runBuilt root runRoot "clean" "clean-oracle" cb
  db <- program "drop" (Just "WORKFLOW_CALCULUS_OBLIGATION_DROPPED_MUTANT"); dr <- runBuilt root runRoot "drop" "drop-oracle" db
  xb <- program "double" (Just "WORKFLOW_CALCULUS_OBLIGATION_DISCHARGED_TWICE_MUTANT"); xr <- runBuilt root runRoot "double" "double-oracle" xb
  cbad <- program "condition" (Just "WORKFLOW_CALCULUS_TRANSFER_WITHOUT_A_CONDITION_MUTANT"); crbad <- runBuilt root runRoot "condition" "condition-oracle" cbad
  pb <- program "parallel" (Just "WORKFLOW_CALCULUS_PARALLEL_REVERSES_BRANCHES_MUTANT"); pr <- runBuilt root runRoot "parallel" "parallel-oracle" pb
  tl <- fixture "terminal-legal" Nothing terminalLegalSource; ti <- fixture "terminal-illegal" Nothing terminalIllegalSource
  tr <- fixture "terminal-relaxed" (Just "WORKFLOW_CALCULUS_RUN_ACCEPTS_OUTSTANDING_MUTANT") terminalIllegalSource
  cl <- fixture "transfer-legal" Nothing transferLegalSource; ci <- fixture "transfer-illegal" Nothing transferIllegalSource
  co <- fixture "transfer-optional" (Just "WORKFLOW_CALCULUS_TRANSFER_CONDITION_OPTIONAL_MUTANT") transferIllegalSource
  rl <- fixture "removal-legal" Nothing removalLegalSource; ri <- fixture "removal-illegal" Nothing removalIllegalSource
  rr <- fixture "removal-relaxed" (Just "WORKFLOW_CALCULUS_REMOVE_UNHELD_ALLOWED_MUTANT") removalIllegalSource
  pure (Matrix cb cr db dr xb xr cbad crbad pb pr tl ti tr cl ci co rl ri rr)
 where
  program variant selector = compileProgram root runRoot database compiler variant selector
  fixture variant selector source = compileFixture root runRoot database compiler variant selector source

compileProgram :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileProgram root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"; binary = runRoot </> variant </> "workflow-calculus-oracle"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler (common database objects selector <> ["-o", binary, oracleSource])

compileFixture :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> FilePath -> IO Receipt
compileFixture root runRoot database compiler variant selector source = do
  let objects = runRoot </> variant </> "objects"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler (common database objects selector <> ["-fno-code", source])

common :: FilePath -> FilePath -> Maybe String -> [String]
common database objects selector =
  ["-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
  , "-clear-package-db", "-global-package-db", "-package-db", database, "-isrc", "-itest/spec/calculus"
  , "-package", "text", "-odir", objects, "-hidir", objects, "-stubdir", objects]
  <> maybe [] (pure . ("-D" <>)) selector

runBuilt :: FilePath -> FilePath -> FilePath -> Text -> Receipt -> IO Receipt
runBuilt root runRoot variant name build
  | receiptExit build == ExitSuccess = runProcess root name (runRoot </> variant </> "workflow-calculus-oracle") []
  | otherwise = pure (unavailable name)

compilerCheck :: [Receipt] -> CheckResult
compilerCheck receipts = CheckResult "workflow-calculus-compiler" (map (observation "workflow-calculus.compiler" . receiptSummary) receipts)
  [finding "WORKFLOW-CALCULUS-COMPILER" (Text.unpack name) "a clean or runnable changed-production oracle did not compile" | Receipt name _ _ status _ _ <- receipts, status /= ExitSuccess]

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "workflow-calculus-independent-oracle" [observation "workflow-calculus.oracle" (receiptSummary receipt)]
  [finding "WORKFLOW-CALCULUS-ORACLE" oracleSource "the Haskell oracle did not report all ten checks green" | receiptExit receipt /= ExitSuccess || not ("PASS (8 obligations, 5 workflows, 10 checks)" `Text.isInfixOf` receiptStdout receipt)]

positiveCheck :: Matrix -> CheckResult
positiveCheck matrix = CheckResult "workflow-calculus-positive-controls" [observation "workflow-calculus.positive" "clean-oracle,three-legal-compile-controls"]
  [finding "WORKFLOW-CALCULUS-POSITIVE" "<clean-controls>" "clean oracle or a legal compile control failed" | not good]
 where good = all ((== ExitSuccess) . receiptExit) [cleanRun matrix, terminalLegal matrix, transferLegal matrix, removalLegal matrix]

negativeCheck :: Matrix -> CheckResult
negativeCheck matrix = CheckResult "workflow-calculus-paired-negatives"
  [observation "workflow-calculus.negative.terminal" (receiptSummary (terminalIllegal matrix))
  ,observation "workflow-calculus.negative.transfer" (receiptSummary (transferIllegal matrix))
  ,observation "workflow-calculus.negative.removal" (receiptSummary (removalIllegal matrix))]
  [finding "WORKFLOW-CALCULUS-NEGATIVE" "<compile-pairs>" "an illegal twin did not fail for its exact obligation/condition/resource reason" | not good]
 where
  good = failedWith (terminalIllegal matrix) "Couldn't match type" && failedWith (terminalIllegal matrix) "db-volume"
      && failedWith (transferIllegal matrix) "Couldn't match expected type" && failedWith (transferIllegal matrix) "Condition"
      && failedWith (removalIllegal matrix) "the workflow holds no teardown obligation for" && failedWith (removalIllegal matrix) "never-provisioned"

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "workflow-calculus-mutants" [observation "workflow-calculus.mutants" (Text.intercalate ":" (map receiptDigest subjects))]
  [finding "WORKFLOW-CALCULUS-MUTANT" "<changed-production-matrix>" "one or more applied workflow mutants survived its assigned observation" | not good]
 where
  subjects = [dropRun matrix, doubleRun matrix, conditionRun matrix, parallelRun matrix, terminalRelaxed matrix, transferOptional matrix, removalRelaxed matrix]
  good = failsOnly "provisioned-and-released-sets-are-equal" (dropRun matrix)
      && failsOnly "each-obligation-discharged-once" (doubleRun matrix)
      && failsOnly "transfer-records-its-condition" (conditionRun matrix)
      && failsOnly "parallel-branches-both-provision" (parallelRun matrix)
      && all ((== ExitSuccess) . receiptExit) [terminalRelaxed matrix, transferOptional matrix, removalRelaxed matrix]

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "workflow-calculus-discovery" [observation "workflow-calculus.discovery.count" (Text.pack (show (length observed)))]
  [finding "WORKFLOW-CALCULUS-DISCOVERY" "<workflow-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), inScope path]
  inScope path = ".hs" `isSuffixOf` path && any (`isPrefixOf` path) sourcePrefixes

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot compiler receipts = CheckResult "workflow-calculus-authority" [observation "workflow-calculus.compiler-serialization" "one synchronous GHC child at a time; no -j; no pb; no hardware or network"]
  ([finding "WORKFLOW-CALCULUS-RUN-ROOT" runRoot "run root escaped .build/runs/phase-06/work" | not (pathBelow (root </> ".build/runs/phase-06/work") runRoot)] <>
   [finding "WORKFLOW-CALCULUS-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority" | Receipt name executable args _ _ _ <- receipts, "-compiler" `Text.isSuffixOf` name, executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args])

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "workflow-calculus-observer" (map (observation "workflow-calculus.observer.process" . receiptSummary) receipts)
  [finding "WORKFLOW-CALCULUS-OBSERVER" (Text.unpack name) "a process receipt lacks an absolute executable or digest" | receipt@(Receipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom =
  [named "phase-06-claim" [pre], named "phase-06-subject" [compiler, positive], named "phase-06-command" [compiler, authority]
  ,named "phase-06-oracle" [oracle], named "phase-06-positive-controls" [positive], named "phase-06-paired-negatives" [negatives]
  ,named "phase-06-mutants" [mutants], named "phase-06-discovery" [discovery], named "phase-06-challenge" [mutants]
  ,named "phase-06-observer" [observer], named "phase-06-authority-bypass" [authority], named "phase-06-freshness" [freshness]
  ,named "phase-06-qualification" [qualification], named "phase-06-cleanroom" [cleanroom], named "phase-06-legacy-closure" [pre]
  ,CheckResult "phase-06-predecessor" [observation "phase-06.predecessor" "deferred to durable receipt verifier"] []
  ,CheckResult "phase-06-residue" [observation "phase-06.residue" "evidence binding, calculus composition, live effects, runtimes, and hardware remain later-owned"] []
  ,named "phase-06-pass-criterion" [pre]]
 where named = mergeChecks

failsOnly :: String -> Receipt -> Bool
failsOnly label receipt = receiptExit receipt == ExitFailure 1
  && filter ("FAIL" `isInfixOf`) (lines (Text.unpack (receiptStdout receipt))) == ["  FAIL " <> label, "workflow-calculus-spec: FAIL " <> label]
failedWith :: Receipt -> Text -> Bool
failedWith receipt needle = receiptExit receipt == ExitFailure 1 && needle `Text.isInfixOf` receiptStderr receipt

discoverPackageDatabases :: IO [FilePath]
discoverPackageDatabases = do
  home <- getHomeDirectory; let store = home </> ".cabal/store"
  present <- doesDirectoryExist store
  if not present then pure [] else do names <- listDirectory store; filterM doesDirectoryExist [store </> name </> "package.db" | name <- names, "ghc-9.12.4-" `isInfixOf` name]

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-06/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"; hClose handle; removeFile leaf; createDirectory leaf; pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working name executable args = do
  attempt <- try (readCreateProcessWithExitCode ((proc executable args) {cwd = Just working}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ either (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem))) (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err)) attempt

receiptExit :: Receipt -> ExitCode
receiptExit (Receipt _ _ _ status _ _) = status
receiptStdout, receiptStderr :: Receipt -> Text
receiptStdout (Receipt _ _ _ _ out _) = out
receiptStderr (Receipt _ _ _ _ _ err) = err
receiptDigest :: Receipt -> Text
receiptDigest (Receipt name executable args status out err) = digestTexts [name, Text.pack executable, Text.pack (show args), Text.pack (show status), out, err]
receiptSummary :: Receipt -> Text
receiptSummary receipt@(Receipt name executable args status _ err) = name <> "|" <> Text.pack executable <> "|argv=" <> Text.pack (show args) <> "|exit=" <> Text.pack (show status) <> "|sha256=" <> receiptDigest receipt <> failure
 where failure = if status == ExitSuccess then "" else "|stderr=" <> Text.replace "\n" "\\n" (Text.take 512 err)
checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]
digestTexts :: [Text] -> Text
digestTexts = sha256 . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"
sha256 :: ByteString -> Text
sha256 = Text.pack . concatMap hex . ByteString.unpack . SHA256.hash where hex byte = [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]
pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child) in relative /= ".." && not ("../" `isPrefixOf` relative) && not (isAbsolute relative)
unavailable :: Text -> Receipt
unavailable name = Receipt name "<unavailable>" [] (ExitFailure 127) "" "package database or compiler construction unavailable"
unavailableMatrix :: Matrix
unavailableMatrix = Matrix (u "clean-compiler") (u "clean-oracle") (u "drop-compiler") (u "drop-oracle") (u "double-compiler") (u "double-oracle") (u "condition-compiler") (u "condition-oracle") (u "parallel-compiler") (u "parallel-oracle") (u "terminal-legal-compiler") (u "terminal-illegal-compiler") (u "terminal-relaxed-compiler") (u "transfer-legal-compiler") (u "transfer-illegal-compiler") (u "transfer-optional-compiler") (u "removal-legal-compiler") (u "removal-illegal-compiler") (u "removal-relaxed-compiler") where u = unavailable
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts m = [cleanBuild m, cleanRun m, dropBuild m, dropRun m, doubleBuild m, doubleRun m, conditionBuild m, conditionRun m, parallelBuild m, parallelRun m, terminalLegal m, terminalIllegal m, terminalRelaxed m, transferLegal m, transferIllegal m, transferOptional m, removalLegal m, removalIllegal m, removalRelaxed m]

sourcePrefixes :: [FilePath]
sourcePrefixes = ["src/Amoebius/Calculus/Workflow/", "test/spec/calculus/Workflow", "test/negative/compile_fail/workflow_calculus/"]
expectedSources :: [FilePath]
expectedSources = sort ["src/Amoebius/Calculus/Workflow/Arm.hs", "src/Amoebius/Calculus/Workflow/Ledger.hs", "src/Amoebius/Calculus/Workflow/Obligation.hs", "src/Amoebius/Calculus/Workflow/Run.hs", oracleSource, terminalLegalSource, terminalIllegalSource, transferLegalSource, transferIllegalSource, removalLegalSource, removalIllegalSource]
oracleSource, terminalLegalSource, terminalIllegalSource, transferLegalSource, transferIllegalSource, removalLegalSource, removalIllegalSource :: FilePath
oracleSource = "test/spec/calculus/WorkflowCalculusSpec.hs"
terminalLegalSource = "test/negative/compile_fail/workflow_calculus/workflow_discharges_its_obligation.hs"
terminalIllegalSource = "test/negative/compile_fail/workflow_calculus/workflow_ends_owing_a_teardown.hs"
transferLegalSource = "test/negative/compile_fail/workflow_calculus/transfer_names_its_condition.hs"
transferIllegalSource = "test/negative/compile_fail/workflow_calculus/transfer_without_a_condition.hs"
removalLegalSource = "test/negative/compile_fail/workflow_calculus/teardown_discharges_what_was_provisioned.hs"
removalIllegalSource = "test/negative/compile_fail/workflow_calculus/teardown_of_an_unheld_obligation.hs"
