{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.UiProgramSchemaRun.Internal (
    AcquiredUiProgramSchemaRun,
    acquireUiProgramSchemaRefreshRun,
    acquireUiProgramSchemaRun,
    acquiredUiProgramSchemaRunCheck,
    foldAcquiredUiProgramSchemaRun,
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

data AcquiredUiProgramSchemaRun
    = AcquiredUiProgramSchemaRun
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

acquiredUiProgramSchemaRunCheck :: AcquiredUiProgramSchemaRun -> CheckResult
acquiredUiProgramSchemaRunCheck (AcquiredUiProgramSchemaRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredUiProgramSchemaRun ::
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
    AcquiredUiProgramSchemaRun ->
    value
foldAcquiredUiProgramSchemaRun consume (AcquiredUiProgramSchemaRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireUiProgramSchemaRun
    , acquireUiProgramSchemaRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiProgramSchemaRun
acquireUiProgramSchemaRun = acquire False
acquireUiProgramSchemaRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiProgramSchemaRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 37 acquired
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
        cleanroom = mergeChecks "ui-program-schema-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "ui-program-schema-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "ui-program-schema-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "ui-program-schema" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "ui-program-schema-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "ui-program-schema-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "ui-program-schema-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "ui-program-schema-observer" [checkDigest observer]
        qualificationId = ids "ui-program-schema-qualification" [checkDigest qualification]
        acquiredRunId = ids "ui-program-schema-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "ui-program-schema-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredUiProgramSchemaRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
    barriers <- mapM runBarrier compileSpecifications
    mutants <- mapM runMutant mutantSpecifications
    clean <- runSpec "clean" Nothing
    pure (Matrix barriers mutants clean)
  where
    runBarrier (name, target, shouldSucceed, expected) = CompileBarrier name shouldSucceed expected <$> runProcess root name cabal (common <> ["build", "test:" <> target] <> disableMutants)
    runMutant (name, flagName, locus, expected) = Mutant name locus expected <$> runSpec name (Just flagName)
    runSpec name selected =
        runProcess
            root
            name
            cabal
            ( common
                <> [ "test"
                   , "ui-program-schema-spec"
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
    disableMutants = ["-f-" <> flagName | (_, flagName, _, _) <- mutantSpecifications]
    selectMutant selected = [if Just flagName == selected then "-f" <> flagName else "-f-" <> flagName | (_, flagName, _, _) <- mutantSpecifications]

compileSpecifications :: [(Text, String, Bool, Text)]
compileSpecifications =
    [ ("checked-ui-legal", "ui-program-schema-compile-legal", True, "")
    , ("checked-ui-illegal", "ui-program-schema-compile-illegal", False, "Illegal term-level use of the type constructor")
    ]

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
    [ mutant "add-raw-js-arm" "ui-program-schema-add-raw-js-arm-mutant" "Source.decodeUiSourceText" "raw_browser_escape outcome drifted: accepted"
    , mutant "add-raw-url-arm" "ui-program-schema-add-raw-url-arm-mutant" "Source.decodeUiSourceText" "raw_external_link_url outcome drifted: accepted"
    , mutant "drop-bound-check" "ui-program-schema-drop-bound-check-mutant" "Check.checkBounds" "unbounded_collection outcome drifted: accepted"
    , mutant "first-id-wins" "ui-program-schema-first-id-wins-mutant" "Check.buildNodeTable" "duplicate_qualified_id outcome drifted: accepted"
    , mutant "skip-exhaustiveness" "ui-program-schema-skip-exhaustiveness-mutant" "Check.checkEvents" "non_exhaustive_event outcome drifted: accepted"
    , mutant "swap-port-contract" "ui-program-schema-swap-port-contract-mutant" "Check.checkPorts" "port_type_mismatch outcome drifted: accepted"
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
        "ui-program-schema-toolchain"
        [observation "ui-program-schema.cabal" (receiptSummary version), observation "ui-program-schema.compiler" (Text.pack compiler)]
        ( [ finding "UI-PROGRAM-SCHEMA-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "UI-PROGRAM-SCHEMA-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
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
        "ui-program-schema-independent-oracle"
        [observation "ui-program-schema.oracle" (receiptSummary clean), observation "ui-program-schema.oracle-independence" "UiProgramSchemaOracle imports no production or fixture module"]
        [ finding "UI-PROGRAM-SCHEMA-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "ui-program-schema-spec: PASS (3 semantic positives, 10 exact negatives, 3 graph rows, 8 coverage classes, 6 mutants, opaque seal)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "ui-program-schema-positive-controls"
        [observation "ui-program-schema.positives" "three typed Haskell program cases, exact semantic projections, deterministic checks, and one closed source algebra passed"]
        [ finding "UI-PROGRAM-SCHEMA-POSITIVE" specSource "the clean UI program corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "ui-program-schema-calculus: PASS (5 kinds, 30 projected units)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix barriers _ _) =
    CheckResult
        "ui-program-schema-paired-negatives"
        [observation ("ui-program-schema.compile-barrier." <> name) (receiptSummary receipt) | CompileBarrier name _ _ receipt <- barriers]
        [ finding "UI-PROGRAM-SCHEMA-COMPILE-BARRIER" (Text.unpack name) "the legal/illegal compiler twin did not produce its independently authored outcome"
        | CompileBarrier name shouldSucceed expected receipt <- barriers
        , if shouldSucceed then receiptExit receipt /= ExitSuccess else receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "ui-program-schema-mutants"
        [observation ("ui-program-schema.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "UI-PROGRAM-SCHEMA-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "ui-program-schema-source-discipline"
            [observation "ui-program-schema.production-module-count" "2", observation "ui-program-schema.effect-boundary" "pure closed UI algebra, total graph checker, bounded external Dhall decoder, compiler barrier, and run-local Cabal children only; no browser, network, service, cluster, or hardware effects"]
            ( [ finding "UI-PROGRAM-SCHEMA-SOURCE-SHAPE" "<ui-program-schema-production>" ("missing production element: " <> token)
              | token <- ["data TenantMode", "data NodeKind", "data ValueType", "data UiSource", "data CheckedUiProgram", "checkUiSource", "checkCycles", "checkBounds", "checkEvents", "checkPublicProjection"]
              , notContains token production
              ]
                <> [ finding "UI-PROGRAM-SCHEMA-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["caseOracle", "programOracle", "graphOracle", "calculusOracle", "compileBarrierOracle", "mutantOracle", "validationLoci"]
                   , notContains token oracle
                   ]
                <> [ finding "UI-PROGRAM-SCHEMA-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "ui-program-schema-discovery"
        [observation "ui-program-schema.discovery.count" (Text.pack (show (length observed)))]
        [finding "UI-PROGRAM-SCHEMA-DISCOVERY" "<phase-37-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "ui-program-schema-authority"
        [observation "ui-program-schema.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "UI-PROGRAM-SCHEMA-RUN-ROOT" runRoot "run root escaped .build/runs/phase-37/work" | not (pathBelow (root </> ".build/runs/phase-37/work") runRoot)]
            <> [ finding "UI-PROGRAM-SCHEMA-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-37 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "ui-program-schema-observer"
        (map (observation "ui-program-schema.observer.process" . receiptSummary) receipts)
        [ finding "UI-PROGRAM-SCHEMA-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "ui-program-schema-freshness"
        [observation "ui-program-schema.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "UI-PROGRAM-SCHEMA-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-37/work") runRoot)
        ]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
    files <- filterM (doesFileExist . (root </>)) retiredSources
    pure
        ( CheckResult
            "ui-program-schema-legacy-closure"
            [observation "ui-program-schema.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "ui-program-schema.legacy.semantic-inputs" "HaskellOnly"]
            [finding "UI-PROGRAM-SCHEMA-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files]
        )

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-37-claim" [pre]
    , named "phase-37-subject" [toolchain, positives]
    , named "phase-37-command" [toolchain, authority]
    , named "phase-37-oracle" [oracle]
    , named "phase-37-positive-controls" [positives]
    , named "phase-37-paired-negatives" [negatives]
    , named "phase-37-mutants" [mutants]
    , named "phase-37-discovery" [discovery]
    , named "phase-37-challenge" [mutants]
    , named "phase-37-observer" [observer]
    , named "phase-37-authority-bypass" [authority]
    , named "phase-37-freshness" [freshness]
    , named "phase-37-qualification" [qualification]
    , named "phase-37-cleanroom" [cleanroom]
    , named "phase-37-legacy-closure" [legacy]
    , CheckResult "phase-37-predecessor" [observation "phase-37.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-37-residue" [observation "phase-37.residue" "authorization, handler binding, client/server planning, browser interpretation, runtime services, provider enforcement, and hardware remain later-owned"] []
    , named "phase-37-pass-criterion" [pre]
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
            "ui-program-schema-source-repository-cache"
            [observation "ui-program-schema.cache.entries" (Text.pack (show copied))]
            [ finding "UI-PROGRAM-SCHEMA-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
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
    let parent = root </> ".build/runs/phase-37/work"
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
    [ "src/Amoebius/Ui/Source.hs"
    , "src/Amoebius/Ui/Check.hs"
    ]
expectedSources = sort (productionSources <> [oracleSource, casesSource, specSource, legalCompileSource, illegalCompileSource])
retiredSources =
    [ "tools/ui_program_schema_gate.py"
    , "test/fixture/ui_program_schema/cases.tsv"
    , "test/fixture/ui_program_schema/graph_reference.tsv"
    , "test/oracle/ui_program_schema_surfaces.tsv"
    , "test/oracle/ui_program_schema/calculus_projection.tsv"
    , "test/oracle/ui_program_schema/program_semantics.tsv"
    , "test/oracle/ui_program_schema/validation_locus.tsv"
    , "test/mutant/ui_program_schema/M-drop-bound-check.mutant"
    , "test/mutant/ui_program_schema/M-first-id-wins.mutant"
    , "test/mutant/ui_program_schema/M-skip-exhaustiveness.mutant"
    , "test/mutant/ui_program_schema/M-swap-port-contract.mutant"
    , "test/mutant/ui_program_schema/add_raw_js_arm.mutant"
    , "test/mutant/ui_program_schema/add_raw_url_arm.mutant"
    ]

oracleSource, casesSource, specSource, legalCompileSource, illegalCompileSource :: FilePath
oracleSource = "test/spec/ui/UiProgramSchemaOracle.hs"
casesSource = "test/spec/ui/UiProgramSchemaCases.hs"
specSource = "test/spec/ui/UiProgramSchemaSpec.hs"
legalCompileSource = "test/negative/compile_fail/ui_program_schema/checked_ui_legal.hs"
illegalCompileSource = "test/negative/compile_fail/ui_program_schema/checked_ui_illegal.hs"
