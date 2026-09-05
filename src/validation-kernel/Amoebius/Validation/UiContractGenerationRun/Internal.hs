{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.UiContractGenerationRun.Internal (
    AcquiredUiContractGenerationRun,
    acquireUiContractGenerationRefreshRun,
    acquireUiContractGenerationRun,
    acquiredUiContractGenerationRunCheck,
    foldAcquiredUiContractGenerationRun,
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

data AcquiredUiContractGenerationRun
    = AcquiredUiContractGenerationRun
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

acquiredUiContractGenerationRunCheck :: AcquiredUiContractGenerationRun -> CheckResult
acquiredUiContractGenerationRunCheck (AcquiredUiContractGenerationRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredUiContractGenerationRun ::
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
    AcquiredUiContractGenerationRun ->
    value
foldAcquiredUiContractGenerationRun consume (AcquiredUiContractGenerationRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireUiContractGenerationRun
    , acquireUiContractGenerationRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiContractGenerationRun
acquireUiContractGenerationRun = acquire False
acquireUiContractGenerationRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiContractGenerationRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 46 acquired
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
        cleanroom = mergeChecks "ui-contract-generation-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "ui-contract-generation-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "ui-contract-generation-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "ui-contract-generation" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "ui-contract-generation-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "ui-contract-generation-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "ui-contract-generation-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "ui-contract-generation-observer" [checkDigest observer]
        qualificationId = ids "ui-contract-generation-qualification" [checkDigest qualification]
        acquiredRunId = ids "ui-contract-generation-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "ui-contract-generation-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredUiContractGenerationRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
                   , "ui-contract-generation-spec"
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
    [ mutant "raw-sink" "ui-contract-raw-sink-mutant" "BrowserContracts.transitionFields" "raw sink exclusion: expected no rawHtml"
    , mutant "serialize-server-handle" "ui-contract-serialize-server-handle-mutant" "BrowserContracts.publicValueTypes" "server handle privacy: expected no ServerHandle"
    , mutant "undeclared-codec" "ui-contract-undeclared-codec-mutant" "BrowserContracts.clientPlanFields" "declared codec closure: expected no providerCoordinate"
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
        "ui-contract-generation-toolchain"
        [observation "ui-contract-generation.cabal" (receiptSummary version), observation "ui-contract-generation.compiler" (Text.pack compiler)]
        ( [ finding "UI-CONTRACT-GENERATION-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "UI-CONTRACT-GENERATION-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
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
        "ui-contract-generation-independent-oracle"
        [observation "ui-contract-generation.oracle" (receiptSummary clean), observation "ui-contract-generation.oracle-independence" "UiContractGenerationReference imports no production or case module"]
        [ finding "UI-CONTRACT-GENERATION-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "ui-contract-generation-spec: PASS (16 contracts, 3 generated recipes, 3 mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "ui-contract-generation-positive-controls"
        [observation "ui-contract-generation.positives" "sixteen public contract rows, three deterministic browser recipes, independent scanner, and calculus controls passed"]
        [ finding "UI-CONTRACT-GENERATION-POSITIVE" specSource "the clean Haskell UI-contract corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "ui-contract-generation-calculus: PASS (5 kinds, 31 projected units)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ _ clean) =
    CheckResult
        "ui-contract-generation-paired-negatives"
        [observation "ui-contract-generation.negatives" "raw sinks, private server handles, undeclared codecs, evaluation primitives, provider coordinates, and external URLs were absent"]
        [ finding "UI-CONTRACT-GENERATION-PAIRED-NEGATIVES" specSource "the clean candidate did not exercise the complete typed refusal and sensitivity battery"
        | receiptExit clean /= ExitSuccess || notContains "16 contracts, 3 generated recipes, 3 mutants" (receiptOutput clean)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "ui-contract-generation-mutants"
        [observation ("ui-contract-generation.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "UI-CONTRACT-GENERATION-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "ui-contract-generation-source-discipline"
            [observation "ui-contract-generation.production-module-count" "1", observation "ui-contract-generation.effect-boundary" "pure Haskell contract recipes plus run-local generated browser files and serial Cabal children only; no browser, Node, Python, PureScript compiler, network, service, cluster, or hardware effects"]
            ( [ finding "UI-CONTRACT-GENERATION-SOURCE-SHAPE" "<ui-contract-generation-production>" ("missing production element: " <> token)
              | token <- ["contractInventory", "browserArtifacts", "writeBrowserArtifacts", "UI_CONTRACT_GENERATION_RAW_SINK_MUTANT", "UI_CONTRACT_GENERATION_SERIALIZE_SERVER_HANDLE_MUTANT", "UI_CONTRACT_GENERATION_UNDECLARED_CODEC_MUTANT"]
              , notContains token production
              ]
                <> [ finding "UI-CONTRACT-GENERATION-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["contractRows", "WorkflowProgress", "focus"]
                   , notContains token oracle
                   ]
                <> [ finding "UI-CONTRACT-GENERATION-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "ui-contract-generation-discovery"
        [observation "ui-contract-generation.discovery.count" (Text.pack (show (length observed)))]
        [finding "UI-CONTRACT-GENERATION-DISCOVERY" "<phase-46-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "ui-contract-generation-authority"
        [observation "ui-contract-generation.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "UI-CONTRACT-GENERATION-RUN-ROOT" runRoot "run root escaped .build/runs/phase-46/work" | not (pathBelow (root </> ".build/runs/phase-46/work") runRoot)]
            <> [ finding "UI-CONTRACT-GENERATION-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-46 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "ui-contract-generation-observer"
        (map (observation "ui-contract-generation.observer.process" . receiptSummary) receipts)
        [ finding "UI-CONTRACT-GENERATION-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "ui-contract-generation-freshness"
        [observation "ui-contract-generation.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "UI-CONTRACT-GENERATION-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-46/work") runRoot)
        ]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
    files <- filterM (doesFileExist . (root </>)) retiredSources
    pure
        ( CheckResult
            "ui-contract-generation-legacy-closure"
            [observation "ui-contract-generation.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "ui-contract-generation.legacy.semantic-inputs" "HaskellOnly"]
            [finding "UI-CONTRACT-GENERATION-LEGACY" path "retired Python/PureScript/JavaScript/serialized/materialized-mutant authority remains" | path <- files]
        )

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-46-claim" [pre]
    , named "phase-46-subject" [toolchain, positives]
    , named "phase-46-command" [toolchain, authority]
    , named "phase-46-oracle" [oracle]
    , named "phase-46-positive-controls" [positives]
    , named "phase-46-paired-negatives" [negatives]
    , named "phase-46-mutants" [mutants]
    , named "phase-46-discovery" [discovery]
    , named "phase-46-challenge" [mutants]
    , named "phase-46-observer" [observer]
    , named "phase-46-authority-bypass" [authority]
    , named "phase-46-freshness" [freshness]
    , named "phase-46-qualification" [qualification]
    , named "phase-46-cleanroom" [cleanroom]
    , named "phase-46-legacy-closure" [legacy]
    , CheckResult "phase-46-predecessor" [observation "phase-46.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-46-residue" [observation "phase-46.residue" "PureScript compilation, browser bundle execution, protocol use, browser fidelity, publication, deployment, HA, and hardware remain later-owned"] []
    , named "phase-46-pass-criterion" [pre]
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
            "ui-contract-generation-source-repository-cache"
            [observation "ui-contract-generation.cache.entries" (Text.pack (show copied))]
            [ finding "UI-CONTRACT-GENERATION-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
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
    let parent = root </> ".build/runs/phase-46/work"
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
productionSources = ["src/ui-contract-generation/Amoebius/Ui/Generate/BrowserContracts.hs"]
expectedSources = sort (productionSources <> [oracleSource, casesSource, specSource])
retiredSources =
    [ "tools/ui_contract_generation_gate.py"
    , "test/oracle/ui_contract_generation/calculus_projection.tsv"
    , "test/oracle/ui_contract_generation/contract_inventory.tsv"
    , "test/oracle/ui_contract_generation/scanner_rules.tsv"
    , "test/oracle/ui_contract_generation/validation_locus.tsv"
    , "test/oracle/ui_contract_generation_surfaces.tsv"
    , "test/mutant/ui_contract_generation/raw_sink.patch"
    , "test/mutant/ui_contract_generation/serialize_server_handle.patch"
    , "test/mutant/ui_contract_generation/undeclared_codec.patch"
    , "ui/spago.yaml"
    , "ui/src/Amoebius/Ui/Components.purs"
    , "ui/src/Amoebius/Ui/Interpreter.purs"
    , "ui/src/Main.js"
    , "ui/src/Main.purs"
    , "package.json"
    ]

oracleSource, casesSource, specSource :: FilePath
oracleSource = "test/spec/ui/UiContractGenerationReference.hs"
casesSource = "test/spec/ui/UiContractGenerationCases.hs"
specSource = "test/spec/ui/UiContractGenerationSpec.hs"
