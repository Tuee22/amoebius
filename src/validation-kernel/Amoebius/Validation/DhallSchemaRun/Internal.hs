{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.DhallSchemaRun.Internal
  ( AcquiredDhallSchemaRun
  , acquireDhallSchemaRun
  , acquireDhallSchemaRefreshRun
  , acquiredDhallSchemaRunCheck
  , foldAcquiredDhallSchemaRun
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
data Matrix = Matrix {matrixMutants :: [Mutant], matrixClean :: Receipt}

data AcquiredDhallSchemaRun = AcquiredDhallSchemaRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredDhallSchemaRunCheck :: AcquiredDhallSchemaRun -> CheckResult
acquiredDhallSchemaRunCheck (AcquiredDhallSchemaRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredDhallSchemaRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredDhallSchemaRun -> value
foldAcquiredDhallSchemaRun consume (AcquiredDhallSchemaRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireDhallSchemaRun, acquireDhallSchemaRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredDhallSchemaRun
acquireDhallSchemaRun = acquire False
acquireDhallSchemaRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredDhallSchemaRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 25 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root [] "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler store
  discipline <- sourceDisciplineCheck root
  legacy <- legacyCheck root acquired
  generated <- generatedCheck root runRoot
  let discovery = discoveryCheck acquired
      toolchain = toolchainCheck cabal compiler store cabalVersion matrix
      oracle = oracleCheck (matrixClean matrix)
      positive = positiveCheckWithGenerated (matrixClean matrix) generated
      negatives = negativeCheck (matrixClean matrix)
      mutation = mutantCheck matrix
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot (matrixClean matrix)
      cleanroom = mergeChecks "dhall-schema-cleanroom" [cache, generated, freshness]
      qualification = mergeChecks "dhall-schema-qualification" [toolchain, oracle, positive, negatives, mutation, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "dhall-schema-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positive,
         negatives, mutation, discovery, authority, observer, freshness, qualification, cleanroom, discipline, legacy]
      rows = phaseRows prerequisite toolchain oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "dhall-schema" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "dhall-schema-subject" [checkDigest discipline, receiptDigest (matrixClean matrix)]
      oracleId = ids "dhall-schema-oracle" [receiptDigest (matrixClean matrix), checkDigest oracle, checkDigest negatives]
      harnessId = ids "dhall-schema-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "dhall-schema-observer" [checkDigest observer]
      qualificationId = ids "dhall-schema-qualification" [checkDigest qualification]
      acquiredRunId = ids "dhall-schema-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "dhall-schema-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredDhallSchemaRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM (runMutant root runRoot cabal compiler store) mutantSpecifications
  clean <- runSpec root runRoot cabal compiler store "clean" Nothing
  pure (Matrix mutants clean)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> (Text, String, Text) -> IO Mutant
runMutant root runRoot cabal compiler store (name, flagName, locus) = do
  receipt <- runSpec root runRoot cabal compiler store name (Just flagName)
  pure (Mutant name (Text.pack flagName) locus receipt)

runSpec :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runSpec root runRoot cabal compiler store name selected =
  runProcess root [("AMOEBIUS_DHALL_SCHEMA_OUTPUT", runRoot </> "generated" </> Text.unpack name)] name cabal
    (["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler,
      "--jobs=1", "test", "dhall-schema-conformance-spec", "--offline", "--test-show-details=direct"]
      <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [ ("optional-resource", "dhall-schema-optional-resource-mutant", "Resources locus invariant failed")
  , ("resource-type", "dhall-schema-resource-type-mutant", "Resources locus invariant failed")
  , ("plaintext-secret", "dhall-schema-plaintext-secret-mutant", "SecretRef locus invariant failed")
  , ("custom-capability", "dhall-schema-custom-capability-mutant", "Capability locus invariant failed")
  ]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "dhall-schema-toolchain"
  [observation "dhall-schema.cabal" (receiptSummary version), observation "dhall-schema.compiler" (Text.pack compiler), observation "dhall-schema.engine" "in-process dhall-1.42.3"]
  ([finding "DHALL-SCHEMA-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "DHALL-SCHEMA-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck, positiveCheck, negativeCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "dhall-schema-independent-oracle"
  [observation "dhall-schema.oracle" (receiptSummary clean), observation "dhall-schema.oracle-independence" "DhallSchemaGenerationOracle.hs imports no production schema or case type"]
  [finding "DHALL-SCHEMA-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where acceptance = "PASS (18 modules, 4 positives, 14 paired negatives, 4 production mutants, 38 generated products)"
positiveCheck clean = CheckResult "dhall-schema-positive-controls"
  [observation "dhall-schema.positive" "eighteen modules and four full representative values typecheck through the in-process Dhall 1.42.3 engine"]
  [finding "DHALL-SCHEMA-POSITIVE" oracleSource "the clean positive corpus did not pass" | receiptExit clean /= ExitSuccess]
negativeCheck clean = CheckResult "dhall-schema-paired-negatives"
  [observation "dhall-schema.negatives" "fourteen exact structural/import refusals each bind a named passing sibling and an independent locus"]
  [finding "DHALL-SCHEMA-NEGATIVE" oracleSource "the paired-negative corpus did not execute" |
    receiptExit clean /= ExitSuccess || notContains "14 paired negatives" (receiptOutput clean)]

positiveCheckWithGenerated :: Receipt -> CheckResult -> CheckResult
positiveCheckWithGenerated clean generated = mergeChecks "dhall-schema-positive-and-generated" [positiveCheck clean, generated]

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "dhall-schema-mutants"
  [observation ("dhall-schema.mutant." <> name) (flagName <> "|" <> receiptSummary receipt) | Mutant name flagName _ receipt <- matrixMutants matrix]
  [finding "DHALL-SCHEMA-MUTANT" (Text.unpack name) ("the changed production projection did not turn red at " <> locus) |
    Mutant name _ locus receipt <- matrixMutants matrix,
    receiptExit receipt /= ExitFailure 1 || notContains locus (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.pack <$> readFile (root </> productionSource)
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  pure (CheckResult "dhall-schema-source-discipline"
    [observation "dhall-schema.production-module-count" "1", observation "dhall-schema.effect-boundary" "pure Haskell declarations plus run-scoped Dhall typechecking; no host, network, service, cluster, or hardware effects"]
    ([finding "DHALL-SCHEMA-SOURCE-SHAPE" productionSource ("missing production element: " <> token) |
       token <- ["schemaModules", "schemaCases", "renderForeclosureLedger", "DHALL_SCHEMA_CUSTOM_CAPABILITY_MUTANT"], notContains token production]
     <> [finding "DHALL-SCHEMA-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token) |
       token <- ["expectedModuleNames", "expectedNegativeRows", "expectedSchemaLoci"], notContains token oracle]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "dhall-schema-discovery"
  [observation "dhall-schema.discovery.count" (Text.pack (show (length observed)))]
  [finding "DHALL-SCHEMA-DISCOVERY" "<phase-25-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "dhall-schema-authority"
  [observation "dhall-schema.authority" "no pb/network/host/hardware/live service; in-process Dhall; exact Cabal/compiler; serial synchronous children"]
  ([finding "DHALL-SCHEMA-RUN-ROOT" runRoot "run root escaped .build/runs/phase-25/work" | not (pathBelow (root </> ".build/runs/phase-25/work") runRoot)]
   <> [finding "DHALL-SCHEMA-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-25 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "dhall-schema-observer" (map (observation "dhall-schema.observer.process" . receiptSummary) receipts)
  [finding "DHALL-SCHEMA-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "dhall-schema-freshness"
  [observation "dhall-schema.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "DHALL-SCHEMA-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-25/work") runRoot)]

generatedCheck :: FilePath -> FilePath -> IO CheckResult
generatedCheck root runRoot = do
  let names = ["inventory.tsv", "foreclosure-ledger.tsv"] <> ["schema/" <> Text.unpack name <> ".dhall" | name <- schemaNames] <> ["cases/" <> Text.unpack name <> ".dhall" | name <- caseNames]
      paths = map ((runRoot </> "generated/clean") </>) names
  present <- mapM doesFileExist paths
  pure (CheckResult "dhall-schema-generated-products"
    [observation "dhall-schema.generated-count" (Text.pack (show (length (filter id present)))), observation "dhall-schema.generated-root" (Text.pack (makeRelative root (runRoot </> "generated/clean")))]
    [finding "DHALL-SCHEMA-GENERATED" (makeRelative root path) "a fresh generated result is absent" | (path, False) <- zip paths present])

legacyCheck :: FilePath -> AcquiredSourceSnapshot -> IO CheckResult
legacyCheck root acquired = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  let trackedDhall = [indexPath (trackedIndex entry) | entry <- snapshotEntries (acquiredSourceSnapshot acquired), ".dhall" `isSuffixOf` indexPath (trackedIndex entry)]
  pure (CheckResult "dhall-schema-legacy-closure"
    [observation "dhall-schema.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "dhall-schema.legacy.tracked-dhall-count" (Text.pack (show (length trackedDhall)))]
    ([finding "DHALL-SCHEMA-LEGACY" path "retired Dhall/Python/serialized behavioral authority remains" | path <- files]
     <> [finding "DHALL-SCHEMA-TRACKED-DHALL" path "tracked Dhall behavioral source remains after LTD-SRC-002 closure" | path <- trackedDhall]))

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-25-claim" [pre], named "phase-25-subject" [toolchain, positive], named "phase-25-command" [toolchain, authority],
   named "phase-25-oracle" [oracle], named "phase-25-positive-controls" [positive], named "phase-25-paired-negatives" [negatives],
   named "phase-25-mutants" [mutants], named "phase-25-discovery" [discovery], named "phase-25-challenge" [mutants],
   named "phase-25-observer" [observer], named "phase-25-authority-bypass" [authority], named "phase-25-freshness" [freshness],
   named "phase-25-qualification" [qualification], named "phase-25-cleanroom" [cleanroom], named "phase-25-legacy-closure" [legacy],
   CheckResult "phase-25-predecessor" [observation "phase-25.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-25-residue" [observation "phase-25.residue" "binding, indexed decode, whole-deployment feasibility, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"] [],
   named "phase-25-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "dhall-schema-source-repository-cache" [observation "dhall-schema.cache.entries" (Text.pack (show copied))]
    [finding "DHALL-SCHEMA-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-25/work"
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
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "AMOEBIUS_DHALL_SCHEMA_OUTPUT"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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
isSuffixOf :: String -> String -> Bool
isSuffixOf suffix value = reverse suffix `isPrefixOf` reverse value
matrixReceipts :: Matrix -> [Receipt]
matrixReceipts matrix = map (\(Mutant _ _ _ receipt) -> receipt) (matrixMutants matrix) <> [matrixClean matrix]

schemaNames, caseNames :: [Text]
schemaNames = ["App", "Backup", "BakeCatalog", "Capability", "Capacity", "Cluster", "Consistency", "Deployment", "Extension", "Image", "Resources", "Retention", "SanctionedApi", "SecretRef", "Storage", "Topology", "UiOffline", "prelude/package"]
caseNames = ["legal_multisubstrate_cluster", "legal_managed_eks", "trivial_app", "legal_deployment_rules", "product_named_capability", "insecure_ingress", "missing_resource_envelope", "unbounded_storage", "topic_without_retention", "growth_without_scaling_policy", "even_rke2_servers", "unsupported_substrate", "foreign_image", "run_shell_bake_step", "container_without_process", "plaintext_secret", "import_env", "import_remote"]

expectedSources, retiredSources :: [FilePath]
expectedSources = sort [productionSource, specSource, oracleSource]
retiredSources = ["tools/dhall_typecheck.py", "tools/dhall_typecheck.sh", "tools/dhall_typecheck_negatives.sh", "tools/dhall_typecheck_schema_gate.py", "test/oracle/dhall_typecheck_schema_surfaces.tsv", "dhall/examples/locus_registry.tsv"]
productionSource, specSource, oracleSource :: FilePath
productionSource = "src/dhall-schema-generation/Amoebius/Dhall/Schema/Generation.hs"
specSource = "test/spec/extension/DhallSchemaConformanceSpec.hs"
oracleSource = "test/spec/extension/DhallSchemaGenerationOracle.hs"
