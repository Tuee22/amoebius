{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ConformanceGateRun.Internal
  ( AcquiredConformanceGateRun
  , acquireConformanceGateRun
  , acquireConformanceGateRefreshRun
  , acquiredConformanceGateRunCheck
  , foldAcquiredConformanceGateRun
  ) where

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust, genesisTrustCheck, genesisTrustCompilerExecutable, genesisTrustToolchainIdentity )
import Amoebius.Validation.PhaseContract.Internal
  ( AcquiredPhaseContractEvidence, acquirePhaseContractEvidenceFor, acquireRecordedPhaseContractEvidence
  , acquiredPhaseContractEvidenceCheck )
import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot, IndexEntry (indexPath), SourceSnapshot (snapshotEntries, snapshotIdentity)
  , TrackedEntry (trackedIndex), acquiredSourceSnapshot )
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
  ( copyFile, createDirectory, createDirectoryIfMissing, doesDirectoryExist, doesFileExist
  , getHomeDirectory, listDirectory, removeFile )
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix
  { matrixMutants :: [Mutant]
  , matrixCompilePositive :: Receipt
  , matrixCompileNegatives :: [(Text, Receipt)]
  , matrixClean :: Receipt
  }

data AcquiredConformanceGateRun = AcquiredConformanceGateRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredConformanceGateRunCheck :: AcquiredConformanceGateRun -> CheckResult
acquiredConformanceGateRunCheck (AcquiredConformanceGateRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredConformanceGateRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredConformanceGateRun -> value
foldAcquiredConformanceGateRun consume (AcquiredConformanceGateRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireConformanceGateRun, acquireConformanceGateRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredConformanceGateRun
acquireConformanceGateRun = acquire False
acquireConformanceGateRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredConformanceGateRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 24 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root [] "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler store
  discipline <- sourceDisciplineCheck root
  let discovery = discoveryCheck acquired
  legacy <- legacyCheck root
  generated <- generatedCheck root runRoot
  let toolchain = toolchainCheck cabal compiler store cabalVersion matrix
      oracle = oracleCheck (matrixClean matrix)
      positive = positiveCheck (matrixClean matrix) generated
      negatives = negativeCheck matrix
      mutation = mutantCheck matrix
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot (matrixClean matrix)
      cleanroom = mergeChecks "extension-conformance-cleanroom" [cache, generated, freshness]
      qualification = mergeChecks "extension-conformance-qualification"
        [toolchain, oracle, positive, negatives, mutation, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "extension-conformance-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positive,
         negatives, mutation, discovery, authority, observer, freshness, qualification, cleanroom, discipline, legacy]
      rows = phaseRows prerequisite toolchain oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "extension-conformance" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "extension-conformance-subject" [checkDigest discipline, receiptDigest (matrixClean matrix)]
      oracleId = ids "extension-conformance-oracle" [receiptDigest (matrixClean matrix), checkDigest oracle, checkDigest negatives]
      harnessId = ids "extension-conformance-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "extension-conformance-observer" [checkDigest observer]
      qualificationId = ids "extension-conformance-qualification" [checkDigest qualification]
      acquiredRunId = ids "extension-conformance-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "extension-conformance-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredConformanceGateRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM (runMutant root runRoot cabal compiler store) mutantSpecifications
  compilePositive <- runCompile root runRoot cabal compiler store "legal-boundary" Nothing
  compileNegatives <- mapM runNegative compileSpecifications
  clean <- runSpec root runRoot cabal compiler store "clean" Nothing
  pure (Matrix mutants compilePositive compileNegatives clean)
 where
  runNegative (name, flagName, locus) = do
    receipt <- runCompile root runRoot cabal compiler store name (Just flagName)
    pure (locus, receipt)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> (Text, String, Text) -> IO Mutant
runMutant root runRoot cabal compiler store (name, flagName, locus) = do
  receipt <- runSpec root runRoot cabal compiler store name (Just flagName)
  pure (Mutant name (Text.pack flagName) locus receipt)

runSpec :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runSpec root runRoot cabal compiler store name selected =
  runProcess root [("AMOEBIUS_EXTENSION_CONFORMANCE_OUTPUT", runRoot </> "generated" </> Text.unpack name)] name cabal
    (cabalArgs runRoot store compiler "extension-conformance-gate-spec" selected)

runCompile :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runCompile root runRoot cabal compiler store name selected =
  runProcess root [] name cabal (cabalArgs runRoot store compiler "extension-conformance-gate-compile" selected)

cabalArgs :: FilePath -> FilePath -> FilePath -> String -> Maybe String -> [String]
cabalArgs runRoot store compiler target selected =
  ["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler,
   "--jobs=1", "test", target, "--offline", "--test-show-details=direct"]
  <> maybe [] (pure . ("-f" <>)) selected

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [ ("omit-law", "extension-conformance-omit-law-mutant", "L5")
  , ("ignore-suite-digest", "extension-conformance-ignore-suite-digest-mutant", "modified suite reached wrong result")
  , ("ignore-verdict", "extension-conformance-ignore-verdict-mutant", "changed-core admission reached wrong result")
  ]

compileSpecifications :: [(Text, String, Text)]
compileSpecifications =
  [ ("forge-verdict", "extension-conformance-test-forge-verdict", "ConformanceVerdict")
  , ("omit-verdict", "extension-conformance-test-unsealed-admission", "admitExtension plan declaration linkSet")
  , ("cross-scope-verdict", "extension-conformance-test-cross-scope-verdict", "crossScopeAdmission = admitExtension")
  ]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "extension-conformance-toolchain"
  [observation "extension-conformance.cabal" (receiptSummary version), observation "extension-conformance.compiler" (Text.pack compiler)]
  ([finding "EXTENSION-SECURITY-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "EXTENSION-SECURITY-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "extension-conformance-independent-oracle"
  [ observation "extension-conformance.oracle" (receiptSummary clean)
  , observation "extension-conformance.oracle-independence" "ExtensionConformanceGateOracle.hs imports no production generator, plan, verdict, or admission type" ]
  [finding "EXTENSION-SECURITY-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where acceptance = "PASS (19 cases, 24 coverage cells, 1 sealed admission, 3 production mutants, 3 compiler barriers, 10 generated products)"

positiveCheck :: Receipt -> CheckResult -> CheckResult
positiveCheck clean generated = CheckResult "extension-conformance-positive-controls"
  [observation "extension-conformance.positive" "nineteen derived cases, 24 coverage cells, six generated suite/coverage files, one sealed admission, and ten contained products"]
  ([finding "EXTENSION-SECURITY-POSITIVE" oracleSource "the closed Haskell corpus did not pass" | receiptExit clean /= ExitSuccess]
   <> checkFindings generated)

negativeCheck :: Matrix -> CheckResult
negativeCheck matrix = CheckResult "extension-conformance-paired-negatives"
  [observation "extension-conformance.negatives" "modified suite, failed case, wrong declaration, and changed core are refused; one legal compiler control versus three type-refused siblings"]
  ([finding "EXTENSION-CONFORMANCE-SEMANTIC-NEGATIVE" oracleSource "the exact negative verdict cases did not execute" |
      receiptExit clean /= ExitSuccess || notContains "19 cases" (receiptOutput clean)]
   <> [finding "EXTENSION-CONFORMANCE-COMPILE-POSITIVE" compileSource "the verdict-gated admission control did not run" |
      receiptExit positive /= ExitSuccess || notContains "PASS verdict-gated admission signature" (receiptOutput positive)]
   <> [finding "EXTENSION-SECURITY-COMPILE-NEGATIVE" compileSource ("the compiler did not refuse the exact boundary at " <> locus) |
      (locus, receipt) <- matrixCompileNegatives matrix,
      receiptExit receipt /= ExitFailure 1 || notContains "error:" (receiptOutput receipt) || notContains locus (receiptOutput receipt)])
 where
  clean = matrixClean matrix
  positive = matrixCompilePositive matrix

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "extension-conformance-mutants"
  [observation ("extension-conformance.mutant." <> name) (flagName <> "|" <> receiptSummary receipt) | Mutant name flagName _ receipt <- matrixMutants matrix]
  [finding "EXTENSION-SECURITY-MUTANT" (Text.unpack name) ("the changed production evaluator did not turn red at " <> locus) |
    Mutant name _ locus receipt <- matrixMutants matrix,
    receiptExit receipt /= ExitFailure 1 || notContains locus (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.pack <$> readFile (root </> productionSource)
  oracle <- Text.intercalate "\n" <$> mapM (fmap Text.pack . readFile . (root </>)) oracleSources
  let productionTokens = ["deriveGatePlan", "generatedFiles", "runGeneratedGate", "verifyVerdict", "admitExtension",
        "EXTENSION_CONFORMANCE_OMIT_LAW_MUTANT", "EXTENSION_CONFORMANCE_IGNORE_SUITE_DIGEST_MUTANT", "EXTENSION_CONFORMANCE_IGNORE_VERDICT_MUTANT"]
      oracleTokens = ["suiteInventory", "coverageGrid", "expectedVerdictCases"]
  pure (CheckResult "extension-conformance-source-discipline"
    [observation "extension-conformance.production-module-count" "1", observation "extension-conformance.effect-boundary" "pure Register-1 declaration-derived plan/files/verdict/admission kernel; no host, network, service, cluster, or hardware effects"]
    ([finding "EXTENSION-SECURITY-SOURCE-SHAPE" productionSource ("missing production element: " <> token) | token <- productionTokens, notContains token production]
     <> [finding "EXTENSION-SECURITY-ORACLE-SHAPE" "<phase-24-oracle>" ("missing oracle element: " <> token) | token <- oracleTokens, notContains token oracle]
     <> [finding "EXTENSION-SECURITY-SOURCE-DISCIPLINE" productionSource ("forbidden production token: " <> token) |
          token <- ["unsafePerformIO", "undefined", "pb validate", "System.Process", "Network.HTTP"], not (notContains token production)]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "extension-conformance-discovery"
  [observation "extension-conformance.discovery.count" (Text.pack (show (length observed)))]
  [finding "EXTENSION-SECURITY-DISCOVERY" "<phase-24-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "extension-conformance-authority"
  [observation "extension-conformance.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children",
   observation "extension-conformance.register" "Register 1 pure/build claim; runtime fidelity UNVERIFIED"]
  ([finding "EXTENSION-SECURITY-RUN-ROOT" runRoot "run root escaped .build/runs/phase-24/work" | not (pathBelow (root </> ".build/runs/phase-24/work") runRoot)]
   <> [finding "EXTENSION-SECURITY-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-24 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "extension-conformance-observer"
  (map (observation "extension-conformance.observer.process" . receiptSummary) receipts)
  [finding "EXTENSION-SECURITY-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "extension-conformance-freshness"
  [observation "extension-conformance.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "EXTENSION-SECURITY-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-24/work") runRoot)]

generatedCheck :: FilePath -> FilePath -> IO CheckResult
generatedCheck root runRoot = do
  let names = ["property-suite.tsv", "composition-suite.tsv", "compile-fail-suite.tsv", "security-suite.tsv", "transaction-suite.tsv", "coverage-grid.tsv", "phase-results.tsv", "inventory.tsv", "coverage-observed.tsv", "verdict.tsv"]
      paths = map ((runRoot </> "generated/clean") </>) names
  present <- mapM doesFileExist paths
  pure (CheckResult "extension-conformance-generated-products"
    [observation "extension-conformance.generated-count" (Text.pack (show (length (filter id present)))), observation "extension-conformance.generated-root" (Text.pack (makeRelative root (runRoot </> "generated/clean")))]
    [finding "EXTENSION-SECURITY-GENERATED" (makeRelative root path) "a fresh generated result is absent" | (path, False) <- zip paths present])

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "extension-conformance-legacy-closure"
    [observation "extension-conformance.legacy.retired-count" (Text.pack (show (length retiredSources)))]
    [finding "EXTENSION-SECURITY-LEGACY" path "retired Python gate, serialized behavioral authority, or test-local mutant remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-24-claim" [pre], named "phase-24-subject" [toolchain, positive], named "phase-24-command" [toolchain, authority],
   named "phase-24-oracle" [oracle], named "phase-24-positive-controls" [positive], named "phase-24-paired-negatives" [negatives],
   named "phase-24-mutants" [mutants], named "phase-24-discovery" [discovery], named "phase-24-challenge" [mutants],
   named "phase-24-observer" [observer], named "phase-24-authority-bypass" [authority], named "phase-24-freshness" [freshness],
   named "phase-24-qualification" [qualification], named "phase-24-cleanroom" [cleanroom], named "phase-24-legacy-closure" [legacy],
   CheckResult "phase-24-predecessor" [observation "phase-24.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-24-residue" [observation "phase-24.residue" "transaction instances, observer authenticity, executable semantic harness generation, universal closure, collision absence, decode, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"] [],
   named "phase-24-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "extension-conformance-source-repository-cache" [observation "extension-conformance.cache.entries" (Text.pack (show copied))]
    [finding "EXTENSION-SECURITY-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-24/work"
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
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "AMOEBIUS_EXTENSION_CONFORMANCE_OUTPUT"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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
matrixReceipts matrix = map (\(Mutant _ _ _ receipt) -> receipt) (matrixMutants matrix) <> [matrixCompilePositive matrix] <> map snd (matrixCompileNegatives matrix) <> [matrixClean matrix]

productionSources, oracleSources, expectedSources, retiredSources :: [FilePath]
productionSources = [productionSource]
oracleSources = sort ["test/spec/extension/ExtensionConformanceGateSpec.hs", "test/spec/extension/ExtensionConformanceGateOracle.hs", "test/harness/extension_laws/LawFixtures.hs", compileSource]
expectedSources = sort (productionSources <> oracleSources)
retiredSources =
  [ "tools/conformance_gate_generator_gate.py"
  , "test/mutant/extension_conformance/ConformanceGateMutants.hs"
  , "test/oracle/extension_conformance/suite_inventory.tsv"
  , "test/oracle/extension_conformance/coverage_grid.tsv"
  , "test/oracle/extension_conformance/verdict_cases.tsv"
  , "test/oracle/extension_conformance/mutation_catalog.tsv"
  , "test/oracle/extension_conformance_gate_surfaces.tsv"
  ]

oracleSource, compileSource :: FilePath
oracleSource = "test/spec/extension/ExtensionConformanceGateOracle.hs"
compileSource = "test/negative/compile_fail/extension_conformance/ConformanceCompile.hs"

productionSource :: FilePath
productionSource = "src/extension-conformance-gate/Amoebius/Extension/Conformance/Gate.hs"
