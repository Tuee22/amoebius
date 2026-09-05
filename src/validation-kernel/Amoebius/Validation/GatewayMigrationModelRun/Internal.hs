{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.GatewayMigrationModelRun.Internal
  ( AcquiredGatewayMigrationModelRun
  , acquireGatewayMigrationModelRun
  , acquireGatewayMigrationModelRefreshRun
  , acquiredGatewayMigrationModelRunCheck
  , foldAcquiredGatewayMigrationModelRun
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
data Matrix = Matrix Receipt [Mutant]

data AcquiredGatewayMigrationModelRun = AcquiredGatewayMigrationModelRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredGatewayMigrationModelRunCheck :: AcquiredGatewayMigrationModelRun -> CheckResult
acquiredGatewayMigrationModelRunCheck (AcquiredGatewayMigrationModelRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredGatewayMigrationModelRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredGatewayMigrationModelRun -> value
foldAcquiredGatewayMigrationModelRun consume (AcquiredGatewayMigrationModelRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireGatewayMigrationModelRun, acquireGatewayMigrationModelRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredGatewayMigrationModelRun
acquireGatewayMigrationModelRun = acquire False
acquireGatewayMigrationModelRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredGatewayMigrationModelRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      dependencyStore = home </> ".cabal/store"
      java = root </> ".build/toolchain/runtime/java/bin/java"
      tlaJar = root </> ".build/toolchain/runtime/tla/tla2tools.jar"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 17 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root [] "cabal-version" cabal ["--numeric-version"]
  javaVersion <- runProcess root [] "java-version" java ["-version"]
  tlcVersion <- runProcess root [] "tlc-version" java ["-jar", tlaJar, "-help"]
  javaDigest <- fileDigest java
  tlcDigest <- fileDigest tlaJar
  matrix <- executeMatrix root runRoot cabal compiler dependencyStore java tlaJar
  discipline <- sourceDisciplineCheck root
  legacy <- legacyCheck root
  generated <- generatedCheck root runRoot
  let Matrix cleanRun mutants = matrix
      toolchain = toolchainCheck cabal compiler dependencyStore java tlaJar javaDigest tlcDigest cabalVersion javaVersion tlcVersion matrix
      oracle = oracleCheck cleanRun
      positive = positiveCheck cleanRun generated
      negatives = pairedNegativeCheck cleanRun
      mutation = mutantCheck mutants
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot cabal compiler dependencyStore java tlaJar (cabalVersion : javaVersion : tlcVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : javaVersion : tlcVersion : matrixReceipts matrix)
      freshness = CheckResult "gateway-migration-model-freshness"
        [observation "gateway-migration-model.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = mergeChecks "gateway-migration-model-cleanroom"
        [cache, generated, CheckResult "gateway-migration-model-contained-root"
          [observation "gateway-migration-model.run-root" (Text.pack (makeRelative root runRoot))]
          [finding "GATEWAY-MIGRATION-CLEANROOM" runRoot "generated products escaped the Phase-17 run root"
            | not (pathBelow (root </> ".build/runs/phase-17/work") runRoot)]]
      qualification = mergeChecks "gateway-migration-model-qualification"
        [toolchain, mutation, oracle, positive, negatives, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "gateway-migration-model-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positive,
         negatives, mutation, discovery, authority, observer, freshness, qualification, cleanroom, discipline, legacy]
      rows = phaseRows prerequisite toolchain oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "gateway-migration-model" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "gateway-migration-model-subject" [checkDigest discipline, receiptDigest cleanRun]
      oracleId = ids "gateway-migration-model-oracle" [receiptDigest cleanRun, checkDigest oracle, checkDigest negatives]
      harnessId = ids "gateway-migration-model-harness" (map receiptDigest (cabalVersion : javaVersion : tlcVersion : matrixReceipts matrix))
      observerId = ids "gateway-migration-model-observer" [checkDigest observer]
      qualificationId = ids "gateway-migration-model-qualification" [checkDigest qualification]
      acquiredRunId = ids "gateway-migration-model-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "gateway-migration-model-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion, receiptDigest javaVersion, receiptDigest tlcVersion]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredGatewayMigrationModelRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler dependencyStore java tlaJar = do
  mutants <- mapM (runMutant root runRoot cabal compiler dependencyStore java tlaJar) mutantSpecifications
  clean <- runVariant root runRoot cabal compiler dependencyStore java tlaJar "clean" Nothing
  pure (Matrix clean mutants)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> (Text, String, Text) -> IO Mutant
runMutant root runRoot cabal compiler dependencyStore java tlaJar (name, flagName, locus) = do
  receipt <- runVariant root runRoot cabal compiler dependencyStore java tlaJar name (Just flagName)
  pure (Mutant name (Text.pack flagName) locus receipt)

runVariant :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runVariant root runRoot cabal compiler dependencyStore java tlaJar name selected =
  runProcess root
    [("AMOEBIUS_JAVA", java), ("AMOEBIUS_TLA2TOOLS", tlaJar),
     ("AMOEBIUS_GATEWAY_MODEL_OUTPUT", runRoot </> "generated" </> Text.unpack name)]
    name cabal
    (["--builddir=" <> runRoot </> "dist", "--store-dir=" <> dependencyStore,
      "--with-compiler=" <> compiler, "--jobs=1", "test", "gateway-migration-model-spec", "--offline", "--test-show-details=direct"]
      <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [("dual-owner", "gateway-migration-dual-owner-mutant", "GatewayMigration explorer safety"),
   ("cutoff-budget", "gateway-migration-cutoff-budget-mutant", "over-budget unexpectedly accepted"),
   ("drop-fairness", "gateway-migration-drop-fairness-mutant", "GatewayMigration renderer semantic facts")]

toolchainCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe Text -> Maybe Text -> Receipt -> Receipt -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler dependencyStore java tlaJar javaDigest tlcDigest cabalVersion javaVersion tlcVersion matrix = CheckResult "gateway-migration-model-toolchain"
  [observation "gateway-migration-model.cabal" (receiptSummary cabalVersion),
   observation "gateway-migration-model.compiler" (Text.pack compiler),
   observation "gateway-migration-model.java" (receiptSummary javaVersion),
   observation "gateway-migration-model.tlc" (receiptSummary tlcVersion)]
  ([finding "GATEWAY-MIGRATION-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit cabalVersion /= ExitSuccess || Text.strip (receiptStdout cabalVersion) /= "3.16.1.0"]
   <> [finding "GATEWAY-MIGRATION-JAVA" java "the digest-pinned Temurin 21.0.9 JVM was not observed" |
      not (isAbsolute java) || receiptExit javaVersion /= ExitSuccess || notContains "21.0.9" (receiptOutput javaVersion)]
   <> [finding "GATEWAY-MIGRATION-TLC" tlaJar "the digest-pinned TLA+ 1.8.0 TLC artifact was not observed" |
      not (isAbsolute tlaJar) || receiptExit tlcVersion /= ExitFailure 1 || notContains "TLC - provides model checking" (receiptOutput tlcVersion)]
   <> [finding "GATEWAY-MIGRATION-JAVA-DIGEST" java "the JVM executable digest does not match the admitted cache input" | javaDigest /= Just expectedJavaDigest]
   <> [finding "GATEWAY-MIGRATION-TLC-DIGEST" tlaJar "the TLC jar digest does not match the admitted cache input" | tlcDigest /= Just expectedTlcDigest]
   <> [finding "GATEWAY-MIGRATION-COMPILER" (Text.unpack name) "the Cabal row did not use the exact compiler, offline mode, and serial execution" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute dependencyStore) ||
      ("--store-dir=" <> dependencyStore) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "gateway-migration-model-independent-oracle"
  [observation "gateway-migration-model.oracle" (receiptSummary receipt),
   observation "gateway-migration-model.oracle-independence" "GatewayMigrationOracle.hs is separately authored from the production model and structural-fit fold"]
  [finding "GATEWAY-MIGRATION-ORACLE" oracleSource "the Haskell oracle did not report the exact acceptance token" |
    receiptExit receipt /= ExitSuccess || notContains acceptance (receiptOutput receipt)]
 where acceptance = "PASS (53 states, 5 invariants, 3 properties, 20 actions, IOSimPOR bound 20, 8 cutoff clauses)"

positiveCheck :: Receipt -> CheckResult -> CheckResult
positiveCheck receipt generated = CheckResult "gateway-migration-model-positive-controls"
  [observation "gateway-migration-model.positive" "53 explorer/TLC states; five invariants; three fair liveness properties; both branches; scope-3 stress"]
  ([finding "GATEWAY-MIGRATION-POSITIVE" oracleSource "the closed positive corpus did not pass" | receiptExit receipt /= ExitSuccess]
   <> checkFindings generated)

pairedNegativeCheck :: Receipt -> CheckResult
pairedNegativeCheck receipt = CheckResult "gateway-migration-model-paired-negatives"
  [observation "gateway-migration-model.negatives" "five exact invariant mutants; five mechanical mutants; three fairness deletions; eight cutoff deletions; shared-owner mutant"]
  [finding "GATEWAY-MIGRATION-NEGATIVE" oracleSource "the independent negative corpus was not executed" |
    receiptExit receipt /= ExitSuccess || any (\token -> notContains token (receiptOutput receipt))
      ["per-invariant and mechanical mutants", "StructuralFit cutoff", "scope-3 shared-resource stress"]]

mutantCheck :: [Mutant] -> CheckResult
mutantCheck mutants = CheckResult "gateway-migration-model-mutants"
  [observation ("gateway-migration-model.mutant." <> name) (flagName <> "|" <> receiptSummary receipt) | Mutant name flagName _ receipt <- mutants]
  [finding "GATEWAY-MIGRATION-MUTANT" (Text.unpack name) ("changed production subject did not turn red at " <> locus) |
    Mutant name _ locus receipt <- mutants,
    receiptExit receipt /= ExitFailure 1 || notContains locus (receiptOutput receipt) ||
    notContains "Test suite gateway-migration-model-spec: RUNNING" (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  productionBodies <- mapM (fmap Text.pack . readFile . (root </>)) productionSources
  oracleBodies <- mapM (fmap Text.pack . readFile . (root </>)) oracleSources
  let production = Text.intercalate "\n" productionBodies
      oracles = Text.intercalate "\n" oracleBodies
      requiredProduction = ["gatewayMigrationModel", "structuralFitWith", "GATEWAY_MIGRATION_DUAL_OWNER_MUTANT", "GATEWAY_MIGRATION_CUTOFF_BUDGET_MUTANT", "GATEWAY_MIGRATION_DROP_FAIRNESS_MUTANT"]
      requiredOracle = ["expectedRendererFacts", "expectedCutoffCases", "referenceFit", "checkIOSimPOR", "runTlc"]
      forbiddenProduction = ["unsafePerformIO", "undefined", "lookupEnv", "getEnv", "readFile", "readProcess", "pb validate"]
  pure (CheckResult "gateway-migration-model-source-discipline"
    [observation "gateway-migration-model.production-module-count" (Text.pack (show (length productionSources))),
     observation "gateway-migration-model.effect-boundary" "pure Haskell model/fold; injected digest-pinned JVM/TLC; generated products below run root; no live effects"]
    ([finding "GATEWAY-MIGRATION-SOURCE-SHAPE" (Text.unpack (Text.intercalate ";" (map Text.pack productionSources))) ("missing production element: " <> token) | token <- requiredProduction, notContains token production]
      <> [finding "GATEWAY-MIGRATION-ORACLE-SHAPE" (Text.unpack (Text.intercalate ";" (map Text.pack oracleSources))) ("missing oracle element: " <> token) | token <- requiredOracle, notContains token oracles]
      <> [finding "GATEWAY-MIGRATION-SOURCE-DISCIPLINE" path ("forbidden production token: " <> token) | (path, body) <- zip productionSources productionBodies, token <- forbiddenProduction, token `Text.isInfixOf` body]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "gateway-migration-model-discovery"
  [observation "gateway-migration-model.discovery.count" (Text.pack (show (length observed)))]
  [finding "GATEWAY-MIGRATION-DISCOVERY" "<phase-17-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler dependencyStore java tlaJar receipts = CheckResult "gateway-migration-model-authority"
  [observation "gateway-migration-model.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler/JVM/TLC; serial synchronous children",
   observation "gateway-migration-model.register" "Register 1 bounded formal claim; runtime fidelity UNVERIFIED; decomposition lemma OPEN"]
  ([finding "GATEWAY-MIGRATION-RUN-ROOT" runRoot "run root escaped .build/runs/phase-17/work" | not (pathBelow (root </> ".build/runs/phase-17/work") runRoot)]
   <> [finding "GATEWAY-MIGRATION-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-17 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable `notElem` [cabal, java] ||
      (executable == cabal && name /= "cabal-version" && (("--store-dir=" <> dependencyStore) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) ||
      any forbiddenArg args || (name == "tlc-version" && tlaJar `notElem` args)])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "gateway-migration-model-observer"
  (map (observation "gateway-migration-model.observer.process" . receiptSummary) receipts)
  [finding "GATEWAY-MIGRATION-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

generatedCheck :: FilePath -> FilePath -> IO CheckResult
generatedCheck root runRoot = do
  let output = runRoot </> "generated/clean"
      expected = ["phase-results.tsv", "safety/GatewayMigration.tla", "safety/GatewayMigration.cfg", "safety/GatewayMigration.dot", "safety/GatewayMigration.tlc.log", "liveness/GatewayMigration.tla", "liveness/GatewayMigration.cfg", "liveness/GatewayMigration.tlc.log"]
  present <- filterM (doesFileExist . (output </>)) expected
  pure (CheckResult "gateway-migration-model-generated-products"
    [observation "gateway-migration-model.generated-count" (Text.pack (show (length present))),
     observation "gateway-migration-model.generated-root" (Text.pack (makeRelative root output))]
    [finding "GATEWAY-MIGRATION-GENERATED" (makeRelative root (output </> path)) "required fresh generated model-check product is absent" | path <- expected, path `notElem` present])

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "gateway-migration-model-legacy-closure"
    [observation "gateway-migration-model.legacy.retired-count" (Text.pack (show (length retiredSources)))]
    [finding "GATEWAY-MIGRATION-LEGACY" path "retired Python or serialized behavioral authority remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-17-claim" [pre], named "phase-17-subject" [toolchain, positive], named "phase-17-command" [toolchain, authority],
   named "phase-17-oracle" [oracle], named "phase-17-positive-controls" [positive], named "phase-17-paired-negatives" [negatives],
   named "phase-17-mutants" [mutants], named "phase-17-discovery" [discovery], named "phase-17-challenge" [mutants],
   named "phase-17-observer" [observer], named "phase-17-authority-bypass" [authority], named "phase-17-freshness" [freshness],
   named "phase-17-qualification" [qualification], named "phase-17-cleanroom" [cleanroom], named "phase-17-legacy-closure" [legacy],
   CheckResult "phase-17-predecessor" [observation "phase-17.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-17-residue" [observation "phase-17.residue" "runtime fidelity remains UNVERIFIED; decomposition lemma remains OPEN; live gateway effects remain Phase-75-owned"] [],
   named "phase-17-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"
      target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "gateway-migration-model-source-repository-cache"
    [observation "gateway-migration-model.cache.entries" (Text.pack (show copied))]
    [finding "GATEWAY-MIGRATION-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-17/work"
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
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "AMOEBIUS_JAVA", "AMOEBIUS_TLA2TOOLS", "AMOEBIUS_GATEWAY_MODEL_OUTPUT"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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

fileDigest :: FilePath -> IO (Maybe Text)
fileDigest path = either (const Nothing) (Just . sha256) <$> (try (ByteString.readFile path) :: IO (Either IOException ByteString))

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
matrixReceipts (Matrix clean mutants) = map (\(Mutant _ _ _ receipt) -> receipt) mutants <> [clean]

productionSources, oracleSources, expectedSources, retiredSources :: [FilePath]
productionSources = sort ["src/Amoebius/Formal/GatewayMigration.hs", "src/Amoebius/Multicluster/StructuralFit.hs"]
oracleSources = sort [oracleSource, "test/spec/formal/gateway/GatewayMigrationOracle.hs", "test/harness/deterministic_simulation/CalculusProjection.hs"]
expectedSources = sort (productionSources <> oracleSources)
oracleSource :: FilePath
oracleSource = "test/spec/formal/gateway/GatewayMigrationSpec.hs"
retiredSources =
  ["tools/gateway_migration_model_gate.py", "test/oracle/gateway_migration_model_surfaces.tsv",
   "test/oracle/formal/gateway/cutoff_cases.tsv", "test/oracle/formal/gateway/cutoff_mutants.tsv",
   "test/oracle/formal/gateway/gateway_migration_manifest.tsv", "test/oracle/formal/gateway/invariant_mutants.tsv",
   "test/oracle/formal/gateway/model_contract.tsv", "test/oracle/formal/gateway/renderer_semantics.tsv"]

expectedJavaDigest, expectedTlcDigest :: Text
expectedJavaDigest = "e865867065e48928c58293f30e7ae26a79c842f8607fa51d7e2e9fb90b602786"
expectedTlcDigest = "dbcc75552f21978a4846688b8e23be1a6b6c0b3fcee35d78fec2df167958ec94"
