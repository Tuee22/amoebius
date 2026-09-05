{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.TransactionVocabularyRun.Internal (
    AcquiredTransactionVocabularyRun,
    acquireTransactionVocabularyRefreshRun,
    acquireTransactionVocabularyRun,
    acquiredTransactionVocabularyRunCheck,
    foldAcquiredTransactionVocabularyRun,
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
data CompileBarrier = CompileBarrier Text Text Receipt deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix [CompileBarrier] [Mutant] Receipt

data AcquiredTransactionVocabularyRun
    = AcquiredTransactionVocabularyRun
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

acquiredTransactionVocabularyRunCheck :: AcquiredTransactionVocabularyRun -> CheckResult
acquiredTransactionVocabularyRunCheck (AcquiredTransactionVocabularyRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredTransactionVocabularyRun ::
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
    AcquiredTransactionVocabularyRun ->
    value
foldAcquiredTransactionVocabularyRun consume (AcquiredTransactionVocabularyRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireTransactionVocabularyRun
    , acquireTransactionVocabularyRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredTransactionVocabularyRun
acquireTransactionVocabularyRun = acquire False
acquireTransactionVocabularyRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredTransactionVocabularyRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 36 acquired
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
        cleanroom = mergeChecks "transaction-vocabulary-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "transaction-vocabulary-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "transaction-vocabulary-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "transaction-vocabulary" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "transaction-vocabulary-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "transaction-vocabulary-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "transaction-vocabulary-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "transaction-vocabulary-observer" [checkDigest observer]
        qualificationId = ids "transaction-vocabulary-qualification" [checkDigest qualification]
        acquiredRunId = ids "transaction-vocabulary-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "transaction-vocabulary-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredTransactionVocabularyRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

executeMatrix :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO Matrix
executeMatrix root runRoot cabal compiler store = do
    barriers <- mapM runBarrier compileSpecifications
    mutants <- mapM runMutant mutantSpecifications
    clean <- runSpec "clean" Nothing True
    pure (Matrix barriers mutants clean)
  where
    runBarrier (name, flagName, expected) = CompileBarrier name expected <$> runProcess root name cabal (common <> ["build", "test:transaction-vocabulary-compile"] <> selectCompile flagName <> disableMutants)
    runMutant (name, flagName, locus, expected) = Mutant name locus expected <$> runSpec name (Just flagName) False
    runSpec name selected emit =
        runProcess
            root
            name
            cabal
            ( common
                <> [ "test"
                   , "transaction-vocabulary-spec"
                   , "--offline"
                   , "--test-show-details=direct"
                   ]
                <> disableCompile
                <> selectMutant selected
                <> ["--test-options=--emit=" <> runRoot </> "generated/schema.sql" | emit]
            )
    common =
        [ "--builddir=" <> runRoot </> "dist"
        , "--store-dir=" <> store
        , "--with-compiler=" <> compiler
        , "--jobs=1"
        , "--offline"
        ]
    selectCompile selected = [if flagName == selected then "-f" <> flagName else "-f-" <> flagName | (_, flagName, _) <- compileSpecifications]
    disableCompile = ["-f-" <> flagName | (_, flagName, _) <- compileSpecifications]
    disableMutants = ["-f-" <> flagName | (_, flagName, _, _) <- mutantSpecifications]
    selectMutant selected = [if Just flagName == selected then "-f" <> flagName else "-f-" <> flagName | (_, flagName, _, _) <- mutantSpecifications]

compileSpecifications :: [(Text, String, Text)]
compileSpecifications =
    [ ("unscoped-transaction", "transaction-vocabulary-test-unscoped", "applied to too few arguments")
    , ("raw-statement", "transaction-vocabulary-test-raw-query", "does not export")
    , ("predicate-constructor", "transaction-vocabulary-test-predicate", "does not export")
    , ("cross-scope-composition", "transaction-vocabulary-test-cross-scope", "Couldn't match type")
    ]

mutantSpecifications :: [(Text, String, Text, Text)]
mutantSpecifications =
    [ mutant "transaction-optional-scope" "transaction-vocabulary-optional-scope-mutant" "Vocabulary.projectPredicate" "a transaction scope became optional"
    , mutant "transaction-match-all" "transaction-vocabulary-match-all-mutant" "Vocabulary.scopePredicate" "row/schema/policy semantic oracle drifted"
    , mutant "transaction-wrong-policy-column" "transaction-vocabulary-wrong-policy-column-mutant" "Vocabulary.projectRow" "row/schema/policy semantic oracle drifted"
    ]
  where
    mutant name flagName locus expected = (name, flagName, locus, expected)

cleanReceipt :: Matrix -> Receipt
cleanReceipt (Matrix _ _ clean) = clean

matrixReceipts :: Matrix -> [Receipt]
matrixReceipts (Matrix barriers mutants clean) = [receipt | CompileBarrier _ _ receipt <- barriers] <> [receipt | Mutant _ _ _ receipt <- mutants] <> [clean]

toolchainCheck :: FilePath -> FilePath -> FilePath -> Receipt -> Matrix -> CheckResult
toolchainCheck cabal compiler store version matrix =
    CheckResult
        "transaction-vocabulary-toolchain"
        [observation "transaction-vocabulary.cabal" (receiptSummary version), observation "transaction-vocabulary.compiler" (Text.pack compiler)]
        ( [ finding "TRANSACTION-VOCABULARY-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "TRANSACTION-VOCABULARY-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
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
        "transaction-vocabulary-independent-oracle"
        [observation "transaction-vocabulary.oracle" (receiptSummary clean), observation "transaction-vocabulary.oracle-independence" "TransactionVocabularyOracle imports no production or fixture module"]
        [ finding "TRANSACTION-VOCABULARY-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "transaction-vocabulary-spec: PASS (3 semantic oracles, 5 generation cases, 3 mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "transaction-vocabulary-positive-controls"
        [observation "transaction-vocabulary.positives" "three row declarations, five closed transactions, five generation cases, and one deterministic SQL projection passed"]
        [ finding "TRANSACTION-VOCABULARY-POSITIVE" specSource "the clean transaction corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "transaction-vocabulary-invariants: PASS (3 rows, 5 closed transactions, 2 additive transitions, 4 compile barriers)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix barriers _ _) =
    CheckResult
        "transaction-vocabulary-paired-negatives"
        [observation ("transaction-vocabulary.compile-negative." <> name) (receiptSummary receipt) | CompileBarrier name _ receipt <- barriers]
        [ finding "TRANSACTION-VOCABULARY-COMPILE-NEGATIVE" (Text.unpack name) "the compiler barrier did not turn red at its independently authored reason"
        | CompileBarrier name expected receipt <- barriers
        , receiptExit receipt == ExitSuccess || notContains expected (receiptOutput receipt)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "transaction-vocabulary-mutants"
        [observation ("transaction-vocabulary.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "TRANSACTION-VOCABULARY-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "transaction-vocabulary-source-discipline"
            [observation "transaction-vocabulary.production-module-count" "1", observation "transaction-vocabulary.effect-boundary" "pure closed GADT, total schema/statement projections, compiler barriers, and run-local Cabal children only; no database, network, service, cluster, or hardware effects"]
            ( [ finding "TRANSACTION-VOCABULARY-SOURCE-SHAPE" "<transaction-vocabulary-production>" ("missing production element: " <> token)
              | token <- ["data RowDeclaration", "data Transaction scope result where", "scopePredicate", "transitionGeneration", "sqlBundleText"]
              , notContains token production
              ]
                <> [ finding "TRANSACTION-VOCABULARY-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["rowOracle", "transactionOracle", "generationOracle", "calculusOracle", "compileBarrierOracle", "mutantOracle", "validationLoci"]
                   , notContains token oracle
                   ]
                <> [ finding "TRANSACTION-VOCABULARY-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or fixture module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "transaction-vocabulary-discovery"
        [observation "transaction-vocabulary.discovery.count" (Text.pack (show (length observed)))]
        [finding "TRANSACTION-VOCABULARY-DISCOVERY" "<phase-36-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "transaction-vocabulary-authority"
        [observation "transaction-vocabulary.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "TRANSACTION-VOCABULARY-RUN-ROOT" runRoot "run root escaped .build/runs/phase-36/work" | not (pathBelow (root </> ".build/runs/phase-36/work") runRoot)]
            <> [ finding "TRANSACTION-VOCABULARY-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-36 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "transaction-vocabulary-observer"
        (map (observation "transaction-vocabulary.observer.process" . receiptSummary) receipts)
        [ finding "TRANSACTION-VOCABULARY-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "transaction-vocabulary-freshness"
        [observation "transaction-vocabulary.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "TRANSACTION-VOCABULARY-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-36/work") runRoot)
        ]

legacyCheck :: FilePath -> IO CheckResult
legacyCheck root = do
    files <- filterM (doesFileExist . (root </>)) retiredSources
    pure
        ( CheckResult
            "transaction-vocabulary-legacy-closure"
            [observation "transaction-vocabulary.legacy.retired-count" (Text.pack (show (length retiredSources))), observation "transaction-vocabulary.legacy.semantic-inputs" "HaskellOnly"]
            [finding "TRANSACTION-VOCABULARY-LEGACY" path "retired Python/serialized/test-local-mutant authority remains" | path <- files]
        )

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-36-claim" [pre]
    , named "phase-36-subject" [toolchain, positives]
    , named "phase-36-command" [toolchain, authority]
    , named "phase-36-oracle" [oracle]
    , named "phase-36-positive-controls" [positives]
    , named "phase-36-paired-negatives" [negatives]
    , named "phase-36-mutants" [mutants]
    , named "phase-36-discovery" [discovery]
    , named "phase-36-challenge" [mutants]
    , named "phase-36-observer" [observer]
    , named "phase-36-authority-bypass" [authority]
    , named "phase-36-freshness" [freshness]
    , named "phase-36-qualification" [qualification]
    , named "phase-36-cleanroom" [cleanroom]
    , named "phase-36-legacy-closure" [legacy]
    , CheckResult "phase-36-predecessor" [observation "phase-36.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-36-residue" [observation "phase-36.residue" "live database connections, executor roles, row-policy enforcement, destructive retention lifecycle, runtime services, and hardware remain later-owned"] []
    , named "phase-36-pass-criterion" [pre]
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
            "transaction-vocabulary-source-repository-cache"
            [observation "transaction-vocabulary.cache.entries" (Text.pack (show copied))]
            [ finding "TRANSACTION-VOCABULARY-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
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
    let parent = root </> ".build/runs/phase-36/work"
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
    ["src/transaction-vocabulary/Amoebius/Transaction/Vocabulary.hs"]
expectedSources = sort (productionSources <> [oracleSource, specSource, compileSource])
retiredSources =
    [ "tools/transaction_vocabulary_gate.py"
    , "test/oracle/transaction_vocabulary_surfaces.tsv"
    , "test/oracle/transaction_vocabulary/calculus_projection.tsv"
    , "test/oracle/transaction_vocabulary/generations.tsv"
    , "test/oracle/transaction_vocabulary/rows.tsv"
    , "test/oracle/transaction_vocabulary/transactions.tsv"
    , "test/oracle/transaction_vocabulary/validation_locus.tsv"
    , "test/mutant/transaction_vocabulary/transaction-optional-scope/mutant.txt"
    , "test/mutant/transaction_vocabulary/transaction-match-all/mutant.txt"
    , "test/mutant/transaction_vocabulary/transaction-wrong-policy-column/mutant.txt"
    ]

oracleSource, specSource, compileSource :: FilePath
oracleSource = "test/spec/transaction/TransactionVocabularyOracle.hs"
specSource = "test/spec/transaction/TransactionVocabularySpec.hs"
compileSource = "test/negative/compile_fail/transaction_vocabulary/TransactionCompile.hs"
