{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden, hardware-free Phase-4 authority. Compiler and linker
-- children are deliberately synchronous and never receive a parallelism flag.
module Amoebius.Validation.BudgetCalculusRun.Internal
  ( AcquiredBudgetCalculusRun
  , acquireBudgetCalculusRun
  , acquireBudgetCalculusRefreshRun
  , acquiredBudgetCalculusRunCheck
  , foldAcquiredBudgetCalculusRun
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust, genesisTrustCheck, genesisTrustCompilerExecutable
  , genesisTrustToolchainIdentity )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence, acquirePhaseContractEvidenceFor
  , acquireRecordedPhaseContractEvidence, acquiredPhaseContractEvidenceCheck )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot, IndexEntry (indexPath), SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedIndex), acquiredSourceSnapshot )
import Amoebius.Validation.Types
  ( CheckResult (..), finding, mergeChecks, observation )
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
  { cleanBuild, cleanRun, cleanStore :: Receipt
  , partialBuild, partialRun, partialStore :: Receipt
  , scarcityBuild, scarcityRun, concurrencyBuild, concurrencyRun :: Receipt
  , grantLegal, grantIllegal, grantExposed :: Receipt
  , retentionLegal, retentionIllegal, retentionWeakened :: Receipt
  }

data AcquiredBudgetCalculusRun = AcquiredBudgetCalculusRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredBudgetCalculusRunCheck :: AcquiredBudgetCalculusRun -> CheckResult
acquiredBudgetCalculusRunCheck (AcquiredBudgetCalculusRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredBudgetCalculusRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredBudgetCalculusRun -> value
foldAcquiredBudgetCalculusRun consume (AcquiredBudgetCalculusRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireBudgetCalculusRun, acquireBudgetCalculusRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredBudgetCalculusRun
acquireBudgetCalculusRun = acquire False
acquireBudgetCalculusRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredBudgetCalculusRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "budget-calculus-package-database"
        [observation "budget-calculus.package-db" (Text.pack path) | path <- databases]
        [finding "BUDGET-CALCULUS-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  let receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 4 acquired
      compiler = compilerCheck [cleanBuild matrix, partialBuild matrix, scarcityBuild matrix, concurrencyBuild matrix]
      oracle = oracleCheck (cleanRun matrix)
      positive = positiveCheck matrix
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts
      observer = observerCheck receipts
      freshness = CheckResult "budget-calculus-freshness" [observation "budget-calculus.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = CheckResult "budget-calculus-cleanroom" [observation "budget-calculus.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "BUDGET-CALCULUS-CLEANROOM" runRoot "generated products escaped the phase run root" | not (pathBelow (root </> ".build/runs/phase-04/work") runRoot)]
      qualification = mergeChecks "budget-calculus-qualification" [compiler, oracle, positive, negatives, mutants]
      prerequisite = mergeChecks "budget-calculus-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler, oracle, positive, negatives, mutants, discovery, authority, observer, freshness, cleanroom]
      rows = phaseRows prerequisite compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom
      result = mergeChecks "budget-calculus" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "budget-subject" [checkDigest compiler]
      oracleId = ids "budget-oracle" [receiptDigest (cleanRun matrix)]
      harnessId = ids "budget-harness" (map receiptDigest receipts)
      observerId = ids "budget-observer" [checkDigest observer]
      qualificationId = ids "budget-qualification" [checkDigest qualification]
      acquiredRunId = ids "budget-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "budget-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredBudgetCalculusRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  cb <- compileProgram root runRoot database compiler "clean" Nothing
  cr <- runBuilt root runRoot "clean" "clean-oracle" [] cb
  cs <- runBuilt root runRoot "clean" "clean-store" ["--store-identity"] cb
  pb <- compileProgram root runRoot database compiler "partial" (Just "BUDGET_CALCULUS_ADMIT_AFTER_PARTIAL_WRITE_MUTANT")
  pr <- runBuilt root runRoot "partial" "partial-oracle" [] pb
  ps <- runBuilt root runRoot "partial" "partial-store" ["--store-identity"] pb
  sb <- compileProgram root runRoot database compiler "scarcity" (Just "BUDGET_CALCULUS_GRANT_DEFAULTS_UNBOUNDED_MUTANT")
  sr <- runBuilt root runRoot "scarcity" "scarcity-oracle" [] sb
  xb <- compileProgram root runRoot database compiler "concurrency" (Just "BUDGET_CALCULUS_CEILING_SEPARATED_FROM_CONCURRENCY_MUTANT")
  xr <- runBuilt root runRoot "concurrency" "concurrency-oracle" [] xb
  gl <- compileFixture root runRoot database compiler "grant-legal" Nothing grantLegalSource
  gi <- compileFixture root runRoot database compiler "grant-illegal" Nothing grantIllegalSource
  ge <- compileFixture root runRoot database compiler "grant-exposed" (Just "BUDGET_CALCULUS_GRANT_CONSTRUCTORS_EXPOSED_MUTANT") grantIllegalSource
  rl <- compileFixture root runRoot database compiler "retention-legal" Nothing retentionLegalSource
  ri <- compileFixture root runRoot database compiler "retention-illegal" Nothing retentionIllegalSource
  rw <- compileFixture root runRoot database compiler "retention-weakened" (Just "BUDGET_CALCULUS_RETENTION_OMITS_REAPER_MUTANT") retentionIllegalSource
  pure (Matrix cb cr cs pb pr ps sb sr xb xr gl gi ge rl ri rw)

compileProgram :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileProgram root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"; binary = runRoot </> variant </> "budget-calculus-oracle"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler (common database objects selector <> ["-o", binary, oracleSource])

compileFixture :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> FilePath -> IO Receipt
compileFixture root runRoot database compiler variant selector source = do
  let objects = runRoot </> variant </> "objects"
  createDirectoryIfMissing True objects
  runProcess root (Text.pack variant <> "-compiler") compiler (common database objects selector <> ["-fno-code", source])

common :: FilePath -> FilePath -> Maybe String -> [String]
common database objects selector =
  ["-XGHC2024", "-O0", "-fforce-recomp", "-clear-package-db", "-global-package-db", "-package-db", database
  , "-isrc", "-itest/spec/calculus", "-package", "bytestring", "-package", "containers", "-package", "cryptohash-sha256", "-package", "text"
  , "-odir", objects, "-hidir", objects, "-stubdir", objects] <> maybe [] (pure . ("-D" <>)) selector

runBuilt :: FilePath -> FilePath -> FilePath -> Text -> [String] -> Receipt -> IO Receipt
runBuilt root runRoot variant name args build
  | receiptExit build == ExitSuccess = runProcess root name (runRoot </> variant </> "budget-calculus-oracle") args
  | otherwise = pure (unavailable name)

compilerCheck :: [Receipt] -> CheckResult
compilerCheck receipts = CheckResult "budget-calculus-compiler" (map (observation "budget-calculus.compiler" . receiptSummary) receipts)
  [finding "BUDGET-CALCULUS-COMPILER" (Text.unpack name) "a clean or changed-production oracle did not compile" | Receipt name _ _ status _ _ <- receipts, status /= ExitSuccess]

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "budget-calculus-independent-oracle" [observation "budget-calculus.oracle" (receiptSummary receipt)]
  [finding "BUDGET-CALCULUS-ORACLE" oracleSource "the Haskell oracle did not report all ten checks green" | receiptExit receipt /= ExitSuccess || not ("PASS (24 rows, 5 refusal reasons, 10 checks)" `Text.isInfixOf` receiptStdout receipt)]

positiveCheck :: Matrix -> CheckResult
positiveCheck matrix = CheckResult "budget-calculus-positive-controls" [observation "budget-calculus.positive.store" (receiptDigest (cleanStore matrix))]
  [finding "BUDGET-CALCULUS-POSITIVE" "<clean-controls>" "clean oracle/store or legal compile controls failed" | not good]
 where
  good = all ((== ExitSuccess) . receiptExit) [cleanRun matrix, cleanStore matrix, grantLegal matrix, retentionLegal matrix]
      && storeStable (receiptStdout (cleanStore matrix))

negativeCheck :: Matrix -> CheckResult
negativeCheck matrix = CheckResult "budget-calculus-paired-negatives"
  [observation "budget-calculus.negative.grant" (receiptSummary (grantIllegal matrix)), observation "budget-calculus.negative.retention" (receiptSummary (retentionIllegal matrix))]
  [finding "BUDGET-CALCULUS-NEGATIVE" "<compile-pairs>" "an illegal twin did not fail for its exact constructor/reaper reason" | not good]
 where
  good = failedWith (grantIllegal matrix) "Illegal term-level use of the type constructor" && failedWith (grantIllegal matrix) "Grant"
      && failedWith (retentionIllegal matrix) "Couldn't match expected type" && failedWith (retentionIllegal matrix) "Reaper"

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "budget-calculus-mutants" [observation "budget-calculus.mutants" (Text.intercalate ":" (map receiptDigest subjects))]
  [finding "BUDGET-CALCULUS-MUTANT" "<changed-production-matrix>" "one or more applied budget mutants survived its assigned observation" | not good]
 where
  subjects = [partialStore matrix, scarcityRun matrix, concurrencyRun matrix, grantExposed matrix, retentionWeakened matrix]
  good = receiptExit (partialRun matrix) == ExitSuccess && not (storeStable (receiptStdout (partialStore matrix)))
      && failsOnly "pool-is-scarce" (scarcityRun matrix) && failsOnly "admission-matches-oracle" (concurrencyRun matrix)
      && receiptExit (grantExposed matrix) == ExitSuccess && receiptExit (retentionWeakened matrix) == ExitSuccess

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "budget-calculus-discovery" [observation "budget-calculus.discovery.count" (Text.pack (show (length observed)))]
  [finding "BUDGET-CALCULUS-DISCOVERY" "<budget-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), inScope path]
  inScope path = ".hs" `isSuffixOf` path && any (`isPrefixOf` path) sourcePrefixes

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot compiler receipts = CheckResult "budget-calculus-authority" [observation "budget-calculus.compiler-serialization" "one synchronous GHC child at a time; no -j; no pb; no hardware or network"]
  ([finding "BUDGET-CALCULUS-RUN-ROOT" runRoot "run root escaped .build/runs/phase-04/work" | not (pathBelow (root </> ".build/runs/phase-04/work") runRoot)] <>
   [finding "BUDGET-CALCULUS-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority" | Receipt name executable args _ _ _ <- receipts, "-compiler" `Text.isSuffixOf` name, executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args])

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "budget-calculus-observer" (map (observation "budget-calculus.observer.process" . receiptSummary) receipts)
  [finding "BUDGET-CALCULUS-OBSERVER" (Text.unpack name) "a process receipt lacks an absolute executable or digest" | receipt@(Receipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom =
  [named "phase-04-claim" [pre], named "phase-04-subject" [compiler, positive], named "phase-04-command" [compiler, authority]
  ,named "phase-04-oracle" [oracle], named "phase-04-positive-controls" [positive], named "phase-04-paired-negatives" [negatives]
  ,named "phase-04-mutants" [mutants], named "phase-04-discovery" [discovery], named "phase-04-challenge" [mutants]
  ,named "phase-04-observer" [observer], named "phase-04-authority-bypass" [authority], named "phase-04-freshness" [freshness]
  ,named "phase-04-qualification" [qualification], named "phase-04-cleanroom" [cleanroom], named "phase-04-legacy-closure" [pre]
  ,CheckResult "phase-04-predecessor" [observation "phase-04.predecessor" "deferred to durable receipt verifier"] []
  ,CheckResult "phase-04-residue" [observation "phase-04.residue" "composition, live free-space, effects, runtimes, and hardware remain later-owned"] []
  ,named "phase-04-pass-criterion" [pre]]
 where named = mergeChecks

storeStable :: Text -> Bool
storeStable output = lookupValue "ceiling-refusal-before" == lookupValue "ceiling-refusal-after"
  && lookupValue "declaration-refusal-before" == lookupValue "declaration-refusal-after"
  && lookupValue "committed-after-refusal" == Just "3"
 where
  rows = [(Text.takeWhile (/= '\t') line, Text.drop 1 (Text.dropWhile (/= '\t') line)) | line <- Text.lines output]
  lookupValue key = lookup key rows

failsOnly :: String -> Receipt -> Bool
failsOnly label receipt = receiptExit receipt == ExitFailure 1
  && filter ("FAIL" `isInfixOf`) (lines (Text.unpack (receiptStdout receipt))) == ["  FAIL " <> label, "budget-calculus-spec: FAIL " <> label]

failedWith :: Receipt -> Text -> Bool
failedWith receipt needle = receiptExit receipt == ExitFailure 1 && needle `Text.isInfixOf` receiptStderr receipt

discoverPackageDatabases :: IO [FilePath]
discoverPackageDatabases = do
  home <- getHomeDirectory; let store = home </> ".cabal/store"
  present <- doesDirectoryExist store
  if not present then pure [] else do
    names <- listDirectory store
    filterM doesDirectoryExist [store </> name </> "package.db" | name <- names, "ghc-9.12.4-" `isInfixOf` name]

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-04/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"; hClose handle; removeFile leaf; createDirectory leaf; pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working name executable args = do
  attempt <- try (readCreateProcessWithExitCode ((proc executable args) {cwd = Just working}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ either (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem)))
    (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err)) attempt

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
unavailableMatrix = Matrix (u "clean-compiler") (u "clean-oracle") (u "clean-store") (u "partial-compiler") (u "partial-oracle") (u "partial-store") (u "scarcity-compiler") (u "scarcity-oracle") (u "concurrency-compiler") (u "concurrency-oracle") (u "grant-legal-compiler") (u "grant-illegal-compiler") (u "grant-exposed-compiler") (u "retention-legal-compiler") (u "retention-illegal-compiler") (u "retention-weakened-compiler") where u = unavailable
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts m = [cleanBuild m, cleanRun m, cleanStore m, partialBuild m, partialRun m, partialStore m, scarcityBuild m, scarcityRun m, concurrencyBuild m, concurrencyRun m, grantLegal m, grantIllegal m, grantExposed m, retentionLegal m, retentionIllegal m, retentionWeakened m]

sourcePrefixes :: [FilePath]
sourcePrefixes = ["src/Amoebius/Calculus/Budget/", "test/spec/calculus/Budget", "test/negative/compile_fail/budget_calculus/"]
expectedSources :: [FilePath]
expectedSources = sort ["src/Amoebius/Calculus/Budget/Admission.hs", "src/Amoebius/Calculus/Budget/Grant.hs", "src/Amoebius/Calculus/Budget/Retention.hs", "src/Amoebius/Calculus/Budget/Store.hs", oracleSource, grantLegalSource, grantIllegalSource, retentionLegalSource, retentionIllegalSource]
oracleSource, grantLegalSource, grantIllegalSource, retentionLegalSource, retentionIllegalSource :: FilePath
oracleSource = "test/spec/calculus/BudgetCalculusSpec.hs"
grantLegalSource = "test/negative/compile_fail/budget_calculus/grant_comes_from_the_issuer.hs"
grantIllegalSource = "test/negative/compile_fail/budget_calculus/grant_forged_unbounded.hs"
retentionLegalSource = "test/negative/compile_fail/budget_calculus/retention_names_its_reaper.hs"
retentionIllegalSource = "test/negative/compile_fail/budget_calculus/retention_omits_its_reaper.hs"
