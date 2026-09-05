{-# LANGUAGE OverloadedStrings #-}

-- | Package-hidden, hardware-free Phase-5 authority. Every compiler child is
-- synchronous; no invocation uses @pb@, a network, hardware, or parallelism.
module Amoebius.Validation.LiftCalculusRun.Internal
  ( AcquiredLiftCalculusRun
  , acquireLiftCalculusRun
  , acquireLiftCalculusRefreshRun
  , acquiredLiftCalculusRunCheck
  , foldAcquiredLiftCalculusRun
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
  , fallbackBuild, fallbackRun :: Receipt
  , forgedBuild, forgedRun :: Receipt
  , joinedBuild, joinedRun :: Receipt
  , missingFrame, missingContainer :: Receipt
  , witnessLegal, witnessIllegal, witnessExposed :: Receipt
  , pathsLegal, pathsIllegal, pathsRelaxed :: Receipt
  }

data AcquiredLiftCalculusRun = AcquiredLiftCalculusRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredLiftCalculusRunCheck :: AcquiredLiftCalculusRun -> CheckResult
acquiredLiftCalculusRunCheck (AcquiredLiftCalculusRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredLiftCalculusRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredLiftCalculusRun -> value
foldAcquiredLiftCalculusRun consume (AcquiredLiftCalculusRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireLiftCalculusRun, acquireLiftCalculusRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredLiftCalculusRun
acquireLiftCalculusRun = acquire False
acquireLiftCalculusRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredLiftCalculusRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  databases <- discoverPackageDatabases
  let databaseCheck = CheckResult "lift-calculus-package-database"
        [observation "lift-calculus.package-db" (Text.pack path) | path <- databases]
        [finding "LIFT-CALCULUS-PACKAGE-DB" "<cabal-store>" "exactly one GHC-9.12.4 package database is required" | length databases /= 1]
  matrix <- case databases of
    [database] -> executeMatrix root runRoot database (genesisTrustCompilerExecutable trust)
    _ -> pure unavailableMatrix
  let receipts = matrixReceipts matrix
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 5 acquired
      compiler = compilerCheck [cleanBuild matrix, fallbackBuild matrix, forgedBuild matrix, joinedBuild matrix]
      oracle = oracleCheck (cleanRun matrix)
      positive = positiveCheck matrix
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot (genesisTrustCompilerExecutable trust) receipts
      observer = observerCheck receipts
      freshness = CheckResult "lift-calculus-freshness" [observation "lift-calculus.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = CheckResult "lift-calculus-cleanroom" [observation "lift-calculus.run-root" (Text.pack (makeRelative root runRoot))]
        [finding "LIFT-CALCULUS-CLEANROOM" runRoot "generated products escaped the phase run root" | not (pathBelow (root </> ".build/runs/phase-05/work") runRoot)]
      qualification = mergeChecks "lift-calculus-qualification" [compiler, oracle, positive, negatives, mutants]
      prerequisite = mergeChecks "lift-calculus-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, databaseCheck, compiler, oracle, positive, negatives, mutants, discovery, authority, observer, freshness, cleanroom]
      rows = phaseRows prerequisite compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom
      result = mergeChecks "lift-calculus" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "lift-subject" [checkDigest compiler]
      oracleId = ids "lift-oracle" [receiptDigest (cleanRun matrix)]
      harnessId = ids "lift-harness" (map receiptDigest receipts)
      observerId = ids "lift-observer" [checkDigest observer]
      qualificationId = ids "lift-qualification" [checkDigest qualification]
      acquiredRunId = ids "lift-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "lift-toolchain" [genesisTrustToolchainIdentity trust]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0"
  pure (AcquiredLiftCalculusRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot database compiler = do
  cb <- compileProgram root runRoot database compiler "clean" Nothing
  cr <- runBuilt root runRoot "clean" "clean-oracle" cb
  fb <- compileProgram root runRoot database compiler "fallback" (Just "LIFT_CALCULUS_DISPATCH_ADMITS_A_FALLBACK_MUTANT")
  fr <- runBuilt root runRoot "fallback" "fallback-oracle" fb
  wb <- compileProgram root runRoot database compiler "forged" (Just "LIFT_CALCULUS_WITNESS_FORGED_WITHOUT_OBSERVATION_MUTANT")
  wr <- runBuilt root runRoot "forged" "forged-oracle" wb
  jb <- compileProgram root runRoot database compiler "joined" (Just "LIFT_CALCULUS_COMPOSITION_JOINS_UNMET_LAYERS_MUTANT")
  jr <- runBuilt root runRoot "joined" "joined-oracle" jb
  mf <- compileProgram root runRoot database compiler "missing-frame" (Just "LIFT_CALCULUS_REMOVE_ENTER_FRAME_RELATION_MUTANT")
  mc <- compileProgram root runRoot database compiler "missing-container" (Just "LIFT_CALCULUS_REMOVE_ENTER_CONTAINER_RELATION_MUTANT")
  wl <- compileFixture root runRoot database compiler "witness-legal" Nothing witnessLegalSource
  wi <- compileFixture root runRoot database compiler "witness-illegal" Nothing witnessIllegalSource
  we <- compileFixture root runRoot database compiler "witness-exposed" (Just "LIFT_CALCULUS_WITNESS_CONSTRUCTOR_EXPOSED_MUTANT") witnessIllegalSource
  pl <- compileFixture root runRoot database compiler "paths-legal" Nothing pathsLegalSource
  pathsBad <- compileFixture root runRoot database compiler "paths-illegal" Nothing pathsIllegalSource
  pathsLoose <- compileFixture root runRoot database compiler "paths-relaxed" (Just "LIFT_CALCULUS_COMPOSE_DROPS_MEETING_LAYER_MUTANT") pathsIllegalSource
  pure (Matrix cb cr fb fr wb wr jb jr mf mc wl wi we pl pathsBad pathsLoose)

compileProgram :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe String -> IO Receipt
compileProgram root runRoot database compiler variant selector = do
  let objects = runRoot </> variant </> "objects"; binary = runRoot </> variant </> "lift-calculus-oracle"
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
  | receiptExit build == ExitSuccess = runProcess root name (runRoot </> variant </> "lift-calculus-oracle") []
  | otherwise = pure (unavailable name)

compilerCheck :: [Receipt] -> CheckResult
compilerCheck receipts = CheckResult "lift-calculus-compiler" (map (observation "lift-calculus.compiler" . receiptSummary) receipts)
  [finding "LIFT-CALCULUS-COMPILER" (Text.unpack name) "a clean or runnable changed-production oracle did not compile" | Receipt name _ _ status _ _ <- receipts, status /= ExitSuccess]

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "lift-calculus-independent-oracle" [observation "lift-calculus.oracle" (receiptSummary receipt)]
  [finding "LIFT-CALCULUS-ORACLE" oracleSource "the Haskell oracle did not report all eleven checks green" | receiptExit receipt /= ExitSuccess || not ("PASS (9 pairs, 20 observations, 11 checks)" `Text.isInfixOf` receiptStdout receipt)]

positiveCheck :: Matrix -> CheckResult
positiveCheck matrix = CheckResult "lift-calculus-positive-controls"
  [observation "lift-calculus.positive" "clean-oracle,witness-legal,paths-legal"]
  [finding "LIFT-CALCULUS-POSITIVE" "<clean-controls>" "clean oracle or legal compile controls failed" | not good]
 where good = all ((== ExitSuccess) . receiptExit) [cleanRun matrix, witnessLegal matrix, pathsLegal matrix]

negativeCheck :: Matrix -> CheckResult
negativeCheck matrix = CheckResult "lift-calculus-paired-negatives"
  [observation "lift-calculus.negative.witness" (receiptSummary (witnessIllegal matrix)), observation "lift-calculus.negative.paths" (receiptSummary (pathsIllegal matrix))]
  [finding "LIFT-CALCULUS-NEGATIVE" "<compile-pairs>" "an illegal twin did not fail for its exact witness/layer reason" | not good]
 where
  good = failedWith (witnessIllegal matrix) "Illegal term-level use of the type constructor" && failedWith (witnessIllegal matrix) "Witness"
      && failedWith (pathsIllegal matrix) "Couldn't match type" && failedWith (pathsIllegal matrix) "InContainer" && failedWith (pathsIllegal matrix) "OnHost"

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "lift-calculus-mutants" [observation "lift-calculus.mutants" (Text.intercalate ":" (map receiptDigest subjects))]
  [finding "LIFT-CALCULUS-MUTANT" "<changed-production-matrix>" "one or more applied lift mutants survived its assigned observation" | not good]
 where
  subjects = [fallbackRun matrix, forgedRun matrix, joinedRun matrix, missingFrame matrix, missingContainer matrix, witnessExposed matrix, pathsRelaxed matrix]
  good = failsOnly "relation-matches-oracle" (fallbackRun matrix)
      && failsOnly "witness-requires-observation" (forgedRun matrix)
      && failsOnly "composition-requires-meeting-layers" (joinedRun matrix)
      && incompleteAt (missingFrame matrix) "OnHost, InFrame"
      && incompleteAt (missingContainer matrix) "InFrame, InContainer"
      && receiptExit (witnessExposed matrix) == ExitSuccess
      && receiptExit (pathsRelaxed matrix) == ExitSuccess

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "lift-calculus-discovery" [observation "lift-calculus.discovery.count" (Text.pack (show (length observed)))]
  [finding "LIFT-CALCULUS-DISCOVERY" "<lift-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), inScope path]
  inScope path = ".hs" `isSuffixOf` path && any (`isPrefixOf` path) sourcePrefixes

authorityCheck :: FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot compiler receipts = CheckResult "lift-calculus-authority" [observation "lift-calculus.compiler-serialization" "one synchronous GHC child at a time; no -j; no pb; no hardware or network"]
  ([finding "LIFT-CALCULUS-RUN-ROOT" runRoot "run root escaped .build/runs/phase-05/work" | not (pathBelow (root </> ".build/runs/phase-05/work") runRoot)] <>
   [finding "LIFT-CALCULUS-AUTHORITY" (Text.unpack name) "compiler executable or argv violated direct serial authority" | Receipt name executable args _ _ _ <- receipts, "-compiler" `Text.isSuffixOf` name, executable /= compiler || any (isInfixOf "-j") args || any (isInfixOf "pb") args])

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "lift-calculus-observer" (map (observation "lift-calculus.observer.process" . receiptSummary) receipts)
  [finding "LIFT-CALCULUS-OBSERVER" (Text.unpack name) "a process receipt lacks an absolute executable or digest" | receipt@(Receipt name executable _ _ _ _) <- receipts, executable /= "<unavailable>" && (not (isAbsolute executable) || Text.null (receiptDigest receipt))]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre compiler oracle positive negatives mutants discovery authority observer freshness qualification cleanroom =
  [named "phase-05-claim" [pre], named "phase-05-subject" [compiler, positive], named "phase-05-command" [compiler, authority]
  ,named "phase-05-oracle" [oracle], named "phase-05-positive-controls" [positive], named "phase-05-paired-negatives" [negatives]
  ,named "phase-05-mutants" [mutants], named "phase-05-discovery" [discovery], named "phase-05-challenge" [mutants]
  ,named "phase-05-observer" [observer], named "phase-05-authority-bypass" [authority], named "phase-05-freshness" [freshness]
  ,named "phase-05-qualification" [qualification], named "phase-05-cleanroom" [cleanroom], named "phase-05-legacy-closure" [pre]
  ,CheckResult "phase-05-predecessor" [observation "phase-05.predecessor" "deferred to durable receipt verifier"] []
  ,CheckResult "phase-05-residue" [observation "phase-05.residue" "workflow obligations, composition, effects, runtimes, and hardware remain later-owned"] []
  ,named "phase-05-pass-criterion" [pre]]
 where named = mergeChecks

failsOnly :: String -> Receipt -> Bool
failsOnly label receipt = receiptExit receipt == ExitFailure 1
  && filter ("FAIL" `isInfixOf`) (lines (Text.unpack (receiptStdout receipt))) == ["  FAIL " <> label, "lift-calculus-spec: FAIL " <> label]

failedWith :: Receipt -> Text -> Bool
failedWith receipt needle = receiptExit receipt == ExitFailure 1 && needle `Text.isInfixOf` receiptStderr receipt

incompleteAt :: Receipt -> Text -> Bool
incompleteAt receipt pair = failedWith receipt "Pattern match(es) are non-exhaustive" && failedWith receipt pair

discoverPackageDatabases :: IO [FilePath]
discoverPackageDatabases = do
  home <- getHomeDirectory; let store = home </> ".cabal/store"
  present <- doesDirectoryExist store
  if not present then pure [] else do
    names <- listDirectory store
    filterM doesDirectoryExist [store </> name </> "package.db" | name <- names, "ghc-9.12.4-" `isInfixOf` name]

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-05/work"
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
unavailableMatrix = Matrix (u "clean-compiler") (u "clean-oracle") (u "fallback-compiler") (u "fallback-oracle") (u "forged-compiler") (u "forged-oracle") (u "joined-compiler") (u "joined-oracle") (u "missing-frame-compiler") (u "missing-container-compiler") (u "witness-legal-compiler") (u "witness-illegal-compiler") (u "witness-exposed-compiler") (u "paths-legal-compiler") (u "paths-illegal-compiler") (u "paths-relaxed-compiler") where u = unavailable
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts m = [cleanBuild m, cleanRun m, fallbackBuild m, fallbackRun m, forgedBuild m, forgedRun m, joinedBuild m, joinedRun m, missingFrame m, missingContainer m, witnessLegal m, witnessIllegal m, witnessExposed m, pathsLegal m, pathsIllegal m, pathsRelaxed m]

sourcePrefixes :: [FilePath]
sourcePrefixes = ["src/Amoebius/Calculus/Lift/", "test/spec/calculus/Lift", "test/negative/compile_fail/lift_calculus/"]
expectedSources :: [FilePath]
expectedSources = sort ["src/Amoebius/Calculus/Lift/Compose.hs", "src/Amoebius/Calculus/Lift/Layer.hs", "src/Amoebius/Calculus/Lift/Transition.hs", "src/Amoebius/Calculus/Lift/Witness.hs", oracleSource, witnessLegalSource, witnessIllegalSource, pathsLegalSource, pathsIllegalSource]
oracleSource, witnessLegalSource, witnessIllegalSource, pathsLegalSource, pathsIllegalSource :: FilePath
oracleSource = "test/spec/calculus/LiftCalculusSpec.hs"
witnessLegalSource = "test/negative/compile_fail/lift_calculus/witness_comes_from_an_observation.hs"
witnessIllegalSource = "test/negative/compile_fail/lift_calculus/witness_asserted.hs"
pathsLegalSource = "test/negative/compile_fail/lift_calculus/paths_meet_at_a_layer.hs"
pathsIllegalSource = "test/negative/compile_fail/lift_calculus/paths_do_not_meet.hs"
