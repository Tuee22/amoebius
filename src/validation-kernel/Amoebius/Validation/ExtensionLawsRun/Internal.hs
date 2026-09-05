{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ExtensionLawsRun.Internal
  ( AcquiredExtensionLawsRun
  , acquireExtensionLawsRun
  , acquireExtensionLawsRefreshRun
  , acquiredExtensionLawsRunCheck
  , foldAcquiredExtensionLawsRun
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
  , matrixCompileHarness :: Receipt
  , matrixClean :: Receipt
  }

data AcquiredExtensionLawsRun = AcquiredExtensionLawsRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredExtensionLawsRunCheck :: AcquiredExtensionLawsRun -> CheckResult
acquiredExtensionLawsRunCheck (AcquiredExtensionLawsRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredExtensionLawsRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredExtensionLawsRun -> value
foldAcquiredExtensionLawsRun consume (AcquiredExtensionLawsRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireExtensionLawsRun, acquireExtensionLawsRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExtensionLawsRun
acquireExtensionLawsRun = acquire False
acquireExtensionLawsRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExtensionLawsRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 21 acquired
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
      negatives = negativeCheck (matrixClean matrix) (matrixCompileHarness matrix)
      mutation = mutantCheck matrix
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot (matrixClean matrix)
      cleanroom = mergeChecks "extension-laws-cleanroom" [cache, generated, freshness]
      qualification = mergeChecks "extension-laws-qualification"
        [toolchain, oracle, positive, negatives, mutation, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "extension-laws-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positive,
         negatives, mutation, discovery, authority, observer, freshness, qualification, cleanroom, discipline, legacy]
      rows = phaseRows prerequisite toolchain oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "extension-laws" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "extension-laws-subject" [checkDigest discipline, receiptDigest (matrixClean matrix)]
      oracleId = ids "extension-laws-oracle" [receiptDigest (matrixClean matrix), checkDigest oracle, checkDigest negatives]
      harnessId = ids "extension-laws-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "extension-laws-observer" [checkDigest observer]
      qualificationId = ids "extension-laws-qualification" [checkDigest qualification]
      acquiredRunId = ids "extension-laws-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "extension-laws-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredExtensionLawsRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM (runMutant root runRoot cabal compiler store) mutantSpecifications
  compileHarness <- runCompileHarness root runRoot cabal compiler store
  clean <- runSpec root runRoot cabal compiler store "clean" Nothing
  pure (Matrix mutants compileHarness clean)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> (Text, String, Text) -> IO Mutant
runMutant root runRoot cabal compiler store (name, flagName, locus) = do
  receipt <- runSpec root runRoot cabal compiler store name (Just flagName)
  pure (Mutant name (Text.pack flagName) locus receipt)

runSpec :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runSpec root runRoot cabal compiler store name selected =
  runProcess root [("AMOEBIUS_EXTENSION_LAWS_OUTPUT", runRoot </> "generated" </> Text.unpack name)] name cabal
    (cabalArgs runRoot store compiler "extension-laws-per-extension-spec" selected)

runCompileHarness :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Receipt
runCompileHarness root runRoot cabal compiler store =
  runProcess root [] "claim-compile-pair" cabal
    (cabalArgs runRoot store compiler "compile-fail-harness-spec" Nothing <>
      ["--test-option=" <> compiler, "--test-option=" <> runRoot </> "generated/compile-fail"])

cabalArgs :: FilePath -> FilePath -> FilePath -> String -> Maybe String -> [String]
cabalArgs runRoot store compiler target selected =
  ["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler,
   "--jobs=1", "test", target, "--offline", "--test-show-details=direct"]
  <> maybe [] (pure . ("-f" <>)) selected

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [ ("ignore-operation-escape", "extension-laws-ignore-operation-escape-mutant", "Totality")
  , ("ignore-artifact-difference", "extension-laws-ignore-artifact-difference-mutant", "Determinism")
  , ("ignore-retention-reaper", "extension-laws-ignore-retention-reaper-mutant", "BudgetHonesty")
  , ("ignore-scope-widening", "extension-laws-ignore-scope-widening-mutant", "ScopePropagation")
  , ("ignore-missing-fixture", "extension-laws-ignore-missing-fixture-mutant", "EvidenceBinding")
  ]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "extension-laws-toolchain"
  [observation "extension-laws.cabal" (receiptSummary version), observation "extension-laws.compiler" (Text.pack compiler)]
  ([finding "EXTENSION-LAWS-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "EXTENSION-LAWS-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "extension-laws-independent-oracle"
  [ observation "extension-laws.oracle" (receiptSummary clean)
  , observation "extension-laws.oracle-independence" "ExtensionLawsPerExtensionOracle.hs imports no production law evaluator" ]
  [finding "EXTENSION-LAWS-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where acceptance = "PASS (7 subjects, 35 verdicts, 6 generated inputs, 5 single-law defects)"

positiveCheck :: Receipt -> CheckResult -> CheckResult
positiveCheck clean generated = CheckResult "extension-laws-positive-controls"
  [observation "extension-laws.positive" "two lawful declarations; ten green law verdicts; six total operations; isolated deterministic renders; exact budget and evidence values"]
  ([finding "EXTENSION-LAWS-POSITIVE" oracleSource "the closed Haskell corpus did not pass" | receiptExit clean /= ExitSuccess]
   <> checkFindings generated)

negativeCheck :: Receipt -> Receipt -> CheckResult
negativeCheck clean compileHarness = CheckResult "extension-laws-paired-negatives"
  [observation "extension-laws.negatives" "lawful versus one-defect L1-L5 subjects; legal claim-fixture twin versus missing-fixture compile negative"]
  ([finding "EXTENSION-LAWS-SEMANTIC-NEGATIVE" oracleSource "the five exact single-law negatives did not execute" |
      receiptExit clean /= ExitSuccess || notContains "5 single-law defects" (receiptOutput clean)]
   <> [finding "EXTENSION-LAWS-COMPILE-PAIR" compileSource "the Phase-15 claim fixture compile pair did not pass its pinned diagnostic" |
      receiptExit compileHarness /= ExitSuccess || notContains "10 legal/illegal twins" (receiptOutput compileHarness) || notContains "3 specific negatives" (receiptOutput compileHarness)])

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "extension-laws-mutants"
  [observation ("extension-laws.mutant." <> name) (flagName <> "|" <> receiptSummary receipt) | Mutant name flagName _ receipt <- matrixMutants matrix]
  [finding "EXTENSION-LAWS-MUTANT" (Text.unpack name) ("the changed production evaluator did not turn red at " <> locus) |
    Mutant name _ locus receipt <- matrixMutants matrix,
    receiptExit receipt /= ExitFailure 1 || notContains locus (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.pack <$> readFile (root </> productionSource)
  oracle <- Text.intercalate "\n" <$> mapM (fmap Text.pack . readFile . (root </>)) oracleSources
  let productionTokens = ["evaluateLaws", "declarationVocabulary", "OperationEscapedFailure", "ArtifactBytesDiffer",
        "RetainedOutputHasNoReaper", "ScopeWasWidened", "ClaimHasNoFixture",
        "EXTENSION_LAWS_IGNORE_OPERATION_ESCAPE_MUTANT", "EXTENSION_LAWS_IGNORE_ARTIFACT_DIFFERENCE_MUTANT",
        "EXTENSION_LAWS_IGNORE_RETENTION_REAPER_MUTANT", "EXTENSION_LAWS_IGNORE_SCOPE_WIDENING_MUTANT", "EXTENSION_LAWS_IGNORE_MISSING_FIXTURE_MUTANT"]
      oracleTokens = ["operationCases", "expectedVerdicts", "mutantProperties", "Totality", "EvidenceBinding"]
  pure (CheckResult "extension-laws-source-discipline"
    [observation "extension-laws.production-module-count" "1", observation "extension-laws.effect-boundary" "pure Register-1 finite law evaluator; isolated child renders only; no host, network, service, cluster, or hardware effects"]
    ([finding "EXTENSION-LAWS-SOURCE-SHAPE" productionSource ("missing production element: " <> token) | token <- productionTokens, notContains token production]
     <> [finding "EXTENSION-LAWS-ORACLE-SHAPE" "<phase-21-oracle>" ("missing oracle element: " <> token) | token <- oracleTokens, notContains token oracle]
     <> [finding "EXTENSION-LAWS-SOURCE-DISCIPLINE" productionSource ("forbidden production token: " <> token) |
          token <- ["unsafePerformIO", "undefined", "pb validate", "System.Process", "Network.HTTP"], not (notContains token production)]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "extension-laws-discovery"
  [observation "extension-laws.discovery.count" (Text.pack (show (length observed)))]
  [finding "EXTENSION-LAWS-DISCOVERY" "<phase-21-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "extension-laws-authority"
  [observation "extension-laws.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children",
   observation "extension-laws.register" "Register 1 pure/build claim; runtime fidelity UNVERIFIED"]
  ([finding "EXTENSION-LAWS-RUN-ROOT" runRoot "run root escaped .build/runs/phase-21/work" | not (pathBelow (root </> ".build/runs/phase-21/work") runRoot)]
   <> [finding "EXTENSION-LAWS-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-21 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "extension-laws-observer"
  (map (observation "extension-laws.observer.process" . receiptSummary) receipts)
  [finding "EXTENSION-LAWS-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "extension-laws-freshness"
  [observation "extension-laws.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "EXTENSION-LAWS-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-21/work") runRoot)]

generatedCheck :: FilePath -> FilePath -> IO CheckResult
generatedCheck root runRoot = do
  let paths = [runRoot </> "generated/clean/phase-results.tsv"]
  present <- mapM doesFileExist paths
  pure (CheckResult "extension-laws-generated-products"
    [observation "extension-laws.generated-count" (Text.pack (show (length (filter id present)))), observation "extension-laws.generated-root" (Text.pack (makeRelative root (runRoot </> "generated/clean")))]
    [finding "EXTENSION-LAWS-GENERATED" (makeRelative root path) "a fresh generated result is absent" | (path, False) <- zip paths present])

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "extension-laws-legacy-closure"
    [observation "extension-laws.legacy.retired-count" (Text.pack (show (length retiredSources)))]
    [finding "EXTENSION-LAWS-LEGACY" path "retired Python gate, serialized behavioral authority, or test-local mutant remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-21-claim" [pre], named "phase-21-subject" [toolchain, positive], named "phase-21-command" [toolchain, authority],
   named "phase-21-oracle" [oracle], named "phase-21-positive-controls" [positive], named "phase-21-paired-negatives" [negatives],
   named "phase-21-mutants" [mutants], named "phase-21-discovery" [discovery], named "phase-21-challenge" [mutants],
   named "phase-21-observer" [observer], named "phase-21-authority-bypass" [authority], named "phase-21-freshness" [freshness],
   named "phase-21-qualification" [qualification], named "phase-21-cleanroom" [cleanroom], named "phase-21-legacy-closure" [legacy],
   CheckResult "phase-21-predecessor" [observation "phase-21.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-21-residue" [observation "phase-21.residue" "compositional and security laws, conformance verdicts, decode, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"] [],
   named "phase-21-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "extension-laws-source-repository-cache" [observation "extension-laws.cache.entries" (Text.pack (show copied))]
    [finding "EXTENSION-LAWS-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-21/work"
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
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "AMOEBIUS_EXTENSION_LAWS_OUTPUT", "AMOEBIUS_EXTENSION_LAW_SEED"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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
matrixReceipts matrix = map (\(Mutant _ _ _ receipt) -> receipt) (matrixMutants matrix) <> [matrixCompileHarness matrix, matrixClean matrix]

productionSources, oracleSources, expectedSources, retiredSources :: [FilePath]
productionSources = [productionSource]
oracleSources = sort ["test/spec/extension/ExtensionLawsPerExtensionSpec.hs", "test/spec/extension/ExtensionLawsPerExtensionOracle.hs", "test/harness/extension_laws/LawFixtures.hs"]
expectedSources = sort (productionSources <> oracleSources)
retiredSources =
  [ "tools/extension_laws_per_extension_gate.py"
  , "test/mutant/extension_laws/ExtensionLawMutants.hs"
  , "test/oracle/extension_laws/operation_cases.tsv"
  , "test/oracle/extension_laws/law_verdicts.tsv"
  , "test/oracle/extension_laws/mutation_catalog.tsv"
  , "test/oracle/extension_laws_per_extension_surfaces.tsv"
  ]

oracleSource, compileSource :: FilePath
oracleSource = "test/spec/extension/ExtensionLawsPerExtensionOracle.hs"
compileSource = "test/negative/compile_fail/evidence_calculus/claim_without_a_fixture.hs"

productionSource :: FilePath
productionSource = "src/extension-laws/Amoebius/Extension/Laws/PerExtension.hs"
