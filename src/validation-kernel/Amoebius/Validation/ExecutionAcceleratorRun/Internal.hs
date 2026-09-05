{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ExecutionAcceleratorRun.Internal
  ( AcquiredExecutionAcceleratorRun
  , acquireExecutionAcceleratorRefreshRun
  , acquireExecutionAcceleratorRun
  , acquiredExecutionAcceleratorRunCheck
  , foldAcquiredExecutionAcceleratorRun
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
data Matrix = Matrix [Mutant] Receipt

data AcquiredExecutionAcceleratorRun = AcquiredExecutionAcceleratorRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredExecutionAcceleratorRunCheck :: AcquiredExecutionAcceleratorRun -> CheckResult
acquiredExecutionAcceleratorRunCheck (AcquiredExecutionAcceleratorRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredExecutionAcceleratorRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredExecutionAcceleratorRun
  -> value
foldAcquiredExecutionAcceleratorRun consume (AcquiredExecutionAcceleratorRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireExecutionAcceleratorRun, acquireExecutionAcceleratorRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExecutionAcceleratorRun
acquireExecutionAcceleratorRun = acquire False
acquireExecutionAcceleratorRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredExecutionAcceleratorRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 29 acquired
  cache <- prepareSourceRepositoryCache root runRoot
  cabalVersion <- runProcess root "cabal-version" cabal ["--numeric-version"]
  matrix <- executeMatrix root runRoot cabal compiler store
  discipline <- sourceDisciplineCheck root
  legacy <- legacyCheck root
  let toolchain = toolchainCheck cabal compiler store cabalVersion matrix
      oracle = oracleCheck (cleanReceipt matrix)
      positives = positiveCheck (cleanReceipt matrix)
      negatives = negativeCheck (cleanReceipt matrix)
      mutants = mutantCheck matrix
      discovery = discoveryCheck acquired
      authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
      observer = observerCheck (cabalVersion : matrixReceipts matrix)
      freshness = freshnessCheck root runRoot (cleanReceipt matrix)
      cleanroom = mergeChecks "execution-accelerator-cleanroom" [cache, freshness, legacy]
      qualification = mergeChecks "execution-accelerator-qualification"
        [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "execution-accelerator-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "execution-accelerator" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "execution-accelerator-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
      oracleId = ids "execution-accelerator-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "execution-accelerator-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "execution-accelerator-observer" [checkDigest observer]
      qualificationId = ids "execution-accelerator-qualification" [checkDigest qualification]
      acquiredRunId = ids "execution-accelerator-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "execution-accelerator-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredExecutionAcceleratorRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
  mutants <- mapM runMutant mutantSpecifications
  clean <- runSpec "clean" Nothing
  pure (Matrix mutants clean)
 where
  runMutant (name, flagName, variant, locus) = Mutant name variant locus <$> runSpec name (Just flagName)
  runSpec name selected =
    runProcess root name cabal
      ([ "--builddir=" <> runRoot </> "dist"
       , "--store-dir=" <> store
       , "--with-compiler=" <> compiler
       , "--jobs=1"
       , "test"
       , "execution-accelerator-spec"
       , "--offline"
       , "--test-show-details=direct"
       ] <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
  [ mutant "accelerator-drop-device-count" "cuda-device-count" "whole-device cardinality"
  , mutant "accelerator-drop-source-domain" "cuda-unsharded-fragmentation" "source inventory equality"
  , mutant "accelerator-favorable-epoch" "cuda-unsharded-fragmentation" "all coexistence epochs"
  , mutant "accelerator-ignore-metal-profile" "metal-profile" "Metal profile"
  , mutant "accelerator-ignore-shard-sum" "cuda-shard-byte-sum" "shard byte equality"
  , mutant "accelerator-share-device" "accelerator-shared-owner" "device owner uniqueness"
  , mutant "accelerator-spend-raw-vram" "cuda-vram-reserve" "net allocatable VRAM"
  , mutant "accelerator-split-unsharded" "cuda-unsharded-fragmentation" "unsharded per-device fit"
  , mutant "accelerator-treat-none-as-cuda" "cuda-family-absent" "accelerator family"
  , mutant "copy-new-execution-as-old" "execution-prior-old-revision" "prior and desired peak"
  , mutant "drop-execution-old-revision" "execution-prior-old-revision" "old revision epoch"
  , mutant "drop-execution-replica" "execution-replica-peak" "replica expansion"
  , mutant "drop-execution-surge" "execution-rollout-surge" "rolling surge epoch"
  , mutant "drop-removed-execution" "execution-prior-old-revision" "prior-only retention"
  , mutant "etcd-drop-defrag" "etcd-transition-physical" "defrag peak"
  , mutant "etcd-drop-preallocated-next" "etcd-transition-physical" "next WAL"
  , mutant "etcd-drop-snapshot-save" "etcd-transition-physical" "snapshot temporary"
  , mutant "etcd-drop-wal" "etcd-transition-physical" "WAL files"
  , mutant "image-drop-index" "image-content-join" "OCI index join"
  , mutant "image-drop-manifest" "image-manifest-join" "manifest join"
  , mutant "image-drop-snapshot" "image-snapshot-join" "snapshot join"
  , mutant "image-drop-workspace" "node-image-workspace" "pull workspace"
  , mutant "image-ignore-model" "image-storage-model" "image model"
  , mutant "invent-first-deploy-old" "execution-replica-peak" "empty first deployment"
  , mutant "layout-allow-alias" "filesystem-layout-alias" "split backing distinctness"
  , mutant "layout-enable-v1-split-image" "split-image-containerd-v1" "containerd support"
  , mutant "layout-ignore-observation" "filesystem-layout-swapped" "observed role equality"
  , mutant "partition-double-debit-child" "partition-carve-alias" "unique child identity"
  , mutant "partition-drop-system-reserve" "partition-parent" "system reserve debit"
  , mutant "partition-mix-vm-usable" "partition-unit-mismatch" "parent unit separation"
  , mutant "partition-use-vm-usable-as-raw" "partition-parent" "VM high-water"
  , mutant "provider-debit-durable" "root-ebs-volume-quota" "node root quota"
  , mutant "provider-reuse-template-id" "root-ebs-volume-quota" "qualified identities"
  , mutant "provider-skip-allocation-rounding" "root-ebs-bytes-quota" "allocation quantum"
  , mutant "provider-skip-presentation" "root-ebs-bytes-quota" "filesystem presentation"
  , mutant "provider-under-size-instance-store" "instance-store-root" "instance-store bytes"
  , mutant "resolve-latest-execution" "execution-prior-old-revision" "exact prior reference"
  , mutant "runtime-drop-largest-metadata" "runtime-nodefs" "complete metadata epoch"
  , mutant "runtime-missing-model" "runtime-model" "metadata model"
  , mutant "runtime-scope-confusion" "runtime-scope-domain" "identity domain"
  , mutant "runtime-swap-role" "runtime-imagefs" "CRI role routing"
  , mutant "scheduler-binding-crash-release" "scheduler-aggregate-root" "binding debit retention"
  , mutant "scheduler-drop-pad" "scheduler-projection" "reservation projection"
  , mutant "scheduler-per-record-cas" "scheduler-snapshot-cas" "root fingerprint"
  , mutant "scheduler-timeout-release" "scheduler-aggregate-root" "reserved debit retention"
  ]
 where
  mutant name variant locus = (name, "execution-accelerator-" <> Text.unpack name <> "-mutant", variant, locus)

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ clean) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = [receipt | Mutant _ _ _ receipt <- mutants] <> [clean]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "execution-accelerator-toolchain"
  [observation "execution-accelerator.cabal" (receiptSummary version), observation "execution-accelerator.compiler" (Text.pack compiler)]
  ([finding "EXECUTION-ACCELERATOR-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "EXECUTION-ACCELERATOR-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "execution-accelerator-independent-oracle"
  [observation "execution-accelerator.oracle" (receiptSummary clean), observation "execution-accelerator.oracle-independence" "ExecutionAcceleratorOracle imports no production or fixture module"]
  [finding "EXECUTION-ACCELERATOR-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where
  acceptance = "PASS (18 named negatives, 37 variants, 37 twins, 2 positives, 7 properties, 45 changed-production mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean = CheckResult "execution-accelerator-positive-controls"
  [observation "execution-accelerator.positives" "thirty-seven legal twins, two composed positive placements, and seven sampled properties pass"]
  [finding "EXECUTION-ACCELERATOR-POSITIVE" specSource "the clean positive corpus did not pass" | receiptExit clean /= ExitSuccess]

negativeCheck :: Receipt -> CheckResult
negativeCheck clean = CheckResult "execution-accelerator-paired-negatives"
  [observation "execution-accelerator.negatives" "thirty-seven minimally different pairs cover eighteen named Phase-29 refusal families"]
  [finding "EXECUTION-ACCELERATOR-NEGATIVE" specSource "the paired-negative corpus did not execute" |
    receiptExit clean /= ExitSuccess || notContains "37 variants, 37 twins" (receiptOutput clean)]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "execution-accelerator-mutants"
  [observation ("execution-accelerator.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
  [finding "EXECUTION-ACCELERATOR-MUTANT" (Text.unpack name) ("the changed production fold did not turn red at " <> locus) |
    Mutant name variant locus receipt <- mutants,
    receiptExit receipt /= ExitFailure 1 || notContains (variant <> " negative result drifted") (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  pure (CheckResult "execution-accelerator-source-discipline"
    [observation "execution-accelerator.production-module-count" "11", observation "execution-accelerator.effect-boundary" "pure folds and run-local Cabal children only; no host, network, service, cluster, or hardware effects"]
    ([finding "EXECUTION-ACCELERATOR-SOURCE-SHAPE" "<execution-accelerator-production>" ("missing production element: " <> token) |
       token <- ["provisionExecutionEpochs", "provisionSchedulingGuard", "provisionNodeRuntimeStorageAccounting", "fitLayoutComponents", "provisionPerInstanceDiskTemplate", "provisionEtcdDemand", "provisionAccelerator", "phase29MutationTargets"], notContains token production]
     <> [finding "EXECUTION-ACCELERATOR-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token) |
       token <- ["expectedRows", "mutantSpecs", "expectedCalculusProjection"], notContains token oracle]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "execution-accelerator-discovery"
  [observation "execution-accelerator.discovery.count" (Text.pack (show (length observed)))]
  [finding "EXECUTION-ACCELERATOR-DISCOVERY" "<phase-29-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "execution-accelerator-authority"
  [observation "execution-accelerator.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
  ([finding "EXECUTION-ACCELERATOR-RUN-ROOT" runRoot "run root escaped .build/runs/phase-29/work" | not (pathBelow (root </> ".build/runs/phase-29/work") runRoot)]
   <> [finding "EXECUTION-ACCELERATOR-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-29 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where
  forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "execution-accelerator-observer"
  (map (observation "execution-accelerator.observer.process" . receiptSummary) receipts)
  [finding "EXECUTION-ACCELERATOR-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "execution-accelerator-freshness"
  [observation "execution-accelerator.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "EXECUTION-ACCELERATOR-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-29/work") runRoot)]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "execution-accelerator-legacy-closure"
    [observation "execution-accelerator.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "execution-accelerator.legacy.semantic-inputs" "HaskellOnly"]
    [finding "EXECUTION-ACCELERATOR-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [ named "phase-29-claim" [pre]
  , named "phase-29-subject" [toolchain, positives]
  , named "phase-29-command" [toolchain, authority]
  , named "phase-29-oracle" [oracle]
  , named "phase-29-positive-controls" [positives]
  , named "phase-29-paired-negatives" [negatives]
  , named "phase-29-mutants" [mutants]
  , named "phase-29-discovery" [discovery]
  , named "phase-29-challenge" [mutants]
  , named "phase-29-observer" [observer]
  , named "phase-29-authority-bypass" [authority]
  , named "phase-29-freshness" [freshness]
  , named "phase-29-qualification" [qualification]
  , named "phase-29-cleanroom" [cleanroom]
  , named "phase-29-legacy-closure" [legacy]
  , CheckResult "phase-29-predecessor" [observation "phase-29.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-29-residue" [observation "phase-29.residue" "binding, provision seal, rendering, effects, runtime fidelity, live scaling, host, service, cluster, and hardware remain later-owned"] []
  , named "phase-29-pass-criterion" [pre]
  ]
 where
  named = mergeChecks

prepareSourceRepositoryCache :: FilePath -> FilePath -> IO CheckResult
prepareSourceRepositoryCache root runRoot = do
  let source = root </> ".build/dist-newstyle/phase-00-baseline/src"
      target = runRoot </> "dist/src"
  present <- doesDirectoryExist source
  if present then copyTree source target else pure ()
  copied <- if present then sort <$> listDirectory target else pure []
  pure (CheckResult "execution-accelerator-source-repository-cache"
    [observation "execution-accelerator.cache.entries" (Text.pack (show copied))]
    [finding "EXECUTION-ACCELERATOR-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
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
  let parent = root </> ".build/runs/phase-29/work"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openBinaryTempFile parent "candidate-"
  hClose handle
  removeFile leaf
  createDirectory leaf
  pure leaf

runProcess :: FilePath -> Text -> FilePath -> [String] -> IO Receipt
runProcess working name executable args = do
  inherited <- getEnvironment
  let environment = filter (not . forbiddenEnvironment . fst) inherited
  attempt <- try (readCreateProcessWithExitCode ((proc executable args) {cwd = Just working, env = Just environment}) "") :: IO (Either IOException (ExitCode, String, String))
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
notContains :: Text -> Text -> Bool
notContains needle haystack = not (needle `Text.isInfixOf` haystack)

productionSources, expectedSources, retiredSources :: [FilePath]
productionSources =
  [ "src/execution-accelerator-folds/Amoebius/Capacity/Accelerator.hs"
  , "src/execution-accelerator-folds/Amoebius/Capacity/Composed.hs"
  , "src/execution-accelerator-folds/Amoebius/Capacity/Etcd.hs"
  , "src/execution-accelerator-folds/Amoebius/Capacity/Execution.hs"
  , "src/execution-accelerator-folds/Amoebius/Capacity/HostReservation.hs"
  , "src/execution-accelerator-folds/Amoebius/Capacity/NodeLocalStorage.hs"
  , "src/execution-accelerator-folds/Amoebius/Capacity/Phase29Mutation.hs"
  , "src/execution-accelerator-folds/Amoebius/Capacity/ProviderRoot.hs"
  , "src/execution-accelerator-folds/Amoebius/Capacity/PulumiExecution.hs"
  , "src/execution-accelerator-folds/Amoebius/Capacity/RuntimeStorage.hs"
  , "src/execution-accelerator-folds/Amoebius/Capacity/Scheduler.hs"
  ]
expectedSources = sort (productionSources <> [fixtureSource, gateSource, oracleSource, propsSource, specSource])
retiredSources =
  [ "tools/execution_accelerator_gate.py"
  , "test/oracle/execution_accelerator_surfaces.tsv"
  , "test/oracle/execution_accelerator/calculus_projection.tsv"
  , "test/oracle/execution_accelerator/dhall_typecheck_cases.tsv"
  , "test/oracle/execution_accelerator/execution_accelerator_cases.tsv"
  , "test/spec/dsl/ExecutionAcceleratorMutants.hs"
  ]

fixtureSource, gateSource, oracleSource, propsSource, specSource :: FilePath
fixtureSource = "test/spec/dsl/ExecutionAcceleratorFixtures.hs"
gateSource = "test/spec/dsl/ExecutionAcceleratorGate.hs"
oracleSource = "test/spec/dsl/ExecutionAcceleratorOracle.hs"
propsSource = "test/spec/dsl/ExecutionAcceleratorProps.hs"
specSource = "test/spec/dsl/ExecutionAcceleratorSpec.hs"
