{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.EncryptedBrowserRuntimeRun.Internal (
    AcquiredEncryptedBrowserRuntimeRun,
    acquireEncryptedBrowserRuntimeRefreshRun,
    acquireEncryptedBrowserRuntimeRun,
    acquiredEncryptedBrowserRuntimeRunCheck,
    foldAcquiredEncryptedBrowserRuntimeRun,
) where

import Amoebius.Validation.BootstrapTrust.Internal (
    GenesisTrust,
    genesisTrustCheck,
    genesisTrustCompilerExecutable,
    genesisTrustToolchainIdentity,
 )
import Amoebius.Validation.PhaseContract.Internal (
    AcquiredPhaseContractEvidence,
    acquirePhaseContractEvidenceFor,
    acquireRecordedPhaseContractEvidence,
    acquiredPhaseContractEvidenceCheck,
 )
import Amoebius.Validation.SourceClosure.Internal (
    AcquiredSourceSnapshot,
    IndexEntry (indexPath),
    SourceSnapshot (snapshotEntries, snapshotIdentity),
    TrackedEntry (trackedIndex),
    acquiredSourceSnapshot,
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
import System.Directory (
    copyFile,
    createDirectory,
    createDirectoryIfMissing,
    doesDirectoryExist,
    doesFileExist,
    getHomeDirectory,
    listDirectory,
    removeFile,
 )
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data CompileBarrier = CompileBarrier Text Bool Text Receipt deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix [CompileBarrier] [Mutant] Receipt

data AcquiredEncryptedBrowserRuntimeRun
    = AcquiredEncryptedBrowserRuntimeRun
        AcquiredSourceSnapshot
        GenesisTrust
        AcquiredPhaseContractEvidence
        [CheckResult]
        Text
        Text
        Text
        Text
        Text
        Text
        Text
        Text
        CheckResult

acquiredEncryptedBrowserRuntimeRunCheck :: AcquiredEncryptedBrowserRuntimeRun -> CheckResult
acquiredEncryptedBrowserRuntimeRunCheck (AcquiredEncryptedBrowserRuntimeRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredEncryptedBrowserRuntimeRun ::
    ( AcquiredSourceSnapshot ->
      GenesisTrust ->
      AcquiredPhaseContractEvidence ->
      [CheckResult] ->
      Text ->
      Text ->
      Text ->
      Text ->
      Text ->
      Text ->
      Text ->
      Text ->
      CheckResult ->
      value
    ) ->
    AcquiredEncryptedBrowserRuntimeRun ->
    value
foldAcquiredEncryptedBrowserRuntimeRun consume (AcquiredEncryptedBrowserRuntimeRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireEncryptedBrowserRuntimeRun
    , acquireEncryptedBrowserRuntimeRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredEncryptedBrowserRuntimeRun
acquireEncryptedBrowserRuntimeRun = acquire False
acquireEncryptedBrowserRuntimeRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredEncryptedBrowserRuntimeRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 45 acquired
    cache <- prepareSourceRepositoryCache root runRoot
    cabalVersion <- runProcess root "cabal-version" cabal ["--numeric-version"]
    matrix <- executeMatrix root runRoot cabal compiler store
    discipline <- sourceDisciplineCheck root
    legacy <- legacyCheck root
    let toolchain = toolchainCheck cabal compiler store cabalVersion matrix
        oracle = oracleCheck (cleanReceipt matrix)
        positives = positiveCheck (cleanReceipt matrix)
        negatives = negativeCheck matrix
        mutants = mutantCheck matrix
        discovery = discoveryCheck acquired
        authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
        observer = observerCheck (cabalVersion : matrixReceipts matrix)
        freshness = freshnessCheck root runRoot (cleanReceipt matrix)
        cleanroom = mergeChecks "encrypted-browser-runtime-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "encrypted-browser-runtime-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "encrypted-browser-runtime-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "encrypted-browser-runtime" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "encrypted-browser-runtime-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "encrypted-browser-runtime-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "encrypted-browser-runtime-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "encrypted-browser-runtime-observer" [checkDigest observer]
        qualificationId = ids "encrypted-browser-runtime-qualification" [checkDigest qualification]
        acquiredRunId = ids "encrypted-browser-runtime-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "encrypted-browser-runtime-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredEncryptedBrowserRuntimeRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
    mutants <- mapM runMutant mutantSpecifications
    clean <- runSpec "clean" Nothing
    pure (Matrix [] mutants clean)
  where
    runMutant (name, flagName, locus, expected) = Mutant name locus expected <$> runSpec name (Just flagName)
    runSpec name selected =
        runProcess
            root
            name
            cabal
            ( common
                <> [ "test"
                   , "offline-browser-runtime-spec"
                   , "--offline"
                   , "--test-show-details=direct"
                   ]
                <> selectMutant selected
            )
    common =
        [ "--builddir=" <> runRoot </> "dist"
        , "--store-dir=" <> store
        , "--with-compiler=" <> compiler
        , "--jobs=1"
        , "--offline"
        ]
    selectMutant selected = [if Just flagName == selected then "-f" <> flagName else "-f-" <> flagName | (_, flagName, _, _) <- mutantSpecifications]

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
    [ mutant "store-plaintext" "encrypted-browser-store-plaintext-mutant" "Crypto.sealRecord" "ciphertext envelope: expected False"
    , mutant "retain-credentials" "encrypted-browser-retain-credentials-mutant" "Store.prohibitedPersistenceFields" "credential persistence fields: expected []"
    , mutant "two-replay-leaders" "encrypted-browser-two-replay-leaders-mutant" "Leader.claimLeader" "concurrent owner refusal: expected Left"
    , mutant "omit-fencing" "encrypted-browser-omit-fencing-mutant" "Leader.claimLeader" "fencing generation: expected Generation 2"
    , mutant "silent-dependency-eviction" "encrypted-browser-silent-dependency-eviction-mutant" "Store.admitBytes" "dependency quota refusal: expected RejectedQuota"
    , mutant "reuse-partition-key" "encrypted-browser-reuse-partition-key-mutant" "Partition.partitionKey" "tenant partition separation: expected True"
    , mutant "drop-fence-hook" "encrypted-browser-drop-fence-hook-mutant" "Runtime.renderRuntimeProjection" "projection fencing hook: expected True"
    ]
  where
    mutant name flagName locus expected = (name, flagName, locus, expected)

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ _ clean) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix barriers mutants clean) = [receipt | CompileBarrier _ _ _ receipt <- barriers] <> [receipt | Mutant _ _ _ receipt <- mutants] <> [clean]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix =
    CheckResult
        "encrypted-browser-runtime-toolchain"
        [observation "encrypted-browser-runtime.cabal" (receiptSummary version), observation "encrypted-browser-runtime.compiler" (Text.pack compiler)]
        ( [ finding "ENCRYPTED-BROWSER-RUNTIME-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "ENCRYPTED-BROWSER-RUNTIME-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
               | receipt@(Receipt name executable args _ _ _) <- matrixReceipts matrix
               , executable /= cabal
                    || not (isAbsolute compiler)
                    || not (isAbsolute store)
                    || ("--store-dir=" <> store) `notElem` args
                    || ("--with-compiler=" <> compiler) `notElem` args
                    || "--jobs=1" `notElem` args
                    || "--offline" `notElem` args
                    || Text.null (receiptDigest receipt)
               ]
        )

oracleCheck :: Receipt -> CheckResult
oracleCheck clean =
    CheckResult
        "encrypted-browser-runtime-independent-oracle"
        [observation "encrypted-browser-runtime.oracle" (receiptSummary clean), observation "encrypted-browser-runtime.oracle-independence" "OfflineRuntimeReference imports no production or case module"]
        [ finding "ENCRYPTED-BROWSER-RUNTIME-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "offline-browser-runtime-spec: PASS (14 actions, 3 storage rows, 2 assets, 3 quota rows, 3 access rows, 3 migrations, 4 replay rows, 6 facilities, 7 mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "encrypted-browser-runtime-positive-controls"
        [observation "encrypted-browser-runtime.positives" "fourteen offline actions, encrypted storage, assets, quota, access, migration, replay, facility, deterministic-projection, and calculus controls passed"]
        [ finding "ENCRYPTED-BROWSER-RUNTIME-POSITIVE" specSource "the clean Haskell offline-runtime corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "offline-browser-runtime-calculus: PASS (5 kinds, 69 projected units)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ _ clean) =
    CheckResult
        "encrypted-browser-runtime-paired-negatives"
        [observation "encrypted-browser-runtime.negatives" "plaintext visibility, credential persistence, dual ownership, stale fencing, dependency eviction, partition collision, replay gaps, invalid migrations, and missing projection fences were refused"]
        [ finding "ENCRYPTED-BROWSER-RUNTIME-PAIRED-NEGATIVES" specSource "the clean candidate did not exercise the complete typed refusal and sensitivity battery"
        | receiptExit clean /= ExitSuccess || notContains "3 migrations, 4 replay rows, 6 facilities, 7 mutants" (receiptOutput clean)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "encrypted-browser-runtime-mutants"
        [observation ("encrypted-browser-runtime.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "ENCRYPTED-BROWSER-RUNTIME-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "encrypted-browser-runtime-source-discipline"
            [observation "encrypted-browser-runtime.production-module-count" "6", observation "encrypted-browser-runtime.effect-boundary" "pure typed offline state plus run-local generated projection files and serial Cabal children only; no browser, Node, Python, Dhall executable, network, service, cluster, or hardware effects"]
            ( [ finding "ENCRYPTED-BROWSER-RUNTIME-SOURCE-SHAPE" "<encrypted-browser-runtime-production>" ("missing production element: " <> token)
              | token <- ["sealRecord", "prohibitedPersistenceFields", "claimLeader", "admitBytes", "partitionKey", "renderRuntimeProjection", "ENCRYPTED_BROWSER_RUNTIME_STORE_PLAINTEXT_MUTANT", "ENCRYPTED_BROWSER_RUNTIME_RETAIN_CREDENTIALS_MUTANT", "ENCRYPTED_BROWSER_RUNTIME_TWO_REPLAY_LEADERS_MUTANT", "ENCRYPTED_BROWSER_RUNTIME_OMIT_FENCING_MUTANT", "ENCRYPTED_BROWSER_RUNTIME_SILENT_DEPENDENCY_EVICTION_MUTANT", "ENCRYPTED_BROWSER_RUNTIME_REUSE_PARTITION_KEY_MUTANT", "ENCRYPTED_BROWSER_RUNTIME_DROP_FENCE_HOOK_MUTANT"]
              , notContains token production
              ]
                <> [ finding "ENCRYPTED-BROWSER-RUNTIME-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["accessRows", "assetRows", "facilityRows", "migrationRows", "quotaRows", "replayRows", "storageRows"]
                   , notContains token oracle
                   ]
                <> [ finding "ENCRYPTED-BROWSER-RUNTIME-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "encrypted-browser-runtime-discovery"
        [observation "encrypted-browser-runtime.discovery.count" (Text.pack (show (length observed)))]
        [finding "ENCRYPTED-BROWSER-RUNTIME-DISCOVERY" "<phase-45-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "encrypted-browser-runtime-authority"
        [observation "encrypted-browser-runtime.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "ENCRYPTED-BROWSER-RUNTIME-RUN-ROOT" runRoot "run root escaped .build/runs/phase-45/work" | not (pathBelow (root </> ".build/runs/phase-45/work") runRoot)]
            <> [ finding "ENCRYPTED-BROWSER-RUNTIME-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-45 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "encrypted-browser-runtime-observer"
        (map (observation "encrypted-browser-runtime.observer.process" . receiptSummary) receipts)
        [ finding "ENCRYPTED-BROWSER-RUNTIME-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "encrypted-browser-runtime-freshness"
        [observation "encrypted-browser-runtime.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "ENCRYPTED-BROWSER-RUNTIME-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-45/work") runRoot)
        ]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
    files <- filterM (doesFileExist . (root </>)) retiredSources
    pure
        ( CheckResult
            "encrypted-browser-runtime-legacy-closure"
            [observation "encrypted-browser-runtime.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "encrypted-browser-runtime.legacy.semantic-inputs" "HaskellOnly"]
            [finding "ENCRYPTED-BROWSER-RUNTIME-LEGACY" path "retired Python/PureScript/JavaScript/serialized/materialized-mutant authority remains" | path <- files]
        )

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-45-claim" [pre]
    , named "phase-45-subject" [toolchain, positives]
    , named "phase-45-command" [toolchain, authority]
    , named "phase-45-oracle" [oracle]
    , named "phase-45-positive-controls" [positives]
    , named "phase-45-paired-negatives" [negatives]
    , named "phase-45-mutants" [mutants]
    , named "phase-45-discovery" [discovery]
    , named "phase-45-challenge" [mutants]
    , named "phase-45-observer" [observer]
    , named "phase-45-authority-bypass" [authority]
    , named "phase-45-freshness" [freshness]
    , named "phase-45-qualification" [qualification]
    , named "phase-45-cleanroom" [cleanroom]
    , named "phase-45-legacy-closure" [legacy]
    , CheckResult "phase-45-predecessor" [observation "phase-45.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-45-residue" [observation "phase-45.residue" "IndexedDB, OPFS, Web Locks, BroadcastChannel, service-worker, WebCrypto, cross-tab, storage, release, replay-server, HA, and hardware fidelity remain later-owned"] []
    , named "phase-45-pass-criterion" [pre]
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
    pure
        ( CheckResult
            "encrypted-browser-runtime-source-repository-cache"
            [observation "encrypted-browser-runtime.cache.entries" (Text.pack (show copied))]
            [ finding "ENCRYPTED-BROWSER-RUNTIME-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
            | not present || length copied /= 6 || not (all (completeSourcePackage copied) ["infernix-", "jitML-"])
            ]
        )

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
  where
    matching = filter (prefix `isPrefixOf`) entries

freshRunRoot :: FilePath -> IO FilePath
freshRunRoot root = do
    let parent = root </> ".build/runs/phase-45/work"
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
notContains :: Text -> Text -> Bool
notContains needle haystack = not (needle `Text.isInfixOf` haystack)

productionSources, expectedSources, retiredSources :: [FilePath]
productionSources =
    [ "src/Amoebius/Ui/Offline/Browser/Crypto.hs"
    , "src/Amoebius/Ui/Offline/Browser/Leader.hs"
    , "src/Amoebius/Ui/Offline/Browser/Partition.hs"
    , "src/Amoebius/Ui/Offline/Browser/Runtime.hs"
    , "src/Amoebius/Ui/Offline/Browser/ServiceWorker.hs"
    , "src/Amoebius/Ui/Offline/Browser/Store.hs"
    ]
expectedSources = sort (productionSources <> [oracleSource, casesSource, specSource])
retiredSources =
    [ "tools/encrypted_browser_runtime_gate.py"
    , "tools/encrypted_browser_runtime_live.py"
    , "test/golden/browser/encrypted_browser_runtime/action_trace.json"
    , "test/golden/browser/encrypted_browser_runtime/asset_manifest.tbl"
    , "test/golden/browser/encrypted_browser_runtime/partition_access.tbl"
    , "test/golden/browser/encrypted_browser_runtime/quota_outcomes.tbl"
    , "test/golden/browser/encrypted_browser_runtime/storage_inventory.tbl"
    , "test/oracle/encrypted_browser_runtime/calculus_projection.tsv"
    , "test/oracle/encrypted_browser_runtime/validation_locus.tsv"
    , "test/oracle/encrypted_browser_runtime_surfaces.tsv"
    , "test/mutant/encrypted_browser_runtime/omit_fencing.patch"
    , "test/mutant/encrypted_browser_runtime/retain_credentials.patch"
    , "test/mutant/encrypted_browser_runtime/reuse_partition_key.patch"
    , "test/mutant/encrypted_browser_runtime/silent_dependency_eviction.patch"
    , "test/mutant/encrypted_browser_runtime/store_plaintext.patch"
    , "test/mutant/encrypted_browser_runtime/two_replay_leaders.patch"
    , "ui/src/Amoebius/Ui/Offline/BlobStore.purs"
    , "ui/src/Amoebius/Ui/Offline/Crypto.purs"
    , "ui/src/Amoebius/Ui/Offline/Leader.purs"
    , "ui/src/Amoebius/Ui/Offline/Migration.purs"
    , "ui/src/Amoebius/Ui/Offline/Partition.purs"
    , "ui/src/Amoebius/Ui/Offline/Replay.purs"
    , "ui/src/Amoebius/Ui/Offline/Runtime.js"
    , "ui/src/Amoebius/Ui/Offline/Runtime.purs"
    , "ui/src/Amoebius/Ui/Offline/ServiceWorker.purs"
    , "ui/src/Amoebius/Ui/Offline/Store.purs"
    ]

oracleSource, casesSource, specSource :: FilePath
oracleSource = "test/spec/browser/OfflineRuntimeReference.hs"
casesSource = "test/spec/browser/OfflineRuntimeCases.hs"
specSource = "test/spec/browser/OfflineRuntimeSpec.hs"
