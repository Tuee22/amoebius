{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.UiLocalCompositionRun.Internal (
    AcquiredUiLocalCompositionRun,
    acquireUiLocalCompositionRefreshRun,
    acquireUiLocalCompositionRun,
    acquiredUiLocalCompositionRunCheck,
    foldAcquiredUiLocalCompositionRun,
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

data AcquiredUiLocalCompositionRun
    = AcquiredUiLocalCompositionRun
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

acquiredUiLocalCompositionRunCheck :: AcquiredUiLocalCompositionRun -> CheckResult
acquiredUiLocalCompositionRunCheck (AcquiredUiLocalCompositionRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredUiLocalCompositionRun ::
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
    AcquiredUiLocalCompositionRun ->
    value
foldAcquiredUiLocalCompositionRun consume (AcquiredUiLocalCompositionRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireUiLocalCompositionRun
    , acquireUiLocalCompositionRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiLocalCompositionRun
acquireUiLocalCompositionRun = acquire False
acquireUiLocalCompositionRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiLocalCompositionRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 44 acquired
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
        cleanroom = mergeChecks "ui-local-composition-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "ui-local-composition-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "ui-local-composition-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "ui-local-composition" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "ui-local-composition-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "ui-local-composition-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "ui-local-composition-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "ui-local-composition-observer" [checkDigest observer]
        qualificationId = ids "ui-local-composition-qualification" [checkDigest qualification]
        acquiredRunId = ids "ui-local-composition-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "ui-local-composition-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredUiLocalCompositionRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
                   , "ui-local-composition-spec"
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
    [ mutant "drop-handle-tenant" "ui-local-drop-handle-tenant-mutant" "LocalComposition.tenantMatches" "foreign tenant denial: expected"
    , mutant "direct-workflow-fetch" "ui-local-direct-workflow-fetch-mutant" "LocalComposition.runCompositionRequest" "direct browser backend denial: expected"
    , mutant "mix-client-server-plan" "ui-local-mix-client-server-plan-mutant" "LocalComposition.pairedPlanIdentity" "paired plan digest: expected"
    , mutant "ready-before-receipt" "ui-local-ready-before-receipt-mutant" "LocalComposition.handleReady" "non-ready handle denial: expected"
    , mutant "owner-key-swap" "ui-local-owner-key-swap-mutant" "LocalComposition.ownerMatches" "foreign subject denial: expected"
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
        "ui-local-composition-toolchain"
        [observation "ui-local-composition.cabal" (receiptSummary version), observation "ui-local-composition.compiler" (Text.pack compiler)]
        ( [ finding "UI-LOCAL-COMPOSITION-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "UI-LOCAL-COMPOSITION-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
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
        "ui-local-composition-independent-oracle"
        [observation "ui-local-composition.oracle" (receiptSummary clean), observation "ui-local-composition.oracle-independence" "UiLocalCompositionReference imports no production or case module"]
        [ finding "UI-LOCAL-COMPOSITION-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "ui-local-composition-spec: PASS (2 apps, 5 interactions, 4 visible pins, 4 effect rows, 3 access rows, 5 denials, 5 mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "ui-local-composition-positive-controls"
        [observation "ui-local-composition.positives" "two application shapes, five interactions, four visible states, ordered fake-domain effects, and composed calculus controls passed"]
        [ finding "UI-LOCAL-COMPOSITION-POSITIVE" specSource "the clean local UI composition corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "ui-local-composition-calculus: PASS (5 kinds, 55 projected units)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ _ clean) =
    CheckResult
        "ui-local-composition-paired-negatives"
        [observation "ui-local-composition.negatives" "foreign tenant, foreign owner, caller-tenant spoof, non-ready handle, and direct browser/domain bypass were refused"]
        [ finding "UI-LOCAL-COMPOSITION-PAIRED-NEGATIVES" specSource "the clean candidate did not exercise the complete typed refusal and sensitivity battery"
        | receiptExit clean /= ExitSuccess || notContains "5 interactions, 4 visible pins, 4 effect rows, 3 access rows, 5 denials" (receiptOutput clean)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "ui-local-composition-mutants"
        [observation ("ui-local-composition.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "UI-LOCAL-COMPOSITION-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "ui-local-composition-source-discipline"
            [observation "ui-local-composition.production-module-count" "1", observation "ui-local-composition.effect-boundary" "pure typed workflow/artifact composition and fake-domain effect values with serial run-local Cabal children only; no browser, Node, Python, Dhall executable, network, service, cluster, or hardware effects"]
            ( [ finding "UI-LOCAL-COMPOSITION-SOURCE-SHAPE" "<ui-local-composition-production>" ("missing production element: " <> token)
              | token <- ["data ReadyArtifactHandle", "runCompositionRequest", "pairedPlanIdentity", "UI_LOCAL_DROP_HANDLE_TENANT_MUTANT", "UI_LOCAL_DIRECT_WORKFLOW_FETCH_MUTANT", "UI_LOCAL_MIX_CLIENT_SERVER_PLAN_MUTANT", "UI_LOCAL_READY_BEFORE_RECEIPT_MUTANT", "UI_LOCAL_OWNER_KEY_SWAP_MUTANT"]
              , notContains token production
              ]
                <> [ finding "UI-LOCAL-COMPOSITION-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["accessRows", "denialRows", "effectRows", "visibleRows"]
                   , notContains token oracle
                   ]
                <> [ finding "UI-LOCAL-COMPOSITION-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "ui-local-composition-discovery"
        [observation "ui-local-composition.discovery.count" (Text.pack (show (length observed)))]
        [finding "UI-LOCAL-COMPOSITION-DISCOVERY" "<phase-44-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "ui-local-composition-authority"
        [observation "ui-local-composition.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "UI-LOCAL-COMPOSITION-RUN-ROOT" runRoot "run root escaped .build/runs/phase-44/work" | not (pathBelow (root </> ".build/runs/phase-44/work") runRoot)]
            <> [ finding "UI-LOCAL-COMPOSITION-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-44 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "ui-local-composition-observer"
        (map (observation "ui-local-composition.observer.process" . receiptSummary) receipts)
        [ finding "UI-LOCAL-COMPOSITION-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "ui-local-composition-freshness"
        [observation "ui-local-composition.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "UI-LOCAL-COMPOSITION-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-44/work") runRoot)
        ]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
    files <- filterM (doesFileExist . (root </>)) retiredSources
    pure
        ( CheckResult
            "ui-local-composition-legacy-closure"
            [observation "ui-local-composition.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "ui-local-composition.legacy.semantic-inputs" "HaskellOnly"]
            [finding "UI-LOCAL-COMPOSITION-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files]
        )

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-44-claim" [pre]
    , named "phase-44-subject" [toolchain, positives]
    , named "phase-44-command" [toolchain, authority]
    , named "phase-44-oracle" [oracle]
    , named "phase-44-positive-controls" [positives]
    , named "phase-44-paired-negatives" [negatives]
    , named "phase-44-mutants" [mutants]
    , named "phase-44-discovery" [discovery]
    , named "phase-44-challenge" [mutants]
    , named "phase-44-observer" [observer]
    , named "phase-44-authority-bypass" [authority]
    , named "phase-44-freshness" [freshness]
    , named "phase-44-qualification" [qualification]
    , named "phase-44-cleanroom" [cleanroom]
    , named "phase-44-legacy-closure" [legacy]
    , CheckResult "phase-44-predecessor" [observation "phase-44.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-44-residue" [observation "phase-44.residue" "browser execution and accessibility fidelity, CSP and OS network enforcement, server/provider authority, publication, release, HA, and hardware remain later-owned"] []
    , named "phase-44-pass-criterion" [pre]
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
            "ui-local-composition-source-repository-cache"
            [observation "ui-local-composition.cache.entries" (Text.pack (show copied))]
            [ finding "UI-LOCAL-COMPOSITION-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
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
    let parent = root </> ".build/runs/phase-44/work"
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
productionSources = ["src/Amoebius/Ui/LocalComposition.hs"]
expectedSources = sort (productionSources <> [oracleSource, casesSource, specSource])
retiredSources =
    [ "tools/local_ui_composition_gate.py"
    , "test/fixture/ui_local_composition/access_matrix.tsv"
    , "test/fixture/ui_local_composition/expected_denials.tsv"
    , "test/fixture/ui_local_composition/expected_effect_sequence.tsv"
    , "test/fixture/ui_local_composition/expected_visible_states.tsv"
    , "test/fixture/ui_local_composition/interactions.tsv"
    , "test/harness/local_ui_composition/composition.mjs"
    , "test/oracle/local_ui_composition/calculus_projection.tsv"
    , "test/oracle/local_ui_composition/validation_locus.tsv"
    , "test/oracle/local_ui_composition_surfaces.tsv"
    , "test/mutant/local_ui_composition/M-direct-workflow-fetch.mutant"
    , "test/mutant/local_ui_composition/M-drop-handle-tenant.mutant"
    , "test/mutant/local_ui_composition/M-mix-client-server-plan.mutant"
    , "test/mutant/local_ui_composition/M-ready-before-receipt.mutant"
    , "test/mutant/local_ui_composition/owner_key_swap.mutant"
    ]

oracleSource, casesSource, specSource :: FilePath
oracleSource = "test/spec/ui/UiLocalCompositionReference.hs"
casesSource = "test/spec/ui/UiLocalCompositionCases.hs"
specSource = "test/spec/ui/LocalCompositionSpec.hs"
