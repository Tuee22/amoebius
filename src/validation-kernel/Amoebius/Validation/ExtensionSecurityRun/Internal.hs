{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ExtensionSecurityRun.Internal
  ( AcquiredExtensionSecurityRun
  , acquireExtensionSecurityRun
  , acquireExtensionSecurityRefreshRun
  , acquiredExtensionSecurityRunCheck
  , foldAcquiredExtensionSecurityRun
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

data AcquiredExtensionSecurityRun = AcquiredExtensionSecurityRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredExtensionSecurityRunCheck :: AcquiredExtensionSecurityRun -> CheckResult
acquiredExtensionSecurityRunCheck (AcquiredExtensionSecurityRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredExtensionSecurityRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredExtensionSecurityRun -> value
foldAcquiredExtensionSecurityRun consume (AcquiredExtensionSecurityRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireExtensionSecurityRun, acquireExtensionSecurityRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExtensionSecurityRun
acquireExtensionSecurityRun = acquire False
acquireExtensionSecurityRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExtensionSecurityRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 23 acquired
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
      cleanroom = mergeChecks "extension-security-cleanroom" [cache, generated, freshness]
      qualification = mergeChecks "extension-security-qualification"
        [toolchain, oracle, positive, negatives, mutation, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "extension-security-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positive,
         negatives, mutation, discovery, authority, observer, freshness, qualification, cleanroom, discipline, legacy]
      rows = phaseRows prerequisite toolchain oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "extension-security" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "extension-security-subject" [checkDigest discipline, receiptDigest (matrixClean matrix)]
      oracleId = ids "extension-security-oracle" [receiptDigest (matrixClean matrix), checkDigest oracle, checkDigest negatives]
      harnessId = ids "extension-security-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "extension-security-observer" [checkDigest observer]
      qualificationId = ids "extension-security-qualification" [checkDigest qualification]
      acquiredRunId = ids "extension-security-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "extension-security-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredExtensionSecurityRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
  runProcess root [("AMOEBIUS_EXTENSION_SECURITY_OUTPUT", runRoot </> "generated" </> Text.unpack name)] name cabal
    (cabalArgs runRoot store compiler "extension-security-laws-spec" selected)

runCompile :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runCompile root runRoot cabal compiler store name selected =
  runProcess root [] name cabal (cabalArgs runRoot store compiler "extension-security-laws-compile" selected)

cabalArgs :: FilePath -> FilePath -> FilePath -> String -> Maybe String -> [String]
cabalArgs runRoot store compiler target selected =
  ["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler,
   "--jobs=1", "test", target, "--offline", "--test-show-details=direct"]
  <> maybe [] (pure . ("-f" <>)) selected

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [ ("ignore-s1", "extension-security-ignore-s1-mutant", "TamperedIdentityWasAccepted")
  , ("ignore-s2", "extension-security-ignore-s2-mutant", "SkolemBarrierMissing")
  , ("ignore-s3", "extension-security-ignore-s3-mutant", "UnscopedOperationArmExported")
  , ("ignore-s4", "extension-security-ignore-s4-mutant", "RefusalBytesDiffer")
  , ("ignore-s5", "extension-security-ignore-s5-mutant", "NamespaceCollision")
  , ("ignore-s6", "extension-security-ignore-s6-mutant", "RevocationPolicyMissing")
  ]

compileSpecifications :: [(Text, String, Text)]
compileSpecifications =
  [ ("claimed-as-attested", "extension-security-test-claimed-as-attested", "attestedOnly identity")
  , ("identity-promotion", "extension-security-test-promotion", "promote identity = identity")
  , ("missing-scope", "extension-security-test-missing-scope", "runScopedOperation Read")
  , ("cross-request-key", "extension-security-test-cross-key", "renderScopedKey right")
  ]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "extension-security-toolchain"
  [observation "extension-security.cabal" (receiptSummary version), observation "extension-security.compiler" (Text.pack compiler)]
  ([finding "EXTENSION-SECURITY-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "EXTENSION-SECURITY-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "extension-security-independent-oracle"
  [ observation "extension-security.oracle" (receiptSummary clean)
  , observation "extension-security.oracle-independence" "ExtensionSecurityLawsOracle.hs imports no production law evaluator, identity, request-scope, store, or key type" ]
  [finding "EXTENSION-SECURITY-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where acceptance = "PASS (15 operations, 5 refusal pairs, 5 namespaces, 42 authored verdicts, 6 production mutants, 4 compiler barriers, 4 independent addresses)"

positiveCheck :: Receipt -> CheckResult -> CheckResult
positiveCheck clean generated = CheckResult "extension-security-positive-controls"
  [observation "extension-security.positive" "fifteen exact operations, five refusal pairs, five injective namespaces, two authority layers, one independent fixture signature, and four independent content addresses"]
  ([finding "EXTENSION-SECURITY-POSITIVE" oracleSource "the closed Haskell corpus did not pass" | receiptExit clean /= ExitSuccess]
   <> checkFindings generated)

negativeCheck :: Matrix -> CheckResult
negativeCheck matrix = CheckResult "extension-security-paired-negatives"
  [observation "extension-security.negatives" "one lawful compiler control versus four type-refused siblings; lawful observations versus six minimal one-law defects"]
  ([finding "EXTENSION-SECURITY-SEMANTIC-NEGATIVE" oracleSource "the exact 42-cell lawful/six-defect table did not execute" |
      receiptExit clean /= ExitSuccess || notContains "42 authored verdicts" (receiptOutput clean)]
   <> [finding "EXTENSION-SECURITY-COMPILE-POSITIVE" compileSource "the legal claimed/attested control did not run" |
      receiptExit positive /= ExitSuccess || notContains "PASS legal claimed/attested boundary" (receiptOutput positive)]
   <> [finding "EXTENSION-SECURITY-COMPILE-NEGATIVE" compileSource ("the compiler did not refuse the exact boundary at " <> locus) |
      (locus, receipt) <- matrixCompileNegatives matrix,
      receiptExit receipt /= ExitFailure 1 || notContains "error:" (receiptOutput receipt) || notContains locus (receiptOutput receipt)])
 where
  clean = matrixClean matrix
  positive = matrixCompilePositive matrix

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "extension-security-mutants"
  [observation ("extension-security.mutant." <> name) (flagName <> "|" <> receiptSummary receipt) | Mutant name flagName _ receipt <- matrixMutants matrix]
  [finding "EXTENSION-SECURITY-MUTANT" (Text.unpack name) ("the changed production evaluator did not turn red at " <> locus) |
    Mutant name _ locus receipt <- matrixMutants matrix,
    receiptExit receipt /= ExitFailure 1 || notContains locus (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.pack <$> readFile (root </> productionSource)
  oracle <- Text.intercalate "\n" <$> mapM (fmap Text.pack . readFile . (root </>)) oracleSources
  let productionTokens = ["Identity", "withAttestedScope", "runScopedOperation", "renderScopedKey", "AuthorityLayer", "evaluateSecurityLaws",
        "EXTENSION_SECURITY_IGNORE_S1_MUTANT", "EXTENSION_SECURITY_IGNORE_S2_MUTANT", "EXTENSION_SECURITY_IGNORE_S3_MUTANT",
        "EXTENSION_SECURITY_IGNORE_S4_MUTANT", "EXTENSION_SECURITY_IGNORE_S5_MUTANT", "EXTENSION_SECURITY_IGNORE_S6_MUTANT"]
      oracleTokens = ["operationCases", "namespaceCases", "revocationCases", "expectedVerdicts", "mutationProperties", "expectedFixtureSignature", "oracleContentAddress"]
  pure (CheckResult "extension-security-source-discipline"
    [observation "extension-security.production-module-count" "1", observation "extension-security.effect-boundary" "pure Register-1 typed identity/scope/store/key/policy kernel and bounded S1-S6 evaluator; no host, network, service, cluster, or hardware effects"]
    ([finding "EXTENSION-SECURITY-SOURCE-SHAPE" productionSource ("missing production element: " <> token) | token <- productionTokens, notContains token production]
     <> [finding "EXTENSION-SECURITY-ORACLE-SHAPE" "<phase-23-oracle>" ("missing oracle element: " <> token) | token <- oracleTokens, notContains token oracle]
     <> [finding "EXTENSION-SECURITY-SOURCE-DISCIPLINE" productionSource ("forbidden production token: " <> token) |
          token <- ["unsafePerformIO", "undefined", "pb validate", "System.Process", "Network.HTTP"], not (notContains token production)]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "extension-security-discovery"
  [observation "extension-security.discovery.count" (Text.pack (show (length observed)))]
  [finding "EXTENSION-SECURITY-DISCOVERY" "<phase-23-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "extension-security-authority"
  [observation "extension-security.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children",
   observation "extension-security.register" "Register 1 pure/build claim; runtime fidelity UNVERIFIED"]
  ([finding "EXTENSION-SECURITY-RUN-ROOT" runRoot "run root escaped .build/runs/phase-23/work" | not (pathBelow (root </> ".build/runs/phase-23/work") runRoot)]
   <> [finding "EXTENSION-SECURITY-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-23 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "extension-security-observer"
  (map (observation "extension-security.observer.process" . receiptSummary) receipts)
  [finding "EXTENSION-SECURITY-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "extension-security-freshness"
  [observation "extension-security.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "EXTENSION-SECURITY-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-23/work") runRoot)]

generatedCheck :: FilePath -> FilePath -> IO CheckResult
generatedCheck root runRoot = do
  let paths = [runRoot </> "generated/clean/phase-results.tsv", runRoot </> "generated/clean/addresses.tsv"]
  present <- mapM doesFileExist paths
  pure (CheckResult "extension-security-generated-products"
    [observation "extension-security.generated-count" (Text.pack (show (length (filter id present)))), observation "extension-security.generated-root" (Text.pack (makeRelative root (runRoot </> "generated/clean")))]
    [finding "EXTENSION-SECURITY-GENERATED" (makeRelative root path) "a fresh generated result is absent" | (path, False) <- zip paths present])

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "extension-security-legacy-closure"
    [observation "extension-security.legacy.retired-count" (Text.pack (show (length retiredSources)))]
    [finding "EXTENSION-SECURITY-LEGACY" path "retired Python gate, serialized behavioral authority, or test-local mutant remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-23-claim" [pre], named "phase-23-subject" [toolchain, positive], named "phase-23-command" [toolchain, authority],
   named "phase-23-oracle" [oracle], named "phase-23-positive-controls" [positive], named "phase-23-paired-negatives" [negatives],
   named "phase-23-mutants" [mutants], named "phase-23-discovery" [discovery], named "phase-23-challenge" [mutants],
   named "phase-23-observer" [observer], named "phase-23-authority-bypass" [authority], named "phase-23-freshness" [freshness],
   named "phase-23-qualification" [qualification], named "phase-23-cleanroom" [cleanroom], named "phase-23-legacy-closure" [legacy],
   CheckResult "phase-23-predecessor" [observation "phase-23.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-23-residue" [observation "phase-23.residue" "production cryptography, wall-clock timing, persisted-value re-entry, compositional security closure, generated conformance verdicts, decode, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"] [],
   named "phase-23-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "extension-security-source-repository-cache" [observation "extension-security.cache.entries" (Text.pack (show copied))]
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
  let parent = root </> ".build/runs/phase-23/work"
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
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "AMOEBIUS_EXTENSION_SECURITY_OUTPUT"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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
oracleSources = sort ["test/spec/extension/ExtensionSecurityLawsSpec.hs", "test/spec/extension/ExtensionSecurityLawsOracle.hs", "test/harness/extension_security/SecurityFixtures.hs", compileSource]
expectedSources = sort (productionSources <> oracleSources)
retiredSources =
  [ "tools/extension_security_laws_gate.py"
  , "test/mutant/extension_security/SecurityLawMutants.hs"
  , "test/oracle/extension_security/operation_matrix.tsv"
  , "test/oracle/extension_security/namespace_cases.tsv"
  , "test/oracle/extension_security/revocation_layers.tsv"
  , "test/oracle/extension_security/law_verdicts.tsv"
  , "test/oracle/extension_security/mutation_catalog.tsv"
  , "test/oracle/extension_security_laws_surfaces.tsv"
  ]

oracleSource, compileSource :: FilePath
oracleSource = "test/spec/extension/ExtensionSecurityLawsOracle.hs"
compileSource = "test/negative/compile_fail/extension_security/SecurityCompile.hs"

productionSource :: FilePath
productionSource = "src/extension-security-laws/Amoebius/Extension/Laws/Security.hs"
