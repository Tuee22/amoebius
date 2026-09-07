{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.ToolAndMutantGenerationRun.Internal (
    AcquiredToolAndMutantGenerationRun,
    acquireToolAndMutantGenerationRefreshRun,
    acquireToolAndMutantGenerationRun,
    acquiredToolAndMutantGenerationRunCheck,
    foldAcquiredToolAndMutantGenerationRun,
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
import Control.Monad (forM_)
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
    getHomeDirectory,
    listDirectory,
    removeFile,
 )
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, makeRelative, normalise, takeExtension, takeFileName, (</>))
import System.IO (hClose, openBinaryTempFile)
import System.Process (CreateProcess (cwd, env), proc, readCreateProcessWithExitCode)

data Receipt = Receipt Text FilePath [String] ExitCode Text Text deriving (Eq, Show)
data CompileBarrier = CompileBarrier Text Bool Text Receipt deriving (Eq, Show)
data Mutant = Mutant Text Text Text Receipt deriving (Eq, Show)
data Matrix = Matrix [CompileBarrier] [Mutant] Receipt

data AcquiredToolAndMutantGenerationRun
    = AcquiredToolAndMutantGenerationRun
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

acquiredToolAndMutantGenerationRunCheck :: AcquiredToolAndMutantGenerationRun -> CheckResult
acquiredToolAndMutantGenerationRunCheck (AcquiredToolAndMutantGenerationRun _ _ _ _ _ _ _ _ _ _ _ _ result) = result

foldAcquiredToolAndMutantGenerationRun ::
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
    AcquiredToolAndMutantGenerationRun ->
    value
foldAcquiredToolAndMutantGenerationRun consume (AcquiredToolAndMutantGenerationRun acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result) =
    consume acquired trust contract rows subject oracle harness observer qualification runId toolchain cleanup result

acquireToolAndMutantGenerationRun
    , acquireToolAndMutantGenerationRefreshRun ::
        FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredToolAndMutantGenerationRun
acquireToolAndMutantGenerationRun = acquire False
acquireToolAndMutantGenerationRefreshRun = acquire True

acquire :: Bool -> FilePath -> AcquiredSourceSnapshot -> GenesisTrust -> IO AcquiredToolAndMutantGenerationRun
acquire refresh root acquired trust = do
    runRoot <- freshRunRoot root
    home <- getHomeDirectory
    let cabal = home </> ".ghcup/bin/cabal-3.16.1.0"
        compiler = genesisTrustCompilerExecutable trust
        store = home </> ".cabal/store"
        contract = if refresh then acquireRecordedPhaseContractEvidence acquired else acquirePhaseContractEvidenceFor 47 acquired
    cache <- prepareSourceRepositoryCache root runRoot
    cabalVersion <- runProcess root "cabal-version" cabal ["--numeric-version"]
    matrix <- executeMatrix root runRoot cabal compiler store
    discipline <- sourceDisciplineCheck root
    generated <- generatedDiscoveryCheck root (takeFileName runRoot <> "-clean")
    let legacy = legacyCheck acquired
    let toolchain = toolchainCheck cabal compiler store cabalVersion matrix
        oracle = oracleCheck (cleanReceipt matrix)
        positives = positiveCheck (cleanReceipt matrix)
        negatives = negativeCheck matrix
        mutants = mutantCheck matrix
        discovery = mergeChecks "tool-and-mutant-generation-discovery" [discoveryCheck acquired, generated]
        authority = authorityCheck root runRoot cabal compiler store (cabalVersion : matrixReceipts matrix)
        observer = observerCheck (cabalVersion : matrixReceipts matrix)
        freshness = freshnessCheck root runRoot (cleanReceipt matrix)
        cleanroom = mergeChecks "tool-and-mutant-generation-cleanroom" [cache, freshness, legacy]
        qualification =
            mergeChecks
                "tool-and-mutant-generation-qualification"
                [toolchain, oracle, positives, negatives, mutants, discovery, discipline, legacy, cleanroom]
        prerequisite =
            mergeChecks
                "tool-and-mutant-generation-prerequisite"
                [genesisTrustCheck trust, acquiredPhaseContractEvidenceCheck contract, qualification, authority, observer]
        rows = phaseRows prerequisite toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy
        result = mergeChecks "tool-and-mutant-generation" rows
        sourceId = snapshotIdentity (acquiredSourceSnapshot acquired)
        ids label parts = digestTexts (label : sourceId : parts)
        subjectId = ids "tool-and-mutant-generation-subject" [checkDigest discipline, receiptDigest (cleanReceipt matrix)]
        oracleId = ids "tool-and-mutant-generation-oracle" [checkDigest oracle, checkDigest negatives]
        harnessId = ids "tool-and-mutant-generation-harness" (map receiptDigest (cabalVersion : matrixReceipts matrix))
        observerId = ids "tool-and-mutant-generation-observer" [checkDigest observer]
        qualificationId = ids "tool-and-mutant-generation-qualification" [checkDigest qualification]
        acquiredRunId = ids "tool-and-mutant-generation-run" [Text.pack runRoot, checkDigest result]
        toolchainId = ids "tool-and-mutant-generation-toolchain" [genesisTrustToolchainIdentity trust, receiptDigest cabalVersion]
        cleanup = "run-root-contained=" <> Text.pack (makeRelative root runRoot) <> ";external-residue=0;live-effects=0"
    pure (AcquiredToolAndMutantGenerationRun acquired trust contract rows subjectId oracleId harnessId observerId qualificationId acquiredRunId toolchainId cleanup result)

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
                   , "tool-and-mutant-generation-spec"
                   , "--offline"
                   , "--test-show-details=direct"
                   ]
                <> [ "--test-options=--output " <> (root </> ".build") <> " --run-id " <> takeFileName runRoot <> "-" <> Text.unpack name ]
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
    [ mutant "missing-rule" "tool-generation-missing-rule-mutant" "CheckingCorpus.tools" "tool-and-mutant-generation-mutant: RED missing-rule artifact-set-mismatch"
    , mutant "drop-operator" "tool-generation-drop-operator-mutant" "CheckingCorpus.mutations" "tool-and-mutant-generation-mutant: RED drop-operator mutation-set-mismatch"
    , mutant "tracked-output" "tool-generation-track-output-mutant" "CheckingCorpus.outputPolicy" "tool-and-mutant-generation-mutant: RED tracked-output output-policy-refused"
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
        "tool-and-mutant-generation-toolchain"
        [observation "tool-and-mutant-generation.cabal" (receiptSummary version), observation "tool-and-mutant-generation.compiler" (Text.pack compiler)]
        ( [ finding "TOOL-AND-MUTANT-GENERATION-CABAL" cabal "the exact Cabal 3.16.1.0 executable was not observed"
          | not (isAbsolute cabal) || receiptExit version /= ExitSuccess || Text.strip (receiptStdout version) /= "3.16.1.0"
          ]
            <> [ finding "TOOL-AND-MUTANT-GENERATION-COMPILER" (Text.unpack name) "the row did not use the exact compiler/store, offline mode, and --jobs=1"
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
        "tool-and-mutant-generation-independent-oracle"
        [observation "tool-and-mutant-generation.oracle" (receiptSummary clean), observation "tool-and-mutant-generation.oracle-independence" "ToolAndMutantGenerationOracle imports no production or case module"]
        [ finding "TOOL-AND-MUTANT-GENERATION-ORACLE" oracleSource "the independent Haskell oracle did not report its exact acceptance token"
        | receiptExit clean /= ExitSuccess || notContains acceptance (receiptOutput clean)
        ]
  where
    acceptance = "tool-and-mutant-generation-spec: PASS (3 checking tools, 2 serialized cases, 3 mutation declarations, 1 Pulumi program, 9 content-addressed artifacts, 3 mutants)"

positiveCheck :: Receipt -> CheckResult
positiveCheck clean =
    CheckResult
        "tool-and-mutant-generation-positive-controls"
        [observation "tool-and-mutant-generation.positives" "nine exact Haskell declarations, content-addressed materialization, permission checks, independent byte oracle, and calculus controls passed"]
        [ finding "TOOL-AND-MUTANT-GENERATION-POSITIVE" specSource "the clean Haskell support corpus did not pass"
        | receiptExit clean /= ExitSuccess || notContains "tool-and-mutant-generation-calculus: PASS (5 kinds, 27 projected units)" (receiptOutput clean)
        ]

negativeCheck :: Matrix -> CheckResult
negativeCheck (Matrix _ _ clean) =
    CheckResult
        "tool-and-mutant-generation-paired-negatives"
        [observation "tool-and-mutant-generation.negatives" "relative project roots, authored output roots, and escaping run identities were independently refused while the exact build root passed"]
        [ finding "TOOL-AND-MUTANT-GENERATION-PAIRED-NEGATIVES" specSource "the clean candidate did not exercise the complete typed refusal and sensitivity battery"
        | receiptExit clean /= ExitSuccess || notContains "9 content-addressed artifacts, 3 mutants" (receiptOutput clean)
        ]

mutantCheck :: Matrix -> CheckResult
mutantCheck (Matrix _ mutants _) =
    CheckResult
        "tool-and-mutant-generation-mutants"
        [observation ("tool-and-mutant-generation.mutant." <> name) (receiptSummary receipt) | Mutant name _ _ receipt <- mutants]
        [ finding "TOOL-AND-MUTANT-GENERATION-MUTANT" (Text.unpack name) ("the changed production subject did not turn red at " <> locus)
        | Mutant name locus expected receipt <- mutants
        , receiptExit receipt /= ExitFailure 1 || notContains expected (receiptOutput receipt)
        ]

sourceDisciplineCheck :: FilePath -> IO CheckResult
sourceDisciplineCheck root = do
    production <- Text.concat <$> mapM (fmap Text.pack . readFile . (root </>)) productionSources
    oracle <- Text.pack <$> readFile (root </> oracleSource)
    pure
        ( CheckResult
            "tool-and-mutant-generation-source-discipline"
            [ observation "tool-and-mutant-generation.production-module-count" "1"
            , observation "tool-and-mutant-generation.effect-boundary" "Haskell declaration projection plus run-local files and serial offline Cabal children only; no generated tool execution, pb, Python, network, service, cluster, provider, or hardware effects"
            ]
            ( [ finding "TOOL-AND-MUTANT-GENERATION-SOURCE-SHAPE" "<tool-and-mutant-generation-production>" ("missing production element: " <> token)
              | token <- ["supportCorpus", "mkBuildRoot", "writeGeneratedCorpus", "SHA256.hash", "TOOL_GENERATION_MISSING_RULE_MUTANT", "TOOL_GENERATION_DROP_OPERATOR_MUTANT", "TOOL_GENERATION_TRACK_OUTPUT_MUTANT"]
              , notContains token production
              ]
                <> [ finding "TOOL-AND-MUTANT-GENERATION-ORACLE-SHAPE" oracleSource ("missing oracle element: " <> token)
                   | token <- ["expectedArtifacts", "expectedClassCounts", "expectedRefusals"]
                   , notContains token oracle
                   ]
                <> [ finding "TOOL-AND-MUTANT-GENERATION-ORACLE-INDEPENDENCE" oracleSource "independent oracle imports a production or case module"
                   | "import Amoebius" `Text.isInfixOf` oracle
                   ]
            )
        )

discoveryCheck :: AcquiredSourceSnapshot -> CheckResult
discoveryCheck acquired =
    CheckResult
        "tool-and-mutant-generation-discovery"
        [observation "tool-and-mutant-generation.discovery.count" (Text.pack (show (length observed)))]
        [finding "TOOL-AND-MUTANT-GENERATION-DISCOVERY" "<phase-47-source-set>" ("expected=" <> Text.pack (show expectedSources) <> "; observed=" <> Text.pack (show observed)) | observed /= expectedSources]
  where
    observed = sort [path | entry <- snapshotEntries (acquiredSourceSnapshot acquired), let path = indexPath (trackedIndex entry), path `elem` expectedSources]

generatedDiscoveryCheck :: FilePath -> FilePath -> IO CheckResult
generatedDiscoveryCheck root runIdentity = do
    let bases =
            [ root </> ".build/tools/tool-and-mutant-generation" </> runIdentity
            , root </> ".build/test-corpora/tool-and-mutant-generation" </> runIdentity
            , root </> ".build/pulumi/tool-and-mutant-generation" </> runIdentity
            ]
    files <- fmap (sort . concat) (mapM listFilesRecursively bases)
    pure
        ( CheckResult
            "tool-and-mutant-generation-generated-discovery"
            [ observation "tool-and-mutant-generation.generated.count" (Text.pack (show (length files)))
            , observation "tool-and-mutant-generation.generated.run-identity" (Text.pack runIdentity)
            ]
            [ finding "TOOL-AND-MUTANT-GENERATION-GENERATED-DISCOVERY" "<generated-support-corpus>" ("expected exactly nine generated files below the three class roots; observed=" <> Text.pack (show (map (makeRelative root) files)))
            | length files /= 9
            ]
        )

listFilesRecursively :: FilePath -> IO [FilePath]
listFilesRecursively path = do
    present <- doesDirectoryExist path
    if not present
        then pure []
        else do
            names <- sort <$> listDirectory path
            fmap concat $ mapM descend names
  where
    descend name = do
        let child = path </> name
        directory <- doesDirectoryExist child
        if directory then listFilesRecursively child else pure [child]

authorityCheck :: FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> [Receipt] -> CheckResult
authorityCheck root runRoot cabal compiler store receipts =
    CheckResult
        "tool-and-mutant-generation-authority"
        [observation "tool-and-mutant-generation.authority" "no pb/network/host/hardware/live service; exact Cabal/compiler; serial synchronous children"]
        ( [finding "TOOL-AND-MUTANT-GENERATION-RUN-ROOT" runRoot "run root escaped .build/runs/phase-47/work" | not (pathBelow (root </> ".build/runs/phase-47/work") runRoot)]
            <> [ finding "TOOL-AND-MUTANT-GENERATION-AUTHORITY" (Text.unpack name) "a process executable or argv exceeded Phase-47 authority"
               | Receipt name executable args _ _ _ <- receipts
               , executable /= cabal || (name /= "cabal-version" && (("--store-dir=" <> store) `notElem` args || ("--with-compiler=" <> compiler) `notElem` args || "--jobs=1" `notElem` args || "--offline" `notElem` args)) || any forbiddenArg args
               ]
        )
  where
    forbiddenArg value = any (`isInfixOf` value) ["pb", "docker", "podman", "kubectl", "kind", "ssh", "http://", "https://"]

observerCheck :: [Receipt] -> CheckResult
observerCheck receipts =
    CheckResult
        "tool-and-mutant-generation-observer"
        (map (observation "tool-and-mutant-generation.observer.process" . receiptSummary) receipts)
        [ finding "TOOL-AND-MUTANT-GENERATION-OBSERVER" (Text.unpack name) "process receipt lacks an absolute executable or digest"
        | receipt@(Receipt name executable _ _ _ _) <- receipts
        , not (isAbsolute executable) || Text.null (receiptDigest receipt)
        ]

freshnessCheck :: FilePath -> FilePath -> Receipt -> CheckResult
freshnessCheck root runRoot clean =
    CheckResult
        "tool-and-mutant-generation-freshness"
        [observation "tool-and-mutant-generation.fresh-build-root" (Text.pack (makeRelative root runRoot))]
        [ finding "TOOL-AND-MUTANT-GENERATION-FRESHNESS" runRoot "the clean candidate did not execute in the unique acquired run root"
        | receiptExit clean /= ExitSuccess || not (pathBelow (root </> ".build/runs/phase-47/work") runRoot)
        ]

legacyCheck :: AcquiredSourceSnapshot -> CheckResult
legacyCheck acquired =
    CheckResult
        "tool-and-mutant-generation-legacy-closure"
        [ observation "tool-and-mutant-generation.legacy.remaining-count" (Text.pack (show (length remaining)))
        , observation "tool-and-mutant-generation.legacy.reintroduction-witnesses" (Text.pack (show syntheticWitnesses))
        ]
        ( [ finding "TOOL-AND-MUTANT-GENERATION-LEGACY" path "tracked tools, Pulumi, or non-Haskell test authority remains"
          | path <- remaining
          ]
            <> [ finding "TOOL-AND-MUTANT-GENERATION-LEGACY-WITNESS" "<typed-reintroduction-witness>" "the exact legacy classifier did not reject all three due source families while accepting Haskell test source"
               | not witnessExact
               ]
        )
  where
    paths = [indexPath (trackedIndex entry) | entry <- snapshotEntries (acquiredSourceSnapshot acquired)]
    remaining = sort (filter legacySource paths)
    syntheticWitnesses = ["tools/reintroduced.py", "pulumi/reintroduced.yaml", "test/reintroduced.json"]
    witnessExact = all legacySource syntheticWitnesses && not (legacySource "test/Reintroduced.hs")

legacySource :: FilePath -> Bool
legacySource path =
    pathUnder "tools" path
        || pathUnder "pulumi" path
        || (pathUnder "test" path && takeExtension path /= ".hs")

pathUnder :: FilePath -> FilePath -> Bool
pathUnder parent path = path == parent || (parent <> "/") `isPrefixOf` path

phaseRows :: CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> CheckResult -> [CheckResult]
phaseRows pre toolchain oracle positives negatives mutants discovery authority observer freshness qualification cleanroom legacy =
    [ named "phase-47-claim" [pre]
    , named "phase-47-subject" [toolchain, positives]
    , named "phase-47-command" [toolchain, authority]
    , named "phase-47-oracle" [oracle]
    , named "phase-47-positive-controls" [positives]
    , named "phase-47-paired-negatives" [negatives]
    , named "phase-47-mutants" [mutants]
    , named "phase-47-discovery" [discovery]
    , named "phase-47-challenge" [mutants]
    , named "phase-47-observer" [observer]
    , named "phase-47-authority-bypass" [authority]
    , named "phase-47-freshness" [freshness]
    , named "phase-47-qualification" [qualification]
    , named "phase-47-cleanroom" [cleanroom]
    , named "phase-47-legacy-closure" [legacy]
    , CheckResult "phase-47-predecessor" [observation "phase-47.predecessor" "deferred to durable receipt verifier"] []
    , CheckResult "phase-47-residue" [observation "phase-47.residue" "generated-tool execution, provider semantics, live runtime behavior, publication, deployment, and hardware fidelity remain later-owned"] []
    , named "phase-47-pass-criterion" [pre]
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
            "tool-and-mutant-generation-source-repository-cache"
            [observation "tool-and-mutant-generation.cache.entries" (Text.pack (show copied))]
            [ finding "TOOL-AND-MUTANT-GENERATION-CACHE" (makeRelative root source) "authenticated network-independent source-repository cache is absent or incomplete"
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
    let parent = root </> ".build/runs/phase-47/work"
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

productionSources, expectedSources :: [FilePath]
productionSources = ["src/tool-and-mutant-generation/Amoebius/Generate/CheckingCorpus.hs"]
expectedSources = sort (productionSources <> [oracleSource, specSource])

oracleSource, specSource :: FilePath
oracleSource = "test/spec/generation/ToolAndMutantGenerationOracle.hs"
specSource = "test/spec/generation/ToolAndMutantGenerationSpec.hs"
