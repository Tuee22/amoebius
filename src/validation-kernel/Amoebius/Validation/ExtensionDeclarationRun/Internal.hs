{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ExtensionDeclarationRun.Internal
  ( AcquiredExtensionDeclarationRun
  , acquireExtensionDeclarationRun
  , acquireExtensionDeclarationRefreshRun
  , acquiredExtensionDeclarationRunCheck
  , foldAcquiredExtensionDeclarationRun
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
data Matrix = Matrix
  { matrixOptionalMutant :: Receipt
  , matrixScopeMutant :: Receipt
  , matrixReaderMutant :: Receipt
  , matrixIllegalOptional :: Receipt
  , matrixIllegalScope :: Receipt
  , matrixLegal :: Receipt
  , matrixClean :: Receipt
  }

data AcquiredExtensionDeclarationRun = AcquiredExtensionDeclarationRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredExtensionDeclarationRunCheck :: AcquiredExtensionDeclarationRun -> CheckResult
acquiredExtensionDeclarationRunCheck (AcquiredExtensionDeclarationRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredExtensionDeclarationRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredExtensionDeclarationRun -> value
foldAcquiredExtensionDeclarationRun consume (AcquiredExtensionDeclarationRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireExtensionDeclarationRun, acquireExtensionDeclarationRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExtensionDeclarationRun
acquireExtensionDeclarationRun = acquire False
acquireExtensionDeclarationRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExtensionDeclarationRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 20 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root [] "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler store
  discipline <- sourceDisciplineCheck root
  let discovery = discoveryCheck acquired
  legacy <- legacyCheck root
  generated <- generatedCheck root runRoot
  let toolchain = toolchainCheck cabal compiler store cabalVersion matrix
      oracle = oracleCheck (matrixClean matrix)
      positive = positiveCheck (matrixClean matrix) (matrixLegal matrix) generated
      negatives = negativeCheck (matrixClean matrix) (matrixIllegalOptional matrix) (matrixIllegalScope matrix)
      mutation = mutantCheck matrix
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot (matrixClean matrix)
      cleanroom = mergeChecks "extension-declaration-cleanroom" [cache, generated, freshness]
      qualification = mergeChecks "extension-declaration-qualification"
        [toolchain, oracle, positive, negatives, mutation, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "extension-declaration-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, toolchain, oracle, positive,
         negatives, mutation, discovery, authority, observer, freshness, qualification, cleanroom, discipline, legacy]
      rows = phaseRows prerequisite toolchain oracle positive negatives mutation discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "extension-declaration" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "extension-declaration-subject" [checkDigest discipline, receiptDigest (matrixClean matrix)]
      oracleId = ids "extension-declaration-oracle" [receiptDigest (matrixClean matrix), checkDigest oracle, checkDigest negatives]
      harnessId = ids "extension-declaration-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "extension-declaration-observer" [checkDigest observer]
      qualificationId = ids "extension-declaration-qualification" [checkDigest qualification]
      acquiredRunId = ids "extension-declaration-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "extension-declaration-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredExtensionDeclarationRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  optionalMutant <- runCompile root runRoot cabal compiler store "optional-component-mutant" (Just "extension-declaration-optional-component-mutant")
  scopeMutant <- runCompile root runRoot cabal compiler store "drop-scope-index-mutant" (Just "extension-declaration-drops-scope-index-mutant")
  readerMutant <- runSpec root runRoot cabal compiler store "omit-declared-recipe-mutant" (Just "extension-declaration-omit-declared-recipe-mutant")
  illegalOptional <- runCompile root runRoot cabal compiler store "illegal-optional-component" (Just "extension-declaration-test-optional-component")
  illegalScope <- runCompile root runRoot cabal compiler store "illegal-cross-scope" (Just "extension-declaration-test-cross-scope")
  legal <- runCompile root runRoot cabal compiler store "legal" Nothing
  clean <- runSpec root runRoot cabal compiler store "clean" Nothing
  pure (Matrix optionalMutant scopeMutant readerMutant illegalOptional illegalScope legal clean)

runSpec :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runSpec root runRoot cabal compiler store name selected =
  runProcess root [("AMOEBIUS_EXTENSION_DECLARATION_OUTPUT", runRoot </> "generated" </> Text.unpack name)] name cabal
    (cabalArgs runRoot store compiler "extension-declaration-spec" selected)

runCompile :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> Text -> Maybe String -> IO Receipt
runCompile root runRoot cabal compiler store name selected =
  runProcess root [] name cabal (cabalArgs runRoot store compiler "extension-declaration-compile" selected)

cabalArgs :: FilePath -> FilePath -> FilePath -> String -> Maybe String -> [String]
cabalArgs runRoot store compiler target selected =
  ["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler,
   "--jobs=1", "test", target, "--offline", "--test-show-details=direct"]
  <> maybe [] (pure . ("-f" <>)) selected

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "extension-declaration-toolchain"
  [observation "extension-declaration.cabal" (receiptSummary version), observation "extension-declaration.compiler" (Text.pack compiler)]
  ([finding "EXTENSION-DECLARATION-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "EXTENSION-DECLARATION-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "extension-declaration-independent-oracle"
  [ observation "extension-declaration.oracle" (receiptSummary clean)
  , observation "extension-declaration.oracle-independence" "ExtensionDeclarationOracle.hs imports no production declaration or composition module" ]
  [finding "EXTENSION-DECLARATION-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where acceptance = "PASS (2 declarations, 10 components, 5 readers, 2 digests, 2 refusal pairs)"

positiveCheck :: Receipt -> Receipt -> CheckResult -> CheckResult
positiveCheck clean legal generated = CheckResult "extension-declaration-positive-controls"
  [observation "extension-declaration.positive" "two complete declarations; ten components; five readers; exact resources; independent digests; legal compile twin"]
  ([finding "EXTENSION-DECLARATION-POSITIVE" oracleSource "the closed Haskell corpus did not pass" | receiptExit clean /= ExitSuccess]
   <> [finding "EXTENSION-DECLARATION-LEGAL-TWIN" compileSource "the legal five-component same-scope twin did not run" |
        receiptExit legal /= ExitSuccess || notContains "PASS legal five-component same-scope twin" (receiptOutput legal)]
   <> checkFindings generated)

negativeCheck :: Receipt -> Receipt -> Receipt -> CheckResult
negativeCheck clean optional scope = CheckResult "extension-declaration-paired-negatives"
  [observation "extension-declaration.negatives" "correct/wrong calculus; nonempty/empty name; five/four components; same/cross request scope"]
  ([finding "EXTENSION-DECLARATION-SEMANTIC-NEGATIVE" oracleSource "the two semantic refusal pairs did not execute" | receiptExit clean /= ExitSuccess]
   <> [finding "EXTENSION-DECLARATION-OPTIONAL-NEGATIVE" compileSource "the clean API did not reject the four-component sibling at arity" |
        receiptExit optional /= ExitFailure 1 || notContains "applied to too few arguments" (receiptOutput optional)]
   <> [finding "EXTENSION-DECLARATION-SCOPE-NEGATIVE" compileSource "the clean API did not reject the cross-scope sibling at RequestScope" |
        receiptExit scope /= ExitFailure 1 || notContains "Couldn't match type" (receiptOutput scope) || notContains "RequestScope" (receiptOutput scope)])

mutantCheck :: Matrix -> CheckResult
mutantCheck matrix = CheckResult "extension-declaration-mutants"
  [ observation "extension-declaration.mutant.optional-component" (receiptSummary (matrixOptionalMutant matrix))
  , observation "extension-declaration.mutant.drop-scope-index" (receiptSummary (matrixScopeMutant matrix))
  , observation "extension-declaration.mutant.omit-declared-recipe" (receiptSummary (matrixReaderMutant matrix)) ]
  ([finding "EXTENSION-DECLARATION-MUTANT" "optional-component" "the changed production API did not admit the four-component witness at RequiredComponents" |
      receiptExit (matrixOptionalMutant matrix) /= ExitSuccess || notContains "RED optional-component RequiredComponents" (receiptOutput (matrixOptionalMutant matrix))]
   <> [finding "EXTENSION-DECLARATION-MUTANT" "drop-scope-index" "the changed production API did not admit the cross-scope witness at ScopeIndexPreserved" |
      receiptExit (matrixScopeMutant matrix) /= ExitSuccess || notContains "RED drop-scope-index ScopeIndexPreserved" (receiptOutput (matrixScopeMutant matrix))]
   <> [finding "EXTENSION-DECLARATION-MUTANT" "omit-declared-recipe" "the changed production reader did not turn red at ArtifactReaderComplete" |
      receiptExit (matrixReaderMutant matrix) /= ExitFailure 1 || notContains "ArtifactReaderComplete" (receiptOutput (matrixReaderMutant matrix))])

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.pack <$> readFile (root </> productionSource)
  oracle <- Text.intercalate "\n" <$> mapM (fmap Text.pack . readFile . (root </>)) oracleSources
  let productionTokens = ["ExtensionDeclaration", "declareExtension", "declarationResource", "declarationDigest",
        "EXTENSION_DECLARATION_OPTIONAL_COMPONENT_MUTANT", "EXTENSION_DECLARATION_DROPS_SCOPE_INDEX_MUTANT", "EXTENSION_DECLARATION_OMIT_DECLARED_RECIPE_MUTANT"]
      oracleTokens = ["declarationCases", "oracleDeclarationDigest", "ArtifactReaderComplete", "EXTENSION_DECLARATION_TEST_CROSS_SCOPE"]
  pure (CheckResult "extension-declaration-source-discipline"
    [observation "extension-declaration.production-module-count" "1", observation "extension-declaration.effect-boundary" "pure Register-1 declaration; no host, network, service, cluster, or hardware effects"]
    ([finding "EXTENSION-DECLARATION-SOURCE-SHAPE" productionSource ("missing production element: " <> token) | token <- productionTokens, notContains token production]
     <> [finding "EXTENSION-DECLARATION-ORACLE-SHAPE" "<phase-20-oracle>" ("missing oracle element: " <> token) | token <- oracleTokens, notContains token oracle]
     <> [finding "EXTENSION-DECLARATION-SOURCE-DISCIPLINE" productionSource ("forbidden production token: " <> token) |
          token <- ["unsafePerformIO", "undefined", "pb validate", "System.Process", "Network.HTTP"], not (notContains token production)]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "extension-declaration-discovery"
  [observation "extension-declaration.discovery.count" (Text.pack (show (length observed)))]
  [finding "EXTENSION-DECLARATION-DISCOVERY" "<phase-20-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "extension-declaration-authority"
  [observation "extension-declaration.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children",
   observation "extension-declaration.register" "Register 1 pure/build claim; runtime fidelity UNVERIFIED"]
  ([finding "EXTENSION-DECLARATION-RUN-ROOT" runRoot "run root escaped .build/runs/phase-20/work" | not (pathBelow (root </> ".build/runs/phase-20/work") runRoot)]
   <> [finding "EXTENSION-DECLARATION-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-20 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "extension-declaration-observer"
  (map (observation "extension-declaration.observer.process" . receiptSummary) receipts)
  [finding "EXTENSION-DECLARATION-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "extension-declaration-freshness"
  [observation "extension-declaration.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "EXTENSION-DECLARATION-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-20/work") runRoot)]

generatedCheck :: FilePath -> FilePath -> IO CheckResult
generatedCheck root runRoot = do
  let paths = [runRoot </> "generated/clean/phase-results.tsv", runRoot </> "generated/clean/actual-declarations.tsv"]
  present <- mapM doesFileExist paths
  pure (CheckResult "extension-declaration-generated-products"
    [observation "extension-declaration.generated-count" (Text.pack (show (length (filter id present)))), observation "extension-declaration.generated-root" (Text.pack (makeRelative root (runRoot </> "generated/clean")))]
    [finding "EXTENSION-DECLARATION-GENERATED" (makeRelative root path) "a fresh generated result is absent" | (path, False) <- zip paths present])

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "extension-declaration-legacy-closure"
    [observation "extension-declaration.legacy.retired-count" (Text.pack (show (length retiredSources)))]
    [finding "EXTENSION-DECLARATION-LEGACY" path "retired Python gate, serialized behavioral authority, or test-local mutant remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positive negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-20-claim" [pre], named "phase-20-subject" [toolchain, positive], named "phase-20-command" [toolchain, authority],
   named "phase-20-oracle" [oracle], named "phase-20-positive-controls" [positive], named "phase-20-paired-negatives" [negatives],
   named "phase-20-mutants" [mutants], named "phase-20-discovery" [discovery], named "phase-20-challenge" [mutants],
   named "phase-20-observer" [observer], named "phase-20-authority-bypass" [authority], named "phase-20-freshness" [freshness],
   named "phase-20-qualification" [qualification], named "phase-20-cleanroom" [cleanroom], named "phase-20-legacy-closure" [legacy],
   CheckResult "phase-20-predecessor" [observation "phase-20.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-20-residue" [observation "phase-20.residue" "extension laws, conformance verdicts, decode, effects, runtimes, host, service, cluster, and hardware claims remain later-owned"] [],
   named "phase-20-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "extension-declaration-source-repository-cache" [observation "extension-declaration.cache.entries" (Text.pack (show copied))]
    [finding "EXTENSION-DECLARATION-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-20/work"
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
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "AMOEBIUS_EXTENSION_DECLARATION_OUTPUT"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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
matrixReceipts matrix = [matrixOptionalMutant matrix, matrixScopeMutant matrix, matrixReaderMutant matrix,
  matrixIllegalOptional matrix, matrixIllegalScope matrix, matrixLegal matrix, matrixClean matrix]

productionSources, oracleSources, expectedSources, retiredSources :: [FilePath]
productionSources = [productionSource]
oracleSources = sort ["test/spec/extension/ExtensionDeclarationSpec.hs", "test/spec/extension/ExtensionDeclarationOracle.hs", "test/negative/compile_fail/extension_declaration/DeclarationCompile.hs"]
expectedSources = sort (productionSources <> oracleSources)
retiredSources =
  [ "tools/extension_declaration_gate.py"
  , "test/mutant/extension_declaration/ExtensionDeclarationMutants.hs"
  , "test/oracle/extension_declaration/inventory.tsv"
  , "test/oracle/extension_declaration/mutation_catalog.tsv"
  ]

oracleSource, compileSource :: FilePath
oracleSource = "test/spec/extension/ExtensionDeclarationOracle.hs"
compileSource = "test/negative/compile_fail/extension_declaration/DeclarationCompile.hs"

productionSource :: FilePath
productionSource = "src/extension-declaration/Amoebius/Extension/Declaration.hs"
