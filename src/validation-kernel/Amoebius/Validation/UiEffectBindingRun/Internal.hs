{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.UiEffectBindingRun.Internal (
    AcquiredUiEffectBindingRun,
    acquireUiEffectBindingRefreshRun,
    acquireUiEffectBindingRun,
    acquiredUiEffectBindingRunCheck,
    foldAcquiredUiEffectBindingRun,
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

data AcquiredUiEffectBindingRun
    = AcquiredUiEffectBindingRun
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

acquiredUiEffectBindingRunCheck :: AcquiredUiEffectBindingRun -> CheckResult
acquiredUiEffectBindingRunCheck (AcquiredUiEffectBindingRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredUiEffectBindingRun ::
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
    AcquiredUiEffectBindingRun ->
    value
foldAcquiredUiEffectBindingRun consume (AcquiredUiEffectBindingRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireUiEffectBindingRun
    , acquireUiEffectBindingRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiEffectBindingRun
acquireUiEffectBindingRun = acquire False
acquireUiEffectBindingRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiEffectBindingRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 39 acquired
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
        cleanroom = mergeChecks "ui-effect-binding-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "ui-effect-binding-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "ui-effect-binding-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "ui-effect-binding" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "ui-effect-binding-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "ui-effect-binding-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "ui-effect-binding-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "ui-effect-binding-observer" [checkDigest observer]
        qualificationId = ids "ui-effect-binding-qualification" [checkDigest qualification]
        acquiredRunId = ids "ui-effect-binding-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "ui-effect-binding-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredUiEffectBindingRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
                   , "ui-effect-binding-spec"
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
    [ mutant "first-handler-wins" "ui-effect-first-handler-mutant" "Bind.selectHandler" "duplicate-handler: expected \"DuplicateHandler\", got \"UnexpectedHandler\""
    , mutant "drop-capability" "ui-effect-drop-capability-mutant" "Bind.bindPort" "missing-capability: expected \"MissingCapability\", got \"accepted\""
    , mutant "erase-handler-scope" "ui-effect-erase-scope-mutant" "Bind.bindPort" "scope-mismatch: expected \"ScopeMismatch\", got \"accepted\""
    , mutant "swap-response-codec" "ui-effect-swap-response-mutant" "Bind.bindPort" "codec-mismatch: expected \"ContractMismatch\", got \"accepted\""
    , mutant "retry-without-idempotency" "ui-effect-retry-mutant" "Bind.bindPort" "unsafe-retry: expected \"IdempotencyRequired\", got \"accepted\""
    , mutant "export-raw-topic" "ui-effect-raw-topic-mutant" "Bind.parsePortEffectTarget" "raw-topic: expected \"ProviderCoordinateForbidden\", got \"accepted\""
    , mutant "link-id-as-url" "ui-effect-link-as-url-mutant" "Bind.parsePortEffectTarget" "link-as-url: expected \"ExternalLinkNotAnEffect\", got \"accepted\""
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
        "ui-effect-binding-toolchain"
        [observation "ui-effect-binding.cabal" (receiptSummary version), observation "ui-effect-binding.compiler" (Text.pack compiler)]
        ( [ finding "UI-EFFECT-BINDING-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "UI-EFFECT-BINDING-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
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
        "ui-effect-binding-independent-oracle"
        [observation "ui-effect-binding.oracle" (receiptSummary clean), observation "ui-effect-binding.oracle-independence" "EffectBindingReference imports no production or case module"]
        [ finding "UI-EFFECT-BINDING-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "ui-effect-binding-spec: PASS (7 ports, 2 links, 19 exact refusals, 13 coverage classes, 7 production mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "ui-effect-binding-positive-controls"
        [observation "ui-effect-binding.positives" "seven typed port/capability bindings and two fixed HTTPS link bindings passed the independent relation"]
        [ finding "UI-EFFECT-BINDING-POSITIVE" specSource "the clean UI program corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "ui-effect-binding-calculus: PASS (5 kinds, 48 projected units)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ _ clean) =
    CheckResult
        "ui-effect-binding-paired-negatives"
        [observation "ui-effect-binding.negatives" "nineteen typed missing, duplicate, unexpected, contract, scope, retry, bound, readiness, provider-coordinate, and link refusals passed"]
        [ finding "UI-EFFECT-BINDING-PAIRED-NEGATIVES" specSource "the clean candidate did not exercise the complete typed refusal battery"
        | receiptExit clean /= ExitSuccess || notContains "19 exact refusals, 13 coverage classes" (receiptOutput clean)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "ui-effect-binding-mutants"
        [observation ("ui-effect-binding.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "UI-EFFECT-BINDING-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "ui-effect-binding-source-discipline"
            [observation "ui-effect-binding.production-module-count" "2", observation "ui-effect-binding.effect-boundary" "pure exact port/capability and fixed-HTTPS link binding with run-local serial Cabal children only; no handler, provider, browser, network, service, cluster, or hardware effects"]
            ( [ finding "UI-EFFECT-BINDING-SOURCE-SHAPE" "<ui-effect-binding-production>" ("missing production element: " <> token)
              | token <- ["data PortEffect", "data PortRequirement", "data HandlerSpec", "data CapabilityBinding", "data BoundUiProgram", "bindUiProgram", "bindExternalLinks", "UI_EFFECT_FIRST_HANDLER_MUTANT", "UI_EFFECT_DROP_CAPABILITY_MUTANT", "UI_EFFECT_ERASE_SCOPE_MUTANT", "UI_EFFECT_SWAP_RESPONSE_MUTANT", "UI_EFFECT_RETRY_MUTANT", "UI_EFFECT_RAW_TOPIC_MUTANT", "UI_EFFECT_LINK_AS_URL_MUTANT"]
              , notContains token production
              ]
                <> [ finding "UI-EFFECT-BINDING-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["referenceBindings", "referenceExternalLinks", "unique"]
                   , notContains token oracle
                   ]
                <> [ finding "UI-EFFECT-BINDING-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "ui-effect-binding-discovery"
        [observation "ui-effect-binding.discovery.count" (Text.pack (show (length observed)))]
        [finding "UI-EFFECT-BINDING-DISCOVERY" "<phase-39-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "ui-effect-binding-authority"
        [observation "ui-effect-binding.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "UI-EFFECT-BINDING-RUN-ROOT" runRoot "run root escaped .build/runs/phase-39/work" | not (pathBelow (root </> ".build/runs/phase-39/work") runRoot)]
            <> [ finding "UI-EFFECT-BINDING-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-39 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "ui-effect-binding-observer"
        (map (observation "ui-effect-binding.observer.process" . receiptSummary) receipts)
        [ finding "UI-EFFECT-BINDING-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "ui-effect-binding-freshness"
        [observation "ui-effect-binding.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "UI-EFFECT-BINDING-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-39/work") runRoot)
        ]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
    files <- filterM (doesFileExist . (root </>)) retiredSources
    pure
        ( CheckResult
            "ui-effect-binding-legacy-closure"
            [observation "ui-effect-binding.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "ui-effect-binding.legacy.semantic-inputs" "HaskellOnly"]
            [finding "UI-EFFECT-BINDING-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files]
        )

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-39-claim" [pre]
    , named "phase-39-subject" [toolchain, positives]
    , named "phase-39-command" [toolchain, authority]
    , named "phase-39-oracle" [oracle]
    , named "phase-39-positive-controls" [positives]
    , named "phase-39-paired-negatives" [negatives]
    , named "phase-39-mutants" [mutants]
    , named "phase-39-discovery" [discovery]
    , named "phase-39-challenge" [mutants]
    , named "phase-39-observer" [observer]
    , named "phase-39-authority-bypass" [authority]
    , named "phase-39-freshness" [freshness]
    , named "phase-39-qualification" [qualification]
    , named "phase-39-cleanroom" [cleanroom]
    , named "phase-39-legacy-closure" [legacy]
    , CheckResult "phase-39-predecessor" [observation "phase-39.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-39-residue" [observation "phase-39.residue" "plan compilation, handler execution, browser interpretation, live provider enforcement, tenant-isolation observation, and hardware remain later-owned"] []
    , named "phase-39-pass-criterion" [pre]
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
            "ui-effect-binding-source-repository-cache"
            [observation "ui-effect-binding.cache.entries" (Text.pack (show copied))]
            [ finding "UI-EFFECT-BINDING-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
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
    let parent = root </> ".build/runs/phase-39/work"
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
    [ "src/Amoebius/Ui/Bind.hs"
    , "src/Amoebius/Ui/ExternalLinkCatalog.hs"
    ]
expectedSources = sort (productionSources <> [oracleSource, casesSource, specSource, uiSourceCases, authorizationCases])
retiredSources =
    [ "tools/ui_effect_binding_gate.py"
    , "test/fixture/ui_effect_binding/bind_errors.tsv"
    , "test/fixture/ui_effect_binding/handlers.tsv"
    , "test/fixture/ui_effect_binding/external_link_catalog.tsv"
    , "test/fixture/ui_effect_binding/capabilities.tsv"
    , "test/fixture/ui_effect_binding/ports.tsv"
    , "test/fixture/ui_effect_binding/expected_external_links.tsv"
    , "test/fixture/ui_effect_binding/expected_bindings.tsv"
    , "test/oracle/ui_effect_binding/calculus_projection.tsv"
    , "test/oracle/ui_effect_binding/validation_locus.tsv"
    , "test/oracle/ui_effect_binding_surfaces.tsv"
    , "test/mutant/ui_effect_binding/M-drop-capability.mutant"
    , "test/mutant/ui_effect_binding/M-retry-without-idempotency.mutant"
    , "test/mutant/ui_effect_binding/M-erase-handler-scope.mutant"
    , "test/mutant/ui_effect_binding/M-first-handler-wins.mutant"
    , "test/mutant/ui_effect_binding/M-swap-response-codec.mutant"
    , "test/mutant/ui_effect_binding/M-link-id-as-url.mutant"
    , "test/mutant/ui_effect_binding/export_raw_topic.mutant"
    ]

oracleSource, casesSource, specSource, uiSourceCases, authorizationCases :: FilePath
oracleSource = "test/spec/ui/EffectBindingReference.hs"
casesSource = "test/spec/ui/EffectBindingCases.hs"
specSource = "test/spec/ui/UiEffectBindingSpec.hs"
uiSourceCases = "test/spec/ui/UiProgramSchemaCases.hs"
authorizationCases = "test/spec/ui/AuthorizationCases.hs"
