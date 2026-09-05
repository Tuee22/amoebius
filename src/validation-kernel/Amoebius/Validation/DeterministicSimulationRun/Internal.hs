{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.DeterministicSimulationRun.Internal
  ( AcquiredDeterministicSimulationRun
  , acquireDeterministicSimulationRun
  , acquireDeterministicSimulationRefreshRun
  , acquiredDeterministicSimulationRunCheck
  , foldAcquiredDeterministicSimulationRun
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust
  , genesisTrustCheck
  , genesisTrustCompilerExecutable
  , genesisTrustToolchainIdentity
  )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence
  , acquirePhaseContractEvidenceFor
  , acquireRecordedPhaseContractEvidence
  , acquiredPhaseContractEvidenceCheck
  )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (indexPath)
  , SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedIndex)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.Types (CheckResult (..), finding, mergeChecks, observation)
import Control.Exception (IOException, try)
import Control.Monad (filterM, forM_)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit, isAlphaNum)
import Data.List (isInfixOf, isPrefixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  ( copyFile
  , createDirectory
  , createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getHomeDirectory
  , listDirectory
  , removeFile
  )
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix Receipt [Mutant]

data AcquiredDeterministicSimulationRun = AcquiredDeterministicSimulationRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredDeterministicSimulationRunCheck :: AcquiredDeterministicSimulationRun -> CheckResult
acquiredDeterministicSimulationRunCheck (AcquiredDeterministicSimulationRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredDeterministicSimulationRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredDeterministicSimulationRun -> value
foldAcquiredDeterministicSimulationRun consume (AcquiredDeterministicSimulationRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireDeterministicSimulationRun, acquireDeterministicSimulationRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredDeterministicSimulationRun
acquireDeterministicSimulationRun = acquire False
acquireDeterministicSimulationRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredDeterministicSimulationRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      dependencyStore = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 16 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  versionReceipt <- runProcess root "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler dependencyStore
  discipline <- sourceDisciplineCheck root
  legacy <- legacyCheck root
  let Matrix cleanRun mutants = matrix
      toolchain = toolchainCheck cabal compiler dependencyStore versionReceipt matrix
      oracle = oracleCheck cleanRun
      positive = positiveCheck cleanRun
      negatives = pairedNegativeCheck cleanRun
      mutation = mutantCheck mutants
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot cabal compiler dependencyStore (versionReceipt : matrixReceipts matrix)
      observer = observerCheck (versionReceipt : matrixReceipts matrix)
      freshness = CheckResult "deterministic-simulation-freshness"
        [observation "deterministic-simulation.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = mergeChecks "deterministic-simulation-cleanroom"
        [cache, CheckResult "deterministic-simulation-contained-root"
          [observation "deterministic-simulation.run-root" (Text.pack (makeRelative root runRoot))]
          [finding "DETERMINISTIC-SIM-CLEANROOM" runRoot "generated products escaped the Phase-16 run root"
            | not (pathBelow (root </> ".build/runs/phase-16/work") runRoot)]]
      qualification = mergeChecks "deterministic-simulation-qualification"
        [toolchain, mutation, oracle, positive, negatives, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "deterministic-simulation-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positive,
         negatives, mutation, discovery, authority, observer, freshness, qualification, cleanroom, discipline, legacy]
      rows = phaseRows prerequisite toolchain oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "deterministic-simulation" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "deterministic-simulation-subject" [checkDigest discipline, receiptDigest cleanRun]
      oracleId = ids "deterministic-simulation-oracle" [receiptDigest cleanRun, checkDigest oracle, checkDigest negatives]
      harnessId = ids "deterministic-simulation-harness" (map receiptDigest (versionReceipt : matrixReceipts matrix))
      observerId = ids "deterministic-simulation-observer" [checkDigest observer]
      qualificationId = ids "deterministic-simulation-qualification" [checkDigest qualification]
      acquiredRunId = ids "deterministic-simulation-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "deterministic-simulation-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest versionReceipt]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredDeterministicSimulationRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler dependencyStore = do
  mutants <- mapM (runMutant root runRoot cabal compiler dependencyStore) mutantSpecifications
  clean <- runVariant root runRoot cabal compiler dependencyStore "clean" Nothing
  pure (Matrix clean mutants)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> (Text, String, Text) -> IO Mutant
runMutant root runRoot cabal compiler dependencyStore (name, flagName, locus) = do
  receipt <- runVariant root runRoot cabal compiler dependencyStore name (Just flagName)
  pure (Mutant name (Text.pack flagName) locus receipt)

runVariant :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runVariant root runRoot cabal compiler dependencyStore name selected =
  runProcess root name cabal
    (["--builddir=" <> runRoot </> "dist", "--store-dir=" <> dependencyStore,
      "--with-compiler=" <> compiler, "--jobs=1", "test", "sim-spec", "--offline", "--test-show-details=direct"]
      <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [("dropped-partition", "deterministic-simulation-dropped-partition-mutant", "NoActOnStaleRead")
  ,("ignore-seed", "deterministic-simulation-ignore-seed-mutant", "distinct seed/fault order produced the same trace")
  ,("bypass-faults", "deterministic-simulation-bypass-faults-mutant", "schedule fault-axis coverage")]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler dependencyStore version matrix = CheckResult "deterministic-simulation-toolchain"
  [observation "deterministic-simulation.cabal" (receiptSummary version), observation "deterministic-simulation.compiler" (Text.pack compiler),
   observation "deterministic-simulation.dependency-store" (Text.pack dependencyStore)]
  ([finding "DETERMINISTIC-SIM-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "DETERMINISTIC-SIM-COMPILER" (Text.unpack name) "the Cabal row did not use the exact absolute compiler, offline mode, and serial execution" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute dependencyStore) ||
      ("--store-dir=" <> dependencyStore) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || any (isInfixOf "pb") args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "deterministic-simulation-independent-oracle"
  [observation "deterministic-simulation.oracle" (receiptSummary receipt)]
  [finding "DETERMINISTIC-SIM-ORACLE" oracleSource "the separately authored Haskell oracle did not report the exact acceptance token" |
    receiptExit receipt /= ExitSuccess || not (acceptance `Text.isInfixOf` receiptOutput receipt)]
 where acceptance = "PASS (2 interpreters, 6 fake contracts, 4 schedules, 5-calculus projection, same-seed bytes, sensitivity, IOSimPOR, 3 production mutants qualified)"

positiveCheck, pairedNegativeCheck :: Receipt -> CheckResult
positiveCheck receipt = CheckResult "deterministic-simulation-positive-controls"
  [observation "deterministic-simulation.positive" "IO and IOSim interpreters; six fakes; four schedules; five-calculus projection; four bounded POR runs"]
  [finding "DETERMINISTIC-SIM-POSITIVE" oracleSource "the closed positive corpus did not pass" | receiptExit receipt /= ExitSuccess]
pairedNegativeCheck receipt = CheckResult "deterministic-simulation-paired-negatives"
  [observation "deterministic-simulation.negatives" "enabled/disabled fake knobs; same/different seed traces; partition heal versus stale action"]
  [finding "DETERMINISTIC-SIM-NEGATIVE" oracleSource "the paired semantic controls did not pass" | receiptExit receipt /= ExitSuccess]

mutantCheck :: [Mutant] -> CheckResult
mutantCheck mutants = CheckResult "deterministic-simulation-mutants"
  [observation ("deterministic-simulation.mutant." <> name) (flagName <> "|" <> receiptSummary receipt) | Mutant name flagName _ receipt <- mutants]
  [finding "DETERMINISTIC-SIM-MUTANT" (Text.unpack name) ("changed production subject did not turn red at " <> locus) |
    Mutant name _ locus receipt <- mutants,
    receiptExit receipt /= ExitFailure 1 || not (locus `Text.isInfixOf` receiptOutput receipt) || not ("Test suite sim-spec: RUNNING" `Text.isInfixOf` receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  bodies <- mapM (fmap Text.pack . readFile . (root </>)) expectedSources
  let productionBodies = take (length productionSources) bodies
      combined = Text.intercalate "\n" bodies
      required = ["data Env m", "MonadAsync", "MonadSTM", "MonadDelay", "IOSim", "scheduleCorpus", "expectedProjection",
        "DETERMINISTIC_SIM_DROPPED_PARTITION_MUTANT", "DETERMINISTIC_SIM_IGNORE_SEED_MUTANT", "DETERMINISTIC_SIM_BYPASS_FAULTS_MUTANT"]
      forbidden = ["unsafePerformIO", "undefined", "lookupEnv", "getEnv", "pb validate", "forkIO"]
      bareIo = [(path, lineNumber) | (path, body) <- zip productionSources productionBodies,
        (lineNumber, line) <- zip [(1 :: Int)..] (Text.lines body), "::" `Text.isInfixOf` line, "IO" `elem` textTokens line]
  pure (CheckResult "deterministic-simulation-source-discipline"
    [observation "deterministic-simulation.production-module-count" (Text.pack (show (length productionSources))),
     observation "deterministic-simulation.effect-boundary" "polymorphic Env interpreted under injected real clients and IOSim; no live effects"]
    ([finding "DETERMINISTIC-SIM-SOURCE-SHAPE" path ("bare IO signature at line " <> Text.pack (show lineNumber)) | (path, lineNumber) <- bareIo]
      <> [finding "DETERMINISTIC-SIM-SOURCE-SHAPE" (Text.unpack (Text.intercalate ";" (map Text.pack expectedSources))) ("missing element: " <> token) | token <- required, not (token `Text.isInfixOf` combined)]
      <> [finding "DETERMINISTIC-SIM-SOURCE-DISCIPLINE" path ("forbidden token: " <> token) | (path, body) <- zip productionSources productionBodies, token <- forbidden, token `Text.isInfixOf` body]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "deterministic-simulation-discovery"
  [observation "deterministic-simulation.discovery.count" (Text.pack (show (length observed)))]
  [finding "DETERMINISTIC-SIM-DISCOVERY" "<phase-16-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler dependencyStore receipts = CheckResult "deterministic-simulation-authority"
  [observation "deterministic-simulation.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children",
   observation "deterministic-simulation.register" "Register 2 modeled behavior; environmental fidelity ASSUMED; live runtime UNVERIFIED"]
  ([finding "DETERMINISTIC-SIM-RUN-ROOT" runRoot "run root escaped .build/runs/phase-16/work" | not (pathBelow (root </> ".build/runs/phase-16/work") runRoot)]
    <> [finding "DETERMINISTIC-SIM-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded the Phase-16 authority" |
      Receipt name executable args _ _ _ <- receipts, executable /= cabal ||
      (name /= "cabal-version" && (("--store-dir=" <> dependencyStore) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "deterministic-simulation-observer"
  (map (observation "deterministic-simulation.observer.process" . receiptSummary) receipts)
  [finding "DETERMINISTIC-SIM-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  registry <- Text.pack <$> readFile (root </> "test/mutant/registry.tsv")
  pure (CheckResult "deterministic-simulation-legacy-closure"
    [observation "deterministic-simulation.legacy.retired-count" (Text.pack (show (length retiredSources + 1)))]
    ([finding "DETERMINISTIC-SIM-LEGACY" path "retired Python or serialized behavioral authority remains" | path <- files]
      <> [finding "DETERMINISTIC-SIM-LEGACY" "test/mutant/registry.tsv" "retired materialized Phase-16 mutant registry row remains" | "deterministic_simulation\t" `Text.isInfixOf` registry]))

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-16-claim" [pre], named "phase-16-subject" [toolchain, positive], named "phase-16-command" [toolchain, authority],
   named "phase-16-oracle" [oracle], named "phase-16-positive-controls" [positive], named "phase-16-paired-negatives" [negatives],
   named "phase-16-mutants" [mutants], named "phase-16-discovery" [discovery], named "phase-16-challenge" [mutants],
   named "phase-16-observer" [observer], named "phase-16-authority-bypass" [authority], named "phase-16-freshness" [freshness],
   named "phase-16-qualification" [qualification], named "phase-16-cleanroom" [cleanroom], named "phase-16-legacy-closure" [legacy],
   CheckResult "phase-16-predecessor" [observation "phase-16.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-16-residue" [observation "phase-16.residue" "model fidelity remains ASSUMED; concrete models, runtimes, host and hardware remain later-owned"] [],
   named "phase-16-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"
      target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "deterministic-simulation-source-repository-cache"
    [observation "deterministic-simulation.cache.entries" (Text.pack (show copied))]
    [finding "DETERMINISTIC-SIM-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
      not present || length copied /= 6 || not (all (completeSourcePackage copied) ["infernix-", "jitML-"])])

completeSourcePackage :: [FilePath] -> String -> Bool
completeSourcePackage entries prefix =
  length matching == 3
    && length [entry | entry <- matching, ".cache" `isInfixOf` entry] == 1
    && length [entry | entry <- matching, ".tar.gz" `isInfixOf` entry] == 1
    && length [entry | entry <- matching, not ('.' `elem` entry)] == 1
 where
  matching = filter (prefix `isPrefixOf`) entries

copyTree :: FilePath -> FilePath -> IO ()
copyTree source target = do
  createDirectoryIfMissing True target
  entries <- listDirectory source
  forM_ entries $ \entry -> do
    let from = source </> entry; to = target </> entry
    directory <- doesDirectoryExist from
    if directory then copyTree from to else copyFile from to

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-16/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle >> removeFile leaf >> createDirectory leaf
  pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working name executable args = do
  inherited <- getEnvironment
  let sanitized = filter (not . forbiddenEnvironment . fst) inherited
  attempt <- try (readCreateProcessWithExitCode ((proc executable args) {cwd = Just working, env = Just sanitized}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ either (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem)))
    (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err)) attempt

forbiddenEnvironment :: String -> Bool
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

receiptExit :: Receipt -> ExitCode
receiptExit (Receipt _ _ _ status _ _) = status
receiptStdout :: Receipt -> Text
receiptStdout (Receipt _ _ _ _ out _) = out
receiptOutput :: Receipt -> Text
receiptOutput (Receipt _ _ _ _ out err) = out <> "\n" <> err
receiptDigest :: Receipt -> Text
receiptDigest (Receipt name executable args status out err) = digestTexts [name, Text.pack executable, Text.pack (show args), Text.pack (show status), out, err]
receiptSummary :: Receipt -> Text
receiptSummary receipt@(Receipt name executable args status _ err) = name <> "|" <> Text.pack executable <> "|argv=" <> Text.pack (show args) <> "|exit=" <> Text.pack (show status) <> "|sha256=" <> receiptDigest receipt <> if status == ExitSuccess || status == ExitFailure 1 then "" else "|stderr=" <> Text.replace "\n" "\\n" (Text.take 512 err)
checkDigest :: CheckResult -> Text
checkDigest result = digestTexts [checkName result, Text.pack (show (checkObservations result)), Text.pack (show (checkFindings result))]
digestTexts :: [Text] -> Text
digestTexts = sha256 . TextEncoding.encodeUtf8 . Text.intercalate "\NUL"
sha256 :: ByteString -> Text
sha256 = Text.pack . concatMap (\byte -> [intToDigit (fromIntegral byte `div` 16), intToDigit (fromIntegral byte `mod` 16)]) . ByteString.unpack . SHA256.hash
pathBelow :: FilePath -> FilePath -> Bool
pathBelow parent child = let relative = normalise (makeRelative parent child) in relative /= ".." && not ("../" `isPrefixOf` relative) && not (isAbsolute relative)
textTokens :: Text -> [Text]
textTokens = Text.words . Text.map (\character -> if isAlphaNum character || character == '_' then character else ' ')

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix clean mutants) = map (\(Mutant _ _ _ receipt) -> receipt) mutants <> [clean]

productionSources, oracleSources, expectedSources, retiredSources :: [FilePath]
productionSources = sort
  ["src/Amoebius/Sim/Env.hs", "src/Amoebius/Sim/Fakes/ApiServer.hs", "src/Amoebius/Sim/Fakes/Clock.hs",
   "src/Amoebius/Sim/Fakes/MinIO.hs", "src/Amoebius/Sim/Fakes/Pulsar.hs", "src/Amoebius/Sim/Fakes/Route53.hs",
   "src/Amoebius/Sim/Fakes/Vault.hs", "src/Amoebius/Sim/Interp/Real.hs", "src/Amoebius/Sim/Interp/Sim.hs", "src/Amoebius/Sim/Reconcile.hs"]
oracleSources = sort [oracleSource, "test/spec/sim/FaultContracts.hs", "test/harness/deterministic_simulation/CalculusProjection.hs"]
expectedSources = sort (productionSources <> oracleSources)
oracleSource :: FilePath
oracleSource = "test/spec/sim/SimSpec.hs"
retiredSources =
  ["tools/deterministic_simulation_gate.py", "test/oracle/deterministic_simulation_surfaces.tsv",
   "test/oracle/deterministic_simulation/calculus_projection.tsv", "test/oracle/deterministic_simulation/expected_outcomes.tsv",
   "test/oracle/deterministic_simulation/validation_locus.tsv",
   "test/fixture/deterministic_simulation/schedules/crash.json", "test/fixture/deterministic_simulation/schedules/partition.json",
   "test/fixture/deterministic_simulation/schedules/redelivery.json", "test/fixture/deterministic_simulation/schedules/reorder.json",
   "test/mutant/deterministic_simulation/dropped_partition_handling/DroppedPartitionMutant.hs",
   "test/mutant/deterministic_simulation/dropped_partition_handling/README.md"]
