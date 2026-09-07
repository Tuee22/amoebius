{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.TestWorkflowAlgebraRun.Internal
  ( AcquiredTestWorkflowAlgebraRun
  , acquireTestWorkflowAlgebraRefreshRun
  , acquireTestWorkflowAlgebraRun
  , acquiredTestWorkflowAlgebraRunCheck
  , foldAcquiredTestWorkflowAlgebraRun
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
import Control.Monad (forM_)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (intToDigit)
import Data.List (isInfixOf, isPrefixOf, sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import System.Directory
  ( copyFile, createDirectory, createDirectoryIfMissing, doesDirectoryExist
  , getHomeDirectory, listDirectory, removeFile )
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, takeFileName, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix [Mutant] Receipt Receipt Receipt

data AcquiredTestWorkflowAlgebraRun
  = AcquiredTestWorkflowAlgebraRun
      AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
      Text Text Text Text Text Text Text Text CheckResult

acquiredTestWorkflowAlgebraRunCheck :: AcquiredTestWorkflowAlgebraRun -> CheckResult
acquiredTestWorkflowAlgebraRunCheck (AcquiredTestWorkflowAlgebraRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredTestWorkflowAlgebraRun ::
  (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult] ->
   Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value) ->
  AcquiredTestWorkflowAlgebraRun -> value
foldAcquiredTestWorkflowAlgebraRun consume (AcquiredTestWorkflowAlgebraRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireTestWorkflowAlgebraRun, acquireTestWorkflowAlgebraRefreshRun ::
  FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredTestWorkflowAlgebraRun
acquireTestWorkflowAlgebraRun = acquire False
acquireTestWorkflowAlgebraRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredTestWorkflowAlgebraRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 48 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler store
  discipline <- sourceDisciplineCheck root acquired
  generated <- generatedDiscoveryCheck root (takeFileName runRoot <> "-clean")
  let toolchain = toolchainCheck cabal compiler store cabalVersion matrix
      oracle = oracleCheck (cleanReceipt matrix)
      positives = positiveCheck (cleanReceipt matrix)
      negatives = negativeCheck matrix
      mutants = mutantCheck matrix
      discovery = mergeChecks "test-workflow-algebra-discovery" [discipline, generated]
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot (cleanReceipt matrix)
      legacy = legacyCheck acquired
      cleanroom = mergeChecks "test-workflow-algebra-cleanroom" [cache, generated, legacy]
      qualification = mergeChecks "test-workflow-algebra-qualification"
        [toolchain, oracle, positives, negatives, mutants, discovery, authority, observer, freshness, cleanroom]
      prerequisite = mergeChecks "test-workflow-algebra-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "test-workflow-algebra" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "test-workflow-algebra-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
      oracleId = ids "test-workflow-algebra-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "test-workflow-algebra-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "test-workflow-algebra-observer" [checkDigest observer]
      qualificationId = ids "test-workflow-algebra-qualification" [checkDigest qualification]
      acquiredRunId = ids "test-workflow-algebra-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "test-workflow-algebra-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredTestWorkflowAlgebraRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM runMutant mutantSpecifications
  clean <- runSpec "clean" Nothing
  legal <- runCompile "compile-legal" "test/negative/test_workflow_algebra/legal_teardown.hs"
  illegal <- runCompile "compile-missing-teardown" "test/negative/test_workflow_algebra/missing_teardown.hs"
  pure (Matrix mutants clean legal illegal)
 where
  common buildDirectory =
    [ "--builddir=" <> buildDirectory, "--store-dir=" <> store
    , "--with-compiler=" <> compiler, "--jobs=1", "--offline" ]
  runMutant (name, flagName, locus, expected) = Mutant name locus expected <$> runSpec name (Just flagName)
  runSpec name selected = runProcess root name cabal
    (common (runRoot </> "dist") <>
      ["test", "test-workflow-algebra", "--offline", "--test-show-details=direct",
       "--test-options=--output " <> (root </> ".build") <> " --run-id " <> takeFileName runRoot <> "-" <> Text.unpack name] <>
      [if Just flagName == selected then "-f" <> flagName else "-f-" <> flagName | (_, flagName, _, _) <- mutantSpecifications])
  runCompile name fixture = runProcess root name cabal
    (common (runRoot </> "dist") <>
      ["exec", "--", compiler, "-fno-code", "-fforce-recomp", "-XGHC2024",
       "-isrc/test-workflow-algebra", "-package", "bytestring", "-package", "cryptohash-sha256", "-package", "text", fixture])

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
  [ row "optional-teardown" "test-workflow-optional-teardown-mutant" "topologyTeardownRequired" "test-workflow-algebra-mutant: RED optional-teardown teardown-obligation"
  , row "cleanup-success" "test-workflow-cleanup-success-mutant" "terminalResult.cleanup" "test-workflow-algebra-mutant: RED cleanup-success terminal-result"
  , row "replace-primary" "test-workflow-replace-primary-mutant" "terminalResult.primary" "test-workflow-algebra-mutant: RED replace-primary primary-failure"
  , row "drop-provider-debit" "test-workflow-drop-provider-debit-mutant" "requiredDemand.provider" "test-workflow-algebra-mutant: RED drop-provider-debit quota-demand"
  , row "allow-secret" "test-workflow-allow-secret-mutant" "authorityRef" "test-workflow-algebra-mutant: RED allow-secret authority-reference"
  , row "drop-inventory-domain" "test-workflow-drop-inventory-domain-mutant" "classifyResidue.domains" "test-workflow-algebra-mutant: RED drop-inventory-domain completeness"
  , row "upgrade-runtime" "test-workflow-upgrade-runtime-mutant" "deriveEvidence.runtime" "test-workflow-algebra-mutant: RED upgrade-runtime evidence-strength"
  ]
 where row name flagName locus expected = (name, flagName, locus, expected)

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ clean _ _) = clean
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean legal illegal) = [receipt | Mutant _ _ _ receipt <- mutants] <> [clean, legal, illegal]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "test-workflow-algebra-toolchain"
  [observation "test-workflow-algebra.cabal" (receiptSummary version), observation "test-workflow-algebra.compiler" (Text.pack compiler)]
  ([finding "TEST-WORKFLOW-ALGEBRA-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"] <>
   [finding "TEST-WORKFLOW-ALGEBRA-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "test-workflow-algebra-independent-oracle"
  [observation "test-workflow-algebra.oracle" (receiptSummary clean), observation "test-workflow-algebra.oracle-independence" "TestWorkflowAlgebraOracle imports no production or case module"]
  [finding "TEST-WORKFLOW-ALGEBRA-ORACLE" oracleSource "the independent Haskell oracle did not report the exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where acceptance = "test-workflow-algebra-spec: PASS (5 branches, 9 axes, 6 terminal outcomes, 5 inventory domains, 4 evidence moves, 7 mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean = CheckResult "test-workflow-algebra-positive-controls"
  [observation "test-workflow-algebra.positives" "pure suggestions, phantom teardown, terminal fold, inventory, evidence, projection, and calculus controls passed"]
  [finding "TEST-WORKFLOW-ALGEBRA-POSITIVE" specSource "the clean Phase-48 specification did not pass" |
    receiptExit clean /= ExitSuccess || notContains "test-workflow-algebra-calculus: PASS (5 kinds, 31 projected units)" (receiptOutput clean)]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ clean legal illegal) = CheckResult "test-workflow-algebra-paired-negatives"
  [ observation "test-workflow-algebra.negative.runtime" (receiptSummary clean)
  , observation "test-workflow-algebra.negative.compile-positive" (receiptSummary legal)
  , observation "test-workflow-algebra.negative.compile-refusal" (receiptSummary illegal) ]
  ([finding "TEST-WORKFLOW-ALGEBRA-PAIRED-NEGATIVES" specSource "the exact-fit/one-short, authority, ownership, inventory, or terminal pairs did not pass" | receiptExit clean /= ExitSuccess] <>
   [finding "TEST-WORKFLOW-ALGEBRA-COMPILE-POSITIVE" legalSource "the topology with an observed teardown did not compile" | receiptExit legal /= ExitSuccess] <>
   [finding "TEST-WORKFLOW-ALGEBRA-COMPILE-NEGATIVE" illegalSource "the teardown-pending topology was not rejected at the phantom-state mismatch" |
      receiptExit illegal /= ExitFailure 1 || any (`notContains` receiptOutput illegal) ["Couldn't match type", "TeardownPending", "TeardownObserved"]])

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _ _ _) = CheckResult "test-workflow-algebra-mutants"
  [observation ("test-workflow-algebra.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
  [finding "TEST-WORKFLOW-ALGEBRA-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus) |
    Mutant name locus expected receipt <- mutants, receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> AcquiredSourceSnapshot -> IO CheckResult
sourceDisciplineCheck root acquired = do
  production <- Text.pack <$> readFile (root </> productionSource)
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  let observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]
  pure (CheckResult "test-workflow-algebra-source-discipline"
    [observation "test-workflow-algebra.source-count" (Text.pack (show (length observed))), observation "test-workflow-algebra.effect-boundary" "pure Haskell values plus run-local projection writes and serial offline compiler children only"]
    ([finding "TEST-WORKFLOW-ALGEBRA-DISCOVERY" "<phase-48-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources] <>
     [finding "TEST-WORKFLOW-ALGEBRA-SOURCE-SHAPE" productionSource ("missing production element: " <> token) |
       token <- ["TestTopology state", "terminalResult :: TestTopology TeardownObserved", "suggestTest :: SuppliedTestModel", "classifyResidue", "deriveEvidence", "projectionRelativePath", "TEST_WORKFLOW_OPTIONAL_TEARDOWN_MUTANT", "TEST_WORKFLOW_UPGRADE_RUNTIME_MUTANT"], notContains token production] <>
     [finding "TEST-WORKFLOW-ALGEBRA-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or case module" | "import Amoebius" `Text.isInfixOf` oracle]))

generatedDiscoveryCheck :: FilePath -> FilePath -> IO CheckResult
generatedDiscoveryCheck root runIdentity = do
  let base = root </> ".build/test-corpora/test-workflow-algebra"
  files <- fmap (sort . concat) (mapM (listFilesRecursively . (base </>)) [runIdentity <> "-first", runIdentity <> "-second"])
  pure (CheckResult "test-workflow-algebra-generated-discovery"
    [observation "test-workflow-algebra.generated.count" (Text.pack (show (length files)))]
    [finding "TEST-WORKFLOW-ALGEBRA-GENERATED-DISCOVERY" "<generated-test-topology>" ("expected two cache-bypassed projections, observed=" <> Text.pack (show (map (makeRelative root) files))) | length files /= 2])

listFilesRecursively :: FilePath -> IO [FilePath]
listFilesRecursively path = do
  present <- doesDirectoryExist path
  if not present then pure [] else do
    names <- sort <$> listDirectory path
    fmap concat $ mapM (\name -> let child = path </> name in doesDirectoryExist child >>= \directory -> if directory then listFilesRecursively child else pure [child]) names

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "test-workflow-algebra-authority"
  [observation "test-workflow-algebra.authority" "no pb/network/host/provider/browser/cluster/hardware/live effects; exact serial offline Cabal/compiler children"]
  ([finding "TEST-WORKFLOW-ALGEBRA-RUN-ROOT" runRoot "run root escaped .build/runs/phase-48/work" | not (pathBelow (root </> ".build/runs/phase-48/work") runRoot)] <>
   [finding "TEST-WORKFLOW-ALGEBRA-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-48 authority" |
     Receipt name executable args _ _ _ <- receipts, executable /= cabal ||
     (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "test-workflow-algebra-observer"
  (map (observation "test-workflow-algebra.observer.process" . receiptSummary) receipts)
  [finding "TEST-WORKFLOW-ALGEBRA-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "test-workflow-algebra-freshness"
  [observation "test-workflow-algebra.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "TEST-WORKFLOW-ALGEBRA-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-48/work") runRoot)]

legacyCheck :: AcquiredSourceSnapshot -> CheckResult
legacyCheck acquired = CheckResult "test-workflow-algebra-legacy-closure"
  [observation "test-workflow-algebra.legacy-owned-count" "0"]
  [finding "TEST-WORKFLOW-ALGEBRA-LEGACY" path "a serialized Phase-48 oracle or proposal remains tracked" |
    entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), pathUnder "test/oracle/test_workflow_algebra" path]

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [ named "phase-48-claim" [pre], named "phase-48-subject" [toolchain, positives]
  , named "phase-48-command" [toolchain, authority], named "phase-48-oracle" [oracle]
  , named "phase-48-positive-controls" [positives], named "phase-48-paired-negatives" [negatives]
  , named "phase-48-mutants" [mutants], named "phase-48-discovery" [discovery]
  , named "phase-48-challenge" [mutants, negatives], named "phase-48-observer" [observer]
  , named "phase-48-authority-bypass" [authority], named "phase-48-freshness" [freshness]
  , named "phase-48-qualification" [qualification], named "phase-48-cleanroom" [cleanroom]
  , named "phase-48-legacy-closure" [legacy]
  , CheckResult "phase-48-predecessor" [observation "phase-48.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-48-residue" [observation "phase-48.residue" "live discovery, allocation, credentials, execution, teardown, inventory observation, Runtime evidence, and hardware remain Phase-90/later-owned"] []
  , named "phase-48-pass-criterion" [pre] ]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "test-workflow-algebra-source-repository-cache" [observation "test-workflow-algebra.cache.entries" (Text.pack (show copied))]
    [finding "TEST-WORKFLOW-ALGEBRA-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
      not present || length copied /= 6 || not (all (completeSourcePackage copied) ["infernix-", "jitML-"])])

copyTree :: FilePath -> FilePath -> IO ()
copyTree source target = do
  createDirectoryIfMissing True target
  entries <- listDirectory source
  forM_ entries $ \entry -> do
    let from = source </> entry; to = target </> entry
    directory <- doesDirectoryExist from
    if directory then copyTree from to else copyFile from to

completeSourcePackage :: [FilePath] -> String -> Bool
completeSourcePackage entries prefix = length matching == 3 && length (filter (isInfixOf ".cache") matching) == 1 && length (filter (isInfixOf ".tar.gz") matching) == 1 && length [entry | entry <- matching, not ('.' `elem` entry)] == 1
 where matching = filter (prefix `isPrefixOf`) entries

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-48/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle; removeFile leaf; createDirectory leaf; pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working name executable args = do
  inherited <- getEnvironment
  let environment = filter (not . forbiddenEnvironment . fst) inherited
  attempt <- try (readCreateProcessWithExitCode ((proc executable args){cwd = Just working, env = Just environment}) "") :: IO (Either IOException (ExitCode, String, String))
  pure $ either (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem))) (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err)) attempt

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
pathUnder :: FilePath -> FilePath -> Bool
pathUnder parent path = path == parent || (parent <> "/") `isPrefixOf` path
notContains :: Text -> Text -> Bool
notContains needle haystack = not (needle `Text.isInfixOf` haystack)

productionSource, oracleSource, specSource, legalSource, illegalSource :: FilePath
productionSource = "src/test-workflow-algebra/Amoebius/Test/WorkflowAlgebra.hs"
oracleSource = "test/spec/workflow/TestWorkflowAlgebraOracle.hs"
specSource = "test/spec/workflow/TestWorkflowAlgebraSpec.hs"
legalSource = "test/negative/test_workflow_algebra/legal_teardown.hs"
illegalSource = "test/negative/test_workflow_algebra/missing_teardown.hs"
expectedSources :: [FilePath]
expectedSources = sort [productionSource, oracleSource, specSource, legalSource, illegalSource]
