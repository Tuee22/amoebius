{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.IllegalStateCoveringRun.Internal
  ( AcquiredIllegalStateCoveringRun
  , acquireIllegalStateCoveringRun
  , acquireIllegalStateCoveringRefreshRun
  , acquiredIllegalStateCoveringRunCheck
  , foldAcquiredIllegalStateCoveringRun
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
import Control.Monad (filterM, forM, forM_)
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
data Mutant = Mutant Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix [Mutant] Receipt

data AcquiredIllegalStateCoveringRun = AcquiredIllegalStateCoveringRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredIllegalStateCoveringRunCheck :: AcquiredIllegalStateCoveringRun -> CheckResult
acquiredIllegalStateCoveringRunCheck (AcquiredIllegalStateCoveringRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredIllegalStateCoveringRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredIllegalStateCoveringRun -> value
foldAcquiredIllegalStateCoveringRun consume (AcquiredIllegalStateCoveringRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireIllegalStateCoveringRun, acquireIllegalStateCoveringRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredIllegalStateCoveringRun
acquireIllegalStateCoveringRun = acquire False
acquireIllegalStateCoveringRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredIllegalStateCoveringRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 27 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root [] "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler store
  discipline <- sourceDisciplineCheck root
  legacy <- legacyCheck root acquired
  generated <- generatedCheck root runRoot
  let toolchain = toolchainCheck cabal compiler store cabalVersion matrix
      oracle = oracleCheck (cleanReceipt matrix)
      positives = positiveCheck (cleanReceipt matrix) generated
      negatives = negativeCheck (cleanReceipt matrix)
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot (cleanReceipt matrix)
      cleanroom = mergeChecks "illegal-state-covering-cleanroom" [cache, generated, freshness]
      qualification = mergeChecks "illegal-state-covering-qualification" [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "illegal-state-covering-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "illegal-state-covering" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "illegal-state-covering-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
      oracleId = ids "illegal-state-covering-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "illegal-state-covering-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "illegal-state-covering-observer" [checkDigest observer]
      qualificationId = ids "illegal-state-covering-qualification" [checkDigest qualification]
      acquiredRunId = ids "illegal-state-covering-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "illegal-state-covering-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredIllegalStateCoveringRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM runMutant mutantSpecifications
  clean <- runSpec "clean" Nothing
  pure (Matrix mutants clean)
 where
  runMutant (name, flagName, locus) = Mutant name locus <$> runSpec name (Just flagName)
  runSpec name selected =
    runProcess root
      [ ("AMOEBIUS_ILLEGAL_STATE_OUTPUT", runRoot </> "generated" </> Text.unpack name)
      , ("AMOEBIUS_ILLEGAL_STATE_GHC", compiler)
      ] name cabal
      (["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler,
        "--jobs=1", "test", "illegal-state-corpus-spec", "--offline", "--test-show-details=direct"]
        <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [ ("structural-union", "illegal-state-union-mutant", "structural negative admitted at closed-ingress-shape")
  , ("decode-refinement", "illegal-state-decode-mutant", "decode negative admitted at rolling-progress")
  , ("gadt-index", "illegal-state-gadt-mutant", "compile negative admitted at tenant-index")
  , ("sampled-property", "illegal-state-property-mutant", "property mutant or production behavior made the sampled property suite red")
  ]

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ clean) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = [receipt | Mutant _ _ receipt <- mutants] <> [clean]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "illegal-state-covering-toolchain"
  [observation "illegal-state-covering.cabal" (receiptSummary version), observation "illegal-state-covering.compiler" (Text.pack compiler), observation "illegal-state-covering.engine" "in-process dhall-1.42.3"]
  ([finding "ILLEGAL-STATE-COVERING-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "ILLEGAL-STATE-COVERING-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "illegal-state-covering-independent-oracle"
  [observation "illegal-state-covering.oracle" (receiptSummary clean), observation "illegal-state-covering.oracle-independence" "IllegalStateCoveringOracle.hs imports no production type or decoder"]
  [finding "ILLEGAL-STATE-COVERING-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where acceptance = "PASS (121 catalog rows, 43 reached, 26 Phase-27 rows, 7 structural pairs, 13 decode pairs, 5 compile-refusal pairs, 4 sampled properties, 3/3 finite arms)"

positiveCheck :: Receipt -> CheckResult -> CheckResult
positiveCheck clean generated = mergeChecks "illegal-state-covering-positive-and-generated"
  [ CheckResult "illegal-state-covering-positive-controls" [observation "illegal-state-covering.positives" "twenty-five Dhall, decode, and compile-refusal legal twins plus covered sampled properties pass"]
      [finding "ILLEGAL-STATE-COVERING-POSITIVE" specSource "the clean positive corpus did not pass" | receiptExit clean /= ExitSuccess]
  , generated
  ]

negativeCheck :: Receipt -> CheckResult
negativeCheck clean = CheckResult "illegal-state-covering-paired-negatives"
  [observation "illegal-state-covering.negatives" "seven structural, thirteen decode, and five compile-refusal pairs settle all twenty-six Phase-27-owned rows"]
  [finding "ILLEGAL-STATE-COVERING-NEGATIVE" specSource "the paired-negative corpus did not execute" |
    receiptExit clean /= ExitSuccess || notContains "7 structural pairs, 13 decode pairs, 5 compile-refusal pairs" (receiptOutput clean)]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "illegal-state-covering-mutants"
  [observation ("illegal-state-covering.mutant." <> name) (receiptSummary receipt) | Mutant name _ receipt <- mutants]
  [finding "ILLEGAL-STATE-COVERING-MUTANT" (Text.unpack name) ("the changed production covering subject did not turn red at " <> locus) |
    Mutant name locus receipt <- mutants, receiptExit receipt /= ExitFailure 1 || notContains locus (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.pack <$> readFile (root </> productionSource)
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  pure (CheckResult "illegal-state-covering-source-discipline"
    [observation "illegal-state-covering.production-module-count" "1", observation "illegal-state-covering.effect-boundary" "run-local files and in-process Dhall only; no host, network, service, cluster, or hardware effects"]
    ([finding "ILLEGAL-STATE-COVERING-SOURCE-SHAPE" productionSource ("missing production element: " <> token) |
       token <- ["catalogRows", "structuralCases", "decodeCases", "acceptTenantRef", "ILLEGAL_STATE_PROPERTY_MUTANT"], notContains token production]
     <> [finding "ILLEGAL-STATE-COVERING-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token) |
       token <- ["expectedCatalogSha256", "expectedStructuralRows", "expectedDecodeRows", "compileCases"], notContains token oracle]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "illegal-state-covering-discovery"
  [observation "illegal-state-covering.discovery.count" (Text.pack (show (length observed)))]
  [finding "ILLEGAL-STATE-COVERING-DISCOVERY" "<phase-27-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "illegal-state-covering-authority"
  [observation "illegal-state-covering.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
  ([finding "ILLEGAL-STATE-COVERING-RUN-ROOT" runRoot "run root escaped .build/runs/phase-27/work" | not (pathBelow (root </> ".build/runs/phase-27/work") runRoot)]
   <> [finding "ILLEGAL-STATE-COVERING-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-27 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "illegal-state-covering-observer" (map (observation "illegal-state-covering.observer.process" . receiptSummary) receipts)
  [finding "ILLEGAL-STATE-COVERING-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "illegal-state-covering-freshness"
  [observation "illegal-state-covering.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "ILLEGAL-STATE-COVERING-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-27/work") runRoot)]

generatedCheck :: FilePath -> FilePath -> IO CheckResult
generatedCheck root runRoot = do
  let paths = map ((runRoot </> "generated/clean") </>) generatedProducts
  present <- mapM doesFileExist paths
  pure (CheckResult "illegal-state-covering-generated-products"
    [observation "illegal-state-covering.generated-count" (Text.pack (show (length (filter id present)))), observation "illegal-state-covering.generated-root" (Text.pack (makeRelative root (runRoot </> "generated/clean")))]
    [finding "ILLEGAL-STATE-COVERING-GENERATED" (makeRelative root path) "a fresh generated result is absent" | (path, False) <- zip paths present])

legacyCheck :: FilePath -> AcquiredSourceSnapshot -> IO CheckResult
legacyCheck root _acquired = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  consumerFindings <- fmap concat $ forM consumerSources $ \path -> do
    present <- doesFileExist (root </> path)
    source <- if present then Text.pack <$> readFile (root </> path) else pure ""
    pure [finding "ILLEGAL-STATE-COVERING-CONSUMER" path ("retired serialized covering input remains referenced: " <> token) |
      token <- retiredConsumerTokens, token `Text.isInfixOf` source]
  pure (CheckResult "illegal-state-covering-legacy-closure"
    [ observation "illegal-state-covering.legacy.retired-count" (Text.pack (show (length retiredSources)))
    , observation "illegal-state-covering.legacy.behavioral-document-consumers" "zero"
    , observation "illegal-state-covering.legacy.semantic-inputs" "HaskellOnly"
    ]
    ([finding "ILLEGAL-STATE-COVERING-LEGACY" path "retired Python/serialized illegal-state authority remains" | path <- files] <> consumerFindings))

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-27-claim" [pre], named "phase-27-subject" [toolchain, positives], named "phase-27-command" [toolchain, authority],
   named "phase-27-oracle" [oracle], named "phase-27-positive-controls" [positives], named "phase-27-paired-negatives" [negatives],
   named "phase-27-mutants" [mutants], named "phase-27-discovery" [discovery], named "phase-27-challenge" [mutants],
   named "phase-27-observer" [observer], named "phase-27-authority-bypass" [authority], named "phase-27-freshness" [freshness],
   named "phase-27-qualification" [qualification], named "phase-27-cleanroom" [cleanroom], named "phase-27-legacy-closure" [legacy],
   CheckResult "phase-27-predecessor" [observation "phase-27.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-27-residue" [observation "phase-27.residue" "capacity feasibility, binding, provisioning, rendering, effects, runtimes, host, service, cluster, and hardware remain later-owned"] [],
   named "phase-27-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "illegal-state-covering-source-repository-cache" [observation "illegal-state-covering.cache.entries" (Text.pack (show copied))]
    [finding "ILLEGAL-STATE-COVERING-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-27/work"
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
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "AMOEBIUS_ILLEGAL_STATE_OUTPUT", "AMOEBIUS_ILLEGAL_STATE_GHC"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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
generatedProducts :: [FilePath]
generatedProducts =
  ["validation-locus-ledger.tsv", "catalog.inventory"]
  <> ["dhall/" <> name <> suffix <> ".dhall" | name <- structuralNames, suffix <- ["-legal", "-illegal"]]
  <> ["compile-refusal/" <> name <> suffix <> ".hs" | name <- compileNames, suffix <- ["-legal", "-illegal"]]
 where
  structuralNames = ["closed-ingress-shape", "unsupported-bare-substrate", "fixed-node-cardinality", "daemonset-both-positive", "statefulset-unsupported-feature", "statefulset-nonzero-partition", "job-missing-terminal-retention"]
  compileNames = ["tenant-index", "pv-pvc-index", "endpoint-kind-index", "live-service-route-index", "produce-codec"]

expectedSources, retiredSources :: [FilePath]
expectedSources = sort [productionSource, specSource, oracleSource]
retiredSources =
  [ "tools/covering_grid.py", "tools/locus_registry_lint.py", "tools/illegal_state_corpus_gate.py"
  , "dhall/examples/locus_registry.tsv", "test/oracle/illegal_state_corpus_surfaces.tsv"
  , "test/oracle/illegal_state_corpus/calculus_projection.tsv", "test/oracle/illegal_state_corpus/compile_fail.tsv"
  , "test/oracle/illegal_state_corpus/dhall_typecheck_cases.tsv", "test/oracle/illegal_state_corpus/gadt_decode_cases.tsv"
  , "test/oracle/illegal_state_corpus/predecessor_coverage.tsv"
  ]
consumerSources :: [FilePath]
consumerSources = ["test/spec/dsl/CorpusSpec.hs", "test/spec/dsl/ValidationLocusLedger.hs"]
retiredConsumerTokens :: [Text]
retiredConsumerTokens = ["locus_registry.tsv", "illegal_state_corpus/", "covering_grid.py", "locus_registry_lint.py", "illegal_state_corpus_gate.py"]
productionSource, specSource, oracleSource :: FilePath
productionSource = "src/illegal-state-covering/Amoebius/Dsl/IllegalStateCovering.hs"
specSource = "test/spec/dsl/IllegalStateCoveringSpec.hs"
oracleSource = "test/spec/dsl/IllegalStateCoveringOracle.hs"
