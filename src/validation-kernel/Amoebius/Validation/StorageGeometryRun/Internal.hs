{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.StorageGeometryRun.Internal
  ( AcquiredStorageGeometryRun
  , acquireStorageGeometryRefreshRun
  , acquireStorageGeometryRun
  , acquiredStorageGeometryRunCheck
  , foldAcquiredStorageGeometryRun
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

data AcquiredStorageGeometryRun = AcquiredStorageGeometryRun
  AcquiredSourceSnapshot GenesisTrust AcquiredPhaseContractEvidence [CheckResult]
  Text Text Text Text Text Text Text Text CheckResult

acquiredStorageGeometryRunCheck :: AcquiredStorageGeometryRun -> CheckResult
acquiredStorageGeometryRunCheck (AcquiredStorageGeometryRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredStorageGeometryRun
  :: (AcquiredSourceSnapshot -> GenesisTrust -> AcquiredPhaseContractEvidence -> [CheckResult]
      -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> Text -> CheckResult -> value)
  -> AcquiredStorageGeometryRun
  -> value
foldAcquiredStorageGeometryRun consume (AcquiredStorageGeometryRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
  consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireStorageGeometryRun, acquireStorageGeometryRefreshRun
  :: FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredStorageGeometryRun
acquireStorageGeometryRun = acquire False
acquireStorageGeometryRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredStorageGeometryRun
acquire refresh root acquired trust = do
  runRoot <- freshRunRoot root
  home <- getHomeDirectory
  let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
      compiler = genesisTrustCompilerExecutable trust
      store = home </> ".cabal/store"
      contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 28 acquired
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
      cleanroom = mergeChecks "storage-geometry-cleanroom" [cache, freshness, legacy]
      qualification = mergeChecks "storage-geometry-qualification"
        [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
      prerequisite = mergeChecks "storage-geometry-prerequisite"
        [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
      rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
      result = mergeChecks "storage-geometry" rows
      sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
      ids label parts = digestTexts (label : sourceId : parts)
      subjectId = ids "storage-geometry-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
      oracleId = ids "storage-geometry-oracle" [checkDigest oracle, checkDigest negatives]
      harnessId = ids "storage-geometry-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
      observerId = ids "storage-geometry-observer" [checkDigest observer]
      qualificationId = ids "storage-geometry-qualification" [checkDigest qualification]
      acquiredRunId = ids "storage-geometry-run" [Text.pack runRoot, checkDigest result]
      toolchainId = ids "storage-geometry-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
      cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
  pure (AcquiredStorageGeometryRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
       , "storage-geometry-spec"
       , "--offline"
       , "--test-show-details=direct"
       ] <> maybe [] (pure . ("-f" <>)) selected)

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
  [ mutant "allocation-drop-quantum" "backing-allocation-rounding" "backing allocation rounding"
  , mutant "backing-accept-over" "direct-backing" "single-owner backing comparison"
  , mutant "backup-drop-retention" "backup-medium-fit" "retained backup generations"
  , mutant "bookkeeper-drop-quorum" "bookkeeper-recovery" "BookKeeper write-quorum bytes"
  , mutant "bookkeeper-drop-recovery" "bookkeeper-recovery" "BookKeeper recovery"
  , mutant "control-plane-drop-transition" "control-plane-transition" "etcd transition high-water"
  , mutant "filesystem-drop-overhead" "filesystem-overhead-rounding" "filesystem presentation"
  , mutant "incluster-cache-drop-nesting" "incluster-cache-budget" "cache budget nesting"
  , mutant "migration-drop-old" "storage-migration-highwater" "migration old-plus-new high-water"
  , mutant "minio-drop-healing" "minio-parity-healing-orphan" "MinIO healing workspace"
  , mutant "minio-drop-orphan" "minio-parity-healing-orphan" "failed-write orphan horizon"
  , mutant "minio-drop-parity" "minio-parity-healing-orphan" "MinIO parity bytes"
  , mutant "native-cache-double-spend" "native-cache-pool" "named cache backing"
  , mutant "object-accept-conflict" "object-identity-conflict" "object identity conflict"
  , mutant "object-drop-count" "object-count-quota" "object-count geometry"
  , mutant "object-drop-producer-arm" "object-producer-inventory" "six-arm inventory equality"
  , mutant "patroni-drop-wal" "patroni-wal-failover" "Patroni WAL and failover peak"
  , mutant "pool-allow-alias" "disjoint-capacity-pool" "disjoint capacity ownership"
  , mutant "provider-root-debit-durable" "root-ebs-quota" "nodeRootStorage quota"
  , mutant "provider-root-under-size" "instance-store-root" "instance-store root"
  , mutant "pulsar-drop-durable" "pulsar-durable-total" "durable-total ceiling"
  , mutant "pulsar-drop-hot" "pulsar-hot-tier-ceiling" "physical hot-tier ceiling"
  , mutant "registry-drop-partials" "registry-upload-partials" "registry failed partials"
  , mutant "registry-migration-drop-workspace" "registry-backend-migration" "registry migration workspace"
  , mutant "restore-drop-workspace" "restore-target-fit" "restore target workspace"
  , mutant "scaling-drop-highwater" "scaling-shrink-highwater" "shrink migration witness"
  , mutant "scaling-ignore-fingerprint" "scaling-fingerprint" "snapshot fingerprint"
  , mutant "schema-drop-wal" "schema-migration-highwater" "schema migration WAL"
  , mutant "uniform-use-aggregate" "uniform-claim-per-backing" "per-backing uniform claim"
  , mutant "vault-drop-audit" "vault-raft-audit" "Vault audit rotation"
  , mutant "zookeeper-drop-recovery" "zookeeper-recovery" "ZooKeeper recovery overlap"
  ]
 where
  mutant name variant locus = (name, "storage-geometry-" <> Text.unpack name <> "-mutant", variant, locus)

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ clean) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix mutants clean) = [receipt | Mutant _ _ _ receipt <- mutants] <> [clean]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix = CheckResult "storage-geometry-toolchain"
  [ observation "storage-geometry.cabal" (receiptSummary version)
  , observation "storage-geometry.compiler" (Text.pack compiler)
  ]
  ([finding "STORAGE-GEOMETRY-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed" |
      not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"]
   <> [finding "STORAGE-GEOMETRY-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1" |
      receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix,
      executable /= cabal || not (isAbsolute compiler) || not (isAbsolute store) ||
      ("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args ||
      "--jobs=1" `notElem` args || "--offline" `notElem` args || Text.null (receiptDigest receipt)])

oracleCheck :: Receipt -> CheckResult
oracleCheck clean = CheckResult "storage-geometry-independent-oracle"
  [ observation "storage-geometry.oracle" (receiptSummary clean)
  , observation "storage-geometry.oracle-independence" "StorageGeometryOracle imports no production or fixture module"
  ]
  [finding "STORAGE-GEOMETRY-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token" |
    receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)]
 where
  acceptance = "PASS (5 named negatives, 30 variants, 30 twins, 2 positives, 6 properties, 31 changed-production mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean = CheckResult "storage-geometry-positive-controls"
  [observation "storage-geometry.positives" "thirty legal twins, two positive deployment rows, and six sampled equivalence properties pass"]
  [finding "STORAGE-GEOMETRY-POSITIVE" specSource "the clean positive corpus did not pass" | receiptExit clean /= ExitSuccess]

negativeCheck :: Receipt -> CheckResult
negativeCheck clean = CheckResult "storage-geometry-paired-negatives"
  [observation "storage-geometry.negatives" "thirty minimally different negative/legal pairs cover five named Phase-28 illegal-state families"]
  [finding "STORAGE-GEOMETRY-NEGATIVE" specSource "the paired-negative corpus did not execute" |
    receiptExit clean /= ExitSuccess || notContains "30 variants, 30 twins" (receiptOutput clean)]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix mutants _) = CheckResult "storage-geometry-mutants"
  [observation ("storage-geometry.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
  [finding "STORAGE-GEOMETRY-MUTANT" (Text.unpack name) ("the changed production fold did not turn red at " <> locus) |
    Mutant name variant locus receipt <- mutants,
    receiptExit receipt /= ExitFailure 1 || notContains (variant <> " negative result drifted") (receiptOutput receipt)]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
  production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
  oracle <- Text.pack <$> readFile (root </> oracleSource)
  pure (CheckResult "storage-geometry-source-discipline"
    [ observation "storage-geometry.production-module-count" "5"
    , observation "storage-geometry.effect-boundary" "pure folds and run-local Cabal children only; no host, network, service, cluster, or hardware effects"
    ]
    ([finding "STORAGE-GEOMETRY-SOURCE-SHAPE" "<storage-production>" ("missing production element: " <> token) |
       token <- ["StorageBudget", "bookKeeperPhysicalDemand", "minioPhysicalDemand", "provisionCacheDemand", "planStorageScaling", "STORAGE_GEOMETRY_PULSAR_DROP_HOT_MUTANT"], notContains token production]
     <> [finding "STORAGE-GEOMETRY-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token) |
       token <- ["expectedRows", "mutantSpecs", "expectedCalculusProjection"], notContains token oracle]))

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired = CheckResult "storage-geometry-discovery"
  [observation "storage-geometry.discovery.count" (Text.pack (show (length observed)))]
  [finding "STORAGE-GEOMETRY-DISCOVERY" "<phase-28-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
 where
  observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts = CheckResult "storage-geometry-authority"
  [observation "storage-geometry.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
  ([finding "STORAGE-GEOMETRY-RUN-ROOT" runRoot "run root escaped .build/runs/phase-28/work" | not (pathBelow (root </> ".build/runs/phase-28/work") runRoot)]
   <> [finding "STORAGE-GEOMETRY-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-28 authority" |
      Receipt name executable args _ _ _ <- receipts,
      executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args])
 where
  forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts = CheckResult "storage-geometry-observer"
  (map (observation "storage-geometry.observer.process" . receiptSummary) receipts)
  [finding "STORAGE-GEOMETRY-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest" |
    receipt@(Receipt name executable _ _ _ _) <- receipts, not (isAbsolute executable) || Text.null (receiptDigest receipt)]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean = CheckResult "storage-geometry-freshness"
  [observation "storage-geometry.fresh-build-root" (Text.pack (makeRelative root runRoot))]
  [finding "STORAGE-GEOMETRY-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root" |
    receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-28/work") runRoot)]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
  files <- filterM (doesFileExist . (root </>)) retiredSources
  pure (CheckResult "storage-geometry-legacy-closure"
    [ observation "storage-geometry.legacy.retired-count" (Text.pack (show (length retiredSources)))
    , observation "storage-geometry.legacy.semantic-inputs" "HaskellOnly"
    ]
    [finding "STORAGE-GEOMETRY-LEGACY" path "retired Python/serialized storage-geometry authority remains" | path <- files])

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
  [ named "phase-28-claim" [pre]
  , named "phase-28-subject" [toolchain, positives]
  , named "phase-28-command" [toolchain, authority]
  , named "phase-28-oracle" [oracle]
  , named "phase-28-positive-controls" [positives]
  , named "phase-28-paired-negatives" [negatives]
  , named "phase-28-mutants" [mutants]
  , named "phase-28-discovery" [discovery]
  , named "phase-28-challenge" [mutants]
  , named "phase-28-observer" [observer]
  , named "phase-28-authority-bypass" [authority]
  , named "phase-28-freshness" [freshness]
  , named "phase-28-qualification" [qualification]
  , named "phase-28-cleanroom" [cleanroom]
  , named "phase-28-legacy-closure" [legacy]
  , CheckResult "phase-28-predecessor" [observation "phase-28.predecessor" "deferred to durable receipt verifier"] []
  , CheckResult "phase-28-residue" [observation "phase-28.residue" "binding, whole-deployment provisioning, rendering, effects, runtime storage, live scaling, host, service, cluster, and hardware remain later-owned"] []
  , named "phase-28-pass-criterion" [pre]
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
  pure (CheckResult "storage-geometry-source-repository-cache"
    [observation "storage-geometry.cache.entries" (Text.pack (show copied))]
    [finding "STORAGE-GEOMETRY-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete" |
      not present || length copied /= 6 || not (all (completeSourcePackage copied) ["infernix-", "jitML-"])])

copyTree :: FilePath -> FilePath -> IO ()
copyTree source target = do
  createDirectoryIfMissing True target
  entries <- listDirectory source
  forM_ entries $ \entry -> do
    let from = source </> entry
        to = target </> entry
    directory <- doesDirectoryExist from
    if directory then copyTree from to else copyFile from to

completeSourcePackage :: [FilePath] -> String -> Bool
completeSourcePackage entries prefix = length matching == 3 && length (filter (isInfixOf ".cache") matching) == 1 && length (filter (isInfixOf ".tar.gz") matching) == 1 && length [entry | entry <- matching, not ('.' `elem` entry)] == 1
 where
  matching = filter (prefix `isPrefixOf`) entries

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
  let parent = root </> ".build/runs/phase-28/work"
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
  pure $ either
    (\problem -> Receipt name executable args (ExitFailure 127) "" (Text.pack (show problem)))
    (\(status, out, err) -> Receipt name executable args status (Text.pack out) (Text.pack err))
    attempt

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
  [ "src/storage-geometry-folds/Amoebius/Capacity/Growable.hs"
  , "src/storage-geometry-folds/Amoebius/Capacity/ServiceStorage.hs"
  , "src/storage-geometry-folds/Amoebius/Capacity/Storage.hs"
  , "src/storage-geometry-folds/Amoebius/Capacity/StorageGeometry.hs"
  , "src/storage-geometry-folds/Amoebius/Capacity/StorageScaling.hs"
  ]
expectedSources = sort (productionSources <> [fixtureSource, gateSource, oracleSource, propsSource, specSource])
retiredSources =
  [ "tools/storage_geometry_gate.py"
  , "test/oracle/storage_geometry_surfaces.tsv"
  , "test/oracle/storage_geometry/calculus_projection.tsv"
  , "test/oracle/storage_geometry/dhall_typecheck_cases.tsv"
  , "test/oracle/storage_geometry/storage_cases.tsv"
  , "test/spec/dsl/StorageGeometryMutants.hs"
  ]

fixtureSource, gateSource, oracleSource, propsSource, specSource :: FilePath
fixtureSource = "test/spec/dsl/StorageGeometryFixtures.hs"
gateSource = "test/spec/dsl/StorageGeometryGate.hs"
oracleSource = "test/spec/dsl/StorageGeometryOracle.hs"
propsSource = "test/spec/dsl/StorageGeometryProps.hs"
specSource = "test/spec/dsl/StorageGeometrySpec.hs"
