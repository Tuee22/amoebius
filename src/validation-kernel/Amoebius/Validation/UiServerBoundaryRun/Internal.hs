{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.UiServerBoundaryRun.Internal (
    AcquiredUiServerBoundaryRun,
    acquireUiServerBoundaryRefreshRun,
    acquireUiServerBoundaryRun,
    acquiredUiServerBoundaryRunCheck,
    foldAcquiredUiServerBoundaryRun,
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

data AcquiredUiServerBoundaryRun
    = AcquiredUiServerBoundaryRun
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

acquiredUiServerBoundaryRunCheck :: AcquiredUiServerBoundaryRun -> CheckResult
acquiredUiServerBoundaryRunCheck (AcquiredUiServerBoundaryRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredUiServerBoundaryRun ::
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
    AcquiredUiServerBoundaryRun ->
    value
foldAcquiredUiServerBoundaryRun consume (AcquiredUiServerBoundaryRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireUiServerBoundaryRun
    , acquireUiServerBoundaryRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiServerBoundaryRun
acquireUiServerBoundaryRun = acquire False
acquireUiServerBoundaryRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiServerBoundaryRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 43 acquired
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
        cleanroom = mergeChecks "ui-server-boundary-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "ui-server-boundary-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "ui-server-boundary-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "ui-server-boundary" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "ui-server-boundary-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "ui-server-boundary-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "ui-server-boundary-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "ui-server-boundary-observer" [checkDigest observer]
        qualificationId = ids "ui-server-boundary-qualification" [checkDigest qualification]
        acquiredRunId = ids "ui-server-boundary-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "ui-server-boundary-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredUiServerBoundaryRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
                   , "ui-server-boundary-spec"
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
    [ mutant "trust-tenant-header" "ui-server-trust-tenant-header-mutant" "Dispatch.authorizeAndDispatch" "HTTP policy rows: expected"
    , mutant "dispatch-before-authorize" "ui-server-dispatch-before-authorize-mutant" "Dispatch.authorizeAndDispatch" "denied handler bytes: expected"
    , mutant "skip-current-epoch" "ui-server-skip-current-epoch-mutant" "Dispatch.authorizeAndDispatch" "HTTP policy rows: expected"
    , mutant "disable-origin-check" "ui-server-disable-origin-check-mutant" "Dispatch.authorizeAndDispatch" "HTTP policy rows: expected"
    , mutant "drop-csp-header" "ui-server-drop-csp-header-mutant" "Dispatch.securityHeadersFor" "CSP header: expected"
    , mutant "ready-unresolved-handler" "ui-server-ready-unresolved-handler-mutant" "Dispatch.admitServerPlan" "startup policy rows: expected"
    , mutant "first-handler-wins" "ui-server-first-handler-wins-mutant" "Dispatch.admitServerPlan" "startup policy rows: expected"
    , mutant "serve-private-plan" "ui-server-serve-private-plan-mutant" "Dispatch.assetVisible" "private plan probe: expected"
    , mutant "new-retry-key" "ui-server-new-retry-key-mutant" "Dispatch.retryIdempotencyKey" "idempotent replay: expected"
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
        "ui-server-boundary-toolchain"
        [observation "ui-server-boundary.cabal" (receiptSummary version), observation "ui-server-boundary.compiler" (Text.pack compiler)]
        ( [ finding "UI-SERVER-BOUNDARY-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "UI-SERVER-BOUNDARY-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
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
        "ui-server-boundary-independent-oracle"
        [observation "ui-server-boundary.oracle" (receiptSummary clean), observation "ui-server-boundary.oracle-independence" "UiServerBoundaryReference imports no production or case module"]
        [ finding "UI-SERVER-BOUNDARY-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "ui-server-boundary-spec: PASS (5 HTTP rows, 5 access rows, 5 audits, 2 effects, 6 startup rows, 5 public assets, 5 private probes, 7 WebSocket rows, 9 mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "ui-server-boundary-positive-controls"
        [observation "ui-server-boundary.positives" "authenticated HTTP policy, authorization-before-dispatch, startup admission, public-only asset serving, idempotent retry, WebSocket registration, and composed calculus controls passed"]
        [ finding "UI-SERVER-BOUNDARY-POSITIVE" specSource "the clean UI-server boundary corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "ui-server-boundary-calculus: PASS (5 kinds, 80 projected units)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ _ clean) =
    CheckResult
        "ui-server-boundary-paired-negatives"
        [observation "ui-server-boundary.negatives" "foreign scope, hostile origin, stale epoch, missing/duplicate/incompatible handlers, private assets, and invalid WebSocket registrations were refused"]
        [ finding "UI-SERVER-BOUNDARY-PAIRED-NEGATIVES" specSource "the clean candidate did not exercise the complete typed refusal and sensitivity battery"
        | receiptExit clean /= ExitSuccess || notContains "5 HTTP rows, 5 access rows, 5 audits, 2 effects, 6 startup rows, 5 public assets, 5 private probes, 7 WebSocket rows" (receiptOutput clean)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "ui-server-boundary-mutants"
        [observation ("ui-server-boundary.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "UI-SERVER-BOUNDARY-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "ui-server-boundary-source-discipline"
            [observation "ui-server-boundary.production-module-count" "6", observation "ui-server-boundary.effect-boundary" "pure authenticated request, startup, asset, retry, and WebSocket boundary checks with serial run-local Cabal children only; no browser, Node, Python, network, service, cluster, or hardware effects"]
            ( [ finding "UI-SERVER-BOUNDARY-SOURCE-SHAPE" "<ui-server-boundary-production>" ("missing production element: " <> token)
              | token <- ["compiledBoundaryMutant", "authorizeAndDispatch", "admitServerPlan", "signCredential", "productionSecurityHeaders", "validateRegistration", "UI_SERVER_TRUST_TENANT_HEADER_MUTANT", "UI_SERVER_DISPATCH_BEFORE_AUTHORIZE_MUTANT", "UI_SERVER_SKIP_CURRENT_EPOCH_MUTANT", "UI_SERVER_DISABLE_ORIGIN_CHECK_MUTANT", "UI_SERVER_DROP_CSP_HEADER_MUTANT", "UI_SERVER_READY_UNRESOLVED_HANDLER_MUTANT", "UI_SERVER_FIRST_HANDLER_WINS_MUTANT", "UI_SERVER_SERVE_PRIVATE_PLAN_MUTANT", "UI_SERVER_NEW_RETRY_KEY_MUTANT"]
              , notContains token production
              ]
                <> [ finding "UI-SERVER-BOUNDARY-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["httpRows", "startupRows", "publicAssets", "privateAssets", "websocketTags"]
                   , notContains token oracle
                   ]
                <> [ finding "UI-SERVER-BOUNDARY-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "ui-server-boundary-discovery"
        [observation "ui-server-boundary.discovery.count" (Text.pack (show (length observed)))]
        [finding "UI-SERVER-BOUNDARY-DISCOVERY" "<phase-43-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "ui-server-boundary-authority"
        [observation "ui-server-boundary.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "UI-SERVER-BOUNDARY-RUN-ROOT" runRoot "run root escaped .build/runs/phase-43/work" | not (pathBelow (root </> ".build/runs/phase-43/work") runRoot)]
            <> [ finding "UI-SERVER-BOUNDARY-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-43 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "ui-server-boundary-observer"
        (map (observation "ui-server-boundary.observer.process" . receiptSummary) receipts)
        [ finding "UI-SERVER-BOUNDARY-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "ui-server-boundary-freshness"
        [observation "ui-server-boundary.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "UI-SERVER-BOUNDARY-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-43/work") runRoot)
        ]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
    files <- filterM (doesFileExist . (root </>)) retiredSources
    pure
        ( CheckResult
            "ui-server-boundary-legacy-closure"
            [observation "ui-server-boundary.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "ui-server-boundary.legacy.semantic-inputs" "HaskellOnly"]
            [finding "UI-SERVER-BOUNDARY-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files]
        )

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-43-claim" [pre]
    , named "phase-43-subject" [toolchain, positives]
    , named "phase-43-command" [toolchain, authority]
    , named "phase-43-oracle" [oracle]
    , named "phase-43-positive-controls" [positives]
    , named "phase-43-paired-negatives" [negatives]
    , named "phase-43-mutants" [mutants]
    , named "phase-43-discovery" [discovery]
    , named "phase-43-challenge" [mutants]
    , named "phase-43-observer" [observer]
    , named "phase-43-authority-bypass" [authority]
    , named "phase-43-freshness" [freshness]
    , named "phase-43-qualification" [qualification]
    , named "phase-43-cleanroom" [cleanroom]
    , named "phase-43-legacy-closure" [legacy]
    , CheckResult "phase-43-predecessor" [observation "phase-43.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-43-residue" [observation "phase-43.residue" "browser execution and accessibility fidelity, CSP and OS network enforcement, server/provider authority, publication, release, HA, and hardware remain later-owned"] []
    , named "phase-43-pass-criterion" [pre]
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
            "ui-server-boundary-source-repository-cache"
            [observation "ui-server-boundary.cache.entries" (Text.pack (show copied))]
            [ finding "UI-SERVER-BOUNDARY-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
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
    let parent = root </> ".build/runs/phase-43/work"
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
    [ "src/Amoebius/Ui/Server/Dispatch.hs"
    , "src/Amoebius/Ui/Server/RequestContext.hs"
    , "src/Amoebius/Ui/Server/Security.hs"
    , "src/Amoebius/Ui/Server/SecurityHeaders.hs"
    , "src/Amoebius/Ui/Server/WebSocket.hs"
    , "src/Amoebius/Ui/Realtime/Envelope.hs"
    ]
expectedSources = sort (productionSources <> [oracleSource, casesSource, specSource])
retiredSources =
    [ "tools/ui_server_boundary_gate.py"
    , "test/fixture/ui_server/access_matrix.tsv"
    , "test/fixture/ui_server/expected_audit.tsv"
    , "test/fixture/ui_server/expected_effects.tsv"
    , "test/fixture/ui_server/expected_http.tsv"
    , "test/fixture/ui_server/forbidden_server_manifest_paths.tsv"
    , "test/fixture/ui_server/idempotency.tsv"
    , "test/fixture/ui_server/public_asset_allowlist.tsv"
    , "test/fixture/ui_server/requests.tsv"
    , "test/fixture/ui_server/startup_plan_matrix.tsv"
    , "test/fixture/ui_server/websocket_registration.tsv"
    , "test/harness/ui_server/server_boundary.mjs"
    , "test/oracle/ui_server_boundary/calculus_projection.tsv"
    , "test/oracle/ui_server_boundary/validation_locus.tsv"
    , "test/oracle/ui_server_boundary_surfaces.tsv"
    , "test/mutant/ui_server_boundary/M-disable-origin-check.mutant"
    , "test/mutant/ui_server_boundary/M-dispatch-before-authorize.mutant"
    , "test/mutant/ui_server_boundary/M-drop-csp-header.mutant"
    , "test/mutant/ui_server_boundary/M-new-idempotency-key-on-retry.mutant"
    , "test/mutant/ui_server_boundary/M-ready-with-unresolved-handler.mutant"
    , "test/mutant/ui_server_boundary/M-serve-server-plan-as-client-asset.mutant"
    , "test/mutant/ui_server_boundary/M-server-first-handler-wins.mutant"
    , "test/mutant/ui_server_boundary/M-skip-current-epoch.mutant"
    , "test/mutant/ui_server_boundary/M-trust-tenant-header.mutant"
    ]

oracleSource, casesSource, specSource :: FilePath
oracleSource = "test/spec/ui/UiServerBoundaryReference.hs"
casesSource = "test/spec/ui/UiServerBoundaryCases.hs"
specSource = "test/spec/ui/UiServerBoundarySpec.hs"
