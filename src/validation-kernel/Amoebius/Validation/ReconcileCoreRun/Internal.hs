{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ReconcileCoreRun.Internal
  ( AcquiredReconcileCoreRun
  , acquireReconcileCoreRun
  , acquireReconcileCoreRefreshRun
  , acquiredReconcileCoreRunCheck
  , foldAcquiredReconcileCoreRun
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
import Data.Char (intToDigit)
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
data Matrix = Matrix Receipt [Mutant] Receipt Receipt

data AcquiredReconcileCoreRun = AcquiredReconcileCoreRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredReconcileCoreRunCheck :: AcquiredReconcileCoreRun -> CheckResult
acquiredReconcileCoreRunCheck (AcquiredReconcileCoreRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredReconcileCoreRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredReconcileCoreRun -> value
foldAcquiredReconcileCoreRun consume (AcquiredReconcileCoreRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireReconcileCoreRun, acquireReconcileCoreRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredReconcileCoreRun
acquireReconcileCoreRun = acquire False
acquireReconcileCoreRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredReconcileCoreRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      dependencyStore = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 19 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root [] "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler dependencyStore
  discipline <- sourceDisciplineCheck root
  discovery <- pure (discoveryCheck acquired)
  legacy <- legacyCheck root
  generated <- generatedCheck root runRoot
  let Matrix clean mutants legalDelete illegalDelete = matrix
      toolchain = toolchainCheck cabal compiler dependencyStore cabalVersion matrix
      oracle = oracleCheck clean
      positive = positiveCheck clean legalDelete generated
      negatives = negativeCheck clean illegalDelete
      mutation = mutantCheck mutants illegalDelete
      authority = authorityCheck root runRoot cabal compiler dependencyStore (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot clean
      cleanroom = mergeChecks "reconcile-core-cleanroom" [cache, generated, freshness]
      qualification = mergeChecks "reconcile-core-qualification"
        [toolchain, oracle, positive, negatives, mutation, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "reconcile-core-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positive,
         negatives, mutation, discovery, authority, observer, freshness, qualification, cleanroom, discipline, legacy]
      rows = phaseRows prerequisite toolchain oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "reconcile-core" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "reconcile-core-subject" [checkDigest discipline, receiptDigest clean]
      oracleId = ids "reconcile-core-oracle" [receiptDigest clean, checkDigest oracle, checkDigest negatives]
      harnessId = ids "reconcile-core-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "reconcile-core-observer" [checkDigest observer]
      qualificationId = ids "reconcile-core-qualification" [checkDigest qualification]
      acquiredRunId = ids "reconcile-core-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "reconcile-core-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredReconcileCoreRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM (runMutant root runRoot cabal compiler store) mutantSpecifications
  illegalDelete <- runDelete root runRoot cabal compiler store "delete-unreachable-witness" True
  legalDelete <- runDelete root runRoot cabal compiler store "delete-legal-twin" False
  clean <- runSimulation root runRoot cabal compiler store "clean" Nothing
  pure (Matrix clean mutants legalDelete illegalDelete)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> (Text, String, Text) -> IO Mutant
runMutant root runRoot cabal compiler store (name, flagName, locus) = do
  receipt <- runSimulation root runRoot cabal compiler store name (Just flagName)
  pure (Mutant name (Text.pack flagName) locus receipt)

runSimulation :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runSimulation root runRoot cabal compiler store name selected =
  runProcess root [("AMOEBIUS_RECONCILE_CORE_OUTPUT", runRoot </> "generated" </> Text.unpack name)] name cabal
    (["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler,
      "--jobs=1", "test", "reconcile-core-simulation-spec", "--offline", "--test-show-details=direct"]
      <> maybe [] (pure . ("-f" <>)) selected)

runDelete :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Bool -> IO Receipt
runDelete root runRoot cabal compiler store name mutant =
  runProcess root [] name cabal
    (["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler,
      "--jobs=1", "test", "reconcile-core-delete-witness", "--offline", "--test-show-details=direct"]
      <> ["-freconcile-core-delete-unreachable-mutant" | mutant])

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [ ("fixed-point-reemit", "reconcile-core-fixed-point-reemit-mutant", "FixedPoint")
  , ("oscillating-apply", "reconcile-core-oscillating-apply-mutant", "Convergence")
  , ("token-guard-removed", "reconcile-core-token-guard-removed-mutant", "NoTokenReuse")
  , ("reservation-crash-drop", "reconcile-core-reservation-crash-drop-mutant", "BoundRetainedAfterCrash")
  ]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store cabalVersion matrix = CheckResult "reconcile-core-toolchain"
  [observation "reconcile-core.cabal" (receiptSummary cabalVersion), observation "reconcile-core.compiler" (Text.pack compiler)]
  ([finding "RECONCILE-CORE-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit cabalVersion /= ExitSuccess || Text.strip (receiptStdout cabalVersion) /= "3.16.1.0"]
   <> [finding "RECONCILE-CORE-COMPILER" (Text.unpack name) "the Cabal row did not use the exact compiler, offline mode, and serial execution" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "reconcile-core-independent-oracle"
  [observation "reconcile-core.oracle" (receiptSummary receipt),
   observation "reconcile-core.oracle-independence" "ReconcileCoreOracle.hs and ReferencePlanner.hs import no production reconcile module"]
  [finding "RECONCILE-CORE-ORACLE" oracleSource "the independent Haskell oracle did not report the exact acceptance token" |
    receiptExit receipt /= ExitSuccess || notContains acceptance (receiptOutput receipt)]
 where acceptance = "PASS (9 core cases, 4 schedules, 4 IOSimPOR, 2 protocols, 4 formal links)"

positiveCheck :: Receipt -> Receipt -> CheckResult -> CheckResult
positiveCheck clean legal generated = CheckResult "reconcile-core-positive-controls"
  [observation "reconcile-core.positive" "nine core pairs; two fixed points; four schedules and POR replays; token/reservation protocols; four formal links; legal delete twin"]
  ([finding "RECONCILE-CORE-POSITIVE" oracleSource "the closed positive corpus did not pass" | receiptExit clean /= ExitSuccess]
   <> [finding "RECONCILE-CORE-DELETE-TWIN" deleteSource "the present-observation legal twin did not compile and run" | receiptExit legal /= ExitSuccess]
   <> checkFindings generated)

negativeCheck :: Receipt -> Receipt -> CheckResult
negativeCheck clean illegal = CheckResult "reconcile-core-paired-negatives"
  [observation "reconcile-core.negatives" "present/unreachable delete witness; reachable/unreachable observations; same/changed seed; token first/reuse; reservation present/crash-cut"]
  ([finding "RECONCILE-CORE-NEGATIVE" oracleSource "the independent paired-negative corpus was not executed" |
      receiptExit clean /= ExitSuccess]
   <> [finding "RECONCILE-CORE-DELETE-MUTATION" deleteSource "the weakened production type did not admit the unreachable delete witness" |
      receiptExit illegal /= ExitSuccess || notContains "UnreachableObservation" (receiptOutput illegal)])

mutantCheck :: [Mutant] -> Receipt -> CheckResult
mutantCheck mutants illegal = CheckResult "reconcile-core-mutants"
  ([observation ("reconcile-core.mutant." <> name) (flagName <> "|" <> receiptSummary receipt) | Mutant name flagName _ receipt <- mutants]
    <> [observation "reconcile-core.mutant.delete-unreachable-witness" (receiptSummary illegal)])
  ([finding "RECONCILE-CORE-MUTANT" (Text.unpack name) ("changed production subject did not turn red at " <> locus) |
      Mutant name _ locus receipt <- mutants,
      receiptExit receipt /= ExitFailure 1 || notContains locus (receiptOutput receipt) ||
      notContains "Test suite reconcile-core-simulation-spec: RUNNING" (receiptOutput receipt)]
   <> [finding "RECONCILE-CORE-MUTANT" "delete-unreachable-witness" "the changed production type did not expose DeleteRequiresPresentWitness" |
      receiptExit illegal /= ExitSuccess || notContains "UnreachableObservation" (receiptOutput illegal)])

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.intercalate "\n" <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
  oracles <- Text.intercalate "\n" <$> mapM (fmap Text.pack . readFile . (root </>)) oracleSources
  let requiredProduction = ["planReconcile", "simulateReconcile", "ledgerOnlyAbsentRecovery",
        "RECONCILE_CORE_FIXED_POINT_REEMIT_MUTANT", "RECONCILE_CORE_OSCILLATING_APPLY_MUTANT",
        "RECONCILE_CORE_TOKEN_GUARD_REMOVED_MUTANT", "RECONCILE_CORE_RESERVATION_CRASH_DROP_MUTANT",
        "RECONCILE_CORE_DELETE_UNREACHABLE_MUTANT"]
      requiredOracle = ["coreCases", "scheduleContracts", "formalCorrespondence", "referencePlan", "checkIOSimPOR"]
  pure (CheckResult "reconcile-core-source-discipline"
    [observation "reconcile-core.production-module-count" (Text.pack (show (length productionSources))),
     observation "reconcile-core.effect-boundary" "pure typed core and io-sim modeled STM/timer boundary; no host, network, service, or hardware effects"]
    ([finding "RECONCILE-CORE-SOURCE-SHAPE" "<phase-19-production>" ("missing production element: " <> token) | token <- requiredProduction, notContains token production]
      <> [finding "RECONCILE-CORE-ORACLE-SHAPE" "<phase-19-oracle>" ("missing oracle element: " <> token) | token <- requiredOracle, notContains token oracles]
      <> [finding "RECONCILE-CORE-SOURCE-DISCIPLINE" "<phase-19-production>" ("forbidden production token: " <> token) |
          token <- ["unsafePerformIO", "undefined", "pb validate", "System.Process", "Network.HTTP"], notContains token production == False]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "reconcile-core-discovery"
  [observation "reconcile-core.discovery.count" (Text.pack (show (length observed)))]
  [finding "RECONCILE-CORE-DISCOVERY" "<phase-19-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "reconcile-core-authority"
  [observation "reconcile-core.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children",
   observation "reconcile-core.register" "Register 2 modeled boundary claim; runtime fidelity UNVERIFIED"]
  ([finding "RECONCILE-CORE-RUN-ROOT" runRoot "run root escaped .build/runs/phase-19/work" | not (pathBelow (root </> ".build/runs/phase-19/work") runRoot)]
   <> [finding "RECONCILE-CORE-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-19 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "reconcile-core-observer"
  (map (observation "reconcile-core.observer.process" . receiptSummary) receipts)
  [finding "RECONCILE-CORE-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "reconcile-core-freshness"
  [observation "reconcile-core.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "RECONCILE-CORE-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-19/work") runRoot)]

generatedCheck :: FilePath -> FilePath -> IO CheckResult
generatedCheck root runRoot = do
  let path = runRoot </> "generated/clean/phase-results.tsv"
  present <- doesFileExist path
  pure (CheckResult "reconcile-core-generated-products"
    [ observation "reconcile-core.generated-count" (if present then "1" else "0")
    , observation "reconcile-core.generated-root" (Text.pack (makeRelative root (runRoot </> "generated/clean")))
    ]
    [finding "RECONCILE-CORE-GENERATED" (makeRelative root path) "the fresh generated result is absent" | not present])

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "reconcile-core-legacy-closure"
    [observation "reconcile-core.legacy.retired-count" (Text.pack (show (length retiredSources)))]
    [finding "RECONCILE-CORE-LEGACY" path "retired serialized behavioral authority or test-local mutant remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-19-claim" [pre], named "phase-19-subject" [toolchain, positive], named "phase-19-command" [toolchain, authority],
   named "phase-19-oracle" [oracle], named "phase-19-positive-controls" [positive], named "phase-19-paired-negatives" [negatives],
   named "phase-19-mutants" [mutants], named "phase-19-discovery" [discovery], named "phase-19-challenge" [mutants],
   named "phase-19-observer" [observer], named "phase-19-authority-bypass" [authority], named "phase-19-freshness" [freshness],
   named "phase-19-qualification" [qualification], named "phase-19-cleanroom" [cleanroom], named "phase-19-legacy-closure" [legacy],
   CheckResult "phase-19-predecessor" [observation "phase-19.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-19-residue" [observation "phase-19.residue" "modeled environment fidelity is ASSUMED; effectful runtime, host, service, cluster, and hardware correspondence remain UNVERIFIED"] [],
   named "phase-19-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "reconcile-core-source-repository-cache" [observation "reconcile-core.cache.entries" (Text.pack (show copied))]
    [finding "RECONCILE-CORE-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
      not present || length copied /= 6 || not (all (completeSourcePackage copied) ["infernix-", "jitML-"])])

completeSourcePackage :: [FilePath] -> String -> Bool
completeSourcePackage entries prefix = length matching == 3 && length (filter (isInfixOf ".cache") matching) == 1 && length (filter (isInfixOf ".tar.gz") matching) == 1 && length [entry | entry <- matching, not ('.' `elem` entry)] == 1
 where matching = filter (prefix `isPrefixOf`) entries

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
  let parent = root </> ".build/runs/phase-19/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle >> removeFile leaf >> createDirectory leaf
  pure leaf

runProcess :: FilePath -> [(String, String)] -> Text -> FilePath -> [String] -> IO Receipt
runProcess working additions name executable args = do
  inherited <- getEnvironment
  let sanitized = filter (not . forbiddenEnvironment . fst) inherited
      environment = additions <> filter ((`notElem` map fst additions) . fst) sanitized
  attempt <- try (readCreateProcessWithExitCode ((proc executable args) {cwd = Just working, env = Just environment}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ either (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem)))
    (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err)) attempt

forbiddenEnvironment :: String -> Bool
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "AMOEBIUS_RECONCILE_CORE_OUTPUT"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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
notContains :: Text -> Text -> Bool
notContains needle haystack = not (needle `Text.isInfixOf` haystack)
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix clean mutants legal illegal) = map (\(Mutant _ _ _ receipt) -> receipt) mutants <> [illegal, legal, clean]

productionSources, oracleSources, expectedSources, retiredSources :: [FilePath]
productionSources = sort ["src/reconcile-core/Amoebius/Reconcile/Core.hs", "src/reconcile-core/Amoebius/Reconcile/Sim.hs", "src/execution-accelerator-folds/Amoebius/Capacity/Scheduler.hs"]
oracleSources = sort ["test/spec/reconcile/ReconcileCoreSimulationSpec.hs", "test/spec/reconcile/ReconcileCoreOracle.hs", "test/harness/reconcile_core/ReferencePlanner.hs", "test/negative/compile_fail/reconcile_core/DeleteWitnessCompile.hs"]
expectedSources = sort (productionSources <> oracleSources)
retiredSources =
  [ "test/mutant/reconcile_core/ReconcileCoreMutants.hs"
  , "test/oracle/reconcile_core/core_cases.tsv"
  , "test/oracle/reconcile_core/formal_correspondence.tsv"
  , "test/oracle/reconcile_core/mutation_catalog.tsv"
  , "test/oracle/reconcile_core/schedule_outcomes.tsv"
  , "test/oracle/reconcile_core_simulation_surfaces.tsv"
  , "test/fixture/reconcile_core/schedules/baseline.json"
  , "test/fixture/reconcile_core/schedules/crash.json"
  , "test/fixture/reconcile_core/schedules/duplicate.json"
  , "test/fixture/reconcile_core/schedules/stale.json"
  ]

oracleSource, deleteSource :: FilePath
oracleSource = "test/spec/reconcile/ReconcileCoreOracle.hs"
deleteSource = "test/negative/compile_fail/reconcile_core/DeleteWitnessCompile.hs"
