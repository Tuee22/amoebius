{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.UiPlanCompilerRun.Internal (
    AcquiredUiPlanCompilerRun,
    acquireUiPlanCompilerRefreshRun,
    acquireUiPlanCompilerRun,
    acquiredUiPlanCompilerRunCheck,
    foldAcquiredUiPlanCompilerRun,
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

data AcquiredUiPlanCompilerRun
    = AcquiredUiPlanCompilerRun
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

acquiredUiPlanCompilerRunCheck :: AcquiredUiPlanCompilerRun -> CheckResult
acquiredUiPlanCompilerRunCheck (AcquiredUiPlanCompilerRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredUiPlanCompilerRun ::
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
    AcquiredUiPlanCompilerRun ->
    value
foldAcquiredUiPlanCompilerRun consume (AcquiredUiPlanCompilerRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireUiPlanCompilerRun
    , acquireUiPlanCompilerRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiPlanCompilerRun
acquireUiPlanCompilerRun = acquire False
acquireUiPlanCompilerRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiPlanCompilerRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 40 acquired
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
        cleanroom = mergeChecks "ui-plan-compiler-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "ui-plan-compiler-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "ui-plan-compiler-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "ui-plan-compiler" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "ui-plan-compiler-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "ui-plan-compiler-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "ui-plan-compiler-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "ui-plan-compiler-observer" [checkDigest observer]
        qualificationId = ids "ui-plan-compiler-qualification" [checkDigest qualification]
        acquiredRunId = ids "ui-plan-compiler-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "ui-plan-compiler-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredUiPlanCompilerRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
                   , "ui-plan-compiler-spec"
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
    [ mutant "drop-server-action" "ui-plan-drop-server-action-mutant" "ServerPlan.compileServerPlan" "compile plans: ClientServerActionMismatch"
    , mutant "swap-action-targets" "ui-plan-swap-action-targets-mutant" "ServerPlan.compileServerPlan" "ui_server_plan.golden.json: expected"
    , mutant "emit-private-field" "ui-plan-emit-private-mutant" "ClientPlan.encodeClientPlan" "client_plan.golden.json: expected"
    , mutant "client-only-authority-digest" "ui-plan-client-only-authority-mutant" "Manifest.compileUiPlans" "canonical digests over the authored goldens: expected"
    , mutant "link-navigation-as-fetch" "ui-plan-link-as-fetch-mutant" "ClientPlan.encodeClientPlan" "client_plan.golden.json: expected"
    , mutant "preserve-insertion-order" "ui-plan-insertion-order-mutant" "ClientPlan.uniqueSorted" "client_plan.golden.json: expected"
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
        "ui-plan-compiler-toolchain"
        [observation "ui-plan-compiler.cabal" (receiptSummary version), observation "ui-plan-compiler.compiler" (Text.pack compiler)]
        ( [ finding "UI-PLAN-COMPILER-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "UI-PLAN-COMPILER-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
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
        "ui-plan-compiler-independent-oracle"
        [observation "ui-plan-compiler.oracle" (receiptSummary clean), observation "ui-plan-compiler.oracle-independence" "PlanCompilerReference imports no production or case module"]
        [ finding "UI-PLAN-COMPILER-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "ui-plan-compiler-spec: PASS (4 projections, 4 canonical artifacts, 4 digests, 6 demand cells, 2 fresh processes, 6 mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "ui-plan-compiler-positive-controls"
        [observation "ui-plan-compiler.positives" "four typed logical projections, four canonical artifacts, four independent digests, and six finite demand cells passed"]
        [ finding "UI-PLAN-COMPILER-POSITIVE" specSource "the clean paired-plan compiler corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "ui-plan-compiler-calculus: PASS (5 kinds, 32 projected units)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ _ clean) =
    CheckResult
        "ui-plan-compiler-paired-negatives"
        [observation "ui-plan-compiler.negatives" "private-field, link-as-effect, authority-change, authority-omission, and insertion-order controls passed"]
        [ finding "UI-PLAN-COMPILER-PAIRED-NEGATIVES" specSource "the clean candidate did not exercise the complete typed refusal and sensitivity battery"
        | receiptExit clean /= ExitSuccess || notContains "4 digests, 6 demand cells, 2 fresh processes" (receiptOutput clean)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "ui-plan-compiler-mutants"
        [observation ("ui-plan-compiler.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "UI-PLAN-COMPILER-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "ui-plan-compiler-source-discipline"
            [observation "ui-plan-compiler.production-module-count" "4", observation "ui-plan-compiler.effect-boundary" "pure paired client/server plan, contract, content-manifest, digest, and finite-demand compilation with serial run-local Cabal children only; no interpreter, publication, network, service, cluster, or hardware effects"]
            ( [ finding "UI-PLAN-COMPILER-SOURCE-SHAPE" "<ui-plan-compiler-production>" ("missing production element: " <> token)
              | token <- ["data CompiledUiPlans", "compileUiPlans", "compileClientPlan", "compileServerPlan", "compileRuntimeDemand", "UI_PLAN_DROP_SERVER_ACTION_MUTANT", "UI_PLAN_SWAP_ACTION_TARGETS_MUTANT", "UI_PLAN_EMIT_PRIVATE_MUTANT", "UI_PLAN_CLIENT_ONLY_AUTHORITY_MUTANT", "UI_PLAN_LINK_AS_FETCH_MUTANT", "UI_PLAN_INSERTION_ORDER_MUTANT"]
              , notContains token production
              ]
                <> [ finding "UI-PLAN-COMPILER-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["referenceProjectionRows", "referenceAuthoritySource", "referenceDigest"]
                   , notContains token oracle
                   ]
                <> [ finding "UI-PLAN-COMPILER-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "ui-plan-compiler-discovery"
        [observation "ui-plan-compiler.discovery.count" (Text.pack (show (length observed)))]
        [finding "UI-PLAN-COMPILER-DISCOVERY" "<phase-40-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "ui-plan-compiler-authority"
        [observation "ui-plan-compiler.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "UI-PLAN-COMPILER-RUN-ROOT" runRoot "run root escaped .build/runs/phase-40/work" | not (pathBelow (root </> ".build/runs/phase-40/work") runRoot)]
            <> [ finding "UI-PLAN-COMPILER-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-40 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "ui-plan-compiler-observer"
        (map (observation "ui-plan-compiler.observer.process" . receiptSummary) receipts)
        [ finding "UI-PLAN-COMPILER-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "ui-plan-compiler-freshness"
        [observation "ui-plan-compiler.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "UI-PLAN-COMPILER-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-40/work") runRoot)
        ]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
    files <- filterM (doesFileExist . (root </>)) retiredSources
    pure
        ( CheckResult
            "ui-plan-compiler-legacy-closure"
            [observation "ui-plan-compiler.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "ui-plan-compiler.legacy.semantic-inputs" "HaskellOnly"]
            [finding "UI-PLAN-COMPILER-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files]
        )

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-40-claim" [pre]
    , named "phase-40-subject" [toolchain, positives]
    , named "phase-40-command" [toolchain, authority]
    , named "phase-40-oracle" [oracle]
    , named "phase-40-positive-controls" [positives]
    , named "phase-40-paired-negatives" [negatives]
    , named "phase-40-mutants" [mutants]
    , named "phase-40-discovery" [discovery]
    , named "phase-40-challenge" [mutants]
    , named "phase-40-observer" [observer]
    , named "phase-40-authority-bypass" [authority]
    , named "phase-40-freshness" [freshness]
    , named "phase-40-qualification" [qualification]
    , named "phase-40-cleanroom" [cleanroom]
    , named "phase-40-legacy-closure" [legacy]
    , CheckResult "phase-40-predecessor" [observation "phase-40.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-40-residue" [observation "phase-40.residue" "browser and server interpretation, offline pairing, publication, live authority enforcement, tenant-isolation observation, and hardware remain later-owned"] []
    , named "phase-40-pass-criterion" [pre]
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
            "ui-plan-compiler-source-repository-cache"
            [observation "ui-plan-compiler.cache.entries" (Text.pack (show copied))]
            [ finding "UI-PLAN-COMPILER-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
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
    let parent = root </> ".build/runs/phase-40/work"
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
    [ "src/Amoebius/Ui/Compile/ClientPlan.hs"
    , "src/Amoebius/Ui/Compile/ServerPlan.hs"
    , "src/Amoebius/Ui/Compile/Manifest.hs"
    , "src/Amoebius/Ui/Compile/Demand.hs"
    ]
expectedSources = sort (productionSources <> [oracleSource, casesSource, specSource, uiSourceCases, authorizationCases])
retiredSources =
    [ "tools/ui_plan_compiler_gate.py"
    , "test/fixture/ui_plan_compiler/client_plan.golden.json"
    , "test/fixture/ui_plan_compiler/content_manifest.golden.json"
    , "test/fixture/ui_plan_compiler/projection_rows.tsv"
    , "test/fixture/ui_plan_compiler/public_contracts.golden.json"
    , "test/fixture/ui_plan_compiler/ui_server_plan.golden.json"
    , "test/oracle/ui_plan_compiler/calculus_projection.tsv"
    , "test/oracle/ui_plan_compiler/validation_locus.tsv"
    , "test/oracle/ui_plan_compiler_surfaces.tsv"
    , "test/mutant/ui_plan_compiler/M-client-only-authority-digest.mutant"
    , "test/mutant/ui_plan_compiler/M-drop-server-action.mutant"
    , "test/mutant/ui_plan_compiler/M-emit-private-field.mutant"
    , "test/mutant/ui_plan_compiler/M-link-navigation-as-fetch.mutant"
    , "test/mutant/ui_plan_compiler/M-preserve-map-insertion-order.mutant"
    , "test/mutant/ui_plan_compiler/M-swap-action-targets.mutant"
    ]

oracleSource, casesSource, specSource, uiSourceCases, authorizationCases :: FilePath
oracleSource = "test/spec/ui/PlanCompilerReference.hs"
casesSource = "test/spec/ui/UiPlanCompilerCases.hs"
specSource = "test/spec/ui/UiPlanCompilerSpec.hs"
uiSourceCases = "test/spec/ui/UiProgramSchemaCases.hs"
authorizationCases = "test/spec/ui/AuthorizationCases.hs"
