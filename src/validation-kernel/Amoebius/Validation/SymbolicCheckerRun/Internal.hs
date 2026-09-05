{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.SymbolicCheckerRun.Internal
  ( AcquiredSymbolicCheckerRun, acquireSymbolicCheckerRun
  , acquireSymbolicCheckerRefreshRun, acquiredSymbolicCheckerRunCheck
  , foldAcquiredSymbolicCheckerRun ) where

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
data Matrix = Matrix Receipt Receipt Receipt [Mutant]

data AcquiredSymbolicCheckerRun = AcquiredSymbolicCheckerRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredSymbolicCheckerRunCheck :: AcquiredSymbolicCheckerRun -> CheckResult
acquiredSymbolicCheckerRunCheck (AcquiredSymbolicCheckerRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredSymbolicCheckerRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredSymbolicCheckerRun -> value
foldAcquiredSymbolicCheckerRun consume (AcquiredSymbolicCheckerRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireSymbolicCheckerRun, acquireSymbolicCheckerRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredSymbolicCheckerRun
acquireSymbolicCheckerRun = acquire False
acquireSymbolicCheckerRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredSymbolicCheckerRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "symbolic-checker-package-database"
        [observation "symbolic-checker.package-db" (Text.pack path) | path <- databases]
        [finding "SYMBOLIC-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  discipline <- sourceDisciplineCheck root
  artifact <- artifactCheck root runRoot
  let Matrix _ _ cleanRun mutants = matrix
      receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 13 acquired
      compiler = compilerCheck matrix
      oracle = oracleCheck cleanRun
      positive = positiveCheck cleanRun
      negatives = negativeCheck cleanRun
      mutation = mutantCheck mutants
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts discipline
      observer = observerCheck receipts
      freshness = CheckResult "symbolic-checker-freshness" [observation "symbolic-checker.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = mergeChecks "symbolic-checker-cleanroom" [artifact, CheckResult "symbolic-checker-contained-root"
        [observation "symbolic-checker.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "SYMBOLIC-CLEANROOM" runRoot "generated products escaped the phase run root" | not (pathBelow (root </> ".build/runs/phase-13/work") runRoot)]]
      qualification = mergeChecks "symbolic-checker-qualification" [compiler, oracle, positive, negatives, mutation, discovery, discipline, artifact]
      prerequisite = mergeChecks "symbolic-checker-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler, oracle, positive, negatives, mutation, discovery, authority, observer, freshness, cleanroom, discipline, artifact]
      rows = phaseRows prerequisite compiler oracle positive negatives mutation discovery authority observer freshness qualification cleanroom artifact
      result = mergeChecks "symbolic-checker" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "symbolic-checker-subject" [checkDigest compiler, checkDigest discipline]
      oracleId = ids "symbolic-checker-oracle" [receiptDigest cleanRun]
      harnessId = ids "symbolic-checker-harness" (map receiptDigest receipts)
      observerId = ids "symbolic-checker-observer" [checkDigest observer]
      qualificationId = ids "symbolic-checker-qualification" [checkDigest qualification]
      acquiredRunId = ids "symbolic-checker-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "symbolic-checker-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredSymbolicCheckerRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  fakeBuild <- compileFake root runRoot database compiler
  cleanBuild <- compileOracle root runRoot database compiler "clean" Nothing
  cleanRun <- runBuilt root runRoot "clean" "clean-oracle" fakeBuild cleanBuild
  mutants <- mapM (runMutant root runRoot database compiler fakeBuild) mutantSpecifications
  pure (Matrix fakeBuild cleanBuild cleanRun mutants)

compileFake :: FilePath -> FilePath -> FilePath -> FilePath -> IO Receipt
compileFake root runRoot database compiler = do
  let objects = runRoot </> "fake/objects"
      binary = runRoot </> "fake/fake-smt-solver"
  createDirectoryIfMissing True objects
  runProcess root "fake-solver-compiler" compiler
    ["-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
    ,"-clear-package-db", "-global-package-db", "-package-db", database
    ,"-odir", objects, "-hidir", objects, "-stubdir", objects, "-o", binary, fakeSource]

compileOracle :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileOracle root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"
      binary = runRoot </> variant </> "symbolic-oracle"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler
    (common database objects selector <> ["-o", binary, oracleSource])

common :: FilePath -> FilePath -> Maybe String -> [String]
common database objects selector =
  ["-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
  ,"-clear-package-db", "-global-package-db", "-package-db", database
  ,"-isrc", "-isrc/explicit-state-checker", "-isrc/symbolic-checker", "-itest/spec/formal/symbolic"
  ,"-package", "containers", "-package", "bytestring", "-package", "cryptohash-sha256"
  ,"-odir", objects, "-hidir", objects, "-stubdir", objects]
  <> maybe [] (pure . ("-D" <>)) selector

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> Receipt -> (Text, String, Text) -> IO Mutant
runMutant root runRoot database compiler fakeBuild (name, selector, locus) = do
  let variant = "mutant-" <> Text.unpack name
  build <- compileOracle root runRoot database compiler variant (Just selector)
  run <- runBuilt root runRoot variant (name <> "-oracle") fakeBuild build
  pure (Mutant name (Text.pack selector) locus build run)

runBuilt :: FilePath -> FilePath -> FilePath -> Text -> Receipt -> Receipt -> IO Receipt
runBuilt root runRoot variant name fakeBuild build
  | receiptExit fakeBuild == ExitSuccess && receiptExit build == ExitSuccess = do
      let output = runRoot </> variant </> "generated"
      createDirectoryIfMissing True output
      runProcess root name (runRoot </> variant </> "symbolic-oracle") [runRoot </> "fake/fake-smt-solver", output]
  | otherwise = pure (unavailable name)

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [("hypothesis-drop", "SYMBOLIC_DROPS_CONJOINED_HYPOTHESIS_MUTANT", "coupled-invariants symbolic status: expected \"inductive\"")
  ,("guard-negation", "SYMBOLIC_NEGATES_ACTION_GUARD_MUTANT", "inductive-counter symbolic status: expected \"inductive\"")
  ,("sat-step-acceptance", "SYMBOLIC_ACCEPTS_SAT_STEP_MUTANT", "step-failure symbolic status: expected \"step-failure\"")]

compilerCheck :: Matrix -> CheckResult
compilerCheck (Matrix fakeBuild cleanBuild _ mutants) = CheckResult "symbolic-checker-compiler"
  (map (observation "symbolic-checker.compiler" . receiptSummary) required)
  [finding "SYMBOLIC-COMPILER" (Text.unpack name) "a fake, clean, or changed-production subject did not compile" | Receipt name _ _ status _ _ <- required, status /= ExitSuccess]
 where required = fakeBuild : cleanBuild : [build | Mutant _ _ _ build _ <- mutants]

oracleCheck, positiveCheck, negativeCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "symbolic-checker-independent-oracle" [observation "symbolic-checker.oracle" (receiptSummary receipt)]
  [finding "SYMBOLIC-ORACLE" oracleSource "the authored Haskell oracle did not report its exact inventory" | receiptExit receipt /= ExitSuccess || not (acceptance `Text.isInfixOf` receiptStdout receipt)]
 where acceptance = "PASS (7 fixtures, 5 explicit agreements, 3 induction witnesses)"
positiveCheck receipt = CheckResult "symbolic-checker-positive-controls" [observation "symbolic-checker.positive" "seven fixtures,five explicit agreements,three induction witnesses"]
  [finding "SYMBOLIC-POSITIVE" oracleSource "clean symbolic controls failed" | receiptExit receipt /= ExitSuccess]
negativeCheck receipt = CheckResult "symbolic-checker-paired-negatives" [observation "symbolic-checker.negative" "absolute solver versus relative refusal; inductive versus base/step/unsupported/conservative classes"]
  [finding "SYMBOLIC-NEGATIVE" oracleSource "solver-path or result-class negatives were not included" | receiptExit receipt /= ExitSuccess]

mutantCheck :: [Mutant] -> CheckResult
mutantCheck mutants = CheckResult "symbolic-checker-mutants"
  [observation ("symbolic-checker.mutant." <> name) (selector <> "|" <> receiptSummary run) | Mutant name selector _ _ run <- mutants]
  [finding "SYMBOLIC-MUTANT" (Text.unpack name) ("changed production subject did not turn red at " <> locus)
    | Mutant name _ locus build run <- mutants, receiptExit build /= ExitSuccess || receiptExit run /= ExitFailure 1 || not (locus `Text.isInfixOf` receiptStderr run)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  source <- Text.pack <$> readFile (root </> productionSource)
  let forbidden = ["import Amoebius.Checker.ExplicitState", "import Amoebius.Formal.Explore", "unsafePerformIO", "undefined", "lookupEnv", "getEnv", "readFile"]
      required = ["newtype Solver", "mkSolver ::", "checkInductive ::", "prepareObligations ::", "set-logic QF_LIA", "SymbolicResult"]
  pure (CheckResult "symbolic-checker-source-discipline"
    [observation "symbolic-checker.effect-boundary" "injected-absolute-solver-only", observation "symbolic-checker.closed-elements" (Text.pack (show (length required)))]
    ([finding "SYMBOLIC-SOURCE-DISCIPLINE" productionSource ("forbidden token: " <> token) | token <- forbidden, token `Text.isInfixOf` source]
      <> [finding "SYMBOLIC-MODEL-SHAPE" productionSource ("missing element: " <> token) | token <- required, not (token `Text.isInfixOf` source)]))

artifactCheck :: FilePath -> FilePath -> IO CheckResult
artifactCheck root runRoot = do
  let path = runRoot </> "clean/generated/results.tsv"
  present <- doesFileExist path
  pure (CheckResult "symbolic-checker-generated-artifact" [observation "symbolic-checker.generated.result" (Text.pack (makeRelative root path))]
    [finding "SYMBOLIC-GENERATED-MISSING" (makeRelative root path) "clean oracle emitted no contained result observation" | not present])

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "symbolic-checker-discovery" [observation "symbolic-checker.discovery.count" (Text.pack (show (length observed)))]
  [finding "SYMBOLIC-DISCOVERY" "<symbolic-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult -> CheckResult
authorityCheck root runRoot compiler receipts discipline = CheckResult "symbolic-checker-authority"
  [observation "symbolic-checker.resource-contract" "run-local Haskell fake solver; absolute path; stdin only; no PATH/network/host/hardware; zero external residue"
  ,observation "symbolic-checker.compiler-serialization" "one synchronous GHC child at a time; no -j"]
  ([finding "SYMBOLIC-RUN-ROOT" runRoot "run root escaped .build/runs/phase-13/work" | not (pathBelow (root </> ".build/runs/phase-13/work") runRoot)]
    <> [finding "SYMBOLIC-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority" | Receipt name executable args _ _ _ <- receipts, "compiler" `Text.isInfixOf` name, executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args]
    <> checkFindings discipline)

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "symbolic-checker-observer" (map (observation "symbolic-checker.observer.process" . receiptSummary) receipts)
  [finding "SYMBOLIC-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" | receipt@(Receipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom artifact =
  [named "phase-13-claim" [pre], named "phase-13-subject" [compiler, positive], named "phase-13-command" [compiler, authority]
  ,named "phase-13-oracle" [oracle], named "phase-13-positive-controls" [positive], named "phase-13-paired-negatives" [negatives]
  ,named "phase-13-mutants" [mutants], named "phase-13-discovery" [discovery], named "phase-13-challenge" [mutants]
  ,named "phase-13-observer" [observer], named "phase-13-authority-bypass" [authority], named "phase-13-freshness" [freshness]
  ,named "phase-13-qualification" [qualification], named "phase-13-cleanroom" [cleanroom], named "phase-13-legacy-closure" [artifact]
  ,CheckResult "phase-13-predecessor" [observation "phase-13.predecessor" "deferred to durable receipt verifier"] []
  ,CheckResult "phase-13-residue" [observation "phase-13.residue" "refinement, reusable compile-fail machinery, simulation, concrete models, runtimes, and hardware remain later-owned"] []
  ,named "phase-13-pass-criterion" [pre]] where named = mergeChecks

discoverPackageDatabases :: IO [FilePath]
discoverPackageDatabases = do
  home <- getHomeDirectory
  let store = home </> ".cabal/store"
  present <- doesDirectoryExist store
  if not present then pure [] else listDirectory store >>= filterM doesDirectoryExist . map (\name -> store </> name </> "package.db") . filter ("ghc-9.12.4-" `isInfixOf`)

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-13/work"
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
unavailableMatrix = Matrix (u "fake-solver-compiler") (u "clean-compiler") (u "clean-oracle") [Mutant name (Text.pack selector) locus (u (name <> "-compiler")) (u (name <> "-oracle")) | (name, selector, locus) <- mutantSpecifications] where u = unavailable
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix fakeBuild cleanBuild cleanRun mutants) = [fakeBuild, cleanBuild, cleanRun] <> concat [[build, run] | Mutant _ _ _ build run <- mutants]

productionSource, oracleSource, fakeSource :: FilePath
productionSource = "src/symbolic-checker/Amoebius/Checker/Symbolic.hs"
oracleSource = "test/spec/formal/symbolic/SymbolicCheckerSpec.hs"
fakeSource = "test/spec/formal/symbolic/FakeSmtSolver.hs"
expectedSources :: [FilePath]
expectedSources = sort [productionSource, oracleSource, fakeSource]
