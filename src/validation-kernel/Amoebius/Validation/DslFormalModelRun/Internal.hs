{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.DslFormalModelRun.Internal
  ( AcquiredDslFormalModelRun
  , acquireDslFormalModelRun
  , acquireDslFormalModelRefreshRun
  , acquiredDslFormalModelRunCheck
  , foldAcquiredDslFormalModelRun
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

data AcquiredDslFormalModelRun = AcquiredDslFormalModelRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredDslFormalModelRunCheck :: AcquiredDslFormalModelRun -> CheckResult
acquiredDslFormalModelRunCheck (AcquiredDslFormalModelRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredDslFormalModelRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredDslFormalModelRun -> value
foldAcquiredDslFormalModelRun consume (AcquiredDslFormalModelRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireDslFormalModelRun, acquireDslFormalModelRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredDslFormalModelRun
acquireDslFormalModelRun = acquire False
acquireDslFormalModelRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredDslFormalModelRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      dependencyStore = home </> ".cabal/store"
      java = root </> ".build/toolchain/runtime/java/bin/java"
      tlaJar = root </> ".build/toolchain/runtime/tla/tla2tools.jar"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 18 acquired
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
      freshness = CheckResult "dsl-formal-model-freshness"
        [observation "dsl-formal-model.fresh-build-root" (Text.pack (makeRelative root runRoot))] []
      cleanroom = mergeChecks "dsl-formal-model-cleanroom"
        [cache, generated, CheckResult "dsl-formal-model-contained-root"
          [observation "dsl-formal-model.run-root" (Text.pack (makeRelative root runRoot))]
          [finding "DSL-FORMAL-CLEANROOM" runRoot "generated products escaped the Phase-18 run root"
            | not (pathBelow (root </> ".build/runs/phase-18/work") runRoot)]]
      qualification = mergeChecks "dsl-formal-model-qualification"
        [toolchain, mutation, oracle, positive, negatives, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "dsl-formal-model-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positive,
         negatives, mutation, discovery, authority, observer, freshness, qualification, cleanroom, discipline, legacy]
      rows = phaseRows prerequisite toolchain oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "dsl-formal-model" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "dsl-formal-model-subject" [checkDigest discipline, receiptDigest cleanRun]
      oracleId = ids "dsl-formal-model-oracle" [receiptDigest cleanRun, checkDigest oracle, checkDigest negatives]
      harnessId = ids "dsl-formal-model-harness" (map receiptDigest (cabalVersion : javaVersion : tlcVersion : matrixReceipts matrix))
      observerId = ids "dsl-formal-model-observer" [checkDigest observer]
      qualificationId = ids "dsl-formal-model-qualification" [checkDigest qualification]
      acquiredRunId = ids "dsl-formal-model-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "dsl-formal-model-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion, receiptDigest javaVersion, receiptDigest tlcVersion]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredDslFormalModelRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
     ("AMOEBIUS_DSL_FORMAL_MODEL_OUTPUT", runRoot </> "generated" </> Text.unpack name)]
    name cabal
    (["--builddir=" <> runRoot </> "dist", "--store-dir=" <> dependencyStore,
      "--with-compiler=" <> compiler, "--jobs=1", "test", "dsl-formal-model-spec", "--offline", "--test-show-details=direct"]
      <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [("projection-count", "dsl-formal-projection-count-mutant", "DslProjection explorer safety"),
   ("token-reuse", "dsl-formal-token-reuse-mutant", "SnapshotToken state count"),
   ("unreachable-delete", "dsl-formal-reconcile-unreachable-mutant", "ReconcileProtocol actions")]

toolchainCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Maybe Text -> Maybe Text -> Receipt -> Receipt -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler dependencyStore java tlaJar javaDigest tlcDigest cabalVersion javaVersion tlcVersion matrix = CheckResult "dsl-formal-model-toolchain"
  [observation "dsl-formal-model.cabal" (receiptSummary cabalVersion),
   observation "dsl-formal-model.compiler" (Text.pack compiler),
   observation "dsl-formal-model.java" (receiptSummary javaVersion),
   observation "dsl-formal-model.tlc" (receiptSummary tlcVersion)]
  ([finding "DSL-FORMAL-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit cabalVersion /= ExitSuccess || Text.strip (receiptStdout cabalVersion) /= "3.16.1.0"]
   <> [finding "DSL-FORMAL-JAVA" java "the digest-pinned Temurin 21.0.9 JVM was not observed" |
      not (isAbsolute java) || receiptExit javaVersion /= ExitSuccess || notContains "21.0.9" (receiptOutput javaVersion)]
   <> [finding "DSL-FORMAL-TLC" tlaJar "the digest-pinned TLA+ 1.8.0 artifact was not observed" |
      not (isAbsolute tlaJar) || receiptExit tlcVersion /= ExitFailure 1 || notContains "TLC - provides model checking" (receiptOutput tlcVersion)]
   <> [finding "DSL-FORMAL-JAVA-DIGEST" java "the JVM digest differs from the admitted input" | javaDigest /= Just expectedJavaDigest]
   <> [finding "DSL-FORMAL-TLC-DIGEST" tlaJar "the TLC digest differs from the admitted input" | tlcDigest /= Just expectedTlcDigest]
   <> [finding "DSL-FORMAL-COMPILER" (Text.unpack name) "the Cabal row did not use the exact compiler, offline mode, and serial execution" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute dependencyStore) ||
      ("--store-dir=" <> dependencyStore) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck receipt = CheckResult "dsl-formal-model-independent-oracle"
  [observation "dsl-formal-model.oracle" (receiptSummary receipt),
   observation "dsl-formal-model.oracle-independence" "DslFormalModelOracle.hs is separately authored from the production model and projections"]
  [finding "DSL-FORMAL-ORACLE" oracleSource "the Haskell oracle did not report the exact acceptance token" |
    receiptExit receipt /= ExitSuccess || notContains acceptance (receiptOutput receipt)]
 where acceptance = "PASS (6 models, 18 states, 8 invariants, 4 properties, 6561 capacity cases)"

positiveCheck :: Receipt -> CheckResult -> CheckResult
positiveCheck receipt generated = CheckResult "dsl-formal-model-positive-controls"
  [observation "dsl-formal-model.positive" "six model contracts; 18 states; five explorer/TLC agreements; 6561 capacity cases; calculus and protocol projections"]
  ([finding "DSL-FORMAL-POSITIVE" oracleSource "the closed positive corpus did not pass" | receiptExit receipt /= ExitSuccess]
   <> checkFindings generated)

pairedNegativeCheck :: Receipt -> CheckResult
pairedNegativeCheck receipt = CheckResult "dsl-formal-model-paired-negatives"
  [observation "dsl-formal-model.negatives" "eight exact safety mutants and four fairness deletions; capacity admitted/overcommit pairs; one-use token and unreachable/present pairs"]
  [finding "DSL-FORMAL-NEGATIVE" oracleSource "the independent negative corpus was not executed" |
    receiptExit receipt /= ExitSuccess || any (\token -> notContains token (receiptOutput receipt))
      ["actual DSL projections", "exact safety and fairness mutants"]]

mutantCheck :: [Mutant] -> CheckResult
mutantCheck mutants = CheckResult "dsl-formal-model-mutants"
  [observation ("dsl-formal-model.mutant." <> name) (flagName <> "|" <> receiptSummary receipt) | Mutant name flagName _ receipt <- mutants]
  [finding "DSL-FORMAL-MUTANT" (Text.unpack name) ("changed production subject did not turn red at " <> locus) |
    Mutant name _ locus receipt <- mutants,
    receiptExit receipt /= ExitFailure 1 || notContains locus (receiptOutput receipt) ||
    notContains "Test suite dsl-formal-model-spec: RUNNING" (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  productionBodies <- mapM (fmap Text.pack . readFile . (root </>)) productionSources
  oracleBodies <- mapM (fmap Text.pack . readFile . (root </>)) oracleSources
  let production = Text.intercalate "\n" productionBodies
      oracles = Text.intercalate "\n" oracleBodies
      requiredProduction = ["dslModels", "fits", "planLeaseAction", "reserveCandidate", "RefuseOnUnreachable", "DSL_FORMAL_PROJECTION_COUNT_MUTANT", "DSL_FORMAL_TOKEN_REUSE_MUTANT", "DSL_FORMAL_RECONCILE_UNREACHABLE_MUTANT"]
      requiredOracle = ["expectedModelContracts", "expectedCapacityCaseCount", "expectedCalculusFacts", "expectedMutationCatalogue", "referenceCalculusModel", "runTlc"]
      forbiddenProduction = ["unsafePerformIO", "undefined", "lookupEnv", "getEnv", "readFile", "readProcess", "pb validate"]
  pure (CheckResult "dsl-formal-model-source-discipline"
    [observation "dsl-formal-model.production-module-count" (Text.pack (show (length productionSources))),
     observation "dsl-formal-model.effect-boundary" "pure model/capacity decisions and injected in-memory protocol roots; generated TLC products below run root; no live effects"]
    ([finding "DSL-FORMAL-SOURCE-SHAPE" (Text.unpack (Text.intercalate ";" (map Text.pack productionSources))) ("missing production element: " <> token) | token <- requiredProduction, notContains token production]
      <> [finding "DSL-FORMAL-ORACLE-SHAPE" (Text.unpack (Text.intercalate ";" (map Text.pack oracleSources))) ("missing oracle element: " <> token) | token <- requiredOracle, notContains token oracles]
      <> [finding "DSL-FORMAL-SOURCE-DISCIPLINE" path ("forbidden production token: " <> token) | (path, body) <- zip productionSources productionBodies, token <- forbiddenProduction, token `Text.isInfixOf` body]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "dsl-formal-model-discovery"
  [observation "dsl-formal-model.discovery.count" (Text.pack (show (length observed)))]
  [finding "DSL-FORMAL-DISCOVERY" "<phase-18-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler dependencyStore java tlaJar receipts = CheckResult "dsl-formal-model-authority"
  [observation "dsl-formal-model.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler/JVM/TLC; serial synchronous children",
   observation "dsl-formal-model.register" "Register 1 bounded formal claim; runtime/effect fidelity UNVERIFIED"]
  ([finding "DSL-FORMAL-RUN-ROOT" runRoot "run root escaped .build/runs/phase-18/work" | not (pathBelow (root </> ".build/runs/phase-18/work") runRoot)]
   <> [finding "DSL-FORMAL-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-18 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable `notElem` [cabal, java] ||
      (executable == cabal && name /= "cabal-version" && (("--store-dir=" <> dependencyStore) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) ||
      any forbiddenArg args || (name == "tlc-version" && tlaJar `notElem` args)])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "dsl-formal-model-observer"
  (map (observation "dsl-formal-model.observer.process" . receiptSummary) receipts)
  [finding "DSL-FORMAL-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

generatedCheck :: FilePath -> FilePath -> IO CheckResult
generatedCheck root runRoot = do
  let output = runRoot </> "generated/clean"
      correct = [("correct-" <> model, model, True) | model <- transitionModels]
      safety = [("mutant-" <> name, model, False) | (name, model) <- safetyMutants]
      fairness = [("fairness-drop-" <> model, model, False) | model <- fairnessModels]
      files (directory, model, dot) =
        [directory </> model <> ".tla", directory </> model <> ".cfg", directory </> model <> ".tlc.log"]
          <> [directory </> model <> ".dot" | dot]
      expected = "phase-results.tsv" : concatMap files (correct <> safety <> fairness)
  present <- filterM (doesFileExist . (output </>)) expected
  pure (CheckResult "dsl-formal-model-generated-products"
    [observation "dsl-formal-model.generated-count" (Text.pack (show (length present))),
     observation "dsl-formal-model.generated-root" (Text.pack (makeRelative root output))]
    [finding "DSL-FORMAL-GENERATED" (makeRelative root (output </> path)) "required fresh generated model-check product is absent" | path <- expected, path `notElem` present])

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "dsl-formal-model-legacy-closure"
    [observation "dsl-formal-model.legacy.retired-count" (Text.pack (show (length retiredSources)))]
    [finding "DSL-FORMAL-LEGACY" path "retired Python or serialized behavioral authority remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-18-claim" [pre], named "phase-18-subject" [toolchain, positive], named "phase-18-command" [toolchain, authority],
   named "phase-18-oracle" [oracle], named "phase-18-positive-controls" [positive], named "phase-18-paired-negatives" [negatives],
   named "phase-18-mutants" [mutants], named "phase-18-discovery" [discovery], named "phase-18-challenge" [mutants],
   named "phase-18-observer" [observer], named "phase-18-authority-bypass" [authority], named "phase-18-freshness" [freshness],
   named "phase-18-qualification" [qualification], named "phase-18-cleanroom" [cleanroom], named "phase-18-legacy-closure" [legacy],
   CheckResult "phase-18-predecessor" [observation "phase-18.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-18-residue" [observation "phase-18.residue" "runtime and effectful correspondence remain UNVERIFIED; decoder/render/chain projections remain later-phase-owned"] [],
   named "phase-18-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"
      target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "dsl-formal-model-source-repository-cache"
    [observation "dsl-formal-model.cache.entries" (Text.pack (show copied))]
    [finding "DSL-FORMAL-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-18/work"
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
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "AMOEBIUS_JAVA", "AMOEBIUS_TLA2TOOLS", "AMOEBIUS_DSL_FORMAL_MODEL_OUTPUT"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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
productionSources = sort
  ["src/Amoebius/Formal/Dsl/Models.hs", "src/capacity-topology/Amoebius/Capacity/Fold.hs",
   "src/Amoebius/Manifest/Authority.hs", "src/Amoebius/Scheduler/Reservation.hs",
   "src/Amoebius/Cluster/NodeProvisioner.hs"]
oracleSources = sort [oracleSource, "test/spec/formal/dsl/DslFormalModelOracle.hs", "test/harness/deterministic_simulation/CalculusProjection.hs"]
expectedSources = sort (productionSources <> oracleSources)
oracleSource :: FilePath
oracleSource = "test/spec/formal/dsl/DslFormalModelSpec.hs"
retiredSources =
  ["tools/dsl_formal_model_gate.py", "test/oracle/dsl_formal_model_surfaces.tsv",
   "test/oracle/formal/dsl/implementation_projection.tsv", "test/oracle/formal/dsl/model_contract.tsv",
   "test/oracle/formal/dsl/mutation_catalog.tsv"]

transitionModels, fairnessModels :: [String]
transitionModels = ["DslProjection", "SnapshotToken", "ReservationProtocol", "LeaseAuthority", "ReconcileProtocol"]
fairnessModels = ["SnapshotToken", "ReservationProtocol", "LeaseAuthority", "ReconcileProtocol"]
safetyMutants :: [(String, String)]
safetyMutants =
  [("projection-count-drift", "DslProjection"), ("token-reuse", "SnapshotToken"),
   ("reservation-double-debit", "ReservationProtocol"), ("lease-second-holder", "LeaseAuthority"),
   ("reconcile-second-holder", "ReconcileProtocol"), ("reconcile-delete-unreachable", "ReconcileProtocol"),
   ("reconcile-delete-before-ready", "ReconcileProtocol"), ("reconcile-post-convergence-write", "ReconcileProtocol")]

expectedJavaDigest, expectedTlcDigest :: Text
expectedJavaDigest = "e865867065e48928c58293f30e7ae26a79c842f8607fa51d7e2e9fb90b602786"
expectedTlcDigest = "dbcc75552f21978a4846688b8e23be1a6b6c0b3fcee35d78fec2df167958ec94"
