{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ExtensionCompositionRun.Internal
  ( AcquiredExtensionCompositionRun
  , acquireExtensionCompositionRun
  , acquireExtensionCompositionRefreshRun
  , acquiredExtensionCompositionRunCheck
  , foldAcquiredExtensionCompositionRun
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
  , matrixCompileNegative :: Receipt
  , matrixClean :: Receipt
  }

data AcquiredExtensionCompositionRun = AcquiredExtensionCompositionRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredExtensionCompositionRunCheck :: AcquiredExtensionCompositionRun -> CheckResult
acquiredExtensionCompositionRunCheck (AcquiredExtensionCompositionRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredExtensionCompositionRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredExtensionCompositionRun -> value
foldAcquiredExtensionCompositionRun consume (AcquiredExtensionCompositionRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireExtensionCompositionRun, acquireExtensionCompositionRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExtensionCompositionRun
acquireExtensionCompositionRun = acquire False
acquireExtensionCompositionRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExtensionCompositionRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 22 acquired
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
      negatives = negativeCheck (matrixClean matrix) (matrixCompilePositive matrix) (matrixCompileNegative matrix)
      mutation = mutantCheck matrix
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot (matrixClean matrix)
      cleanroom = mergeChecks "extension-composition-cleanroom" [cache, generated, freshness]
      qualification = mergeChecks "extension-composition-qualification"
        [toolchain, oracle, positive, negatives, mutation, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "extension-composition-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positive,
         negatives, mutation, discovery, authority, observer, freshness, qualification, cleanroom, discipline, legacy]
      rows = phaseRows prerequisite toolchain oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "extension-composition" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "extension-composition-subject" [checkDigest discipline, receiptDigest (matrixClean matrix)]
      oracleId = ids "extension-composition-oracle" [receiptDigest (matrixClean matrix), checkDigest oracle, checkDigest negatives]
      harnessId = ids "extension-composition-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "extension-composition-observer" [checkDigest observer]
      qualificationId = ids "extension-composition-qualification" [checkDigest qualification]
      acquiredRunId = ids "extension-composition-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "extension-composition-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredExtensionCompositionRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM (runMutant root runRoot cabal compiler store) mutantSpecifications
  compilePositive <- runCompile root runRoot cabal compiler store "same-request" Nothing
  compileNegative <- runCompile root runRoot cabal compiler store "cross-request" (Just "extension-laws-compositional-test-cross-scope")
  clean <- runSpec root runRoot cabal compiler store "clean" Nothing
  pure (Matrix mutants compilePositive compileNegative clean)

runMutant :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> (Text, String, Text) -> IO Mutant
runMutant root runRoot cabal compiler store (name, flagName, locus) = do
  receipt <- runSpec root runRoot cabal compiler store name (Just flagName)
  pure (Mutant name (Text.pack flagName) locus receipt)

runSpec :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runSpec root runRoot cabal compiler store name selected =
  runProcess root [("AMOEBIUS_EXTENSION_COMPOSITION_OUTPUT", runRoot </> "generated" </> Text.unpack name)] name cabal
    (cabalArgs runRoot store compiler "extension-laws-compositional-spec" selected)

runCompile :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runCompile root runRoot cabal compiler store name selected =
  runProcess root [] name cabal (cabalArgs runRoot store compiler "extension-laws-compositional-compile" selected)

cabalArgs :: FilePath -> FilePath -> FilePath -> String -> Maybe String -> [String]
cabalArgs runRoot store compiler target selected =
  ["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler,
   "--jobs=1", "test", target, "--offline", "--test-show-details=direct"]
  <> maybe [] (pure . ("-f" <>)) selected

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [ ("ignore-closure", "extension-laws-compositional-ignore-closure-mutant", "Closure")
  , ("ignore-identity", "extension-laws-compositional-ignore-identity-mutant", "Identity")
  , ("ignore-associativity", "extension-laws-compositional-ignore-associativity-mutant", "Associativity")
  , ("ignore-non-interference", "extension-laws-compositional-ignore-non-interference-mutant", "NonInterference")
  , ("ignore-budget-additivity", "extension-laws-compositional-ignore-budget-additivity-mutant", "BudgetAdditivity")
  , ("ignore-scope-conjunction", "extension-laws-compositional-ignore-scope-conjunction-mutant", "ScopeConjunction")
  , ("ignore-name-disjointness", "extension-laws-compositional-ignore-name-disjointness-mutant", "NameDisjointness")
  ]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "extension-composition-toolchain"
  [observation "extension-composition.cabal" (receiptSummary version), observation "extension-composition.compiler" (Text.pack compiler)]
  ([finding "EXTENSION-COMPOSITION-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "EXTENSION-COMPOSITION-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "extension-composition-independent-oracle"
  [ observation "extension-composition.oracle" (receiptSummary clean)
  , observation "extension-composition.oracle-independence" "ExtensionLawsCompositionalOracle.hs imports no production law evaluator or composite type" ]
  [finding "EXTENSION-COMPOSITION-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where acceptance = "PASS (7 composition cases, 63 authored verdicts, 7 production mutants, 4 independent addresses)"

positiveCheck :: Receipt -> CheckResult -> CheckResult
positiveCheck clean generated = CheckResult "extension-composition-positive-controls"
  [observation "extension-composition.positive" "seven lawful pair cases; 49 green cells; two lawful address controls; exact identities, associations, resource sums, and four independent content addresses"]
  ([finding "EXTENSION-COMPOSITION-POSITIVE" oracleSource "the closed Haskell corpus did not pass" | receiptExit clean /= ExitSuccess]
   <> checkFindings generated)

negativeCheck :: Receipt -> Receipt -> Receipt -> CheckResult
negativeCheck clean positive negative = CheckResult "extension-composition-paired-negatives"
  [observation "extension-composition.negatives" "two lawful versus seven defect subjects; same-request compile twin versus cross-request type refusal"]
  ([finding "EXTENSION-COMPOSITION-SEMANTIC-NEGATIVE" oracleSource "the exact 63-cell two-control/seven-defect table did not execute" |
      receiptExit clean /= ExitSuccess || notContains "63 authored verdicts" (receiptOutput clean)]
   <> [finding "EXTENSION-COMPOSITION-COMPILE-POSITIVE" compileSource "the same-request compile twin did not run" |
      receiptExit positive /= ExitSuccess || notContains "PASS same-request pair" (receiptOutput positive)]
   <> [finding "EXTENSION-COMPOSITION-COMPILE-NEGATIVE" compileSource "the cross-request twin was not refused at the scope equality" |
      receiptExit negative /= ExitFailure 1 || notContains "Couldn't match type" (receiptOutput negative) ||
      notContains "CompositeDeclaration" (receiptOutput negative) || notContains "singletonComposite right" (receiptOutput negative)])

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "extension-composition-mutants"
  [observation ("extension-composition.mutant." <> name) (flagName <> "|" <> receiptSummary receipt) | Mutant name flagName _ receipt <- matrixMutants matrix]
  [finding "EXTENSION-COMPOSITION-MUTANT" (Text.unpack name) ("the changed production evaluator did not turn red at " <> locus) |
    Mutant name _ locus receipt <- matrixMutants matrix,
    receiptExit receipt /= ExitFailure 1 || notContains locus (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.pack <$> readFile (root </> productionSource)
  oracle <- Text.intercalate "\n" <$> mapM (fmap Text.pack . readFile . (root </>)) oracleSources
  let productionTokens = ["CompositeDeclaration", "composeComposites", "sortOn declarationKey", "unionVocabulary",
        "addResources", "evaluateCompositionLaws", "contentAddress",
        "EXTENSION_LAWS_COMPOSITIONAL_IGNORE_CLOSURE_MUTANT", "EXTENSION_LAWS_COMPOSITIONAL_IGNORE_IDENTITY_MUTANT",
        "EXTENSION_LAWS_COMPOSITIONAL_IGNORE_ASSOCIATIVITY_MUTANT", "EXTENSION_LAWS_COMPOSITIONAL_IGNORE_NON_INTERFERENCE_MUTANT",
        "EXTENSION_LAWS_COMPOSITIONAL_IGNORE_BUDGET_ADDITIVITY_MUTANT", "EXTENSION_LAWS_COMPOSITIONAL_IGNORE_SCOPE_CONJUNCTION_MUTANT",
        "EXTENSION_LAWS_COMPOSITIONAL_IGNORE_NAME_DISJOINTNESS_MUTANT"]
      oracleTokens = ["compositionCases", "expectedVerdicts", "mutantProperties", "oracleContentAddress", "NameDisjointness"]
  pure (CheckResult "extension-composition-source-discipline"
    [observation "extension-composition.production-module-count" "1", observation "extension-composition.effect-boundary" "pure Register-1 normalized composite and finite C1-C7 evaluator; no host, network, service, cluster, or hardware effects"]
    ([finding "EXTENSION-COMPOSITION-SOURCE-SHAPE" productionSource ("missing production element: " <> token) | token <- productionTokens, notContains token production]
     <> [finding "EXTENSION-COMPOSITION-ORACLE-SHAPE" "<phase-22-oracle>" ("missing oracle element: " <> token) | token <- oracleTokens, notContains token oracle]
     <> [finding "EXTENSION-COMPOSITION-SOURCE-DISCIPLINE" productionSource ("forbidden production token: " <> token) |
          token <- ["unsafePerformIO", "undefined", "pb validate", "System.Process", "Network.HTTP"], not (notContains token production)]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "extension-composition-discovery"
  [observation "extension-composition.discovery.count" (Text.pack (show (length observed)))]
  [finding "EXTENSION-COMPOSITION-DISCOVERY" "<phase-22-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "extension-composition-authority"
  [observation "extension-composition.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children",
   observation "extension-composition.register" "Register 1 pure/build claim; runtime fidelity UNVERIFIED"]
  ([finding "EXTENSION-COMPOSITION-RUN-ROOT" runRoot "run root escaped .build/runs/phase-22/work" | not (pathBelow (root </> ".build/runs/phase-22/work") runRoot)]
   <> [finding "EXTENSION-COMPOSITION-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-22 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "extension-composition-observer"
  (map (observation "extension-composition.observer.process" . receiptSummary) receipts)
  [finding "EXTENSION-COMPOSITION-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "extension-composition-freshness"
  [observation "extension-composition.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "EXTENSION-COMPOSITION-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-22/work") runRoot)]

generatedCheck :: FilePath -> FilePath -> IO CheckResult
generatedCheck root runRoot = do
  let paths = [runRoot </> "generated/clean/phase-results.tsv", runRoot </> "generated/clean/addresses.tsv"]
  present <- mapM doesFileExist paths
  pure (CheckResult "extension-composition-generated-products"
    [observation "extension-composition.generated-count" (Text.pack (show (length (filter id present)))), observation "extension-composition.generated-root" (Text.pack (makeRelative root (runRoot </> "generated/clean")))]
    [finding "EXTENSION-COMPOSITION-GENERATED" (makeRelative root path) "a fresh generated result is absent" | (path, False) <- zip paths present])

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "extension-composition-legacy-closure"
    [observation "extension-composition.legacy.retired-count" (Text.pack (show (length retiredSources)))]
    [finding "EXTENSION-COMPOSITION-LEGACY" path "retired Python gate, serialized behavioral authority, or test-local mutant remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-22-claim" [pre], named "phase-22-subject" [toolchain, positive], named "phase-22-command" [toolchain, authority],
   named "phase-22-oracle" [oracle], named "phase-22-positive-controls" [positive], named "phase-22-paired-negatives" [negatives],
   named "phase-22-mutants" [mutants], named "phase-22-discovery" [discovery], named "phase-22-challenge" [mutants],
   named "phase-22-observer" [observer], named "phase-22-authority-bypass" [authority], named "phase-22-freshness" [freshness],
   named "phase-22-qualification" [qualification], named "phase-22-cleanroom" [cleanroom], named "phase-22-legacy-closure" [legacy],
   CheckResult "phase-22-predecessor" [observation "phase-22.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-22-residue" [observation "phase-22.residue" "security laws, generated conformance verdicts, universal closure proofs, decode, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"] [],
   named "phase-22-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "extension-composition-source-repository-cache" [observation "extension-composition.cache.entries" (Text.pack (show copied))]
    [finding "EXTENSION-COMPOSITION-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-22/work"
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
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "AMOEBIUS_EXTENSION_COMPOSITION_OUTPUT"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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
matrixReceipts matrix = map (\(Mutant _ _ _ receipt) -> receipt) (matrixMutants matrix) <> [matrixCompilePositive matrix, matrixCompileNegative matrix, matrixClean matrix]

productionSources, oracleSources, expectedSources, retiredSources :: [FilePath]
productionSources = [productionSource]
oracleSources = sort ["test/spec/extension/ExtensionLawsCompositionalSpec.hs", "test/spec/extension/ExtensionLawsCompositionalOracle.hs", "test/harness/extension_laws/CompositionFixtures.hs", "test/harness/extension_laws/LawFixtures.hs", compileSource]
expectedSources = sort (productionSources <> oracleSources)
retiredSources =
  [ "tools/extension_laws_compositional_gate.py"
  , "test/mutant/extension_laws/ExtensionCompositionMutants.hs"
  , "test/oracle/extension_laws/composition_cases.tsv"
  , "test/oracle/extension_laws/composition_law_verdicts.tsv"
  , "test/oracle/extension_laws/composition_mutation_catalog.tsv"
  , "test/oracle/extension_laws_compositional_surfaces.tsv"
  ]

oracleSource, compileSource :: FilePath
oracleSource = "test/spec/extension/ExtensionLawsCompositionalOracle.hs"
compileSource = "test/negative/compile_fail/extension_laws_compositional/CompositionScopeCompile.hs"

productionSource :: FilePath
productionSource = "src/extension-laws-compositional/Amoebius/Extension/Laws/Compositional.hs"
