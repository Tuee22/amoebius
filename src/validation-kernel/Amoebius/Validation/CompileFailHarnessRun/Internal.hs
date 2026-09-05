{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.CompileFailHarnessRun.Internal
  ( AcquiredCompileFailHarnessRun, acquireCompileFailHarnessRun
  , acquireCompileFailHarnessRefreshRun, acquiredCompileFailHarnessRunCheck
  , foldAcquiredCompileFailHarnessRun ) where

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

data AcquiredCompileFailHarnessRun = AcquiredCompileFailHarnessRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredCompileFailHarnessRunCheck :: AcquiredCompileFailHarnessRun -> CheckResult
acquiredCompileFailHarnessRunCheck (AcquiredCompileFailHarnessRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredCompileFailHarnessRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredCompileFailHarnessRun -> value
foldAcquiredCompileFailHarnessRun consume (AcquiredCompileFailHarnessRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireCompileFailHarnessRun, acquireCompileFailHarnessRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredCompileFailHarnessRun
acquireCompileFailHarnessRun = acquire False
acquireCompileFailHarnessRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredCompileFailHarnessRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "compile-fail-harness-package-database"
        [observation "compile-fail-harness.package-db" (Text.pack path) | path <- databases]
        [finding "COMPILE-FAIL-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  discipline <- sourceDisciplineCheck root
  artifact <- artifactCheck root runRoot
  legacy <- legacyCheck root
  let Matrix _ cleanRun mutants = matrix
      receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 15 acquired
      compiler = compilerCheck matrix
      oracle = oracleCheck cleanRun artifact
      positive = positiveCheck cleanRun
      negatives = negativeCheck cleanRun
      mutation = mutantCheck mutants
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts discipline
      observer = observerCheck receipts
      freshness = CheckResult "compile-fail-harness-freshness" [observation "compile-fail-harness.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = mergeChecks "compile-fail-harness-cleanroom" [artifact, CheckResult "compile-fail-harness-contained-root"
        [observation "compile-fail-harness.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "COMPILE-FAIL-CLEANROOM" runRoot "generated products escaped the phase run root" | not (pathBelow (root </> ".build/runs/phase-15/work") runRoot)]]
      qualification = mergeChecks "compile-fail-harness-qualification" [compiler, oracle, positive, negatives, mutation, discovery, discipline, artifact, legacy]
      prerequisite = mergeChecks "compile-fail-harness-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler, oracle, positive, negatives, mutation, discovery, authority, observer, freshness, cleanroom, discipline, artifact, legacy]
      rows = phaseRows prerequisite compiler oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "compile-fail-harness" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "compile-fail-harness-subject" [checkDigest compiler, checkDigest discipline]
      oracleId = ids "compile-fail-harness-oracle" [receiptDigest cleanRun, checkDigest oracle]
      harnessId = ids "compile-fail-harness-harness" (map receiptDigest receipts)
      observerId = ids "compile-fail-harness-observer" [checkDigest observer]
      qualificationId = ids "compile-fail-harness-qualification" [checkDigest qualification]
      acquiredRunId = ids "compile-fail-harness-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "compile-fail-harness-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredCompileFailHarnessRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  cleanBuild <- compileOracle root runRoot database compiler "clean" Nothing
  cleanRun <- runBuilt root runRoot compiler "clean" "clean-oracle" cleanBuild
  mutants <- mapM (runMutant root runRoot database compiler) mutantSpecifications
  pure (Matrix cleanBuild cleanRun mutants)

compileOracle :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileOracle root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"
      binary = runRoot </> variant </> "compile-fail-oracle"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler
    (["-XGHC2024", "-O0", "-fforce-recomp", "-Wincomplete-patterns", "-Werror=incomplete-patterns"
     ,"-clear-package-db", "-global-package-db", "-package-db", database
     ,"-isrc/compile-fail-harness", "-package", "aeson", "-package", "bytestring"
     ,"-package", "cryptohash-sha256", "-package", "text", "-odir", objects
     ,"-hidir", objects, "-stubdir", objects] <> maybe [] (pure . ("-D" <>)) selector <> ["-o", binary, oracleSource])

runBuilt :: FilePath -> FilePath -> FilePath -> FilePath -> Text -> Receipt -> IO Receipt
runBuilt root runRoot compiler variant name build
  | receiptExit build == ExitSuccess = do
      let output = runRoot </> variant </> "generated"
      createDirectoryIfMissing True output
      runProcess root name (runRoot </> variant </> "compile-fail-oracle") [compiler, output]
  | otherwise = pure (unavailable name)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> (Text, String, Text) -> IO Mutant
runMutant root runRoot database compiler (name, selector, locus) = do
  let variant = "mutant-" <> Text.unpack name
  build <- compileOracle root runRoot database compiler variant (Just selector)
  run <- runBuilt root runRoot compiler variant (name <> "-oracle") build
  pure (Mutant name (Text.pack selector) locus build run)

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [("accept-any-failure", "COMPILE_FAIL_ACCEPT_ANY_FAILURE_MUTANT", "accept-any-failure-locus")
  ,("drop-positive-counterpart", "COMPILE_FAIL_DROPS_POSITIVE_COUNTERPART_MUTANT", "drop-positive-counterpart-locus")
  ,("impossible-diagnostic-pin", "COMPILE_FAIL_IMPOSSIBLE_PIN_MUTANT", "impossible-diagnostic-pin-locus")]

compilerCheck :: Matrix -> CheckResult
compilerCheck matrix = CheckResult "compile-fail-harness-compiler"
  (map (observation "compile-fail-harness.compiler" . receiptSummary) required)
  [finding "COMPILE-FAIL-COMPILER" (Text.unpack name) "the clean or changed-production Haskell subject did not compile" | Receipt name _ _ status _ _ <- required, status /= ExitSuccess]
 where required = compilerReceipts matrix

oracleCheck :: Receipt -> CheckResult -> CheckResult
oracleCheck receipt artifact = mergeChecks "compile-fail-harness-independent-oracle"
  [CheckResult "compile-fail-harness-acceptance" [observation "compile-fail-harness.oracle" (receiptSummary receipt)]
    [finding "COMPILE-FAIL-ORACLE" oracleSource "the authored Haskell oracle did not report the exact corpus" | receiptExit receipt /= ExitSuccess || not (acceptance `Text.isInfixOf` receiptStdout receipt)]
  ,artifact]
 where acceptance = "PASS (10 legal/illegal twins, 4 diagnostic codes, 5 owner phases, 3 specific negatives)"

positiveCheck, negativeCheck :: Receipt -> CheckResult
positiveCheck receipt = CheckResult "compile-fail-harness-positive-controls" [observation "compile-fail-harness.positive" "10/10 legal twins compile without a structured Error"]
  [finding "COMPILE-FAIL-POSITIVE" oracleSource "the legal-twin prerequisite failed" | receiptExit receipt /= ExitSuccess]
negativeCheck receipt = CheckResult "compile-fail-harness-paired-negatives" [observation "compile-fail-harness.negative" "10 exact illegal pins plus wrong-reason, missing-diagnostic, and unbound-name refusals"]
  [finding "COMPILE-FAIL-NEGATIVE" oracleSource "the exact negative boundary did not pass" | receiptExit receipt /= ExitSuccess]

mutantCheck :: [Mutant] -> CheckResult
mutantCheck mutants = CheckResult "compile-fail-harness-mutants"
  [observation ("compile-fail-harness.mutant." <> name) (selector <> "|" <> receiptSummary run) | Mutant name selector _ _ run <- mutants]
  [finding "COMPILE-FAIL-MUTANT" (Text.unpack name) ("changed production subject did not turn red at " <> locus)
    | Mutant name _ locus build run <- mutants, receiptExit build /= ExitSuccess || receiptExit run /= ExitFailure 1 || not (locus `Text.isInfixOf` receiptStdout run)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  source <- Text.pack <$> readFile (root </> productionSource)
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  let forbidden = ["unsafePerformIO", "undefined", "lookupEnv", "getEnv", "shell=True", "pb validate"]
      required = ["-fdiagnostics-as-json", "validateNegative", "pairLegalProbe", "pairIllegalProbe", "positiveCounterpartRequired"]
  pure (CheckResult "compile-fail-harness-source-discipline"
    [observation "compile-fail-harness.effect-boundary" "absolute injected GHC; serial synchronous children; source-bound Haskell verdict"
    ,observation "compile-fail-harness.closed-elements" (Text.pack (show (length required)))]
    ([finding "COMPILE-FAIL-SOURCE-DISCIPLINE" productionSource ("forbidden token: " <> token) | token <- forbidden, token `Text.isInfixOf` source || token `Text.isInfixOf` oracle]
      <> [finding "COMPILE-FAIL-SOURCE-SHAPE" (productionSource <> ";" <> oracleSource) ("missing element: " <> token) | token <- required, not (token `Text.isInfixOf` source || token `Text.isInfixOf` oracle)]))

artifactCheck :: FilePath -> FilePath -> IO CheckResult
artifactCheck root runRoot = do
  let target = runRoot </> "clean/generated/results.tsv"
  present <- doesFileExist target
  contents <- if present then Text.pack <$> readFile target else pure ""
  let expected = ["pair-count\t10", "claim-count\t10", "owner-count\t5", "legal-green-count\t10", "illegal-red-count\t10"
        ,"diagnostic-code-pin-count\t10", "source-span-pin-count\t10", "message-pin-count\t10", "twin-probe-count\t10"
        ,"source-digest-count\t20", "structured-diagnostic-count\t11"]
  pure (CheckResult "compile-fail-harness-generated-artifact"
    [observation "compile-fail-harness.generated.result" (Text.pack (makeRelative root target)), observation "compile-fail-harness.generated.sha256" (sha256 (TextEncoding.encodeUtf8 contents))]
    ([finding "COMPILE-FAIL-GENERATED-MISSING" (makeRelative root target) "clean oracle emitted no contained result observation" | not present]
      <> [finding "COMPILE-FAIL-METRIC" (makeRelative root target) ("missing exact metric " <> metric) | metric <- expected, not (metric `elem` Text.lines contents)]))

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  present <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "compile-fail-harness-legacy-closure" [observation "compile-fail-harness.legacy.retired-count" (Text.pack (show (length retiredSources)))]
    [finding "COMPILE-FAIL-LEGACY" path "retired Python or serialized behavioral authority remains" | path <- present])

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "compile-fail-harness-discovery" [observation "compile-fail-harness.discovery.count" (Text.pack (show (length observed)))]
  [finding "COMPILE-FAIL-DISCOVERY" "<compile-fail-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult -> CheckResult
authorityCheck root runRoot compiler receipts discipline = CheckResult "compile-fail-harness-authority"
  [observation "compile-fail-harness.resource-contract" "run-local compiler products only; no pb/network/host/hardware; zero external residue"
  ,observation "compile-fail-harness.compiler-serialization" "one synchronous GHC child at a time; no -j"]
  ([finding "COMPILE-FAIL-RUN-ROOT" runRoot "run root escaped .build/runs/phase-15/work" | not (pathBelow (root </> ".build/runs/phase-15/work") runRoot)]
    <> [finding "COMPILE-FAIL-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority" | Receipt name executable args _ _ _ <- receipts, "compiler" `Text.isInfixOf` name, executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args]
    <> checkFindings discipline)

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "compile-fail-harness-observer" (map (observation "compile-fail-harness.observer.process" . receiptSummary) receipts)
  [finding "COMPILE-FAIL-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" | receipt@(Receipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-15-claim" [pre], named "phase-15-subject" [compiler, positive], named "phase-15-command" [compiler, authority]
  ,named "phase-15-oracle" [oracle], named "phase-15-positive-controls" [positive], named "phase-15-paired-negatives" [negatives]
  ,named "phase-15-mutants" [mutants], named "phase-15-discovery" [discovery], named "phase-15-challenge" [mutants]
  ,named "phase-15-observer" [observer], named "phase-15-authority-bypass" [authority], named "phase-15-freshness" [freshness]
  ,named "phase-15-qualification" [qualification], named "phase-15-cleanroom" [cleanroom], named "phase-15-legacy-closure" [legacy]
  ,CheckResult "phase-15-predecessor" [observation "phase-15.predecessor" "deferred to durable receipt verifier"] []
  ,CheckResult "phase-15-residue" [observation "phase-15.residue" "deterministic simulation, concrete models, runtimes, and hardware remain later-owned"] []
  ,named "phase-15-pass-criterion" [pre]] where named = mergeChecks

discoverPackageDatabases :: IO [FilePath]
discoverPackageDatabases = do
  home <- getHomeDirectory
  let store = home </> ".cabal/store"
  present <- doesDirectoryExist store
  if not present then pure [] else listDirectory store >>= filterM doesDirectoryExist . map (\name -> store </> name </> "package.db") . filter ("ghc-9.12.4-" `isInfixOf`)

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-15/work"
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
receiptStdout :: Receipt -> Text
receiptStdout (Receipt _ _ _ _ out _) = out
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
compilerReceipts :: Matrix -> [Receipt]
compilerReceipts (Matrix clean _ mutants) = clean : [build | Mutant _ _ _ build _ <- mutants]
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts matrix@(Matrix _ cleanRun mutants) = compilerReceipts matrix <> [cleanRun] <> [run | Mutant _ _ _ _ run <- mutants]

productionSource, oracleSource :: FilePath
productionSource = "src/compile-fail-harness/Amoebius/Compiler/CompileFailHarness.hs"
oracleSource = "test/spec/compile_fail_harness/CompileFailHarnessSpec.hs"
fixtureSources, retiredSources, expectedSources :: [FilePath]
fixtureSources = sort
  ["test/negative/compile_fail/budget_calculus/grant_comes_from_the_issuer.hs", "test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs"
  ,"test/negative/compile_fail/budget_calculus/retention_names_its_reaper.hs", "test/negative/compile_fail/budget_calculus/retention_omits_its_reaper.hs"
  ,"test/negative/compile_fail/lift_calculus/paths_meet_at_a_layer.hs", "test/negative/compile_fail/lift_calculus/paths_do_not_meet.hs"
  ,"test/negative/compile_fail/lift_calculus/witness_comes_from_an_observation.hs", "test/negative/compile_fail/lift_calculus/witness_asserted.hs"
  ,"test/negative/compile_fail/workflow_calculus/workflow_discharges_its_obligation.hs", "test/negative/compile_fail/workflow_calculus/workflow_ends_owing_a_teardown.hs"
  ,"test/negative/compile_fail/workflow_calculus/transfer_names_its_condition.hs", "test/negative/compile_fail/workflow_calculus/transfer_without_a_condition.hs"
  ,"test/negative/compile_fail/workflow_calculus/teardown_discharges_what_was_provisioned.hs", "test/negative/compile_fail/workflow_calculus/teardown_of_an_unheld_obligation.hs"
  ,"test/negative/compile_fail/evidence_calculus/claim_names_its_fixture.hs", "test/negative/compile_fail/evidence_calculus/claim_without_a_fixture.hs"
  ,"test/negative/compile_fail/evidence_calculus/gate_declares_its_register.hs", "test/negative/compile_fail/evidence_calculus/gate_without_a_register.hs"
  ,"test/negative/compile_fail/calculus_composition/same_scope_composes.hs", "test/negative/compile_fail/calculus_composition/different_scopes_do_not_compose.hs"]
retiredSources = ["tools/compile_fail_harness.py", "tools/compile_fail_harness_gate.py", "test/oracle/compile_fail_harness/fixtures.tsv", "test/oracle/compile_fail_harness_surfaces.tsv"]
expectedSources = sort (productionSource : oracleSource : fixtureSources)
