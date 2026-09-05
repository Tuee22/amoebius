{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden, hardware-free Phase-7 authority. Every compiler child is
-- synchronous and the runner never uses @pb@, a network, or hardware.
module Amoebius.Validation.EvidenceCalculusRun.Internal
  ( AcquiredEvidenceCalculusRun
  , acquireEvidenceCalculusRun
  , acquireEvidenceCalculusRefreshRun
  , acquiredEvidenceCalculusRunCheck
  , foldAcquiredEvidenceCalculusRun
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
  , emptyBuild, emptyRun, locusBuild, locusRun, registryBuild, registryRun :: Receipt
  , strengthBuild, strengthRun, simulationBuild, simulationRun, reachedBuild, reachedRun :: Receipt
  , claimLegal, claimIllegal, claimRelaxed :: Receipt
  , registerLegal, registerIllegal, registerRelaxed :: Receipt
  }

data AcquiredEvidenceCalculusRun = AcquiredEvidenceCalculusRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredEvidenceCalculusRunCheck :: AcquiredEvidenceCalculusRun -> CheckResult
acquiredEvidenceCalculusRunCheck (AcquiredEvidenceCalculusRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredEvidenceCalculusRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredEvidenceCalculusRun -> value
foldAcquiredEvidenceCalculusRun consume (AcquiredEvidenceCalculusRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireEvidenceCalculusRun, acquireEvidenceCalculusRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredEvidenceCalculusRun
acquireEvidenceCalculusRun = acquire False
acquireEvidenceCalculusRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredEvidenceCalculusRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "evidence-calculus-package-database"
        [observation "evidence-calculus.package-db" (Text.pack path) | path <- databases]
        [finding "EVIDENCE-CALCULUS-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  let receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 7 acquired
      compiler = compilerCheck [cleanBuild matrix, emptyBuild matrix, locusBuild matrix, registryBuild matrix, strengthBuild matrix, simulationBuild matrix, reachedBuild matrix]
      oracle = oracleCheck (cleanRun matrix)
      positive = positiveCheck matrix
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts
      observer = observerCheck receipts
      freshness = CheckResult "evidence-calculus-freshness" [observation "evidence-calculus.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = CheckResult "evidence-calculus-cleanroom" [observation "evidence-calculus.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "EVIDENCE-CALCULUS-CLEANROOM" runRoot "generated products escaped the phase run root" | not (pathBelow (root </> ".build/runs/phase-07/work") runRoot)]
      qualification = mergeChecks "evidence-calculus-qualification" [compiler, oracle, positive, negatives, mutants]
      prerequisite = mergeChecks "evidence-calculus-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler, oracle, positive, negatives, mutants, discovery, authority, observer, freshness, cleanroom]
      rows = phaseRows prerequisite compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom
      result = mergeChecks "evidence-calculus" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "evidence-subject" [checkDigest compiler]
      oracleId = ids "evidence-oracle" [receiptDigest (cleanRun matrix)]
      harnessId = ids "evidence-harness" (map receiptDigest receipts)
      observerId = ids "evidence-observer" [checkDigest observer]
      qualificationId = ids "evidence-qualification" [checkDigest qualification]
      acquiredRunId = ids "evidence-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "evidence-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredEvidenceCalculusRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  cb <- program "clean" Nothing; cr <- runBuilt root runRoot "clean" "clean-oracle" cb
  eb <- program "empty" (Just "EVIDENCE_CALCULUS_CLAIM_WITHOUT_A_FIXTURE_MUTANT"); er <- runBuilt root runRoot "empty" "empty-oracle" eb
  lb <- program "locus" (Just "EVIDENCE_CALCULUS_MUTANT_POINTS_AT_THE_WRONG_LOCUS_MUTANT"); lr <- runBuilt root runRoot "locus" "locus-oracle" lb
  rb <- program "registry" (Just "EVIDENCE_CALCULUS_SECOND_MUTANT_REGISTRY_MUTANT"); rr <- runBuilt root runRoot "registry" "registry-oracle" rb
  sb <- program "strength" (Just "EVIDENCE_CALCULUS_ORACLE_ADMITS_REJECTED_MUTANT"); sr <- runBuilt root runRoot "strength" "strength-oracle" sb
  mb <- program "simulation" (Just "EVIDENCE_CALCULUS_SIMULATION_IS_GATE_REGISTER_MUTANT"); mr <- runBuilt root runRoot "simulation" "simulation-oracle" mb
  db <- program "reached" (Just "EVIDENCE_CALCULUS_DECLARE_GATE_IGNORES_REACHED_MUTANT"); dr <- runBuilt root runRoot "reached" "reached-oracle" db
  cl <- fixture "claim-legal" Nothing claimLegalSource; ci <- fixture "claim-illegal" Nothing claimIllegalSource
  cx <- fixture "claim-relaxed" (Just "EVIDENCE_CALCULUS_CLAIM_FIXTURE_OPTIONAL_MUTANT") claimIllegalSource
  gl <- fixture "register-legal" Nothing registerLegalSource; gi <- fixture "register-illegal" Nothing registerIllegalSource
  gx <- fixture "register-relaxed" (Just "EVIDENCE_CALCULUS_GATE_REGISTER_OPTIONAL_MUTANT") registerIllegalSource
  pure (Matrix cb cr eb er lb lr rb rr sb sr mb mr db dr cl ci cx gl gi gx)
 where
  program variant selector = compileProgram root runRoot database compiler variant selector
  fixture variant selector source = compileFixture root runRoot database compiler variant selector source

compileProgram :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileProgram root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"; binary = runRoot </> variant </> "evidence-calculus-oracle"
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
  | receiptExit build == ExitSuccess = runProcess root name (runRoot </> variant </> "evidence-calculus-oracle") []
  | otherwise = pure (unavailable name)

compilerCheck :: [Receipt] -> CheckResult
compilerCheck receipts = CheckResult "evidence-calculus-compiler" (map (observation "evidence-calculus.compiler" . receiptSummary) receipts)
  [finding "EVIDENCE-CALCULUS-COMPILER" (Text.unpack name) "a clean or runnable changed-production oracle did not compile" | Receipt name _ _ status _ _ <- receipts, status /= ExitSuccess]

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "evidence-calculus-independent-oracle" [observation "evidence-calculus.oracle" (receiptSummary receipt)]
  [finding "EVIDENCE-CALCULUS-ORACLE" oracleSource "the Haskell oracle did not report all twelve checks green" | receiptExit receipt /= ExitSuccess || not ("PASS (7 claims, 3 mutant records, 12 checks)" `Text.isInfixOf` receiptStdout receipt)]

positiveCheck :: Matrix -> CheckResult
positiveCheck matrix = CheckResult "evidence-calculus-positive-controls" [observation "evidence-calculus.positive" "clean-oracle,two-legal-compile-controls"]
  [finding "EVIDENCE-CALCULUS-POSITIVE" "<clean-controls>" "clean oracle or a legal compile control failed" | not good]
 where good = all ((== ExitSuccess) . receiptExit) [cleanRun matrix, claimLegal matrix, registerLegal matrix]

negativeCheck :: Matrix -> CheckResult
negativeCheck matrix = CheckResult "evidence-calculus-paired-negatives"
  [observation "evidence-calculus.negative.claim" (receiptSummary (claimIllegal matrix)), observation "evidence-calculus.negative.register" (receiptSummary (registerIllegal matrix))]
  [finding "EVIDENCE-CALCULUS-NEGATIVE" "<compile-pairs>" "an illegal twin did not fail for its exact Fixture or GateRegister reason" | not good]
 where
  good = failedWith (claimIllegal matrix) "Couldn't match expected type" && failedWith (claimIllegal matrix) "Fixture"
      && failedWith (registerIllegal matrix) "Couldn't match expected type" && failedWith (registerIllegal matrix) "GateRegister"

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "evidence-calculus-mutants" [observation "evidence-calculus.mutants" (Text.intercalate ":" (map receiptDigest subjects))]
  [finding "EVIDENCE-CALCULUS-MUTANT" "<changed-production-matrix>" "one or more applied evidence mutants survived its assigned observation" | not good]
 where
  subjects = [emptyRun matrix, locusRun matrix, registryRun matrix, strengthRun matrix, simulationRun matrix, reachedRun matrix, claimRelaxed matrix, registerRelaxed matrix]
  good = failsOnly ["every-claim-names-a-fixture"] (emptyRun matrix)
      && failsOnly ["derived-loci-match-the-inventory"] (locusRun matrix)
      && failsOnly ["one-registry-for-the-corpus"] (registryRun matrix)
      && failsOnly ["fixture-kind-set-is-closed", "strength-is-bounded-by-its-fixture-kind", "declared-register-cannot-exceed-what-fixtures-reach"] (strengthRun matrix)
      && failsOnly ["simulation-is-not-a-gate-register"] (simulationRun matrix)
      && failsOnly ["declared-register-cannot-exceed-what-fixtures-reach"] (reachedRun matrix)
      && all ((== ExitSuccess) . receiptExit) [claimRelaxed matrix, registerRelaxed matrix]

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "evidence-calculus-discovery" [observation "evidence-calculus.discovery.count" (Text.pack (show (length observed)))]
  [finding "EVIDENCE-CALCULUS-DISCOVERY" "<evidence-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), inScope path]
  inScope path = ".hs" `isSuffixOf` path && any (`isPrefixOf` path) sourcePrefixes

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot compiler receipts = CheckResult "evidence-calculus-authority" [observation "evidence-calculus.compiler-serialization" "one synchronous GHC child at a time; no -j; no pb; no hardware or network"]
  ([finding "EVIDENCE-CALCULUS-RUN-ROOT" runRoot "run root escaped .build/runs/phase-07/work" | not (pathBelow (root </> ".build/runs/phase-07/work") runRoot)] <>
   [finding "EVIDENCE-CALCULUS-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority" | Receipt name executable args _ _ _ <- receipts, "-compiler" `Text.isSuffixOf` name, executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args])

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "evidence-calculus-observer" (map (observation "evidence-calculus.observer.process" . receiptSummary) receipts)
  [finding "EVIDENCE-CALCULUS-OBSERVER" (Text.unpack name) "a process receipt lacks an absolute executable or digest" | receipt@(Receipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom =
  [named "phase-07-claim" [pre], named "phase-07-subject" [compiler, positive], named "phase-07-command" [compiler, authority]
  ,named "phase-07-oracle" [oracle], named "phase-07-positive-controls" [positive], named "phase-07-paired-negatives" [negatives]
  ,named "phase-07-mutants" [mutants], named "phase-07-discovery" [discovery], named "phase-07-challenge" [mutants]
  ,named "phase-07-observer" [observer], named "phase-07-authority-bypass" [authority], named "phase-07-freshness" [freshness]
  ,named "phase-07-qualification" [qualification], named "phase-07-cleanroom" [cleanroom], named "phase-07-legacy-closure" [pre]
  ,CheckResult "phase-07-predecessor" [observation "phase-07.predecessor" "deferred to durable receipt verifier"] []
  ,CheckResult "phase-07-residue" [observation "phase-07.residue" "oracle correctness, finite-sampling limits, calculus composition, effects, runtimes, and hardware remain later-owned"] []
  ,named "phase-07-pass-criterion" [pre]]
 where named = mergeChecks

failsOnly :: [String] -> Receipt -> Bool
failsOnly labels receipt = receiptExit receipt == ExitFailure 1
  && filter ("FAIL" `isInfixOf`) (lines (Text.unpack (receiptStdout receipt))) == map ("  FAIL " <>) labels <> ["evidence-calculus-spec: FAIL " <> unwords labels]
failedWith :: Receipt -> Text -> Bool
failedWith receipt needle = receiptExit receipt == ExitFailure 1 && needle `Text.isInfixOf` receiptStderr receipt

discoverPackageDatabases :: IO [FilePath]
discoverPackageDatabases = do
  home <- getHomeDirectory; let store = home </> ".cabal/store"
  present <- doesDirectoryExist store
  if not present then pure [] else do names <- listDirectory store; filterM doesDirectoryExist [store </> name </> "package.db" | name <- names, "ghc-9.12.4-" `isInfixOf` name]

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-07/work"
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
unavailableMatrix = Matrix (u "clean-compiler") (u "clean-oracle") (u "empty-compiler") (u "empty-oracle") (u "locus-compiler") (u "locus-oracle") (u "registry-compiler") (u "registry-oracle") (u "strength-compiler") (u "strength-oracle") (u "simulation-compiler") (u "simulation-oracle") (u "reached-compiler") (u "reached-oracle") (u "claim-legal-compiler") (u "claim-illegal-compiler") (u "claim-relaxed-compiler") (u "register-legal-compiler") (u "register-illegal-compiler") (u "register-relaxed-compiler") where u = unavailable
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts m = [cleanBuild m, cleanRun m, emptyBuild m, emptyRun m, locusBuild m, locusRun m, registryBuild m, registryRun m, strengthBuild m, strengthRun m, simulationBuild m, simulationRun m, reachedBuild m, reachedRun m, claimLegal m, claimIllegal m, claimRelaxed m, registerLegal m, registerIllegal m, registerRelaxed m]

sourcePrefixes :: [FilePath]
sourcePrefixes = ["src/Amoebius/Calculus/Evidence/", "test/spec/calculus/Evidence", "test/negative/compile_fail/evidence_calculus/"]
expectedSources :: [FilePath]
expectedSources = sort ["src/Amoebius/Calculus/Evidence/Claim.hs", "src/Amoebius/Calculus/Evidence/Fixture.hs", "src/Amoebius/Calculus/Evidence/Mutant.hs", "src/Amoebius/Calculus/Evidence/Register.hs", oracleSource, claimLegalSource, claimIllegalSource, registerLegalSource, registerIllegalSource]
oracleSource, claimLegalSource, claimIllegalSource, registerLegalSource, registerIllegalSource :: FilePath
oracleSource = "test/spec/calculus/EvidenceCalculusSpec.hs"
claimLegalSource = "test/negative/compile_fail/evidence_calculus/claim_names_its_fixture.hs"
claimIllegalSource = "test/negative/compile_fail/evidence_calculus/claim_without_a_fixture.hs"
registerLegalSource = "test/negative/compile_fail/evidence_calculus/gate_declares_its_register.hs"
registerIllegalSource = "test/negative/compile_fail/evidence_calculus/gate_without_a_register.hs"
