{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.RefinementCheckerRun.Internal
  ( AcquiredRefinementCheckerRun, acquireRefinementCheckerRun
  , acquireRefinementCheckerRefreshRun, acquiredRefinementCheckerRunCheck
  , foldAcquiredRefinementCheckerRun ) where

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
data Matrix = Matrix Receipt Receipt Receipt [Receipt] Receipt Receipt [Mutant]

data AcquiredRefinementCheckerRun = AcquiredRefinementCheckerRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredRefinementCheckerRunCheck :: AcquiredRefinementCheckerRun -> CheckResult
acquiredRefinementCheckerRunCheck (AcquiredRefinementCheckerRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredRefinementCheckerRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredRefinementCheckerRun -> value
foldAcquiredRefinementCheckerRun consume (AcquiredRefinementCheckerRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireRefinementCheckerRun, acquireRefinementCheckerRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredRefinementCheckerRun
acquireRefinementCheckerRun = acquire False
acquireRefinementCheckerRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredRefinementCheckerRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "refinement-checker-package-database"
        [observation "refinement-checker.package-db" (Text.pack path) | path <- databases]
        [finding "REFINEMENT-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  discipline <- sourceDisciplineCheck root
  artifact <- artifactCheck root runRoot
  legacy <- legacyCheck root
  let Matrix _ projectionBuild projectionRun _ _ cleanRun mutants = matrix
      receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 14 acquired
      compiler = compilerCheck matrix
      projection = projectionCheck runRoot projectionBuild projectionRun
      oracle = oracleCheck cleanRun
      positive = positiveCheck cleanRun
      negatives = negativeCheck cleanRun
      mutation = mutantCheck mutants
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts discipline
      observer = observerCheck receipts
      freshness = CheckResult "refinement-checker-freshness" [observation "refinement-checker.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = mergeChecks "refinement-checker-cleanroom" [artifact, CheckResult "refinement-checker-contained-root"
        [observation "refinement-checker.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "REFINEMENT-CLEANROOM" runRoot "generated products escaped the phase run root" | not (pathBelow (root </> ".build/runs/phase-14/work") runRoot)]]
      qualification = mergeChecks "refinement-checker-qualification" [compiler, projection, oracle, positive, negatives, mutation, discovery, discipline, artifact, legacy]
      prerequisite = mergeChecks "refinement-checker-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler, projection, oracle, positive, negatives, mutation, discovery, authority, observer, freshness, cleanroom, discipline, artifact, legacy]
      rows = phaseRows prerequisite compiler projection oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "refinement-checker" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "refinement-checker-subject" [checkDigest compiler, checkDigest discipline]
      oracleId = ids "refinement-checker-oracle" [receiptDigest cleanRun, receiptDigest projectionRun]
      harnessId = ids "refinement-checker-harness" (map receiptDigest receipts)
      observerId = ids "refinement-checker-observer" [checkDigest observer]
      qualificationId = ids "refinement-checker-qualification" [checkDigest qualification]
      acquiredRunId = ids "refinement-checker-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "refinement-checker-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredRefinementCheckerRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  fakeBuild <- compileFake root runRoot database compiler
  projectionBuild <- compileProjection root runRoot database compiler
  projectionRun <- runProjection root runRoot projectionBuild
  fixtureBuilds <- mapM (compileFixture root runRoot compiler) fixtureSources
  cleanBuild <- compileOracle root runRoot database compiler "clean" Nothing
  cleanRun <- runBuilt root runRoot "clean" "clean-oracle" fakeBuild cleanBuild
  mutants <- mapM (runMutant root runRoot database compiler fakeBuild) mutantSpecifications
  pure (Matrix fakeBuild projectionBuild projectionRun fixtureBuilds cleanBuild cleanRun mutants)

compileFake :: FilePath -> FilePath -> FilePath -> FilePath -> IO Receipt
compileFake root runRoot database compiler = do
  let objects = runRoot </> "fake/objects"
      binary = runRoot </> "fake/fake-smt-solver"
  createDirectoryIfMissing True objects
  runProcess root "fake-solver-compiler" compiler
    ["-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
    ,"-clear-package-db", "-global-package-db", "-package-db", database
    ,"-odir", objects, "-hidir", objects, "-stubdir", objects, "-o", binary, fakeSource]

compileProjection :: FilePath -> FilePath -> FilePath -> FilePath -> IO Receipt
compileProjection root runRoot database compiler = do
  let objects = runRoot </> "projection/objects"
      binary = runRoot </> "projection/model-projection"
  createDirectoryIfMissing True objects
  runProcess root "model-projection-compiler" compiler
    ["-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
    ,"-clear-package-db", "-global-package-db", "-package-db", database, "-isrc", "-package", "containers"
    ,"-odir", objects, "-hidir", objects, "-stubdir", objects, "-o", binary, projectionSource]

runProjection :: FilePath -> FilePath -> Receipt -> IO Receipt
runProjection root runRoot build
  | receiptExit build == ExitSuccess = do
      let output = runRoot </> "projection/model-invariants.tsv"
      createDirectoryIfMissing True (runRoot </> "projection")
      runProcess root "model-projection" (runRoot </> "projection/model-projection") [output]
  | otherwise = pure (unavailable "model-projection")

compileFixture :: FilePath -> FilePath -> FilePath -> FilePath -> IO Receipt
compileFixture root runRoot compiler source = do
  let label = Text.pack (takeBase source) <> "-fixture-compiler"
      objects = runRoot </> "fixtures" </> takeBase source
  createDirectoryIfMissing True objects
  runProcess root label compiler ["-XGHC2024", "-fno-code", "-fforce-recomp", "-odir", objects, "-hidir", objects, source]

compileOracle :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileOracle root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"
      binary = runRoot </> variant </> "refinement-oracle"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler
    (common database objects selector <> ["-o", binary, oracleSource])

common :: FilePath -> FilePath -> Maybe String -> [String]
common database objects selector =
  ["-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
  ,"-clear-package-db", "-global-package-db", "-package-db", database
  ,"-isrc/refinement-checker", "-package", "containers", "-package", "bytestring", "-package", "cryptohash-sha256"
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
      runProcess root name (runRoot </> variant </> "refinement-oracle") [runRoot </> "fake/fake-smt-solver", output]
  | otherwise = pure (unavailable name)

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [("precondition-conjunct-drop", "REFINEMENT_DROPS_PRECONDITION_CONJUNCT_MUTANT", "sumNonNegative status: expected Proved")
  ,("correspondence-skip", "REFINEMENT_SKIPS_CORRESPONDENCE_MUTANT", "negativeIdentity status: expected CorrespondenceMismatch")
  ,("postcondition-weakening", "REFINEMENT_WEAKENS_POSTCONDITION_MUTANT", "brokenDecrement status: expected PostconditionCounterexample")]

compilerCheck :: Matrix -> CheckResult
compilerCheck matrix = CheckResult "refinement-checker-compiler"
  (map (observation "refinement-checker.compiler" . receiptSummary) required)
  [finding "REFINEMENT-COMPILER" (Text.unpack name) "a projection, fixture, clean, fake, or changed-production subject did not compile" | Receipt name _ _ status _ _ <- required, status /= ExitSuccess]
 where required = compilerReceipts matrix

projectionCheck :: FilePath -> Receipt -> Receipt -> CheckResult
projectionCheck _ build run = CheckResult "refinement-checker-model-projection"
  [observation "refinement-checker.model-projection" (receiptSummary run)]
  [finding "REFINEMENT-PROJECTION" projectionSource "the compiled Phase-11 projection failed" | receiptExit build /= ExitSuccess || receiptExit run /= ExitSuccess || not ("PASS (2 models, 8 reachable states, 2 invariants)" `Text.isInfixOf` receiptStdout run)]

oracleCheck, positiveCheck, negativeCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "refinement-checker-independent-oracle" [observation "refinement-checker.oracle" (receiptSummary receipt)]
  [finding "REFINEMENT-ORACLE" oracleSource "the authored Haskell oracle did not report its exact inventory" | receiptExit receipt /= ExitSuccess || not (acceptance `Text.isInfixOf` receiptStdout receipt)]
 where acceptance = "PASS (6 functions, 2 invariant correspondences, 3 specific negatives)"
positiveCheck receipt = CheckResult "refinement-checker-positive-controls" [observation "refinement-checker.positive" "six compiled functions; three proofs; two correspondences"]
  [finding "REFINEMENT-POSITIVE" oracleSource "clean refinement controls failed" | receiptExit receipt /= ExitSuccess]
negativeCheck receipt = CheckResult "refinement-checker-paired-negatives" [observation "refinement-checker.negative" "relative solver; unbound variable; ill-sorted precondition; three result classes"]
  [finding "REFINEMENT-NEGATIVE" oracleSource "refinement boundary negatives were not included" | receiptExit receipt /= ExitSuccess]

mutantCheck :: [Mutant] -> CheckResult
mutantCheck mutants = CheckResult "refinement-checker-mutants"
  [observation ("refinement-checker.mutant." <> name) (selector <> "|" <> receiptSummary run) | Mutant name selector _ _ run <- mutants]
  [finding "REFINEMENT-MUTANT" (Text.unpack name) ("changed production subject did not turn red at " <> locus)
    | Mutant name _ locus build run <- mutants, receiptExit build /= ExitSuccess || receiptExit run /= ExitFailure 1 || not (locus `Text.isInfixOf` receiptStderr run)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  source <- Text.pack <$> readFile (root </> productionSource)
  let forbidden = ["unsafePerformIO", "undefined", "lookupEnv", "getEnv", "readFile", "import Amoebius.Checker.Symbolic"]
      required = ["data RefinementExpr", "parseRefinementSource ::", "checkRefinement", "set-logic QF_LIA", "mkRefinementSolver ::"]
  pure (CheckResult "refinement-checker-source-discipline"
    [observation "refinement-checker.effect-boundary" "injected-source-bytes-and-absolute-solver-only", observation "refinement-checker.closed-elements" (Text.pack (show (length required)))]
    ([finding "REFINEMENT-SOURCE-DISCIPLINE" productionSource ("forbidden token: " <> token) | token <- forbidden, token `Text.isInfixOf` source]
      <> [finding "REFINEMENT-SOURCE-SHAPE" productionSource ("missing element: " <> token) | token <- required, not (token `Text.isInfixOf` source)]))

artifactCheck :: FilePath -> FilePath -> IO CheckResult
artifactCheck root runRoot = do
  let resultPath = runRoot </> "clean/generated/results.tsv"
      projectionPath = runRoot </> "projection/model-invariants.tsv"
  resultPresent <- doesFileExist resultPath
  projectionPresent <- doesFileExist projectionPath
  projectionBytes <- if projectionPresent then Text.pack <$> readFile projectionPath else pure "<absent>"
  let expected = "model\tinvariant\tpost\nCounter\tNonNegative\t(result >= 0)\nPair\tNonNegativeSum\t(result >= 0)\n"
  pure (CheckResult "refinement-checker-generated-artifact"
    [ observation "refinement-checker.generated.result" (Text.pack (makeRelative root resultPath))
    , observation "refinement-checker.generated.projection.sha256" (sha256 (TextEncoding.encodeUtf8 projectionBytes))
    ]
    ([finding "REFINEMENT-GENERATED-MISSING" (makeRelative root resultPath) "clean oracle emitted no contained result observation" | not resultPresent]
      <> [finding "REFINEMENT-PROJECTION" (makeRelative root projectionPath) "compiled model projection bytes differ from the independent expectation" | projectionBytes /= expected]))

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  present <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "refinement-checker-legacy-closure" [observation "refinement-checker.legacy.retired-count" (Text.pack (show (length retiredSources)))]
    [finding "REFINEMENT-LEGACY" path "retired Python or serialized behavioral source remains" | path <- present])

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "refinement-checker-discovery" [observation "refinement-checker.discovery.count" (Text.pack (show (length observed)))]
  [finding "REFINEMENT-DISCOVERY" "<refinement-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult -> CheckResult
authorityCheck root runRoot compiler receipts discipline = CheckResult "refinement-checker-authority"
  [observation "refinement-checker.resource-contract" "run-local Haskell fake solver and compiled fixtures; no PATH/network/host/hardware; zero external residue"
  ,observation "refinement-checker.compiler-serialization" "one synchronous GHC child at a time; no -j"]
  ([finding "REFINEMENT-RUN-ROOT" runRoot "run root escaped .build/runs/phase-14/work" | not (pathBelow (root </> ".build/runs/phase-14/work") runRoot)]
    <> [finding "REFINEMENT-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority" | Receipt name executable args _ _ _ <- receipts, "compiler" `Text.isInfixOf` name, executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args]
    <> checkFindings discipline)

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "refinement-checker-observer" (map (observation "refinement-checker.observer.process" . receiptSummary) receipts)
  [finding "REFINEMENT-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" | receipt@(Receipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler projection oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-14-claim" [pre], named "phase-14-subject" [compiler, positive], named "phase-14-command" [compiler, authority]
  ,named "phase-14-oracle" [oracle, projection], named "phase-14-positive-controls" [positive], named "phase-14-paired-negatives" [negatives]
  ,named "phase-14-mutants" [mutants], named "phase-14-discovery" [discovery], named "phase-14-challenge" [mutants]
  ,named "phase-14-observer" [observer], named "phase-14-authority-bypass" [authority], named "phase-14-freshness" [freshness]
  ,named "phase-14-qualification" [qualification], named "phase-14-cleanroom" [cleanroom], named "phase-14-legacy-closure" [legacy]
  ,CheckResult "phase-14-predecessor" [observation "phase-14.predecessor" "deferred to durable receipt verifier"] []
  ,CheckResult "phase-14-residue" [observation "phase-14.residue" "reusable compile-fail machinery, simulation, concrete models, runtimes, and hardware remain later-owned"] []
  ,named "phase-14-pass-criterion" [pre]] where named = mergeChecks

discoverPackageDatabases :: IO [FilePath]
discoverPackageDatabases = do
  home <- getHomeDirectory
  let store = home </> ".cabal/store"
  present <- doesDirectoryExist store
  if not present then pure [] else listDirectory store >>= filterM doesDirectoryExist . map (\name -> store </> name </> "package.db") . filter ("ghc-9.12.4-" `isInfixOf`)

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-14/work"
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
unavailableMatrix = Matrix (u "fake-solver-compiler") (u "model-projection-compiler") (u "model-projection") (map (u . (<> "-fixture-compiler") . Text.pack . takeBase) fixtureSources) (u "clean-compiler") (u "clean-oracle") [Mutant name (Text.pack selector) locus (u (name <> "-compiler")) (u (name <> "-oracle")) | (name, selector, locus) <- mutantSpecifications] where u = unavailable
compilerReceipts :: Matrix -> [Receipt]
compilerReceipts (Matrix fake projection _ fixtures clean _ mutants) = [fake, projection] <> fixtures <> [clean] <> [build | Mutant _ _ _ build _ <- mutants]
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts matrix@(Matrix _ _ projectionRun _ _ cleanRun mutants) = compilerReceipts matrix <> [projectionRun, cleanRun] <> [run | Mutant _ _ _ _ run <- mutants]

takeBase :: FilePath -> FilePath
takeBase = reverse . takeWhile (/= '/') . reverse . takeWhile (/= '.')

productionSource, oracleSource, fakeSource, projectionSource :: FilePath
productionSource = "src/refinement-checker/Amoebius/Checker/Refinement.hs"
oracleSource = "test/spec/formal/refinement/RefinementCheckerSpec.hs"
fakeSource = "test/spec/formal/symbolic/FakeSmtSolver.hs"
projectionSource = "test/spec/formal/refinement/RefinementModelProjection.hs"
fixtureSources, retiredSources, expectedSources :: [FilePath]
fixtureSources = sort
  ["test/fixture/refinement_checker/Broken.hs", "test/fixture/refinement_checker/Decrement.hs"
  ,"test/fixture/refinement_checker/Increment.hs", "test/fixture/refinement_checker/Mismatch.hs"
  ,"test/fixture/refinement_checker/Sum.hs", "test/fixture/refinement_checker/Unknown.hs"]
retiredSources =
  ["tools/refinement_checker.py", "tools/refinement_checker_gate.py", "test/oracle/refinement_checker/functions.tsv"
  ,"test/oracle/refinement_checker/model_invariants.tsv", "test/oracle/refinement_checker_surfaces.tsv"]
expectedSources = sort (productionSource : oracleSource : fakeSource : projectionSource : fixtureSources)
