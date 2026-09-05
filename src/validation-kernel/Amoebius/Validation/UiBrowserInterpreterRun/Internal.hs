{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.UiBrowserInterpreterRun.Internal (
    AcquiredUiBrowserInterpreterRun,
    acquireUiBrowserInterpreterRefreshRun,
    acquireUiBrowserInterpreterRun,
    acquiredUiBrowserInterpreterRunCheck,
    foldAcquiredUiBrowserInterpreterRun,
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

data AcquiredUiBrowserInterpreterRun
    = AcquiredUiBrowserInterpreterRun
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

acquiredUiBrowserInterpreterRunCheck :: AcquiredUiBrowserInterpreterRun -> CheckResult
acquiredUiBrowserInterpreterRunCheck (AcquiredUiBrowserInterpreterRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredUiBrowserInterpreterRun ::
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
    AcquiredUiBrowserInterpreterRun ->
    value
foldAcquiredUiBrowserInterpreterRun consume (AcquiredUiBrowserInterpreterRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireUiBrowserInterpreterRun
    , acquireUiBrowserInterpreterRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiBrowserInterpreterRun
acquireUiBrowserInterpreterRun = acquire False
acquireUiBrowserInterpreterRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiBrowserInterpreterRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 42 acquired
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
        cleanroom = mergeChecks "ui-browser-interpreter-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "ui-browser-interpreter-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "ui-browser-interpreter-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "ui-browser-interpreter" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "ui-browser-interpreter-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "ui-browser-interpreter-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "ui-browser-interpreter-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "ui-browser-interpreter-observer" [checkDigest observer]
        qualificationId = ids "ui-browser-interpreter-qualification" [checkDigest qualification]
        acquiredRunId = ids "ui-browser-interpreter-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "ui-browser-interpreter-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredUiBrowserInterpreterRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
                   , "ui-browser-interpreter-spec"
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
    [ mutant "raw-html-sink" "ui-browser-raw-html-mutant" "Interpreter.renderTrustedText" "trusted text escaping: expected"
    , mutant "drop-event-effect" "ui-browser-drop-event-mutant" "Interpreter.interpret" "interpreter traces: expected"
    , mutant "swap-route-target" "ui-browser-swap-route-mutant" "Interpreter.interpret" "interpreter traces: expected"
    , mutant "accept-stale-plan" "ui-browser-accept-stale-mutant" "Interpreter.verifyEnvelope" "stale envelope: expected"
    , mutant "direct-provider-fetch" "ui-browser-direct-provider-mutant" "Interpreter.providerRequestAllowed" "provider request refusal: expected"
    , mutant "sequential-state-writes" "ui-browser-sequential-writes-mutant" "Interpreter.interpret" "interpreter traces: expected"
    , mutant "break-focus-return" "ui-browser-break-focus-mutant" "Interpreter.focusAfter" "focus rows: expected"
    , mutant "unsafe-inline-build" "ui-browser-unsafe-inline-mutant" "Projection.projectPureScript" "safe projected source: expected"
    , mutant "hardcoded-response" "ui-browser-hardcoded-response-mutant" "Interpreter.challengeBody" "fresh challenge: expected"
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
        "ui-browser-interpreter-toolchain"
        [observation "ui-browser-interpreter.cabal" (receiptSummary version), observation "ui-browser-interpreter.compiler" (Text.pack compiler)]
        ( [ finding "UI-BROWSER-INTERPRETER-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "UI-BROWSER-INTERPRETER-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
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
        "ui-browser-interpreter-independent-oracle"
        [observation "ui-browser-interpreter.oracle" (receiptSummary clean), observation "ui-browser-interpreter.oracle-independence" "UiBrowserInterpreterReference imports no production or case module"]
        [ finding "UI-BROWSER-INTERPRETER-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "ui-browser-interpreter-spec: PASS (2 plans, 5 interactions, 5 traces, 2 semantic views, 3 accessibility rows, 5 focus rows, 4 transport rows, 9 mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "ui-browser-interpreter-positive-controls"
        [observation "ui-browser-interpreter.positives" "two plans, five interactions, pure visible-state/effect/route semantics, accessibility/focus rows, transport rows, and deterministic source projection passed"]
        [ finding "UI-BROWSER-INTERPRETER-POSITIVE" specSource "the clean paired-plan compiler corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "ui-browser-interpreter-calculus: PASS (5 kinds, 72 projected units)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ _ clean) =
    CheckResult
        "ui-browser-interpreter-paired-negatives"
        [observation "ui-browser-interpreter.negatives" "stale envelope, hostile text, provider origin, hardcoded challenge, and unsafe projected-source controls passed"]
        [ finding "UI-BROWSER-INTERPRETER-PAIRED-NEGATIVES" specSource "the clean candidate did not exercise the complete typed refusal and sensitivity battery"
        | receiptExit clean /= ExitSuccess || notContains "5 traces, 2 semantic views, 3 accessibility rows, 5 focus rows, 4 transport rows" (receiptOutput clean)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "ui-browser-interpreter-mutants"
        [observation ("ui-browser-interpreter.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "UI-BROWSER-INTERPRETER-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "ui-browser-interpreter-source-discipline"
            [observation "ui-browser-interpreter.production-module-count" "2", observation "ui-browser-interpreter.effect-boundary" "pure client-plan interpretation and browser-language source projection with serial run-local Cabal children only; no browser, Node, Python, network, service, cluster, or hardware effects"]
            ( [ finding "UI-BROWSER-INTERPRETER-SOURCE-SHAPE" "<ui-browser-interpreter-production>" ("missing production element: " <> token)
              | token <- ["data ClientPlan", "interpret", "verifyEnvelope", "renderTrustedText", "focusAfter", "challengeBody", "providerRequestAllowed", "projectPureScript", "projectionIsSafe", "UI_BROWSER_RAW_HTML_SINK_MUTANT", "UI_BROWSER_DROP_EVENT_EFFECT_MUTANT", "UI_BROWSER_SWAP_ROUTE_TARGET_MUTANT", "UI_BROWSER_ACCEPT_STALE_PLAN_MUTANT", "UI_BROWSER_DIRECT_PROVIDER_FETCH_MUTANT", "UI_BROWSER_SEQUENTIAL_WRITES_MUTANT", "UI_BROWSER_BREAK_FOCUS_RETURN_MUTANT", "UI_BROWSER_UNSAFE_INLINE_BUILD_MUTANT", "UI_BROWSER_HARDCODED_RESPONSE_MUTANT"]
              , notContains token production
              ]
                <> [ finding "UI-BROWSER-INTERPRETER-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["traceRows", "accessibilityRows", "focusRows", "transportRows"]
                   , notContains token oracle
                   ]
                <> [ finding "UI-BROWSER-INTERPRETER-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "ui-browser-interpreter-discovery"
        [observation "ui-browser-interpreter.discovery.count" (Text.pack (show (length observed)))]
        [finding "UI-BROWSER-INTERPRETER-DISCOVERY" "<phase-42-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "ui-browser-interpreter-authority"
        [observation "ui-browser-interpreter.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "UI-BROWSER-INTERPRETER-RUN-ROOT" runRoot "run root escaped .build/runs/phase-42/work" | not (pathBelow (root </> ".build/runs/phase-42/work") runRoot)]
            <> [ finding "UI-BROWSER-INTERPRETER-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-42 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "ui-browser-interpreter-observer"
        (map (observation "ui-browser-interpreter.observer.process" . receiptSummary) receipts)
        [ finding "UI-BROWSER-INTERPRETER-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "ui-browser-interpreter-freshness"
        [observation "ui-browser-interpreter.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "UI-BROWSER-INTERPRETER-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-42/work") runRoot)
        ]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
    files <- filterM (doesFileExist . (root </>)) retiredSources
    pure
        ( CheckResult
            "ui-browser-interpreter-legacy-closure"
            [observation "ui-browser-interpreter.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "ui-browser-interpreter.legacy.semantic-inputs" "HaskellOnly"]
            [finding "UI-BROWSER-INTERPRETER-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files]
        )

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-42-claim" [pre]
    , named "phase-42-subject" [toolchain, positives]
    , named "phase-42-command" [toolchain, authority]
    , named "phase-42-oracle" [oracle]
    , named "phase-42-positive-controls" [positives]
    , named "phase-42-paired-negatives" [negatives]
    , named "phase-42-mutants" [mutants]
    , named "phase-42-discovery" [discovery]
    , named "phase-42-challenge" [mutants]
    , named "phase-42-observer" [observer]
    , named "phase-42-authority-bypass" [authority]
    , named "phase-42-freshness" [freshness]
    , named "phase-42-qualification" [qualification]
    , named "phase-42-cleanroom" [cleanroom]
    , named "phase-42-legacy-closure" [legacy]
    , CheckResult "phase-42-predecessor" [observation "phase-42.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-42-residue" [observation "phase-42.residue" "browser execution and accessibility fidelity, CSP and OS network enforcement, server/provider authority, publication, release, HA, and hardware remain later-owned"] []
    , named "phase-42-pass-criterion" [pre]
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
            "ui-browser-interpreter-source-repository-cache"
            [observation "ui-browser-interpreter.cache.entries" (Text.pack (show copied))]
            [ finding "UI-BROWSER-INTERPRETER-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
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
    let parent = root </> ".build/runs/phase-42/work"
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
    [ "src/Amoebius/Ui/Browser/Interpreter.hs"
    , "src/Amoebius/Ui/Browser/Projection.hs"
    ]
expectedSources = sort (productionSources <> [oracleSource, casesSource, specSource])
retiredSources =
    [ "tools/ui_browser_interpreter_gate.py"
    , "test/fixture/ui_browser/artifact_allowlist.tsv"
    , "test/fixture/ui_browser/expected_accessibility.tsv"
    , "test/fixture/ui_browser/expected_dom/multi-choose.txt"
    , "test/fixture/ui_browser/expected_dom/single-submit.txt"
    , "test/fixture/ui_browser/expected_keyboard_focus.tsv"
    , "test/fixture/ui_browser/expected_transport.tsv"
    , "test/fixture/ui_browser/interactions.tsv"
    , "test/fixture/ui_browser/plans/minimal_multi_tenant.json"
    , "test/fixture/ui_browser/plans/minimal_single_tenant.json"
    , "test/harness/ui_browser/browser.mjs"
    , "test/harness/ui_browser/scan_artifact.py"
    , "test/oracle/ui_browser_interpreter/calculus_projection.tsv"
    , "test/oracle/ui_browser_interpreter/validation_locus.tsv"
    , "test/oracle/ui_browser_interpreter_surfaces.tsv"
    , "test/spec/ui/ReferenceClientPlan.hs"
    , "test/mutant/ui_browser_interpreter/M-accept-stale-plan.mutant"
    , "test/mutant/ui_browser_interpreter/M-break-focus-return.mutant"
    , "test/mutant/ui_browser_interpreter/M-direct-provider-fetch.mutant"
    , "test/mutant/ui_browser_interpreter/M-drop-event-effect.mutant"
    , "test/mutant/ui_browser_interpreter/M-hardcoded-response.mutant"
    , "test/mutant/ui_browser_interpreter/M-raw-html-sink.mutant"
    , "test/mutant/ui_browser_interpreter/M-sequential-state-writes.mutant"
    , "test/mutant/ui_browser_interpreter/M-swap-route-target.mutant"
    , "test/mutant/ui_browser_interpreter/M-unsafe-inline-build.mutant"
    ]

oracleSource, casesSource, specSource :: FilePath
oracleSource = "test/spec/ui/UiBrowserInterpreterReference.hs"
casesSource = "test/spec/ui/UiBrowserInterpreterCases.hs"
specSource = "test/spec/ui/UiBrowserInterpreterSpec.hs"
