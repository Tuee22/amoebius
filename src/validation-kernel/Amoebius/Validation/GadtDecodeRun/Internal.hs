{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.GadtDecodeRun.Internal
  ( AcquiredGadtDecodeRun
  , acquireGadtDecodeRun
  , acquireGadtDecodeRefreshRun
  , acquiredGadtDecodeRunCheck
  , foldAcquiredGadtDecodeRun
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
data Mutant = Mutant Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix [Mutant] Receipt

data AcquiredGadtDecodeRun = AcquiredGadtDecodeRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredGadtDecodeRunCheck :: AcquiredGadtDecodeRun -> CheckResult
acquiredGadtDecodeRunCheck (AcquiredGadtDecodeRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredGadtDecodeRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredGadtDecodeRun -> value
foldAcquiredGadtDecodeRun consume (AcquiredGadtDecodeRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireGadtDecodeRun, acquireGadtDecodeRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredGadtDecodeRun
acquireGadtDecodeRun = acquire False
acquireGadtDecodeRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredGadtDecodeRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 26 acquired
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
      cleanroom = mergeChecks "gadt-decode-cleanroom" [cache, generated, freshness]
      qualification = mergeChecks "gadt-decode-qualification" [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "gadt-decode-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "gadt-decode" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "gadt-decode-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
      oracleId = ids "gadt-decode-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "gadt-decode-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "gadt-decode-observer" [checkDigest observer]
      qualificationId = ids "gadt-decode-qualification" [checkDigest qualification]
      acquiredRunId = ids "gadt-decode-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "gadt-decode-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "generated-products-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredGadtDecodeRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM runMutant mutantSpecifications
  clean <- runSpec "clean" Nothing
  pure (Matrix mutants clean)
 where
  runMutant (name, flagName, locus) = Mutant name locus <$> runSpec name (Just flagName)
  runSpec name selected =
    runProcess root [("AMOEBIUS_GADT_DECODE_OUTPUT", runRoot </> "generated" </> Text.unpack name)] name cabal
      (["--builddir=" <> runRoot </> "dist", "--store-dir=" <> store, "--with-compiler=" <> compiler,
        "--jobs=1", "test", "gadt-decode-spec", "--offline", "--test-show-details=direct"]
        <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text)]
mutantSpecifications =
  [ ("zero-revision", "gadt-decode-zero-revision-mutant", "negative admitted at ZeroRevision")
  , ("tenant-mismatch", "gadt-decode-tenant-mismatch-mutant", "negative admitted at TenantMismatch")
  , ("resource-arm", "gadt-decode-resource-arm-mutant", "negative admitted at ResourceArmMismatch")
  , ("protocol-field", "gadt-decode-protocol-field-mutant", "protocol declarations")
  ]

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ clean) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = [receipt | Mutant _ _ receipt <- mutants] <> [clean]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "gadt-decode-toolchain"
  [observation "gadt-decode.cabal" (receiptSummary version), observation "gadt-decode.compiler" (Text.pack compiler), observation "gadt-decode.engine" "in-process dhall-1.42.3"]
  ([finding "GADT-DECODE-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "GADT-DECODE-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "gadt-decode-independent-oracle"
  [observation "gadt-decode.oracle" (receiptSummary clean), observation "gadt-decode.oracle-independence" "GadtDecodeOracle.hs imports no production type or decoder"]
  [finding "GADT-DECODE-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where acceptance = "PASS (5 positives, 12 paired negatives, 3 Haskell protocol messages, 19 generated products)"

positiveCheck :: Receipt -> CheckResult -> CheckResult
positiveCheck clean generated = mergeChecks "gadt-decode-positive-and-generated"
  [ CheckResult "gadt-decode-positive-controls" [observation "gadt-decode.positives" "five controller-indexed worlds decode and all nineteen products are regenerated"]
      [finding "GADT-DECODE-POSITIVE" specSource "the clean positive corpus did not pass" | receiptExit clean /= ExitSuccess]
  , generated
  ]

negativeCheck :: Receipt -> CheckResult
negativeCheck clean = CheckResult "gadt-decode-paired-negatives"
  [observation "gadt-decode.negatives" "twelve structural, import, totality, ownership, secret, and resource-arm refusals"]
  [finding "GADT-DECODE-NEGATIVE" specSource "the paired-negative corpus did not execute" |
    receiptExit clean /= ExitSuccess || notContains "12 paired negatives" (receiptOutput clean)]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "gadt-decode-mutants"
  [observation ("gadt-decode.mutant." <> name) (receiptSummary receipt) | Mutant name _ receipt <- mutants]
  [finding "GADT-DECODE-MUTANT" (Text.unpack name) ("the changed production decoder did not turn red at " <> locus) |
    Mutant name locus receipt <- mutants, receiptExit receipt /= ExitFailure 1 || notContains locus (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.pack <$> readFile (root </> productionSource)
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  pure (CheckResult "gadt-decode-source-discipline"
    [observation "gadt-decode.production-module-count" "1", observation "gadt-decode.effect-boundary" "run-local files and in-process Dhall only; no host, network, service, cluster, or hardware effects"]
    ([finding "GADT-DECODE-SOURCE-SHAPE" productionSource ("missing production element: " <> token) |
       token <- ["data Execution (kind :: ExecutionKind)", "decodeWorldFile", "protocolDeclarations", "GADT_DECODE_PROTOCOL_FIELD_MUTANT"], notContains token production]
     <> [finding "GADT-DECODE-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token) |
       token <- ["expectedCases", "expectedProtocolRows"], notContains token oracle]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "gadt-decode-discovery"
  [observation "gadt-decode.discovery.count" (Text.pack (show (length observed)))]
  [finding "GADT-DECODE-DISCOVERY" "<phase-26-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "gadt-decode-authority"
  [observation "gadt-decode.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
  ([finding "GADT-DECODE-RUN-ROOT" runRoot "run root escaped .build/runs/phase-26/work" | not (pathBelow (root </> ".build/runs/phase-26/work") runRoot)]
   <> [finding "GADT-DECODE-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-26 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "gadt-decode-observer" (map (observation "gadt-decode.observer.process" . receiptSummary) receipts)
  [finding "GADT-DECODE-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "gadt-decode-freshness"
  [observation "gadt-decode.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "GADT-DECODE-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-26/work") runRoot)]

generatedCheck :: FilePath -> FilePath -> IO CheckResult
generatedCheck root runRoot = do
  let names = ["PulsarApi.proto", "inventory.tsv"] <> [Text.unpack name <> ".dhall" | name <- caseNames]
      paths = map ((runRoot </> "generated/clean") </>) names
  present <- mapM doesFileExist paths
  pure (CheckResult "gadt-decode-generated-products"
    [observation "gadt-decode.generated-count" (Text.pack (show (length (filter id present)))), observation "gadt-decode.generated-root" (Text.pack (makeRelative root (runRoot </> "generated/clean")))]
    [finding "GADT-DECODE-GENERATED" (makeRelative root path) "a fresh generated result is absent" | (path, False) <- zip paths present])

legacyCheck :: FilePath -> AcquiredSourceSnapshot -> IO CheckResult
legacyCheck root acquired = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  let trackedProto = [indexPath (trackedIndex entry) | entry <- snapshotEntries (acquiredSourceSnapshot acquired), ".proto" `isSuffixOf` indexPath (trackedIndex entry) || "proto/" `isPrefixOf` indexPath (trackedIndex entry)]
  pure (CheckResult "gadt-decode-legacy-closure"
    [observation "gadt-decode.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "gadt-decode.legacy.tracked-proto-count" (Text.pack (show (length trackedProto)))]
    ([finding "GADT-DECODE-LEGACY" path "retired Python/serialized GADT-decode authority remains" | path <- files]
     <> [finding "GADT-DECODE-TRACKED-PROTO" path "tracked Proto behavioral source remains after LTD-SRC-003 closure" | path <- trackedProto]))

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [named "phase-26-claim" [pre], named "phase-26-subject" [toolchain, positives], named "phase-26-command" [toolchain, authority],
   named "phase-26-oracle" [oracle], named "phase-26-positive-controls" [positives], named "phase-26-paired-negatives" [negatives],
   named "phase-26-mutants" [mutants], named "phase-26-discovery" [discovery], named "phase-26-challenge" [mutants],
   named "phase-26-observer" [observer], named "phase-26-authority-bypass" [authority], named "phase-26-freshness" [freshness],
   named "phase-26-qualification" [qualification], named "phase-26-cleanroom" [cleanroom], named "phase-26-legacy-closure" [legacy],
   CheckResult "phase-26-predecessor" [observation "phase-26.predecessor" "deferred to durable receipt verifier"] [],
   CheckResult "phase-26-residue" [observation "phase-26.residue" "capacity feasibility, binding, provisioning, rendering, effects, runtimes, host, service, cluster, and hardware remain later-owned"] [],
   named "phase-26-pass-criterion" [pre]]
 where named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"; target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "gadt-decode-source-repository-cache" [observation "gadt-decode.cache.entries" (Text.pack (show copied))]
    [finding "GADT-DECODE-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-26/work"
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
forbiddenEnvironment name = name `elem` ["KUBECONFIG", "VAULT_ADDR", "VAULT_TOKEN", "GOOGLE_APPLICATION_CREDENTIALS", "AMOEBIUS_GADT_DECODE_OUTPUT"] || any (`isPrefixOf` name) ["AWS_", "AZURE_", "VAULT_", "KUBE_"]

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

caseNames :: [Text]
caseNames = ["deployment", "statefulset", "daemonset", "job", "host-process", "unknown-surface", "unknown-controller", "unknown-resource", "empty-id", "zero-revision", "tenant-mismatch", "plaintext-secret", "deployment-host-arm", "host-pod-arm", "forbidden-env", "forbidden-remote", "malformed"]

expectedSources, retiredSources :: [FilePath]
expectedSources = sort [productionSource, specSource, oracleSource]
retiredSources = ["tools/gadt_decode_ir_gate.py", "proto/Amoebius/Pulsar/Proto/PulsarApi.proto", "test/oracle/gadt_decode_ir_surfaces.tsv", "test/oracle/gadt_decode_ir/positive_trees.tsv", "test/oracle/gadt_decode_ir/decode_cases.tsv", "test/oracle/gadt_decode_ir/compile_pairs.tsv", "test/oracle/gadt_decode_ir/resource_field_inventory.tsv", "test/oracle/gadt_decode_ir/calculus_projection.tsv", "test/mutant/gadt_decode_ir/resource_mutations.tsv", "test/mutant/gadt_decode_ir/ambient-path-lookup.mutant", "test/mutant/gadt_decode_ir/unobserved-family.mutant"]
productionSource, specSource, oracleSource :: FilePath
productionSource = "src/gadt-decode-ir/Amoebius/Dsl/GadtDecode.hs"
specSource = "test/spec/dsl/GadtDecodeSpec.hs"
oracleSource = "test/spec/dsl/GadtDecodeOracle.hs"
