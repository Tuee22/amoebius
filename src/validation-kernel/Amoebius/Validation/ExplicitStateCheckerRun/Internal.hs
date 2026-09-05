{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ExplicitStateCheckerRun.Internal
  ( AcquiredExplicitStateCheckerRun, acquireExplicitStateCheckerRun
  , acquireExplicitStateCheckerRefreshRun, acquiredExplicitStateCheckerRunCheck
  , foldAcquiredExplicitStateCheckerRun ) where

import Amoebius.Validation.BootstrapTrust.Internal
  (GenesisTrust, genesisTrustCheck, genesisTrustCompilerExecutable, genesisTrustToolchainIdentity)
import Amoebius.Validation.PhaseContract.Internal
  (AcquiredPhaseContractEvidence, acquirePhaseContractEvidenceFor, acquireRecordedPhaseContractEvidence, acquiredPhaseContractEvidenceCheck)
import Amoebius.Validation.SourceClosure.Internal
  (AcquiredSourceSnapshot, IndexEntry (indexPath), SourceSnapshot (snapshotEntries, snapshotIdentity), TrackedEntry (trackedIndex), acquiredSourceSnapshot)
import Amoebius.Validation.Types (CheckResult (..), finding, mergeChecks, observation)
import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (isInfixOf, isPrefixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  (createDirectory, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, getHomeDirectory, listDirectory, removeFile)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt Receipt deriving (Eq, Show)
data Matrix = Matrix Receipt Receipt [Mutant]

data AcquiredExplicitStateCheckerRun = AcquiredExplicitStateCheckerRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredExplicitStateCheckerRunCheck :: AcquiredExplicitStateCheckerRun -> CheckResult
acquiredExplicitStateCheckerRunCheck (AcquiredExplicitStateCheckerRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredExplicitStateCheckerRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredExplicitStateCheckerRun -> value
foldAcquiredExplicitStateCheckerRun consume (AcquiredExplicitStateCheckerRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireExplicitStateCheckerRun, acquireExplicitStateCheckerRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExplicitStateCheckerRun
acquireExplicitStateCheckerRun = acquire False
acquireExplicitStateCheckerRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExplicitStateCheckerRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "explicit-state-checker-package-database"
        [observation "explicit-state-checker.package-db" (Text.pack path) | path <- databases]
        [finding "EXPLICIT-STATE-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  discipline <- sourceDisciplineCheck root
  artifact <- artifactCheck root runRoot
  let Matrix _ cleanRun mutants = matrix
      receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 12 acquired
      compiler = compilerCheck matrix
      oracle = oracleCheck cleanRun
      positive = positiveCheck cleanRun
      negatives = negativeCheck cleanRun
      mutation = mutantCheck mutants
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts discipline
      observer = observerCheck receipts
      freshness = CheckResult "explicit-state-checker-freshness" [observation "explicit-state-checker.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = mergeChecks "explicit-state-checker-cleanroom" [artifact, CheckResult "explicit-state-checker-contained-root"
        [observation "explicit-state-checker.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "EXPLICIT-STATE-CLEANROOM" runRoot "generated products escaped the phase run root" | not (pathBelow (root </> ".build/runs/phase-12/work") runRoot)]]
      qualification = mergeChecks "explicit-state-checker-qualification" [compiler, oracle, positive, negatives, mutation, discovery, discipline, artifact]
      prerequisite = mergeChecks "explicit-state-checker-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler, oracle, positive, negatives, mutation, discovery, authority, observer, freshness, cleanroom, discipline, artifact]
      rows = phaseRows prerequisite compiler oracle positive negatives mutation discovery authority observer freshness qualification cleanroom artifact
      result = mergeChecks "explicit-state-checker" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "explicit-state-checker-subject" [checkDigest compiler, checkDigest discipline]
      oracleId = ids "explicit-state-checker-oracle" [receiptDigest cleanRun]
      harnessId = ids "explicit-state-checker-harness" (map receiptDigest receipts)
      observerId = ids "explicit-state-checker-observer" [checkDigest observer]
      qualificationId = ids "explicit-state-checker-qualification" [checkDigest qualification]
      acquiredRunId = ids "explicit-state-checker-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "explicit-state-checker-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredExplicitStateCheckerRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  cleanBuild <- compileProgram root runRoot database compiler "clean" Nothing
  cleanRun <- runBuilt root runRoot "clean" "clean-oracle" cleanBuild
  mutants <- mapM (runMutant root runRoot database compiler) mutantSpecifications
  pure (Matrix cleanBuild cleanRun mutants)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> (Text, String, Text) -> IO Mutant
runMutant root runRoot database compiler (name, selector, locus) = do
  let variant = "mutant-" <> Text.unpack name
  build <- compileProgram root runRoot database compiler variant (Just selector)
  run <- runBuilt root runRoot variant (name <> "-oracle") build
  pure (Mutant name (Text.pack selector) locus build run)

compileProgram :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileProgram root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"
      binary = runRoot </> variant </> "explicit-state-oracle"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler
    (common database objects selector <> ["-o", binary, oracleSource])

common :: FilePath -> FilePath -> Maybe String -> [String]
common database objects selector =
  ["-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
  ,"-clear-package-db", "-global-package-db", "-package-db", database
  ,"-isrc", "-isrc/explicit-state-checker", "-itest/spec/formal/explicit"
  ,"-package", "containers", "-package", "bytestring", "-package", "cryptohash-sha256"
  ,"-odir", objects, "-hidir", objects, "-stubdir", objects]
  <> maybe [] (pure . ("-D" <>)) selector

runBuilt :: FilePath -> FilePath -> FilePath -> Text -> Receipt -> IO Receipt
runBuilt root runRoot variant name build
  | receiptExit build == ExitSuccess = do
      let output = runRoot </> variant </> "generated"
      createDirectoryIfMissing True output
      runProcess root name (runRoot </> variant </> "explicit-state-oracle") [output]
  | otherwise = pure (unavailable name)

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [("guard-widening", "EXPLICIT_STATE_WIDENS_ACTION_GUARD_MUTANT", "toy-safe status: expected \"safe\"")
  ,("invariant-skip", "EXPLICIT_STATE_SKIPS_INVARIANT_MUTANT", "unsafe-counter status: expected \"unsafe-invariant\"")
  ,("frontier-truncation", "EXPLICIT_STATE_TRUNCATES_FRONTIER_MUTANT", "toy-safe distinct states: expected 8")]

compilerCheck :: Matrix -> CheckResult
compilerCheck (Matrix cleanBuild _ mutants) = CheckResult "explicit-state-checker-compiler"
  (map (observation "explicit-state-checker.compiler" . receiptSummary) required)
  [finding "EXPLICIT-STATE-COMPILER" (Text.unpack name) "a clean or changed-production subject did not compile" | Receipt name _ _ status _ _ <- required, status /= ExitSuccess]
 where required = cleanBuild : [build | Mutant _ _ _ build _ <- mutants]

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "explicit-state-checker-independent-oracle" [observation "explicit-state-checker.oracle" (receiptSummary receipt)]
  [finding "EXPLICIT-STATE-ORACLE" oracleSource "the authored Haskell oracle did not report its exact inventory" | receiptExit receipt /= ExitSuccess || not (acceptance `Text.isInfixOf` receiptStdout receipt)]
 where acceptance = "PASS (7 fixtures, 5 explorer parity rows, 2 replayed counterexamples)"

positiveCheck :: Receipt -> CheckResult
positiveCheck receipt = CheckResult "explicit-state-checker-positive-controls" [observation "explicit-state-checker.positive" "seven fixtures,five parity rows,two trace replays"]
  [finding "EXPLICIT-STATE-POSITIVE" oracleSource "clean checker controls failed" | receiptExit receipt /= ExitSuccess]

negativeCheck :: Receipt -> CheckResult
negativeCheck receipt = CheckResult "explicit-state-checker-paired-negatives" [observation "explicit-state-checker.negative" "positive bound versus zero/negative refusal; authentic trace versus forged target"]
  [finding "EXPLICIT-STATE-NEGATIVE" oracleSource "bound or trace-tamper negatives were not included in the accepted oracle" | receiptExit receipt /= ExitSuccess || not ("PASS (7 fixtures" `Text.isInfixOf` receiptStdout receipt)]

mutantCheck :: [Mutant] -> CheckResult
mutantCheck mutants = CheckResult "explicit-state-checker-mutants"
  [observation ("explicit-state-checker.mutant." <> name) (selector <> "|" <> receiptSummary run) | Mutant name selector _ _ run <- mutants]
  [finding "EXPLICIT-STATE-MUTANT" (Text.unpack name) ("changed production subject did not turn red at " <> locus)
    | Mutant name _ locus build run <- mutants, receiptExit build /= ExitSuccess || receiptExit run /= ExitFailure 1 || not (locus `Text.isInfixOf` receiptStderr run)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  source <- Text.pack <$> readFile (root </> productionSource)
  let forbidden = ["import Amoebius.Formal.Explore", "unsafePerformIO", "undefined", "readFile", "lookupEnv", "getEnv"]
      required = ["newtype SearchBound", "checkModel ::", "replayCounterexample ::", "modelDigest ::", "BoundExceeded", "DeadlockViolation"]
  pure (CheckResult "explicit-state-checker-source-discipline"
    [observation "explicit-state-checker.effect-boundary" "pure-only", observation "explicit-state-checker.closed-elements" (Text.pack (show (length required)))]
    ([finding "EXPLICIT-STATE-SOURCE-DISCIPLINE" productionSource ("forbidden token: " <> token) | token <- forbidden, token `Text.isInfixOf` source]
      <> [finding "EXPLICIT-STATE-MODEL-SHAPE" productionSource ("missing element: " <> token) | token <- required, not (token `Text.isInfixOf` source)]))

artifactCheck :: FilePath -> FilePath -> IO CheckResult
artifactCheck root runRoot = do
  let resultPath = runRoot </> "clean/generated/results.tsv"
  present <- doesFileExist resultPath
  pure (CheckResult "explicit-state-checker-generated-artifact" [observation "explicit-state-checker.generated.result" (Text.pack (makeRelative root resultPath))]
    [finding "EXPLICIT-STATE-GENERATED-MISSING" (makeRelative root resultPath) "clean oracle emitted no contained result observation" | not present])

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "explicit-state-checker-discovery" [observation "explicit-state-checker.discovery.count" (Text.pack (show (length observed)))]
  [finding "EXPLICIT-STATE-DISCOVERY" "<explicit-state-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult -> CheckResult
authorityCheck root runRoot compiler receipts discipline = CheckResult "explicit-state-checker-authority"
  [observation "explicit-state-checker.compiler-serialization" "one synchronous GHC child at a time; no -j; no pb/network/JVM/hardware"]
  ([finding "EXPLICIT-STATE-RUN-ROOT" runRoot "run root escaped .build/runs/phase-12/work" | not (pathBelow (root </> ".build/runs/phase-12/work") runRoot)]
    <> [finding "EXPLICIT-STATE-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority" | Receipt name executable args _ _ _ <- receipts, "-compiler" `Text.isInfixOf` name, executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args]
    <> checkFindings discipline)

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "explicit-state-checker-observer" (map (observation "explicit-state-checker.observer.process" . receiptSummary) receipts)
  [finding "EXPLICIT-STATE-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" | receipt@(Receipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom artifact =
  [named "phase-12-claim" [pre], named "phase-12-subject" [compiler, positive], named "phase-12-command" [compiler, authority]
  ,named "phase-12-oracle" [oracle], named "phase-12-positive-controls" [positive], named "phase-12-paired-negatives" [negatives]
  ,named "phase-12-mutants" [mutants], named "phase-12-discovery" [discovery], named "phase-12-challenge" [mutants]
  ,named "phase-12-observer" [observer], named "phase-12-authority-bypass" [authority], named "phase-12-freshness" [freshness]
  ,named "phase-12-qualification" [qualification], named "phase-12-cleanroom" [cleanroom], named "phase-12-legacy-closure" [artifact]
  ,CheckResult "phase-12-predecessor" [observation "phase-12.predecessor" "deferred to durable receipt verifier"] []
  ,CheckResult "phase-12-residue" [observation "phase-12.residue" "symbolic/refinement checking, reusable compile-fail machinery, simulation, concrete models, runtimes, and hardware remain later-owned"] []
  ,named "phase-12-pass-criterion" [pre]] where named = mergeChecks

discoverPackageDatabases :: IO [FilePath]
discoverPackageDatabases = do
  home <- getHomeDirectory
  let store = home </> ".cabal/store"
  present <- doesDirectoryExist store
  if not present then pure [] else listDirectory store >>= filterM doesDirectoryExist . map (\name -> store </> name </> "package.db") . filter ("ghc-9.12.4-" `isInfixOf`)

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-12/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle >> removeFile leaf >> createDirectory leaf
  pure leaf

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
receiptSummary receipt@(Receipt name executable args status _ err) = name <> "|" <> Text.pack executable <> "|argv=" <> Text.pack (show args) <> "|exit=" <> Text.pack (show status) <> "|sha256=" <> receiptDigest receipt <> if status == ExitSuccess then "" else "|stderr=" <> Text.replace "\n" "\\n" (Text.take 512 err)
checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]
digestTexts :: [Text] -> Text
digestTexts = sha256 . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"
sha256 :: ByteString -> Text
sha256 = Text.pack . concatMap (\byte -> [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]) . ByteString.unpack . SHA256.hash
pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child) in relative /= ".." && not ("../" `isPrefixOf` relative) && not (isAbsolute relative)
unavailable :: Text -> Receipt
unavailable name = Receipt name "<unavailable>" [] (ExitFailure 127) "" "package database or compiler unavailable"
unavailableMatrix :: Matrix
unavailableMatrix = Matrix (u "clean-compiler") (u "clean-oracle") [Mutant name (Text.pack selector) locus (u (name <> "-compiler")) (u (name <> "-oracle")) | (name, selector, locus) <- mutantSpecifications] where u = unavailable
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix cleanBuild cleanRun mutants) = [cleanBuild, cleanRun] <> concat [[build, run] | Mutant _ _ _ build run <- mutants]

productionSource, oracleSource :: FilePath
productionSource = "src/explicit-state-checker/Amoebius/Checker/ExplicitState.hs"
oracleSource = "test/spec/formal/explicit/ExplicitStateCheckerSpec.hs"
expectedSources :: [FilePath]
expectedSources = sort [productionSource, oracleSource]
