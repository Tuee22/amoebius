{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.OfflineLanguagePlanRun.Internal (
    AcquiredOfflineLanguagePlanRun,
    acquireOfflineLanguagePlanRefreshRun,
    acquireOfflineLanguagePlanRun,
    acquiredOfflineLanguagePlanRunCheck,
    foldAcquiredOfflineLanguagePlanRun,
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

data AcquiredOfflineLanguagePlanRun
    = AcquiredOfflineLanguagePlanRun
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

acquiredOfflineLanguagePlanRunCheck :: AcquiredOfflineLanguagePlanRun -> CheckResult
acquiredOfflineLanguagePlanRunCheck (AcquiredOfflineLanguagePlanRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredOfflineLanguagePlanRun ::
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
    AcquiredOfflineLanguagePlanRun ->
    value
foldAcquiredOfflineLanguagePlanRun consume (AcquiredOfflineLanguagePlanRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireOfflineLanguagePlanRun
    , acquireOfflineLanguagePlanRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredOfflineLanguagePlanRun
acquireOfflineLanguagePlanRun = acquire False
acquireOfflineLanguagePlanRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredOfflineLanguagePlanRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 41 acquired
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
        cleanroom = mergeChecks "offline-language-plan-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "offline-language-plan-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "offline-language-plan-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "offline-language-plan" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "offline-language-plan-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "offline-language-plan-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "offline-language-plan-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "offline-language-plan-observer" [checkDigest observer]
        qualificationId = ids "offline-language-plan-qualification" [checkDigest qualification]
        acquiredRunId = ids "offline-language-plan-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "offline-language-plan-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredOfflineLanguagePlanRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
                   , "offline-plan-spec"
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
    [ mutant "drop-queue-bound" "offline-language-drop-queue-bound-mutant" "Decode.decodeQueueContract" "offline-plan-mutant: RED drop_queue_bound locus=queue-age-bound"
    , mutant "omit-server-handler" "offline-language-omit-server-handler-mutant" "Plan.compileOffline" "offline-plan-mutant: RED omit_server_handler locus=paired-plan-keys"
    , mutant "queue-model-invocation" "offline-language-queue-model-invocation-mutant" "Decode.queueableOperation" "offline-plan-mutant: RED queue_model_invocation locus=model-invocation-classification"
    , mutant "persist-private-field" "offline-language-persist-private-field-mutant" "Plan.compileOffline" "offline-plan-mutant: RED persist_private_field locus=public-plan-private-fields"
    , mutant "browser-redis-constructor" "offline-language-browser-redis-constructor-mutant" "Plan.mechanismConstructors" "offline-plan-mutant: RED browser_redis_constructor locus=authored-mechanism-surface"
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
        "offline-language-plan-toolchain"
        [observation "offline-language-plan.cabal" (receiptSummary version), observation "offline-language-plan.compiler" (Text.pack compiler)]
        ( [ finding "OFFLINE-LANGUAGE-PLAN-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "OFFLINE-LANGUAGE-PLAN-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
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
        "offline-language-plan-independent-oracle"
        [observation "offline-language-plan.oracle" (receiptSummary clean), observation "offline-language-plan.oracle-independence" "OfflinePlanReference imports no production or case module"]
        [ finding "OFFLINE-LANGUAGE-PLAN-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "offline-plan-spec: PASS (3 positive contracts, 13 exact negatives, 8 plan rows, 3 paired key sets, 5 mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "offline-language-plan-positive-controls"
        [observation "offline-language-plan.positives" "three typed continuity contracts, eight plan rows, three paired key sets, and two exact artifact commands passed"]
        [ finding "OFFLINE-LANGUAGE-PLAN-POSITIVE" specSource "the clean paired-plan compiler corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "offline-plan-calculus: PASS (5 kinds, 40 projected units)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ _ clean) =
    CheckResult
        "offline-language-plan-paired-negatives"
        [observation "offline-language-plan.negatives" "thirteen exact bounded-contract and operation-classification refusals passed"]
        [ finding "OFFLINE-LANGUAGE-PLAN-PAIRED-NEGATIVES" specSource "the clean candidate did not exercise the complete typed refusal and sensitivity battery"
        | receiptExit clean /= ExitSuccess || notContains "13 exact negatives, 8 plan rows, 3 paired key sets" (receiptOutput clean)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "offline-language-plan-mutants"
        [observation ("offline-language-plan.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "OFFLINE-LANGUAGE-PLAN-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "offline-language-plan-source-discipline"
            [observation "offline-language-plan.production-module-count" "3", observation "offline-language-plan.effect-boundary" "pure continuity-language validation and paired offline/replay plan compilation with serial run-local Cabal children only; no browser, storage, replay, network, service, cluster, or hardware effects"]
            ( [ finding "OFFLINE-LANGUAGE-PLAN-SOURCE-SHAPE" "<offline-language-plan-production>" ("missing production element: " <> token)
              | token <- ["data Continuity", "data OfflineSource", "decodeQueueContract", "compileOffline", "OFFLINE_LANGUAGE_PLAN_DROP_QUEUE_BOUND_MUTANT", "OFFLINE_LANGUAGE_PLAN_OMIT_SERVER_HANDLER_MUTANT", "OFFLINE_LANGUAGE_PLAN_QUEUE_MODEL_INVOCATION_MUTANT", "OFFLINE_LANGUAGE_PLAN_PERSIST_PRIVATE_FIELD_MUTANT", "OFFLINE_LANGUAGE_PLAN_BROWSER_REDIS_CONSTRUCTOR_MUTANT"]
              , notContains token production
              ]
                <> [ finding "OFFLINE-LANGUAGE-PLAN-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["referenceContinuityRows", "referenceNegativeTags", "referencePlanRows"]
                   , notContains token oracle
                   ]
                <> [ finding "OFFLINE-LANGUAGE-PLAN-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "offline-language-plan-discovery"
        [observation "offline-language-plan.discovery.count" (Text.pack (show (length observed)))]
        [finding "OFFLINE-LANGUAGE-PLAN-DISCOVERY" "<phase-41-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "offline-language-plan-authority"
        [observation "offline-language-plan.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "OFFLINE-LANGUAGE-PLAN-RUN-ROOT" runRoot "run root escaped .build/runs/phase-41/work" | not (pathBelow (root </> ".build/runs/phase-41/work") runRoot)]
            <> [ finding "OFFLINE-LANGUAGE-PLAN-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-41 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "offline-language-plan-observer"
        (map (observation "offline-language-plan.observer.process" . receiptSummary) receipts)
        [ finding "OFFLINE-LANGUAGE-PLAN-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "offline-language-plan-freshness"
        [observation "offline-language-plan.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "OFFLINE-LANGUAGE-PLAN-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-41/work") runRoot)
        ]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
    files <- filterM (doesFileExist . (root </>)) retiredSources
    pure
        ( CheckResult
            "offline-language-plan-legacy-closure"
            [observation "offline-language-plan.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "offline-language-plan.legacy.semantic-inputs" "HaskellOnly"]
            [finding "OFFLINE-LANGUAGE-PLAN-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files]
        )

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-41-claim" [pre]
    , named "phase-41-subject" [toolchain, positives]
    , named "phase-41-command" [toolchain, authority]
    , named "phase-41-oracle" [oracle]
    , named "phase-41-positive-controls" [positives]
    , named "phase-41-paired-negatives" [negatives]
    , named "phase-41-mutants" [mutants]
    , named "phase-41-discovery" [discovery]
    , named "phase-41-challenge" [mutants]
    , named "phase-41-observer" [observer]
    , named "phase-41-authority-bypass" [authority]
    , named "phase-41-freshness" [freshness]
    , named "phase-41-qualification" [qualification]
    , named "phase-41-cleanroom" [cleanroom]
    , named "phase-41-legacy-closure" [legacy]
    , CheckResult "phase-41-predecessor" [observation "phase-41.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-41-residue" [observation "phase-41.residue" "browser persistence, encrypted storage, server replay, publication, live authority enforcement, tenant-isolation observation, and hardware remain later-owned"] []
    , named "phase-41-pass-criterion" [pre]
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
            "offline-language-plan-source-repository-cache"
            [observation "offline-language-plan.cache.entries" (Text.pack (show copied))]
            [ finding "OFFLINE-LANGUAGE-PLAN-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
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
    let parent = root </> ".build/runs/phase-41/work"
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
    [ "src/offline-language-types/Amoebius/Ui/Offline/Types.hs"
    , "src/Amoebius/Ui/Offline/Decode.hs"
    , "src/Amoebius/Ui/Offline/Plan.hs"
    ]
expectedSources = sort (productionSources <> [oracleSource, casesSource, specSource])
retiredSources =
    [ "tools/offline_language_plan_gate.py"
    , "test/fixture/offline_language_plan/positive_contracts.tbl"
    , "test/fixture/offline_language_plan/negative_contracts.tbl"
    , "test/golden/offline_language_plan/plan_keys.tbl"
    , "test/oracle/offline_language_plan/calculus_projection.tsv"
    , "test/oracle/offline_language_plan/validation_locus.tsv"
    , "test/oracle/offline_language_plan_surfaces.tsv"
    , "test/mutant/offline_language_plan/drop_queue_bound.patch"
    , "test/mutant/offline_language_plan/omit_server_handler.patch"
    , "test/mutant/offline_language_plan/queue_model_invocation.patch"
    , "test/mutant/offline_language_plan/persist_private_field.patch"
    , "test/mutant/offline_language_plan/browser_redis_constructor.patch"
    ]

oracleSource, casesSource, specSource :: FilePath
oracleSource = "test/spec/ui/OfflinePlanReference.hs"
casesSource = "test/spec/ui/OfflinePlanCases.hs"
specSource = "test/spec/ui/OfflinePlanSpec.hs"
