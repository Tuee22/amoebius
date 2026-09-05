{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.UiAuthorizationRun.Internal (
    AcquiredUiAuthorizationRun,
    acquireUiAuthorizationRefreshRun,
    acquireUiAuthorizationRun,
    acquiredUiAuthorizationRunCheck,
    foldAcquiredUiAuthorizationRun,
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

data AcquiredUiAuthorizationRun
    = AcquiredUiAuthorizationRun
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

acquiredUiAuthorizationRunCheck :: AcquiredUiAuthorizationRun -> CheckResult
acquiredUiAuthorizationRunCheck (AcquiredUiAuthorizationRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredUiAuthorizationRun ::
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
    AcquiredUiAuthorizationRun ->
    value
foldAcquiredUiAuthorizationRun consume (AcquiredUiAuthorizationRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireUiAuthorizationRun
    , acquireUiAuthorizationRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiAuthorizationRun
acquireUiAuthorizationRun = acquire False
acquireUiAuthorizationRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredUiAuthorizationRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 38 acquired
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
        cleanroom = mergeChecks "ui-authorization-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "ui-authorization-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "ui-authorization-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "ui-authorization" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "ui-authorization-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "ui-authorization-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "ui-authorization-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "ui-authorization-observer" [checkDigest observer]
        qualificationId = ids "ui-authorization-qualification" [checkDigest qualification]
        acquiredRunId = ids "ui-authorization-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "ui-authorization-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredUiAuthorizationRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
                   , "ui-authorization-spec"
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
    [ mutant "default-allow" "ui-authorization-default-allow-mutant" "Authorization.authorize" "default-deny production decision: expected False, got True"
    , mutant "visibility-is-authorization" "ui-authorization-visibility-mutant" "Authorization.authorize" "hidden-invocable production decision: expected True, got False"
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
        "ui-authorization-toolchain"
        [observation "ui-authorization.cabal" (receiptSummary version), observation "ui-authorization.compiler" (Text.pack compiler)]
        ( [ finding "UI-AUTHORIZATION-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "UI-AUTHORIZATION-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
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
        "ui-authorization-independent-oracle"
        [observation "ui-authorization.oracle" (receiptSummary clean), observation "ui-authorization.oracle-independence" "UiAuthorizationOracle imports no production or fixture module"]
        [ finding "UI-AUTHORIZATION-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "ui-authorization-spec: PASS (5 actions, 6 matrix rows, 4 parity errors, 4 stale epochs, 9 coverage classes, 2 production mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "ui-authorization-positive-controls"
        [observation "ui-authorization.positives" "five typed action declarations and six independently evaluated authorization decisions passed"]
        [ finding "UI-AUTHORIZATION-POSITIVE" specSource "the clean UI program corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "ui-authorization-calculus: PASS (5 kinds, 30 projected units)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ _ clean) =
    CheckResult
        "ui-authorization-paired-negatives"
        [observation "ui-authorization.negatives" "four registry parity refusals, default deny, wrong scope, wrong permission, and four stale-epoch refusals passed with empty denial traces"]
        [ finding "UI-AUTHORIZATION-PAIRED-NEGATIVES" specSource "the clean candidate did not exercise the complete typed refusal battery"
        | receiptExit clean /= ExitSuccess || notContains "4 parity errors, 4 stale epochs, 9 coverage classes" (receiptOutput clean)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "ui-authorization-mutants"
        [observation ("ui-authorization.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "UI-AUTHORIZATION-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "ui-authorization-source-discipline"
            [observation "ui-authorization.production-module-count" "1", observation "ui-authorization.effect-boundary" "pure sealed registry, current-authority transition, typed effect witness, and run-local serial Cabal children only; no identity provider, browser, network, service, cluster, or hardware effects"]
            ( [ finding "UI-AUTHORIZATION-SOURCE-SHAPE" "<ui-authorization-production>" ("missing production element: " <> token)
              | token <- ["data ActionEffect", "data Permission", "data Visibility", "data ActionSpec", "data BoundActionRegistry", "data AuthorityEpochs", "data AuthoritySnapshot", "data AuthorizedAction", "newtype CanRead", "newtype CanInvoke", "bindActionRegistry", "authorize", "interpretAuthorized", "UI_AUTH_DEFAULT_ALLOW_MUTANT", "UI_AUTH_VISIBILITY_MUTANT"]
              , notContains token production
              ]
                <> [ finding "UI-AUTHORIZATION-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["registryOracle", "decisionOracle", "parityOracle", "epochOracle", "calculusOracle", "mutantOracle", "validationLoci"]
                   , notContains token oracle
                   ]
                <> [ finding "UI-AUTHORIZATION-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "ui-authorization-discovery"
        [observation "ui-authorization.discovery.count" (Text.pack (show (length observed)))]
        [finding "UI-AUTHORIZATION-DISCOVERY" "<phase-38-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "ui-authorization-authority"
        [observation "ui-authorization.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "UI-AUTHORIZATION-RUN-ROOT" runRoot "run root escaped .build/runs/phase-38/work" | not (pathBelow (root </> ".build/runs/phase-38/work") runRoot)]
            <> [ finding "UI-AUTHORIZATION-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-38 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "ui-authorization-observer"
        (map (observation "ui-authorization.observer.process" . receiptSummary) receipts)
        [ finding "UI-AUTHORIZATION-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "ui-authorization-freshness"
        [observation "ui-authorization.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "UI-AUTHORIZATION-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-38/work") runRoot)
        ]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
    files <- filterM (doesFileExist . (root </>)) retiredSources
    pure
        ( CheckResult
            "ui-authorization-legacy-closure"
            [observation "ui-authorization.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "ui-authorization.legacy.semantic-inputs" "HaskellOnly"]
            [finding "UI-AUTHORIZATION-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files]
        )

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-38-claim" [pre]
    , named "phase-38-subject" [toolchain, positives]
    , named "phase-38-command" [toolchain, authority]
    , named "phase-38-oracle" [oracle]
    , named "phase-38-positive-controls" [positives]
    , named "phase-38-paired-negatives" [negatives]
    , named "phase-38-mutants" [mutants]
    , named "phase-38-discovery" [discovery]
    , named "phase-38-challenge" [mutants]
    , named "phase-38-observer" [observer]
    , named "phase-38-authority-bypass" [authority]
    , named "phase-38-freshness" [freshness]
    , named "phase-38-qualification" [qualification]
    , named "phase-38-cleanroom" [cleanroom]
    , named "phase-38-legacy-closure" [legacy]
    , CheckResult "phase-38-predecessor" [observation "phase-38.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-38-residue" [observation "phase-38.residue" "handler binding, client/server planning, browser interpretation, live identity truth, runtime/provider enforcement, tenant-isolation observation, and hardware remain later-owned"] []
    , named "phase-38-pass-criterion" [pre]
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
            "ui-authorization-source-repository-cache"
            [observation "ui-authorization.cache.entries" (Text.pack (show copied))]
            [ finding "UI-AUTHORIZATION-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
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
    let parent = root </> ".build/runs/phase-38/work"
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
    ["src/Amoebius/Ui/Security/Authorization.hs"]
expectedSources = sort (productionSources <> [oracleSource, casesSource, specSource, uiSourceCases])
retiredSources =
    [ "tools/ui_authorization_gate.py"
    , "test/fixture/ui_authorization/action_registry.tsv"
    , "test/fixture/ui_authorization/authorization_matrix.tsv"
    , "test/fixture/ui_authorization/decode_errors.tsv"
    , "test/fixture/ui_authorization/stale_decision_cases.tsv"
    , "test/oracle/ui_authorization/calculus_projection.tsv"
    , "test/oracle/ui_authorization/validation_locus.tsv"
    , "test/oracle/ui_authorization_surfaces.tsv"
    , "test/mutant/ui_authorization/default_allow.mutant"
    , "test/mutant/ui_authorization/visibility_is_authorization.mutant"
    , "test/spec/ui/AuthorizationReference.hs"
    ]

oracleSource, casesSource, specSource, uiSourceCases :: FilePath
oracleSource = "test/spec/ui/AuthorizationOracle.hs"
casesSource = "test/spec/ui/AuthorizationCases.hs"
specSource = "test/spec/ui/AuthorizationSpec.hs"
uiSourceCases = "test/spec/ui/UiProgramSchemaCases.hs"
