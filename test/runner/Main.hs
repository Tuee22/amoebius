{-# LANGUAGE OverloadedStrings #-}

-- | The runner suite: a byte producer for the runner oracle. It exercises the
-- gate-specification constructor, specification verification against a fixture
-- package description, the operator catalogue, deterministic sampling, mutant
-- application with its witness, the kill table, the hygiene row over a fixture
-- tree, and candidate capture. It prints no verdict; the oracle under
-- test/oracle/runner/Main.hs judges the rows from literals.
module Main (main) where

import Amoebius.Doc.Check (checkTree, discoverDocuments)
import Amoebius.Doc.Governance (checkGateSpecBlocks)
import Amoebius.Cli.Delegate (delegateValidate)
import Amoebius.Doc.Types (CheckResult (..), Finding (..))
import Amoebius.Plan.PhaseIdentity qualified as Identity
import Amoebius.Plan.Legacy qualified as Legacy
import Amoebius.Plan.StatusFrontier qualified as Status
import Amoebius.Validation.Custody.Preflight
import Amoebius.Validation.BootstrapPredicate (bootstrapSnapshotMatches)
import Amoebius.Validation.Custody (CommandOutcome (..), CustodyConfig (..), defaultCustodyConfig, resetGeneration, runFresh, voidFromPhase, receiptCompatibility, acceptPhase, previewPhase)
import Amoebius.Validation.Compatibility (closureDigest)
import Amoebius.Validation.Custody.Status
import Amoebius.Validation.Custody.Store
import Amoebius.Validation.GateSpec
import Amoebius.Validation.GateSpec.Registry (specInputFor, registeredSpecInputs)
import Amoebius.Validation.Runner.Binary (Nonce (..), perturbInput)
import Amoebius.Validation.Runner.Capture
import Amoebius.Validation.Runner (GateOutcome (..), RunnerConfig (..), RunnerRefusal (..), defaultRunnerConfig, renderRefusal, reproducibleCore, runGate, parseLedger, ledgerDigest, ledgerGreen, suiteLedger)
import Data.ByteString qualified as ByteString
import Amoebius.Validation.Runner.Hygiene
import Amoebius.Validation.Runner.Mutants
import Amoebius.Validation.Runner.Observer (sha256Hex, observe, observeNativeCabal, ObservedRun (..))
import Amoebius.Validation.Runner.Spec
import Amoebius.Validation.Runner.Legacy qualified as Analyzers
import Control.Monad (forM, forM_)
import Control.Exception (SomeException, IOException, fromException, try)
import Distribution.Fields.ParseResult (runParseResult)
import Distribution.PackageDescription.Parsec (parseGenericPackageDescription)
import Distribution.Parsec.Warning (PWarning (..))
import Distribution.Parsec.Position (showPos)
import Data.IORef (newIORef, modifyIORef', readIORef)
import Data.List (sort, intercalate)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, doesPathExist, findExecutable, listDirectory, makeAbsolute, removeFile, removePathForcibly)
import System.Environment (getArgs, getProgName)
import System.Exit (ExitCode (..))
import System.FilePath (takeBaseName, takeDirectory, makeRelative, splitDirectories, (</>))
import System.IO.Error (ioeGetErrorString)
import SourceCapture (sourceCaptureRows, sourceRewriteRows, sourceTreeRows)
import LegacyAudit (legacyAuditRows, legacyKernelRows, legacyMutationRows, legacySolverRows, legacyBootstrapRows, legacyCorrespondenceRows, legacyCustodyRows, legacyStatusRows, legacyAuthorityRows, legacyFreshRows, legacyAdmissionRows, legacyProbeSourceRows, legacyVendorSourceRows, legacyTestSourceRows, legacyToolSourceRows, legacyPulumiSourceRows, legacyRuntimeIdentityRows, legacyIgnoreContextRows, legacySourceGraphRows, legacyBootstrapSourceRows, mutationRows, solverReintroductionRows, solverSourceRows)
import Portability (portabilityRows, verifierChild, observerRows)

main :: IO ()
main = do
  arguments <- getArgs
  name <- getProgName
  if takeBaseName name == "amoebius-validate" then verifierChild arguments else case arguments of
    "--delegation-parent" : options -> delegateValidate options
    ["--observer", output] -> do
      createDirectoryIfMissing True output
      TextIO.writeFile (output </> "observer.tsv") (Text.unlines (map (Text.intercalate "\t") observerRows))
    ["--oracle-build", output] -> do
      rows <- oracleBuildRows output
      TextIO.writeFile (output </> "oracle-build.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--oracle-input", output] -> do
      rows <- oracleInputRows output
      TextIO.writeFile (output </> "oracle-input.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--source-tree", output] -> do
      createDirectoryIfMissing True output
      rows <- sourceTreeRows output
      TextIO.writeFile (output </> "source-tree.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--oracle-isolation", output] -> do
      rows <- oracleIsolationRows output
      TextIO.writeFile (output </> "oracle-isolation.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--source-read", output] -> do
      rows <- sourceReadRows output
      TextIO.writeFile (output </> "source-read.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--contracts", output] -> do
      createDirectoryIfMissing True output
      rows <- contractStructureRows
      TextIO.writeFile (output </> "contracts.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--contract-correspondence", output] -> do
      rows <- correspondenceRows output
      TextIO.writeFile (output </> "correspondence.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--receipt-custody", output] -> do
      rows <- receiptCustodyRows output
      TextIO.writeFile (output </> "custody.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--status-authority", output] -> do
      rows <- statusAuthorityRows output
      TextIO.writeFile (output </> "status-authority.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--runner-authority", output] -> do
      rows <- runnerAuthorityRows output
      TextIO.writeFile (output </> "authority.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--fresh-inputs", output] -> do
      rows <- freshInputRows output
      TextIO.writeFile (output </> "fresh-inputs.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--package-syntax", output] -> do
      rows <- packageSyntaxRows output
      TextIO.writeFile (output </> "package-syntax.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--reproducible", output] -> do
      createDirectoryIfMissing True output
      rows <- reproducibleRows
      TextIO.writeFile (output </> "reproducible.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--mutation-source", output] -> do
      rows <- mutationRows output
      TextIO.writeFile (output </> "mutation.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--portability", output] -> do
      rows <- portabilityRows output
      TextIO.writeFile (output </> "portability.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
      putStrLn ("portability observations written: " <> (output </> "portability.tsv"))
    ["--legacy-kernel", output] -> do
      rows <- legacyKernelRows output
      TextIO.writeFile (output </> "kernel-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
      putStrLn ("kernel qualification observations written: " <> (output </> "kernel-join.tsv"))
    ["--legacy-admission", output] -> do
      rows <- legacyAdmissionRows output
      TextIO.writeFile (output </> "admission-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-bootstrap-source", output] -> do
      rows <- legacyBootstrapSourceRows output
      TextIO.writeFile (output </> "bootstrap-source-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-source-graph", output] -> do
      rows <- legacySourceGraphRows output
      TextIO.writeFile (output </> "source-graph-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-ignore-context", output] -> do
      rows <- legacyIgnoreContextRows output
      TextIO.writeFile (output </> "ignore-context-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-runtime-identity", output] -> do
      rows <- legacyRuntimeIdentityRows output
      TextIO.writeFile (output </> "runtime-identity-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-pulumi-source", output] -> do
      rows <- legacyPulumiSourceRows output
      TextIO.writeFile (output </> "pulumi-source-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-tool-source", output] -> do
      rows <- legacyToolSourceRows output
      TextIO.writeFile (output </> "tool-source-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-test-source", output] -> do
      rows <- legacyTestSourceRows output
      TextIO.writeFile (output </> "test-source-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-probe-source", output] -> do
      rows <- legacyProbeSourceRows output
      TextIO.writeFile (output </> "probe-source-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-vendor-source", output] -> do
      rows <- legacyVendorSourceRows output
      TextIO.writeFile (output </> "vendor-source-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-mutation", output] -> do
      rows <- legacyMutationRows output
      TextIO.writeFile (output </> "mutation-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
      putStrLn ("mutation qualification observations written: " <> (output </> "mutation-join.tsv"))
    ["--legacy-solver", output] -> do
      rows <- legacySolverRows output
      TextIO.writeFile (output </> "solver-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-bootstrap", output] -> do
      rows <- legacyBootstrapRows output
      TextIO.writeFile (output </> "bootstrap-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-correspondence", output] -> do
      rows <- legacyCorrespondenceRows output
      TextIO.writeFile (output </> "correspondence-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-custody", output] -> do
      rows <- legacyCustodyRows output
      TextIO.writeFile (output </> "custody-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-status", output] -> do
      rows <- legacyStatusRows output
      TextIO.writeFile (output </> "status-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-authority", output] -> do
      rows <- legacyAuthorityRows output
      TextIO.writeFile (output </> "authority-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-fresh", output] -> do
      rows <- legacyFreshRows output
      TextIO.writeFile (output </> "fresh-join.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--solver-reintroduction", output] -> do
      rows <- solverReintroductionRows output
      TextIO.writeFile (output </> "solver-reintroduction.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--solver-source", output] -> do
      rows <- solverSourceRows output
      TextIO.writeFile (output </> "solver-source.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    ["--legacy-audit", output] -> do
      rows <- legacyAuditRows output
      TextIO.writeFile (output </> "legacy.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
      putStrLn ("legacy-audit observations written: " <> (output </> "legacy.tsv"))
    ["--source-capture", output] -> do
      rows <- sourceCaptureRows output
      TextIO.writeFile (output </> "source.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
      putStrLn ("source-capture observations written: " <> (output </> "source.tsv"))
    ["--source-rewrite", output] -> do
      rows <- sourceRewriteRows output
      TextIO.writeFile (output </> "source-rewrite.tsv") (Text.unlines (map (Text.intercalate "\t") rows))
    _ -> runnerChecks arguments

runnerChecks :: [String] -> IO ()
runnerChecks arguments = do
  let output = case arguments of
        [path] -> path
        _ -> ".build/runs/phase-00/runner"
  createDirectoryIfMissing True output
  trees <- map ("source-tree" :) <$> sourceTreeRows output
  isolation <- map ("oracle-isolation" :) <$> oracleIsolationRows output
  sourceReads <- map ("source-read" :) <$> sourceReadRows output
  contracts <- map ("contracts" :) <$> contractStructureRows
  correspondence <- map ("correspondence" :) <$> correspondenceRows output
  custody <- map ("custody-native" :) <$> receiptCustodyRows output
  authority <- map ("status-native" :) <$> statusAuthorityRows output
  runnerAuthority <- map ("authority-native" :) <$> runnerAuthorityRows output
  freshInputs <- map ("fresh-native" :) <$> freshInputRows output
  rows <- concat <$> sequence [contractRows, constructorRows, verifyRows output, oracleHygieneRows output, map ("oracle-build" :) <$> oracleBuildRows output, map ("oracle-input" :) <$> oracleInputRows output, map ("package-syntax" :) <$> packageSyntaxRows output, operatorRows output, killRows', hygieneRows output, legacyRows output, freshnessRows output, legacyInventoryRows, kernelRatchetRows output, captureRows, preflightRows, storeRows output, archiveRows output, replayVoidRows output, crossGenerationVoidRows output, statusRows output, resetRows output, reproducibleRows, packageRows]
  TextIO.writeFile (output </> "runner.tsv") (Text.unlines (map (Text.intercalate "\t") (rows <> trees <> isolation <> sourceReads <> contracts <> correspondence <> custody <> authority <> runnerAuthority <> freshInputs)))
  putStrLn ("runner projection written: " <> (output </> "runner.tsv"))

-- * Fixtures

contractRows :: IO [[Text]]
contractRows = pure [["contract", "extension-oracle", maybe "missing" (oracleExecutableName . inputOracle)
  (specInputFor "extension_admission_attested_scope")]]

contractStructureRows :: IO [[Text]]
contractStructureRows = do
  (documents,_,_) <- discoverDocuments "."
  let required key = maybe (error "contract fixture registration absent") id (lookup key registeredSpecInputs)
      altered key change = [(name,if name == key then change input else input) | (name,input) <- registeredSpecInputs]
      projected inputs = either (Text.intercalate ";") (Text.intercalate "," . map (Text.pack . show . fst)) (compiledBlocks inputs)
      resolved ordinal = either (Text.intercalate ";") (const "accepted") (resolveSpec registeredSpecInputs ordinal)
      first = Identity.phaseDomainLowerOrdinal
      path = maybe (error "contract fixture phase absent") Identity.phaseIdentityPath (Identity.lookupPhaseIdentity first)
      fence text = "```gate-spec\n" <> text <> "\n```\n"
      findings blocks docs = Text.intercalate "," [findingCode finding <> ":" <> Text.pack (findingSubject finding) | finding <- checkGateSpecBlocks blocks docs]
      native = either (Text.intercalate ";") (\blocks -> findings blocks documents) (compiledBlocks registeredSpecInputs)
      role key ordinal = [key,Text.pack (show ordinal) <> ":" <> Text.pack (show (roleFor ordinal))]
      children = required "child_clusters_obligation_teardown"
      ui = required "ui_program_language_binding"
      barrier = required "dsl_barrier"
      predecessors = map required ["typed_spine","witness_manifests_capacity_storage","substrates_lanes_image_recipe","extension_admission_attested_scope"]
      negatives input previous = Text.intercalate "," [caseTag item <> ":" <> caseStage item | item@PairedNegative {} <- inputCases input, caseName item `notElem` concatMap (map caseName . inputCases) previous]
      modules = Text.intercalate "," . map productionModuleName . inputSubjects
  pure
    ([ ["registered",projected registeredSpecInputs], ["empty",projected []]
     , ["duplicate",projected (registeredSpecInputs <> take 1 registeredSpecInputs)]
     , ["duplicate-resolve",either (Text.intercalate ";") (const "accepted") (resolveSpec (registeredSpecInputs <> take 1 registeredSpecInputs) first)]
     , ["unknown",projected [("orphan-contract",(required "toolchain_spike") {inputCapability = "orphan-contract"})]]
     , ["capability-mismatch",projected (altered "documentation_suite" (\input -> input {inputCapability = "toolchain_spike"}))]
     , ["missing-binary",projected (altered "toolchain_spike" (\input -> input {inputBinaryFact = Nothing}))]
     , ["missing-seed",projected (altered "documentation_suite" (\input -> input {inputSeed = Nothing}))]
     , ["unregistered",either (Text.intercalate ";") (const "accepted") (resolveSpec [] first)]
     , ["out-of-domain",resolved (Identity.phaseDomainUpperOrdinal + 1)]
     , ["reserved-gap",resolved 10]
     , ["document-unregistered",findings [] [(path,fence "proposal")]]
     , ["document-duplicate-fence",findings [] [(path,fence "proposal" <> fence "proposal")]]
     , ["document-mismatch",findings [(first,"compiled")] [(path,fence "proposal")]]
     , ["document-matched",findings [(first,"compiled")] [(path,fence "compiled")]]
     , ["native",native]
     , ["children-subjects",modules children], ["ui-subjects",modules ui]
     , ["children-negatives",negatives children predecessors]
     , ["ui-negatives",negatives ui [children]], ["barrier-negatives",negatives barrier [ui]]
     , ["barrier-inherits-subjects",Text.pack (show (all (`elem` inputSubjects barrier) (concatMap (inputSubjects . required) ["typed_spine","witness_manifests_capacity_storage","substrates_lanes_image_recipe","extension_admission_attested_scope","child_clusters_obligation_teardown","ui_program_language_binding"])))]
     , ["barrier-spine",maybe "absent" (\fact -> Text.pack (spineRendered fact) <> ":" <> Text.intercalate "," (spineStages fact) <> ":" <> Text.pack (spineAppliedDigestFile fact)) (inputSpineFact barrier)]
     , ["slice-substrates",Text.intercalate "," (map (renderSubstrate . inputSubstrate) [children,ui,barrier])]
     , ["slice-oracles",Text.intercalate "," (map (oracleExecutableName . inputOracle) [children,ui,barrier])]
     , ["barrier-inherits-cases",Text.pack (show (all (`elem` inputCases barrier) (concatMap inputCases (predecessors <> [children,ui]))))]
     , role "role-root" first, role "role-upper" Identity.phaseDomainUpperOrdinal]
     <> [role key ordinal | (key,marker) <- [("role-barrier",Identity.DslBarrier),("role-bootstrap",Identity.BootstrapHandoff),("role-ensure",Identity.HostEnsure),("role-hardware",Identity.FirstHardware)], Just ordinal <- [Identity.roleOrdinal marker]])

canonicalSpineFixture :: Text
canonicalSpineFixture = Text.replace "test-suite dsl-suite" "test-suite spine-suite"
  (Text.replace "exposed-modules: Amoebius.Dsl.Spec Amoebius.Dsl.Lower"
    "exposed-modules: Amoebius.Dsl.Spec Amoebius.Dsl.Lower Amoebius.Dsl.Import Amoebius.Dsl.Decode Amoebius.Kernel.Step Amoebius.Kernel.Interpret Amoebius.Dsl.Pipeline" fixtureCabal)
canonicalSpine :: Maybe (Int, GateSpec)
canonicalSpine = do
  phase <- Identity.lookupCapabilityOrdinal "typed_spine"
  (_, spec) <- either (const Nothing) Just (resolveSpec registeredSpecInputs phase)
  pure (phase, spec)

freshInputRows :: FilePath -> IO [[Text]]
freshInputRows output = do
  absolute <- makeAbsolute output
  let root = absolute </> "fresh-input-fixture"
      repo = root </> "repo"
      copied = root </> "copy"
      input = ".build/input.hs"
      checked = either id (const "verified")
      captured path = captureSource path >>= either (fail . Text.unpack) pure
      row name role value = [name,role,value]
      boolean = Text.pack . show
  createDirectoryIfMissing True (repo </> ".build")
  initialized <- observe repo "git" ["init","--quiet"]
  if runExit initialized /= ExitSuccess then fail "fresh input fixture Git initialization failed" else pure ()
  TextIO.writeFile (repo </> "Program.hs") "module Main where\nmain = putStrLn \"before\"\n"
  TextIO.writeFile (repo </> input) "declared input\n"
  opening <- captured repo
  first <- materializeSource opening copied
  TextIO.writeFile (copied </> ".build/stale-sentinel") "keep\n"
  stale <- materializeSource opening copied
  sentinel <- TextIO.readFile (copied </> ".build/stale-sentinel")
  ignoredPositive <- verifySourceCopy opening copied
  TextIO.writeFile (copied </> input) "changed input\n"
  ignoredNegative <- verifySourceCopy opening copied
  TextIO.writeFile (copied </> input) "declared input\n"
  authoredPositive <- verifySourceCopy opening copied
  TextIO.writeFile (copied </> "expected.tsv") "authored expected output\n"
  authoredNegative <- verifySourceCopy opening copied
  removeFile (copied </> "expected.tsv")
  restored <- verifySourceCopy opening copied
  TextIO.writeFile (repo </> "Program.hs") "module Main where\nmain = putStrLn \"after\"\n"
  closing <- captured repo
  let unknown = Identity.phaseDomainUpperOrdinal + 1
  collection <- Analyzers.collectLegacy "." (root </> "unknown-collection") unknown Nothing Nothing opening
  replayed <- verifySourceCopy closing copied
  let package = root </> "package"
      ambient = root </> "ambient-run"
      legitimate = package </> ".build/runs/fresh-inputs"
  createDirectoryIfMissing True (package </> "test/oracle/dsl")
  TextIO.writeFile (package </> "amoebius.cabal") canonicalSpineFixture
  TextIO.writeFile (package </> "test/oracle/dsl/Main.hs") "module Main where\nmain = pure ()\n"
  (phase,spec) <- maybe (fail "fresh input canonical contract absent") pure canonicalSpine
  inside <- runRootWithinFrame package legitimate
  outside <- runRootWithinFrame package ambient
  entry <- runGate (defaultRunnerConfig package phase) {runnerRunRoot = ambient,runnerCabal = root </> "must-not-run-cabal",runnerHygienePreflight = False} spec
  created <- doesPathExist ambient
  let entryReason = either (Text.takeWhile (/= ':') . renderRefusal) (const "captured") entry
      matching left right = bootstrapSnapshotMatches (Text.unpack (capturedSourceDigest left)) (Text.unpack (capturedSourceDigest right))
      inventory = either id (Text.intercalate "," . map Text.pack) . parseSourceInventory
      observations =
        [row "stale-run" "positive" (either id (const "copied") first),row "stale-run" "negative" (either id (const "copied") stale)
        ,row "ignored-input" "positive" (checked ignoredPositive),row "ignored-input" "negative" (checked ignoredNegative)
        ,row "authored-output" "positive" (checked authoredPositive),row "authored-output" "negative" (checked authoredNegative)
        ,row "ambient-temp" "positive" (boolean inside),row "ambient-temp" "negative" (boolean outside)
        ,row "replayed-input" "positive" (boolean (matching opening opening)),row "replayed-input" "negative" (boolean (matching opening closing))
        ,row "empty-discovery" "positive" (inventory "Program.hs\0"),row "empty-discovery" "negative" (inventory "")
        ,row "control" "stale-sentinel" (Text.pack (show sentinel)),row "control" "ignored-captured" (boolean (capturedSourceBytes opening input == Just "declared input\n"))
        ,row "control" "source-changed" (boolean (capturedSourceDigest opening /= capturedSourceDigest closing))
        ,row "control" "replayed-copy" (checked replayed),row "control" "authored-restored" (checked restored)
        ,row "control" "ambient-entry" entryReason,row "control" "ambient-created" (boolean created)
        ,row "control" "collection-unknown" (boolean (Analyzers.auditLegacyCollection unknown opening collection == ["LegacyPhaseUnknown"]))
        ,row "control" "collection-phase" (boolean ("LegacyCollectionContextMismatch" `elem` Analyzers.auditLegacyCollection Identity.phaseDomainLowerOrdinal opening collection))
        ,row "control" "collection-source" (boolean ("LegacyCollectionContextMismatch" `elem` Analyzers.auditLegacyCollection unknown closing collection))]
  removePathForcibly root
  removed <- not <$> doesPathExist root
  pure (observations <> [row "control" "cleanup" (boolean removed)])

runnerAuthorityRows :: FilePath -> IO [[Text]]
runnerAuthorityRows output = do
  absolute <- makeAbsolute output
  let root = absolute </> "authority-fixtures"
      generated = root </> "generated"
  createDirectoryIfMissing True generated
  compiler <- findExecutable "ghc" >>= maybe (fail "authority native compiler absent") pure
  cabal <- findExecutable "cabal" >>= maybe (fail "authority native Cabal absent") pure
  located <- observeNativeCabal "." cabal (Just compiler) ["list-bin","--builddir=.build/dist-native","test:oracle-runner"]
  let oracle = Text.unpack (Text.strip (runStdout located))
  emitted <- observe "." oracle ["--write-authority-checkers",generated]
  if runExit located /= ExitSuccess || runExit emitted /= ExitSuccess then fail "authority independent native checker source unavailable" else pure ()
  let subject suffix = Text.unlines
        ["module Main where", "import System.Environment (getArgs)", "import System.Exit (exitFailure)", "main = do"
        ,"  [input,output] <- getArgs", "  bytes <- readFile input", "  writeFile output bytes"] <> suffix
  forM_ [("subject",subject ""),("failed",subject "  putStrLn \"PASS ExitSuccess\"\n  exitFailure\n"),("noop","module Main where\nmain = pure ()\n")] $ \(name,body) ->
    TextIO.writeFile (generated </> name <> ".hs") body
  forM_ ["subject","failed","noop","honest","omitted","constant","seed"] $ \name -> do
    let objects = generated </> (name <> "-objects")
    createDirectoryIfMissing True objects
    built <- observe "." compiler ["-v0","-j1","-XGHC2024","--make","-outputdir",objects,"-o",generated </> name,generated </> name <> ".hs"]
    if runExit built /= ExitSuccess then fail (Text.unpack (runStderr built)) else pure ()
  let input = root </> "input.txt"
      required = ["authority.value","authority.discovery"]
      runOne key role subject_ checker probe_ = do
        let directory = root </> Text.unpack key </> role
            empty = directory </> "empty"
        createDirectoryIfMissing True empty
        subjectRun <- observe "." (generated </> subject_) [input,directory </> "subject.txt"]
        checkerProbe <- observe "." (generated </> probe_) [empty]
        checkerRun <- observe "." (generated </> checker) [directory]
        pure (suiteLedger required subjectRun checkerRun checkerProbe,subjectRun,checkerProbe)
      cases = [("noop-subject","noop","honest","honest"),("constant-success-checker","subject","constant","constant")
        ,("forged-exit","failed","honest","honest"),("omitted-discovery","subject","omitted","omitted")
        ,("unavailable-boundary","subject","honest","absent")]
  TextIO.writeFile input "observed input\n"
  observed <- forM cases $ \(key,subject_,checker,probe_) -> do
    (positive,_,_) <- runOne key "positive" "subject" "honest" "honest"
    (negative,run,probe) <- runOne key "negative" subject_ checker probe_
    pure ([[key,"positive",Text.pack (show (ledgerGreen positive))],[key,"negative",Text.pack (show (ledgerGreen negative))]],key,run,probe)
  (_,seedSpec) <- either (fail . show) pure (resolveSpec registeredSpecInputs Identity.phaseDomainLowerOrdinal)
  names <- Text.lines <$> TextIO.readFile (generated </> "seed-rows.data")
  let manifest = requiredSuiteRows seedSpec
      seedRun role omission = do
        let directory = root </> "seed-manifest" </> role
            empty = directory </> "empty"
        createDirectoryIfMissing True empty
        forM_ omission (TextIO.writeFile (directory </> "omit.txt"))
        subjectRun <- observe "." (generated </> "subject") [input,directory </> "subject.txt"]
        probe <- observe "." (generated </> "seed") [empty]
        oracleRun <- observe "." (generated </> "seed") [directory]
        pure (ledgerGreen (suiteLedger manifest subjectRun oracleRun probe))
  complete <- seedRun "complete" Nothing
  omissions <- forM (zip [1 :: Int ..] names) $ \(index,key) -> do
    accepted <- seedRun (show index) (Just key)
    pure ["manifest","omitted." <> key,Text.pack (show accepted)]
  let controls = concat
        [[ ["control","subject-exit",Text.pack (show (runExit run))],["control","subject-token",Text.pack (show (runStdout run))]] | (_,key,run,_) <- observed,key == "forged-exit"]
        <> [["control","constant-probe",Text.pack (show (runExit probe))] | (_,key,_,probe) <- observed,key == "constant-success-checker"]
        <> [["control","missing-probe",Text.pack (show (runSpawnFailure probe /= Nothing))] | (_,key,_,probe) <- observed,key == "unavailable-boundary"]
  removePathForcibly root
  removed <- not <$> doesPathExist root
  pure (concat [rows | (rows,_,_,_) <- observed] <> controls <> [["control","cleanup",Text.pack (show removed)]
    ,["manifest","seed-names",Text.intercalate "," (sort manifest)],["manifest","seed-positive",Text.pack (show complete)]] <> omissions)

-- Native status acquisition and public command refusals on an isolated plan.
-- Supplied reproduction facts exercise preflight; they never create a gate pass.
statusAuthorityRows :: FilePath -> IO [[Text]]
statusAuthorityRows output = do
  absolute <- makeAbsolute output
  createDirectoryIfMissing True absolute
  verifier <- verifierDigest
  let phase = Identity.phaseDomainLowerOrdinal
      digest = Text.replicate 64 "b"
      required value = maybe (fail "status fixture identity absent") pure value
  initial <- required (Status.frontierForGate phase)
  next <- required (Status.frontierAfterPass initial phase)
  successor <- required (Identity.successorOrdinal phase)
  (_,spec) <- either (fail . show) pure (resolveSpec registeredSpecInputs phase)
  observations <- forM ["status-surface-dirty","status-without-receipt","predecessor-not-reproduced","status-edit-without-receipt"] $ \key -> do
    let root = absolute </> "status-fixtures" </> Text.unpack key
        config = (defaultCustodyConfig root) {custodyStore = Store (root </> ".build/store")}
        writePatch = mapM_ (\(path,contents) -> TextIO.writeFile (root </> path) contents)
        load = statusSurface root >>= either (fail . Text.unpack) pure
        tokens = map (Text.takeWhile (/= ':') . renderPreflightRefusal) . preflight
        facts surface accepted missing unreproduced = (cleanFacts spec)
          {factsSurfaceDigest = surfaceDigest surface, factsAcceptedPostimage = accepted
          ,factsSurfaceConsistent = surfaceConsistent surface, factsDoneWithoutReceipt = missing
          ,factsPredecessorsNotReproduced = unreproduced}
        receiptSet = if key == "status-without-receipt" then Map.empty else Map.singleton phase digest
    writeStatusFixture root initial Map.empty
    original <- load
    let recorded = surfaceDigest original
    -- The malformed initial surface is observed without a prior local seed;
    -- a missing baseline must not make contradictory status fields admissible.
    if key == "status-edit-without-receipt" then pure () else do
      _ <- writeSeed (custodyStore config) (SeedRecord verifier "fixture" verifier governanceDigest recorded "fixture" "2026-10-20 00:00:00 UTC") >>= either (fail . Text.unpack) pure
      pure ()
    if key `elem` ["status-without-receipt","predecessor-not-reproduced"]
      then patchToFrontier root next receiptSet >>= writePatch
      else do
        identity <- required (Identity.lookupPhaseIdentity phase)
        let path = root </> Identity.phaseIdentityPath identity
        contents <- TextIO.readFile path
        TextIO.writeFile path (if key == "status-surface-dirty"
          then Text.replace ": Fixture 🔄" ": Changed 🔄" contents
          else Text.replace (Status.renderPhaseStatusLine Status.ActiveNotValidated) (Status.renderPhaseStatusLine Status.Done) contents)
    changed <- load
    let missing = [p | Just f <- [recordedFrontier changed], p <- Identity.phaseOrdinals
          , Status.phaseStatusAt f p == Status.Done, p `notElem` map fst (surfaceReceipts changed)]
        notReproduced = [p | (p,_) <- surfaceReceipts changed]
        positive = facts original (Just recorded) [] []
        negative = facts changed (if key == "status-edit-without-receipt" then Nothing else Just recorded) missing notReproduced
        selected = if key `elem` ["status-without-receipt","predecessor-not-reproduced"] then successor else phase
        wanted = case key of "status-without-receipt" -> "STATUS-WITHOUT-RECEIPT"; "predecessor-not-reproduced" -> "PredecessorNotReproduced"; _ -> "StatusSurfaceDirty"
        admitted outcome = wanted `elem` map (Text.takeWhile (/= ':')) (outcomeLines outcome)
    beforeArchive <- auditArchivedInventory root
    accepted <- acceptPhase config selected
    previewed <- previewPhase config selected
    after <- load
    afterArchive <- auditArchivedInventory root
    pure ([[key,"positive",Text.intercalate "," (tokens positive)]
      ,[key,"negative",Text.pack (show (wanted `elem` tokens negative))]]
      <> [[part,key,Text.pack (show valid)] | (part,valid) <-
        [("accept",outcomeExit accepted == ExitFailure 1 && admitted accepted)
        ,("preview",outcomeExit previewed == ExitFailure 1 && admitted previewed)
        ,("unchanged",changed == after && beforeArchive == afterArchive)]])
  let fixture = absolute </> "status-fixtures"
  removePathForcibly fixture
  removed <- not <$> doesPathExist fixture
  pure (concat observations <> [["control","cleanup",Text.pack (show removed)]])

writeStatusFixture :: FilePath -> Status.StatusFrontier -> Map.Map Int Text -> IO ()
writeStatusFixture root frontier receipts = do
  createDirectoryIfMissing True (root </> "DEVELOPMENT_PLAN")
  TextIO.writeFile (root </> "DEVELOPMENT_PLAN/README.md") (Text.unlines
    ["| " <> Text.pack (show phase) <> " | fixture | none | none | — | " <> Status.renderTrackerStatus (Status.phaseStatusAt frontier phase) <> " | — |" | phase <- Identity.phaseOrdinals])
  forM_ Identity.allPhaseIdentities $ \identity -> do
    let phase = Identity.phaseIdentityOrdinal identity
        state = Status.phaseStatusAt frontier phase
        contents = ["# Fixture", "", "## Phase Status", "", Status.renderPhaseStatusLine state]
          <> ["**Receipt**: " <> digest | state == Status.Done, Just digest <- [Map.lookup phase receipts]]
          <> ["", "## Phase Summary", "Fixture body"]
          <> concat [["", "## Sprint " <> Text.pack (show phase) <> "." <> Text.pack (show sprint) <> ": Fixture " <> Status.renderStatusMarker (Status.sprintStatusAt frontier phase sprint)
            ,"**Status**: " <> Status.renderSprintStatus (Status.sprintStatusAt frontier phase sprint)] | sprint <- [1,2]]
    TextIO.writeFile (root </> Identity.phaseIdentityPath identity) (Text.unlines contents)

receiptCustodyRows :: FilePath -> IO [[Text]]
receiptCustodyRows output = do
  root <- makeAbsolute (output </> "custody-fixture")
  createDirectoryIfMissing True (root </> "test/oracle/dsl")
  TextIO.writeFile (root </> "amoebius.cabal") canonicalSpineFixture
  TextIO.writeFile (root </> "test/oracle/dsl/Main.hs") "module Main where\nmain = pure ()\n"
  (phase,spec) <- maybe (fail "canonical spine absent") pure canonicalSpine
  forM_ ["app/Main.hs","test/dsl/Main.hs"] $ \path -> do
    createDirectoryIfMissing True (takeDirectory (root </> path))
    TextIO.writeFile (root </> path) "module Main where\nmain = pure ()\n"
  TextIO.writeFile (root </> "cabal.project") "packages: .\n"
  TextIO.writeFile (root </> ".gitignore") ".build/\n"
  createDirectoryIfMissing True (root </> "pb")
  readSourceText "pb/__main__.py" >>= TextIO.writeFile (root </> "pb/__main__.py")
  let source module_ = root </> "src" </> Text.unpack (Text.replace "." "/" module_) <> ".hs"
      body module_ value = "module " <> module_ <> " where\nvalue = " <> value <> "\n"
      target = "Amoebius.Dsl.Spec"
      before = body target "1"
      after = body target "2"
      repro = Text.replicate 64 "b"
      postimage = Text.replicate 64 "c"
  forM_ (gateSubjects spec) $ \(ProductionModule name) -> do
    createDirectoryIfMissing True (takeDirectory (source name))
    TextIO.writeFile (source name) (body name "1")
  graph <- loadPackageGraph root >>= either (fail . show) pure
  verified <- verifySpecAgainst root graph spec >>= either (fail . show) pure
  verifier <- verifierDigest
  original <- closureDigest root graph verified verifier governanceDigest
  let candidate = Text.unlines ["candidate\tphase=" <> Text.pack (show phase) <> "\tcapability=typed_spine","spec-digest\tspec"]
      kills = "mutant\tkilled\n"
      evidence = [("candidate.tsv",candidate),("kill-table.tsv",kills),("outcome.tsv","green\tTrue\n"),("oracle-ledger.tsv","clean\tgreen\n"),("observer.tsv","observed\n")]
      receipt = Receipt phase "typed_spine" verifier "spec" (renderGateSpec spec) (sha256Hex candidate) (sha256Hex kills)
        original repro verifier governanceDigest postimage "fixture" [] Nothing Nothing "2026-10-20 00:00:00 UTC"
      result = either id (const "accepted")
      matching closure value = receiptCompatibility phase repro verifier governanceDigest closure value
      summarize value = case value of
        Left problem -> Text.takeWhile (/= ':') problem
        Right [(value_,_)] | value_ == receipt -> "accepted"
        Right _ -> "unexpected-records"
      archive = root </> "archive"
      foreignArchive = root </> "foreign-verifier"
      foreignReceipt = receipt {receiptVerifierDigest = Text.replicate 64 "d"}
      foreignBundle = archivedBundlePath foreignArchive foreignReceipt evidence
  _ <- writeArchivedReceipt archive receipt evidence >>= either (fail . Text.unpack) pure
  admitted <- readCurrentArchivedBundles archive verifier
  -- The attack transport is self-consistent except for the verifier binding;
  -- admission must observe it, rather than trusting the writer's refusal.
  createDirectoryIfMissing True foreignBundle
  _ <- writeRecord (foreignBundle </> "receipt.tsv") (renderReceipt foreignReceipt) >>= either (fail . Text.unpack) pure
  forM_ evidence $ \(name,bytes) -> TextIO.writeFile (foreignBundle </> name) bytes
  foreignRead <- readCurrentArchivedBundles foreignArchive verifier
  TextIO.writeFile (source target) after
  changed <- closureDigest root graph verified verifier governanceDigest
  TextIO.writeFile (source target) before
  restored <- closureDigest root graph verified verifier governanceDigest
  let outside = root </> "unrelated/Other.hs"
  createDirectoryIfMissing True (takeDirectory outside)
  TextIO.writeFile outside "module Other where\nvalue = 1\n"
  unchanged <- closureDigest root graph verified verifier governanceDigest
  dependencies <- receiptDependencyRows output verifier
  pure
    [["generation-one-receipt","positive",result (parseReceipt (renderReceipt receipt))]
    ,["generation-one-receipt","negative",result (parseReceipt (Text.replace "amoebius-phase-receipt.v2" "amoebius-phase-receipt.v1" (renderReceipt receipt)))]
    ,["verifier-diverged","positive",summarize admitted],["verifier-diverged","negative",summarize foreignRead]
    ,["predecessor-closure-edited","positive",result (matching (Just (original,renderGateSpec spec)) receipt)]
    ,["predecessor-closure-edited","negative",result (matching (Just (changed,renderGateSpec spec)) receipt)]
    ,["binding","verifier-positive",result (matching (Just (original,renderGateSpec spec)) receipt)]
    ,["binding","verifier-negative",result (matching (Just (original,renderGateSpec spec)) foreignReceipt)]
    ,["control","closure-source",Text.pack (show (before,after))]
    ,["control","closure-restored",Text.pack (show (restored == original))]
    ,["control","outside-closure",Text.pack (show (unchanged == original))]
    ,["control","unknown-closure",result (matching Nothing receipt)]
    ,["control","closure-sentinel",result (matching (Just ("closure-unavailable",renderGateSpec spec)) receipt {receiptClosureDigest = "closure-unavailable"})]
    ,["control","capability-binding",result (matching (Just (original,renderGateSpec spec)) receipt {receiptCapability = "documentation_suite"})]
    ,["control","governance-binding",result (matching (Just (original,renderGateSpec spec)) receipt {receiptGovernanceDigest = "foreign"})]
    ,["control","specification-binding",result (matching (Just (original,renderGateSpec spec <> "claim: changed\n")) receipt)]
    ,["control","phase-binding",result (receiptCompatibility Identity.phaseDomainLowerOrdinal repro verifier governanceDigest (Just (original,renderGateSpec spec)) receipt)]]
    >>= \rows -> pure (rows <> dependencies)

receiptDependencyRows :: FilePath -> Text -> IO [[Text]]
receiptDependencyRows output verifier = do
  root <- makeAbsolute (output </> "receipt-dependencies")
  (documents,discovery,_) <- discoverDocuments "."
  if null discovery then pure () else fail "receipt dependency discovery refused"
  files <- concat <$> mapM (haskellFilesUnder ".") ["src","app","test"]
  let copy path contents = createDirectoryIfMissing True (takeDirectory (root </> path)) >> TextIO.writeFile (root </> path) contents
  mapM_ (\path -> readSourceText path >>= copy path) (files <> ["amoebius.cabal","cabal.project",".gitignore","pb/__main__.py"])
  mapM_ (uncurry copy) documents
  (_, spec) <- either (fail . show) pure (resolveSpec registeredSpecInputs Identity.phaseDomainLowerOrdinal)
  graph <- loadPackageGraph root >>= either (fail . show) pure
  verified <- verifySpecAgainst root graph spec >>= either (fail . show) pure
  let digest = closureDigest root graph verified verifier governanceDigest
  before <- digest
  observations <- forM [("suite","test/plan-decisions/Main.hs","-- dependency challenge\n"),("oracle","test/oracle/doc/Main.hs","-- dependency challenge\n"),("custody-suite","test/runner/Main.hs","-- dependency challenge\n"),("entry","app/amoebius-validate/Main.hs","-- dependency challenge\n"),("build-tool","src/probe/ExtensionAdmission.hs","-- dependency challenge\n"),("seed-driver","test/validation-kernel/BootstrapMutationDriver.hs","-- dependency challenge\n"),("metadata","cabal.project","-- dependency challenge\n"),("bootstrap","pb/__main__.py","# dependency challenge\n"),("documentation","README.md","\nDependency challenge.\n")] $ \(key,path,suffix) -> do
    contents <- readSourceText (root </> path)
    copy path (contents <> suffix)
    after <- digest
    copy path contents
    pure ["dependency",key,Text.pack (show (after /= before))]
  initial <- maybe (fail "receipt dependency frontier absent") pure (Status.frontierForGate Identity.phaseDomainLowerOrdinal)
  next <- maybe (fail "receipt dependency successor absent") pure (Status.frontierAfterPass initial Identity.phaseDomainLowerOrdinal)
  patch <- patchToFrontier root next (Map.singleton Identity.phaseDomainLowerOrdinal (Text.replicate 64 "e"))
  mapM_ (uncurry copy) patch
  projected <- digest
  removePathForcibly root
  removed <- not <$> doesPathExist root
  pure (observations <> [["dependency","status-projection",Text.pack (show (projected == before))],["dependency","cleanup",Text.pack (show removed)]])

correspondenceRows :: FilePath -> IO [[Text]]
correspondenceRows output = do
  (documents,discovery,_) <- discoverDocuments "."
  let snapshot = either (Text.intercalate ";") (\blocks -> Text.intercalate "," [findingCode f <> ":" <> Text.pack (findingSubject f) | f <- discovery <> checkGateSpecBlocks blocks documents]) (compiledBlocks registeredSpecInputs)
  (_, seed) <- either (fail . show) pure (resolveSpec registeredSpecInputs Identity.phaseDomainLowerOrdinal)
  selected <- verifySpec "." seed
  root <- makeAbsolute (output </> "correspondence-fixture")
  createDirectoryIfMissing True (root </> "test/oracle/dsl")
  TextIO.writeFile (root </> "amoebius.cabal") canonicalSpineFixture
  TextIO.writeFile (root </> "test/oracle/dsl/Main.hs") "module Main where\nmain = pure ()\n"
  input <- maybe (fail "canonical spine absent") pure (specInputFor "typed_spine")
  ordinal <- maybe (fail "spine identity absent") pure (Identity.lookupCapabilityOrdinal "typed_spine")
  let checked role value = either (fail . show) pure (mkGateSpec role value)
      binding phase spec = either (Text.intercalate ";") (const "accepted") (bindPhaseSpec registeredSpecInputs phase spec)
      doc row spec text = Text.intercalate "," [findingCode f <> ":" <> Text.pack (findingSubject f) | f <- checkGateSpecBlocks [(ordinal,renderGateSpec spec)] [(Identity.phaseIdentityPath row,"```gate-spec\n" <> text <> "```\n")]]
      outcome = either renderRefusal (const "accepted")
      execute name spec = do
        let path = root </> ".build" </> "runs" </> Text.unpack name
        result <- runGate (defaultRunnerConfig root ordinal) {runnerRunRoot = path, runnerCabal = root </> "must-not-run-cabal",runnerHygienePreflight = False} spec
        created <- doesPathExist path
        pure (outcome result,Text.pack (show created))
  canonical <- checked OrdinaryGate input
  swapped <- checked BarrierGate input
  collision <- case inputBinaryFact input of
    Just fact | first : second : rest <- factCommand fact -> checked OrdinaryGate input {inputBinaryFact = Just fact {factCommand = (first <> " " <> second) : rest}}
    _ -> fail "canonical binary argv absent"
  parked <- checked OrdinaryGate input {inputSubjects = [ProductionModule "Amoebius.Parked.Thing"],inputMutants = defaultMutantPolicy [ProductionModule "Amoebius.Parked.Thing"]}
  positive <- verifySpec root canonical
  negative <- verifySpec root parked
  roleEntry <- execute "role" swapped
  collisionEntry <- execute "argv" collision
  identity <- maybe (fail "spine row absent") pure (Identity.lookupPhaseIdentity ordinal)
  pure
    [["gate-spec-mismatch","positive",doc identity canonical (renderGateSpec canonical)]
    ,["gate-spec-mismatch","negative",doc identity canonical (renderGateSpec canonical <> "claim: substituted\n")]
    ,["phase-role-swap","positive",binding ordinal canonical]
    ,["phase-role-swap","negative",binding ordinal swapped]
    ,["byte-copy-equivalence","positive",binding ordinal canonical]
    ,["byte-copy-equivalence","negative",binding ordinal collision]
    ,["subject-not-shipped","positive",either (Text.intercalate ";" . map renderSpecProblem) (const "accepted") positive]
    ,["subject-not-shipped","negative",either (Text.intercalate ";" . map renderSpecProblem) (const "accepted") negative]
    ,["retired-domain-literal","positive",binding ordinal canonical]
    ,["retired-domain-literal","negative",binding (fst Identity.reservedGap) canonical]
    ,["control","render-collision",Text.pack (show (renderGateSpec canonical == renderGateSpec collision && canonical /= collision))]
    ,["entry","phase-role-swap",fst roleEntry],["entry","byte-copy-equivalence",fst collisionEntry]
    ,["entry-root","phase-role-swap",snd roleEntry],["entry-root","byte-copy-equivalence",snd collisionEntry]]
    >>= \rows -> pure (rows <> [["snapshot","contracts",snapshot],["snapshot","selected",either (Text.intercalate ";" . map renderSpecProblem) (const "accepted") selected]])

legalInput :: GateSpecInput
legalInput =
  GateSpecInput
    { inputCapability = "typed_spine"
    , inputClaim = "one spec reaches fake-applied bytes"
    , inputSubjects = [ProductionModule "Amoebius.Dsl.Spec", ProductionModule "Amoebius.Dsl.Lower"]
    , inputSuite = CabalTarget "dsl-suite"
    , inputOracle = OracleExecutable "oracle-dsl"
    , inputCases = [PositiveControl "kind-single-objectstore" "root.dhall" "manifest-delta", PairedNegative "unbound-need" "unbound.dhall" "UnboundNeed" "lower"]
    , inputMutants = defaultMutantPolicy [ProductionModule "Amoebius.Dsl.Spec"]
    , inputBinaryFact = Just (BinaryFact ["compile", "{input}"] "examples/root.dhall" (SentinelToNonce "SENTINEL") ["{run}/out/manifest.yaml"])
    , inputSpineFact = Nothing
    , inputSubstrate = HardwareFree
    , inputSeed = Nothing
    }

constructorRows :: IO [[Text]]
constructorRows =
  pure
    [ ["refusal", "legal-ordinary", outcome OrdinaryGate legalInput]
    , ["refusal", "kernel-subject", outcome OrdinaryGate legalInput {inputSubjects = [ProductionModule "Amoebius.Validation.Runner"], inputMutants = defaultMutantPolicy []}]
    , ["refusal", "missing-binary-fact", outcome OrdinaryGate legalInput {inputBinaryFact = Nothing}]
    , ["refusal", "barrier-without-spine", outcome BarrierGate legalInput]
    , ["refusal", "seed-with-binary-fact", outcome SeedGate legalInput {inputSeed = Just (SeedSpec ["clean"] ["p1"])}]
    , ["refusal", "hardware-substrate-ordinary", outcome OrdinaryGate legalInput {inputSubstrate = LinuxCpu}]
    , ["refusal", "hardware-role-without-substrate", outcome HardwareGate legalInput]
    , ["refusal", "stage-not-subject", outcome OrdinaryGate legalInput {inputMutants = defaultMutantPolicy [ProductionModule "Amoebius.Dsl.Other"]}]
    , ["refusal", "duplicate-case", outcome OrdinaryGate legalInput {inputCases = [PositiveControl "a" "x" "y", PositiveControl "a" "x" "z"]}]
    , ["refusal", "legal-seed", outcome SeedGate legalInput {inputBinaryFact = Nothing, inputSeed = Just (SeedSpec ["clean", "digest-equality-bypass"] ["probe-1"])}]
    , ["render", "legal-ordinary", either (const "refused") (Text.pack . show . length . Text.lines . renderGateSpec) (mkGateSpec OrdinaryGate legalInput)]
    , ["refusal", "ordinary-with-spine", outcome OrdinaryGate legalInput {inputSpineFact = Just (SpineFact "out/manifest.yaml" ["freeze"] "applied.sha256")}]
    , ["render", "staged", either (const "refused") (\spec -> Text.concat [line | line <- Text.lines (renderGateSpec spec), "binary-fact: " `Text.isPrefixOf` line]) (mkGateSpec OrdinaryGate legalInput {inputBinaryFact = Just (BinaryFact ["compile", "{input}"] "examples/root.dhall" (Staged [["render", "x", "--output", "{input}"]] [["apply", "y"]] [SentinelToNonce "S", ReplicaCount 1 3]) ["{run}/out/m"])})]
    , ["perturb", "staged-direct", either (const "refused") (const "applied") (perturbInput (Staged [] [] []) (Nonce "n") "x")]
    ]
 where
  outcome role input = either (Text.intercalate "," . sort . map renderSpecRefusal) (const "ok") (mkGateSpec role input)

fixtureCabal :: Text
fixtureCabal =
  Text.unlines
    [ "cabal-version: 3.0"
    , "name: amoebius"
    , "version: 0.1.0.0"
    , "build-type: Simple"
    , ""
    , "library dsl-core"
    , "    exposed-modules: Amoebius.Dsl.Spec Amoebius.Dsl.Lower"
    , "    hs-source-dirs: src"
    , "    build-depends: base, amoebius:vocabulary"
    , "    default-language: GHC2024"
    , ""
    , "library vocabulary"
    , "    exposed-modules: Amoebius.Vocabulary"
    , "    hs-source-dirs: src"
    , "    build-depends: base"
    , "    default-language: GHC2024"
    , ""
    , "library validation-runner"
    , "    exposed-modules: Amoebius.Validation.Runner"
    , "    hs-source-dirs: src"
    , "    build-depends: base"
    , "    default-language: GHC2024"
    , ""
    , "library parked"
    , "    exposed-modules: Amoebius.Parked.Thing"
    , "    hs-source-dirs: src"
    , "    build-depends: base"
    , "    default-language: GHC2024"
    , ""
    , "executable amoebius"
    , "    main-is: Main.hs"
    , "    hs-source-dirs: app"
    , "    build-depends: base, amoebius:dsl-core"
    , "    default-language: GHC2024"
    , ""
    , "test-suite dsl-suite"
    , "    type: exitcode-stdio-1.0"
    , "    main-is: Main.hs"
    , "    hs-source-dirs: test/dsl"
    , "    build-depends: base, amoebius:dsl-core"
    , "    default-language: GHC2024"
    , ""
    , "test-suite oracle-dsl"
    , "    type: exitcode-stdio-1.0"
    , "    main-is: Main.hs"
    , "    hs-source-dirs: test/oracle/dsl"
    , "    build-depends: base, text"
    , "    default-language: GHC2024"
    , ""
    , "test-suite oracle-leaky"
    , "    type: exitcode-stdio-1.0"
    , "    main-is: Main.hs"
    , "    hs-source-dirs: test/oracle/leaky"
    , "    build-depends: base, amoebius:dsl-core"
    , "    default-language: GHC2024"
    , ""
    , "test-suite oracle-cpp"
    , "    type: exitcode-stdio-1.0"
    , "    main-is: Main.hs"
    , "    hs-source-dirs: test/oracle/cpp"
    , "    build-depends: base"
    , "    default-language: GHC2024"
    ]

verifyRows :: FilePath -> IO [[Text]]
verifyRows output = do
  let root = output </> "fixture-package"
  createDirectoryIfMissing True (root </> "test/oracle/dsl")
  createDirectoryIfMissing True (root </> "test/oracle/leaky")
  createDirectoryIfMissing True (root </> "test/oracle/cpp")
  TextIO.writeFile (root </> "test/oracle/dsl/Main.hs") "module Main (main) where\nmain :: IO ()\nmain = pure ()\n"
  TextIO.writeFile (root </> "test/oracle/leaky/Main.hs") "module Main (main) where\nmain :: IO ()\nmain = pure ()\n"
  TextIO.writeFile (root </> "test/oracle/cpp/Main.hs") "\nmodule Main (main) where\n#if defined(X)\nmain :: IO ()\nmain = pure ()\n#endif\n"
  case parsePackageGraph (TextEncoding.encodeUtf8 fixtureCabal) of
    Left problem -> pure [["verify", "parse", renderSpecProblem problem]]
    Right graph -> do
      let closure = maybe "absent" (Text.intercalate "," . Set.toAscList) (executableClosure graph "amoebius")
          check name role input = do
            result <- case mkGateSpec role input of
              Left refusals -> pure (Left (map renderSpecRefusal refusals))
              Right spec -> either (Left . map renderSpecProblem) (const (Right ())) <$> verifySpecAgainst root graph spec
            pure ["verify", name, either (Text.intercalate "," . sort) (const "ok") result]
      rows <-
        sequence
          [ check "legal" OrdinaryGate legalInput
          , check "outside-closure" OrdinaryGate legalInput {inputSubjects = [ProductionModule "Amoebius.Parked.Thing"], inputMutants = defaultMutantPolicy []}
          , check "not-in-package" OrdinaryGate legalInput {inputSubjects = [ProductionModule "Amoebius.Nowhere"], inputMutants = defaultMutantPolicy []}
          , check "oracle-depends-on-product" OrdinaryGate legalInput {inputOracle = OracleExecutable "oracle-leaky"}
          , check "oracle-cpp" OrdinaryGate legalInput {inputOracle = OracleExecutable "oracle-cpp"}
          , check "oracle-missing" OrdinaryGate legalInput {inputOracle = OracleExecutable "oracle-absent"}
          , check "suite-missing" OrdinaryGate legalInput {inputSuite = CabalTarget "no-suite"}
          ]
      pure (["verify", "closure", closure] : rows)

-- Cabal can change an oracle's build without putting syntax in its .hs files.
-- These observations exercise the same public verifier as numbered gates.
oracleBuildRows :: FilePath -> IO [[Text]]
oracleBuildRows output = do
  let root = output </> "oracle-build"
      directory = root </> "test/oracle/dsl"
      cases =
        [("baseline", "", ""), ("legacy-clean", "", ""), ("warnings", "", "    ghc-options: -Wall -Wcompat -Werror=missing-methods\n")
        ,("optimization", "", "    ghc-options: -O0 -g\n")
        ,("ordinary-extension", "", "    default-extensions: DataKinds\n")
        ,("disabled-th", "", "    default-extensions: NoTemplateHaskell\n")
        ,("default-th", "", "    default-extensions: TemplateHaskell\n")
        ,("other-quotes", "", "    other-extensions: TemplateHaskellQuotes\n")
        ,("old-quasiquotes", "", "    extensions: QuasiQuotes\n")
        ,("default-cpp", "", "    default-extensions: CPP\n")
        ,("option-extension", "", "    ghc-options: -XTemplateHaskell\n")
        ,("plugin", "", "    ghc-options: -fplugin=Example.Plugin\n")
        ,("profiling-plugin", "", "    ghc-prof-options: -fplugin=Example.Plugin\n")
        ,("shared-plugin", "", "    ghc-shared-options: -fplugin=Example.Plugin\n")
        ,("profiling-shared-plugin", "", "    ghc-prof-shared-options: -fplugin=Example.Plugin\n")
        ,("ghcjs-profiling-shared-plugin", "", "    ghcjs-prof-shared-options: -fplugin=Example.Plugin\n")
        ,("ghcjs-plugin", "", "    ghcjs-options: -fplugin=Example.Plugin\n")
        ,("preprocessor", "", "    ghc-options: -F -pgmF ./preprocess\n")
        ,("package-option", "", "    ghc-options: -package amoebius\n")
        ,("cpp-options", "", "    cpp-options: -DORACLE\n")
        ,("c-source", "", "    c-sources: oracle.c\n")
        ,("cxx-source", "", "    cxx-sources: oracle.cpp\n")
        ,("javascript-source", "", "    js-sources: oracle.js\n")
        ,("assembly-source", "", "    asm-sources: oracle.s\n")
        ,("cmm-source", "", "    cmm-sources: oracle.cmm\n")
        ,("linker-options", "", "    ld-options: -loracle\n")
        ,("extra-library", "", "    extra-libraries: oracle\n")
        ,("build-tool", "", "    build-tool-depends: example:generate\n")
        ,("legacy-build-tool", "", "    build-tools: generate\n")
        ,("pkg-config", "", "    pkgconfig-depends: oracle\n")
        ,("conditional-th", "flag feature\n    default: False\n    manual: True\n\n", "    if flag(feature)\n        default-extensions: TemplateHaskell\n")
        ,("conditional-else", "flag feature\n    default: True\n    manual: True\n\n", "    if flag(feature)\n        ghc-options: -Wall\n    else\n        ghc-options: -fplugin=Example.Plugin\n")
        ,("conditional-clean", "flag feature\n    default: True\n    manual: True\n\n", "    if flag(feature)\n        ghc-options: -Wall\n    else\n        default-extensions: DataKinds\n")
        ,("common-clean", "common oracle-policy\n    ghc-options: -Wall\n\n", "    import: oracle-policy\n")
        ,("common-plugin", "common oracle-policy\n    ghc-options: -fplugin=Example.Plugin\n\n", "    import: oracle-policy\n")]
  createDirectoryIfMissing True directory
  TextIO.writeFile (directory </> "Main.hs") "module Main (main) where\nmain :: IO ()\nmain = pure ()\n"
  forM cases $ \(name, before, fields) -> do
    let legacy = name `elem` ["legacy-clean", "old-quasiquotes", "legacy-build-tool"]
        base = if legacy then Text.replace "amoebius:" "" fixtureCabal else fixtureCabal
        package = Text.replace "test-suite oracle-dsl\n" (before <> "test-suite oracle-dsl\n" <> fields)
          (Text.replace "cabal-version: 3.0" (if legacy then "cabal-version: 2.4" else "cabal-version: 3.16") base)
    graph <- either (fail . show) pure (parsePackageGraph (TextEncoding.encodeUtf8 package))
    problems <- verifyOracle root graph (OracleExecutable "oracle-dsl")
    pure [name, Text.intercalate "," (map renderSpecProblem problems)]

packageSyntaxRows :: FilePath -> IO [[Text]]
packageSyntaxRows output = do
  let header = "cabal-version: 3.16\nname: amoebius\nversion: 0.1.0.0\nbuild-type: Simple\n"
      suite = "test-suite oracle-syntax\n    type: exitcode-stdio-1.0\n    main-is: Main.hs\n    hs-source-dirs: test/oracle/main\n    build-depends: base\n    default-language: GHC2024\n"
      cases =
        [("clean", header <> suite), ("custom-field", header <> "x-note: inert metadata\n" <> suite)
        ,("deprecated", Text.replace "3.16" "2.4" header <> suite <> "    extensions: DataKinds\n")
        ,("unknown-root", header <> "unhandled-runtime: ignored\n" <> suite)
        ,("unknown-target", header <> suite <> "    unhandled-runtime: ignored\n")
        ,("unknown-section", header <> "unhandled-runtime hooks\n    command: ignored\n" <> suite)
        ,("too-new-field", Text.replace "3.16" "2.4" header <> suite <> "    ghc-prof-shared-options: -fplugin=Unadmitted.Plugin\n")
        ,("conditional-unknown", header <> "flag feature\n    default: False\n    manual: True\n\n" <> suite <> "    if flag(feature)\n        unhandled-runtime: ignored\n")
        ,("common-unknown", header <> "common shared-policy\n    unhandled-runtime: ignored\n\n" <> Text.replace "test-suite oracle-syntax\n" "test-suite oracle-syntax\n    import: shared-policy\n" suite)]
  repository <- TextIO.readFile "amoebius.cabal"
  createDirectoryIfMissing True (output </> "package-syntax-inputs")
  forM (cases <> [("repository", repository)]) $ \(name, body) -> do
    let bytes = TextEncoding.encodeUtf8 body
        (warnings, native) = runParseResult (parseGenericPackageDescription bytes)
        observed = Text.intercalate "," (sort [Text.pack (show kind <> "@" <> showPos position) | PWarning kind position _ <- warnings])
    TextIO.writeFile (output </> "package-syntax-inputs" </> Text.unpack name <> ".cabal") body
    pure [name, either (const "failed") (const "parsed") native, observed,
      either renderSpecProblem (const "accepted") (parsePackageGraph bytes)]

sourceReadRows :: FilePath -> IO [[Text]]
sourceReadRows output = do
  let native = output </> "source-read-native"
      size = 16 * 1024 * 1024
      package = "cabal-version: 3.12\nname: amoebius\nversion: 0.1.0.0\nbuild-type: Simple\nlibrary subject\n    exposed-modules: Root.Subject\n    hs-source-dirs: src\n    build-depends: base\n    default-language: GHC2024\n"
      oraclePackage = package <> "test-suite oracle-fixture\n    type: exitcode-stdio-1.0\n    main-is: Main.hs\n    hs-source-dirs: test/oracle\n    build-depends: base\n    default-language: GHC2024\n"
      source = "module Main where\nmain :: IO ()\nmain = pure ()\n"
      padded prefix suffix count = prefix <> ByteString.replicate (count - ByteString.length prefix - ByteString.length suffix) 97 <> suffix
      write path bytes = createDirectoryIfMissing True (takeDirectory path) >> ByteString.writeFile path bytes
      observeRead action = do
        result <- try action :: IO (Either SomeException Text)
        pure (either (\problem -> maybe "exception" (Text.pack . ioeGetErrorString) (fromException problem :: Maybe IOException)) id result)
      packageRow name bytes = do
        let root = native </> Text.unpack name
        write (root </> "amoebius.cabal") bytes
        value <- observeRead (packageResult <$> loadPackageGraph root)
        pure [name,value]
      packageResult result = case result of
        Right _ -> "accepted"
        Left (PackageDescriptionUnparsable message) -> "PackageDescriptionUnparsable:" <> if "SourceByteLimit" `Text.isInfixOf` message then "SourceByteLimit" else "unreadable"
        Left problem -> renderSpecProblem problem
  present <- doesPathExist native
  if present then fail "source-read output must be fresh" else createDirectoryIfMissing True native
  createDirectoryIfMissing True (native </> "directory.hs")
  notRegular <- observeRead (const "bytes" <$> readSourceBytes (native </> "directory.hs"))
  packages <- sequence [packageRow "package-clean" package
    ,packageRow "package-limit" (padded (package <> "-- ") "\n" size)
    ,packageRow "package-over" (padded (package <> "-- ") "\n" (size+1))]
  missing <- observeRead (packageResult <$> loadPackageGraph (native </> "missing"))
  graph <- either (fail . show) pure (parsePackageGraph oraclePackage)
  oracles <- forM [("oracle-clean",source),("oracle-over",padded (source <> "{-") "-}\n" (size+1)),("oracle-utf8",ByteString.singleton 255)] $ \(name,bytes) -> do
    let root = native </> Text.unpack name
    write (root </> "test/oracle/Main.hs") bytes
    value <- observeRead (Text.replace (Text.pack root <> "/") "" . Text.intercalate "," . map renderSpecProblem <$> verifyOracle root graph (OracleExecutable "oracle-fixture"))
    pure [name,value]
  let hygiene = native </> "hygiene"
      repo = native </> "repo"
  write (hygiene </> "src/validation-kernel/Large.hs") (padded (source <> "{-") "-}\n" (size+1))
  hygieneResult <- observeRead (const "report" <$> hygieneRow hygiene Nothing 7000)
  write (hygiene </> "amoebius.cabal") (TextEncoding.encodeUtf8 fixtureCabal)
  write (hygiene </> "test/oracle/dsl/Main.hs") source
  spec <- either (fail . show) pure (mkGateSpec OrdinaryGate legalInput)
  let gateResult result = case result of
        Left (SourceCaptureRefused problem) -> "SourceCaptureRefused:" <> problem
        Left problem -> renderRefusal problem
        Right _ -> "accepted"
  gateRead <- observeRead (gateResult <$> runGate (defaultRunnerConfig hygiene Identity.phaseDomainLowerOrdinal) spec)
  freshRead <- observeRead (gateResult <$> runFresh (defaultCustodyConfig hygiene) Identity.phaseDomainLowerOrdinal spec Nothing)
  let statusRoot = native </> "status"
  write (statusRoot </> "DEVELOPMENT_PLAN/README.md") (padded "# Tracker\n" "\n" (size+1))
  statusRead <- observeRead (either id (const "surface") <$> statusSurface statusRoot)
  createDirectoryIfMissing True repo
  initialized <- observe repo "git" ["init","--quiet"]
  if runExit initialized /= ExitSuccess then fail "source-read fixture Git initialization failed" else pure ()
  captures <- forM [("capture-limit",size),("capture-over",size+1)] $ \(name,count) -> do
    write (repo </> "large.hs") (padded (source <> "{-") "-}\n" count)
    value <- captureSource repo
    pure [name,either id (\snapshot -> "captured:" <> maybe "missing" (Text.pack . show . ByteString.length) (capturedSourceBytes snapshot "large.hs")) value]
  pure (packages <> [["package-missing",missing],["source-not-regular",notRegular]] <> oracles
    <> [["hygiene-over",hygieneResult],["gate-hygiene-over",gateRead],["fresh-hygiene-over",freshRead],["status-over",statusRead]] <> captures)

-- Independent entries in one area may share their source directory; product,
-- executable and differently scoped test directories must be disjoint.
oracleIsolationRows :: FilePath -> IO [[Text]]
oracleIsolationRows output = do
  fixtures <- oracleIsolationFixtures output
  graph <- loadPackageGraph "." >>= either (fail . show) pure
  native <- forM ["oracle-doc", "oracle-runner", "oracle-dsl", "oracle-extensions", "oracle-layout", "oracle-toolchain"] $ \name -> do
    problems <- verifyOracle "." graph (OracleExecutable name)
    pure ["repository." <> name, Text.intercalate "," (map renderSpecProblem problems)]
  pure (fixtures <> native)

oracleIsolationFixtures :: FilePath -> IO [[Text]]
oracleIsolationFixtures output = forM cases $ \(name, peer, extras) -> do
  let root = output </> "oracle-isolation" </> Text.unpack name
      package = "cabal-version: 3.16\nname: amoebius\nversion: 0.1.0.0\nbuild-type: Simple\n" <> peer
        <> "\ntest-suite oracle-fixture\n    type: exitcode-stdio-1.0\n    main-is: Main.hs\n    hs-source-dirs: test/oracle/main\n    build-depends: base\n    default-language: GHC2024\n"
  forM_ (("Main.hs", mainSource) : extras) $ \(path, contents) -> do
    let destination = root </> "test/oracle/main" </> path
    createDirectoryIfMissing True (takeDirectory destination)
    TextIO.writeFile destination contents
  graph <- either (fail . show) pure (parsePackageGraph (TextEncoding.encodeUtf8 package))
  problems <- verifyOracle root graph (OracleExecutable "oracle-fixture")
  pure [name, Text.replace (Text.pack root <> "/") "" (Text.intercalate "," (map renderSpecProblem problems))]
 where
  mainSource = "module Main where\nmain :: IO ()\nmain = pure ()\n"
  primary = "test/oracle/main"
  directory path = "    hs-source-dirs: " <> path <> "\n"
  library path = "\nlibrary peer\n    exposed-modules: Fixture.Subject\n" <> directory path <> "    build-depends: base\n    default-language: GHC2024\n"
  executable dirs = "\nexecutable peer\n    main-is: Main.hs\n" <> dirs <> "    build-depends: base\n    default-language: GHC2024\n"
  suite dirs depends options = "\ntest-suite peer\n    type: exitcode-stdio-1.0\n    main-is: Main.hs\n" <> dirs
    <> "    build-depends: " <> depends <> "\n    default-language: GHC2024\n" <> options
  cases =
    [("alone", "", [])
    ,("sibling", library "test/oracle/main2", [])
    ,("library-shared", library primary, [])
    ,("library-parent", library "test/oracle", [])
    ,("library-child", library (primary <> "/nested"), [])
    ,("library-normalized", library "test/oracle/main/../..", [])
    ,("library-case", library "TEST/ORACLE/MAIN", [])
    ,("library-default", "\nlibrary peer\n    exposed-modules: Fixture.Subject\n    build-depends: base\n", [])
    ,("executable-shared", executable (directory primary), [])
    ,("executable-default", executable "", [])
    ,("test-product", library "src" <> suite (directory primary) "base, amoebius:peer" "", [])
    ,("test-child", suite (directory (primary <> "/nested")) "base" "", [])
    ,("test-default", suite "" "base" "", [])
    ,("conditional", "\nflag sharing\n    default: False\n    manual: True\n" <> library "unrelated"
        <> "    if flag(sharing)\n        hs-source-dirs: test/oracle/main\n", [])
    ,("common", "\ncommon shared\n    hs-source-dirs: test/oracle/main\n\nlibrary peer\n    import: shared\n    exposed-modules: Fixture.Subject\n    build-depends: base\n", [])
    ,("area-entry", Text.replace "main-is: Main.hs" "main-is: Alternate.hs" (suite (directory primary) "base" ""), [("Alternate.hs",mainSource)])
    ,("area-helper", suite (directory primary) "base" "    other-modules: Fixture.Helper\n", [("Fixture/Helper.hs","module Fixture.Helper where\nvalue = True\n")])
    ,("area-unsafe-peer", suite (directory primary) "base" "    ghc-options: -fplugin=Missing.Plugin\n", [])
    ,("area-partial", suite (directory (primary <> " test/oracle/support")) "base" "", [])]

oracleInputRows :: FilePath -> IO [[Text]]
oracleInputRows output = do
  let primary = "test/oracle/main"
      support = "test/oracle/support"
      entry path directories modules = Text.unlines
        (["    type: exitcode-stdio-1.0", "    main-is: " <> path, "    hs-source-dirs: " <> directories]
          <> ["    other-modules: " <> modules | not (Text.null modules)])
      mainSource = "module Main (main) where\nmain :: IO ()\nmain = pure ()\n"
      helper = "module Fixture.Helper where\nvalue :: Bool\nvalue = True\n"
      mainFile = (primary <> "/Main.hs", mainSource)
      imported text = (primary <> "/Main.hs", "module Main where\n" <> text <> "\nmain :: IO ()\nmain = pure ()\n")
      simple = "build-type: Simple\n"
      setup = "custom-setup\n    setup-depends: base\n"
      cases =
        [("main", simple, entry "Main.hs" primary "", [mainFile])
        ,("alternate", simple, entry "Entry.hs" primary "", [(primary <> "/Entry.hs", mainSource)])
        ,("missing-entry", simple, entry "Missing.hs" primary "", [mainFile])
        ,("preprocessed-entry", simple, entry "Main.hsc" primary "", [mainFile, (primary <> "/Main.hsc", mainSource)])
        ,("module", simple, entry "Main.hs" primary "Fixture.Helper", [mainFile, (primary <> "/Fixture/Helper.hs", helper)])
        ,("missing-module", simple, entry "Main.hs" primary "Fixture.Helper", [mainFile])
        ,("preprocessed-module", simple, entry "Main.hs" primary "Fixture.Helper", [mainFile, (primary <> "/Fixture/Helper.hsc", helper)])
        ,("shadow-preprocessor", simple, entry "Main.hs" primary "Fixture.Helper", [mainFile, (primary <> "/Fixture/Helper.hs", helper), (primary <> "/Fixture/Helper.hsc", helper)])
        ,("split-directories", simple, entry "Main.hs" (primary <> " " <> support) "Fixture.Helper", [mainFile, (support <> "/Fixture/Helper.hs", helper)])
        ,("parent-directory", simple, entry "Main.hs" (primary <> "/..") "", [mainFile])
        ,("custom-build", "build-type: Custom\n" <> setup, entry "Main.hs" primary "", [mainFile])
        ,("configure-build", "build-type: Configure\n", entry "Main.hs" primary "", [mainFile])
        ,("hooks-build", "build-type: Hooks\n" <> setup, entry "Main.hs" primary "", [mainFile])
        ,("custom-setup", simple <> setup, entry "Main.hs" primary "", [mainFile])
        ,("implicit-custom-setup", setup, entry "Main.hs" primary "", [mainFile])
        ,("library-interface", simple, "    type: detailed-0.9\n    test-module: Library.Tests\n    hs-source-dirs: " <> primary <> "\n", [mainFile])
        ,("external-import", simple, entry "Main.hs" primary "", [imported "import Data.List (sort)"])
        ,("comment-import", simple, entry "Main.hs" primary "", [imported "{- import Product.Subject -}"])
        ,("literal-import", simple, entry "Main.hs" primary "Literal", [mainFile, (primary <> "/Literal.hs", "module Literal where\nvalue = \"import Product.Subject\"\n")])
        ,("import-product", simple, entry "Main.hs" primary "", [imported "import Product.Subject"])
        ,("import-qualified", simple, entry "Main.hs" primary "", [imported "import qualified Product.Subject"])
        ,("import-postqualified", simple, entry "Main.hs" primary "", [imported "import Product.Subject qualified"])
        ,("import-package", simple, entry "Main.hs" primary "", [(primary <> "/Main.hs", "{-# LANGUAGE PackageImports #-}\nmodule Main where\nimport \"amoebius\" Product.Subject\nmain = pure ()\n")])
        ,("import-source", simple, entry "Main.hs" primary "", [imported "import {-# SOURCE #-} Product.Subject"])
        ,("import-alias", simple, entry "Main.hs" primary "", [imported "import Product.Subject as Harmless"])
        ,("helper-product", simple, entry "Main.hs" primary "Fixture.Helper", [imported "import Fixture.Helper", (primary <> "/Fixture/Helper.hs", "module Fixture.Helper where\nimport Product.Subject\nvalue = True\n")])
        ,("shadow-product", simple, entry "Main.hs" primary "Product.Subject", [mainFile, (primary <> "/Product/Subject.hs", "module Product.Subject where\nvalue = True\n")])
        ,("malformed-module", simple, entry "Main.hs" primary "", [(primary <> "/Main.hs", "module Main where\nmain = (\n")])
        ,("implicit-main", simple, entry "Main.hs" primary "", [(primary <> "/Main.hs", "main :: IO ()\nmain = pure ()\n")])
        ,("wrong-entry-name", simple, entry "Main.hs" primary "", [(primary <> "/Main.hs", "module Alternative where\nmain = pure ()\n")])
        ,("wrong-helper-name", simple, entry "Main.hs" primary "Fixture.Helper", [mainFile, (primary <> "/Fixture/Helper.hs", "module Different where\nvalue = True\n")])
        ,("unlisted-helper", simple, entry "Main.hs" primary "", [mainFile, (primary <> "/Fixture/Helper.hs", helper)])
        ,("duplicate-helper", simple, entry "Main.hs" (primary <> " " <> support) "Fixture.Helper", [mainFile, (primary <> "/Fixture/Helper.hs", helper), (support <> "/Fixture/Helper.hs", helper)])
        ,("duplicate-entry", simple, entry "Main.hs" (primary <> " " <> support) "", [mainFile, (support <> "/Main.hs", mainSource)])
        ,("module-path-spoof", simple, entry "Main.hs" primary "Fixture.Helper", [mainFile, (primary <> "/Helper.hs", helper)])
        ,("helper-external", simple, entry "Main.hs" primary "Fixture.Helper", [imported "import Fixture.Helper", (primary <> "/Fixture/Helper.hs", "module Fixture.Helper where\nimport Data.List (sort)\nvalue = True\n")])]
  forM cases $ \(name, policy, body, files) -> do
    let root = output </> "oracle-input" </> Text.unpack name
        package = "cabal-version: 3.16\nname: amoebius\nversion: 0.1.0.0\n" <> policy
          <> "\nlibrary subject\n    exposed-modules: Product.Subject\n    hs-source-dirs: src\n    build-depends: base\n    default-language: GHC2024\n"
          <> "\ntest-suite oracle-fixture\n" <> body <> "    build-depends: base\n    default-language: GHC2024\n"
    forM_ files $ \(path, contents) -> do
      let destination = root </> Text.unpack path
      createDirectoryIfMissing True (takeDirectory destination)
      TextIO.writeFile destination contents
    graph <- either (fail . show) pure (parsePackageGraph (TextEncoding.encodeUtf8 package))
    problems <- verifyOracle root graph (OracleExecutable "oracle-fixture")
    pure [name, Text.replace (Text.pack root <> "/") "" (Text.intercalate "," (map renderSpecProblem problems))]

-- Exercise the public hygiene reader against copied real oracle modules, with
-- exact native syntax changes and ordinary quoted/comment counterparts.
oracleHygieneRows :: FilePath -> IO [[Text]]
oracleHygieneRows output = do
  modules <- haskellFilesUnder "." "test/oracle/runner"
  base <- TextIO.readFile "test/oracle/runner/Portability.hs"
  let package = Text.replace "hs-source-dirs: test/oracle/dsl\n" ("hs-source-dirs: test/oracle/dsl\n    other-modules: "
        <> Text.unwords [Text.pack (takeBaseName path) | path <- modules, takeBaseName path /= "Main"] <> "\n") fixtureCabal
  graph <- either (fail . show) pure (parsePackageGraph (TextEncoding.encodeUtf8 package))
  let controls = [("baseline", "", ""), ("comment", "{-\n{-# LANGUAGE TemplateHaskell, CPP #-}\n$(bad)\nforeign import ccall\n-}\n", "")
        ,("quoted-language", "", "\nexampleSyntax = \"{-# LANGUAGE TemplateHaskell, CPP #-}\"\n")
        ,("quoted-foreign", "", "\nexampleSyntax = \"foreign import ccall\"\n")
        ,("operator", "", "\nexampleSyntax = id $ (())\n")
        ,("cpp-pragma", "{-# LANGUAGE OverloadedStrings, CPP #-}\n", "")
        ,("compact-cpp", "{-#LANGUAGE CPP#-}\n", "")
        ,("cpp-directive", "", "\n#if FEATURE\nexampleSyntax = ()\n#endif\n")
        ,("tab-cpp", "", "\n\t#if FEATURE\nexampleSyntax = ()\n\t#endif\n")
        ,("th-pragma", "{-# LANGUAGE TemplateHaskell #-}\n", "")
        ,("th-quotes", "{-# LANGUAGE TemplateHaskellQuotes #-}\n", "")
        ,("splice", "", "\nexampleSyntax = $(bad)\n")
        ,("typed-splice", "", "\nexampleSyntax = $$(bad)\n")
        ,("quote", "", "\nexampleSyntax = [| () |]\n")
        ,("name-quote", "", "\nexampleSyntax = 'id\n")
        ,("constructor-quote", "", "\nexampleSyntax = 'Just\n")
        ,("operator-quote", "", "\nexampleSyntax = '(+)\n")
        ,("type-name-quote", "", "\nexampleSyntax = ''Int\n")
        ,("promoted-type", "", "\nexampleSyntax :: proxy 'True\nexampleSyntax = undefined\n")
        ,("promoted-list", "", "\nexampleSyntax :: proxy '[True, False]\nexampleSyntax = undefined\n")
        ,("typed-quote", "", "\nexampleSyntax = [|| () ||]\n")
        ,("pattern-quote", "", "\nexampleSyntax = [p| () |]\n")
        ,("declaration-quote", "", "\nexampleSyntax = [d| x = () |]\n")
        ,("type-quote", "", "\nexampleSyntax = [t| Int |]\n")
        ,("quasiquote", "{-# LANGUAGE QuasiQuotes #-}\n", "\nexampleSyntax = [r| data |]\n")
        ,("foreign-comment", "", "\nforeign {- gap -} import ccall \"foo\" foo :: IO ()\n")
        ,("foreign-export", "", "\nforeign export ccall foo :: IO ()\n")
        ,("options", "{-# OPTIONS_GHC -fplugin=Missing.Plugin #-}\n", "")
        ,("malformed", "", "\nexampleSyntax = \"unclosed\n")
        ,("multiline-data", "{-# LANGUAGE MultilineStrings #-}\n", "\nexampleSyntax = \"\"\"\n#if FEATURE\n$(literal)\nforeign import ccall\n\"\"\"\n")]
      problemPath problem = case problem of
        OracleConditionalCompilation path -> path
        OracleTemplateHaskell path -> path
        OracleForeignImport path -> path
        OracleSourceUnscanned path -> path
        _ -> ""
  mapM (\(name, prefix, suffix) -> do
    let root = output </> "oracle-syntax" </> Text.unpack name
        destination = root </> "test/oracle/dsl"
    createDirectoryIfMissing True destination
    mapM_ (\path -> do
      bytes <- ByteString.readFile path
      ByteString.writeFile (destination </> takeBaseName path <> ".hs") bytes) modules
    TextIO.writeFile (destination </> "Portability.hs") (prefix <> base <> suffix)
    problems <- verifyOracle root graph (OracleExecutable "oracle-dsl")
    pure ["oracle-syntax", name, Text.pack (show [(Text.takeWhile (/= ':') (renderSpecProblem problem),
      intercalate "/" (splitDirectories (makeRelative root (problemPath problem)))) | problem <- problems])]) controls

fixtureModule :: Text
fixtureModule =
  Text.unlines
    [ "module Amoebius.Dsl.Fixture (limit, fits, pick, record, items) where"
    , ""
    , "import Data.List (sort)"
    , ""
    , "limit :: Int"
    , "limit = 3"
    , ""
    , "fits :: Int -> Bool"
    , "fits n = n < limit"
    , ""
    , "pick :: Int -> Int"
    , "pick n = if n == 0 then 1 else 2"
    , ""
    , "record :: Record"
    , "record ="
    , "  Record"
    , "    { alpha = 1"
    , "    , beta = 2"
    , "    }"
    , ""
    , "items :: [Int]"
    , "items = [1, 2, 3]"
    ]

operatorRows :: FilePath -> IO [[Text]]
operatorRows output = do
  let allLoci = [(operator, enumerateLoci "Amoebius.Dsl.Fixture" "src/Amoebius/Dsl/Fixture.hs" operator fixtureModule) | operator <- allOperators]
      lociRows = [["loci", renderOperator operator, Text.pack (show (length loci)), Text.intercalate "," (map (Text.pack . show . locusLine) loci)] | (operator, loci) <- allLoci]
      pool = concatMap snd allLoci
      sampleA = sampleLoci "seed-a" 4 pool
      sampleB = sampleLoci "seed-a" 4 pool
      sampleC = sampleLoci "seed-b" 4 pool
      render sample = Text.intercalate "," [Text.pack (show (locusLine locus)) <> ":" <> renderOperator (locusOperator locus) | locus <- sample]
      stringCases =
        [ ("plain", "label = \"linux-cpu\"")
        , ("empty", "label = \"\"")
        , ("escaped", "label = \"say \\\"hi\\\"\"")
        , ("unicode", "label = \"λ\"")
        , ("character-before-string", "quote = '\"'; label = \"cpu\"")
        , ("character-only", "quote = '\"'")
        , ("comment", "-- label = \"cpu\"")
        , ("inline-comment", "label = name -- \"cpu\"")
        , ("block-comment", "label = name {- \"cpu\" -}")
        , ("unterminated", "label = \"cpu")
        , ("integer-priority", "limit = 3; label = \"cpu\"")
        , ("boolean-priority", "flag = True; label = \"cpu\"")
        , ("import", "import \"package\" Module")
        ]
      stringRows = [["string", name, Text.intercalate "|" (map locusAfter (enumerateLoci "Amoebius.Dsl.Fixture" "src/Amoebius/Dsl/Fixture.hs" ConstantFlip source))] | (name, source) <- stringCases]
  let copyRoot = output </> "fixture-copy"
  createDirectoryIfMissing True (copyRoot </> "src/Amoebius/Dsl")
  TextIO.writeFile (copyRoot </> "src/Amoebius/Dsl/Fixture.hs") fixtureModule
  applied <- case [locus | locus <- pool, locusOperator locus == ConstantFlip, locusLine locus == 6] of
    (locus : _) -> do
      result <- applyLocus copyRoot locus
      rewritten <- TextIO.readFile (copyRoot </> "src/Amoebius/Dsl/Fixture.hs")
      pure
        [ ["apply", "witness", either id (\w -> if witnessBeforeDigest w /= witnessAfterDigest w then "changed" else "unchanged") result]
        , ["apply", "line-6", Text.strip (Text.lines rewritten !! 5)]
        ]
    [] -> pure [["apply", "witness", "no-locus"]]
  stale <- case [locus | locus <- pool, locusOperator locus == ConstantFlip, locusLine locus == 6] of
    (locus : _) -> do
      result <- applyLocus copyRoot locus
      pure [["apply", "stale-locus", either (const "refused") (const "applied") result]]
    [] -> pure []
  let laneFile = "src/capacity-topology/Amoebius/Topology/Lanes.hs"
      laneRoot = output </> "lane-copy"
  laneSource <- TextIO.readFile laneFile
  let laneLoci = enumerateLoci "Amoebius.Topology.Lanes" laneFile ConstantFlip laneSource
  createDirectoryIfMissing True (laneRoot </> "src/capacity-topology/Amoebius/Topology")
  TextIO.writeFile (laneRoot </> laneFile) laneSource
  laneApplied <- case laneLoci of
    locus : _ -> do
      changed <- applyLocus laneRoot locus
      pure (either id (\w -> if witnessBeforeDigest w /= witnessAfterDigest w then "changed" else "unchanged") changed)
    [] -> pure "no-locus"
  pure
    ( lociRows
        <> [ ["sample", "deterministic", if render sampleA == render sampleB then "equal" else "differs"]
           , ["sample", "seed-sensitive", if render sampleA /= render sampleC then "differs" else "equal"]
           , ["sample", "size", Text.pack (show (length sampleA))]
           , ["sample", "cap", Text.pack (show (length (sampleLoci "seed-a" 100 pool)))]
           , ["sample", "fixed-a", render sampleA]
           , ["sample", "fixed-b", render sampleC]
           ]
        <> applied
        <> stale
        <> stringRows
        <> [["string", "shipped-lanes-loci", Text.intercalate "," (map (Text.pack . show . locusLine) laneLoci)]
           , ["string", "shipped-lanes-witness", laneApplied]]
    )

killRows' :: IO [[Text]]
killRows' = do
  let locus n = Locus "Amoebius.Dsl.Fixture" "src/Amoebius/Dsl/Fixture.hs" n ConstantFlip "a" "b"
      table =
        killTable
          [ (locus 1, Nothing, Killed "lower")
          , (locus 2, Nothing, Killed "lower")
          , (locus 3, Nothing, Killed "encode")
          , (locus 4, Nothing, Survived)
          , (locus 5, Nothing, Stillborn "parse error")
          , (locus 6, Nothing, Stillborn "type error")
          , (locus 7, Nothing, Unapplied "line mismatch")
          ]
  pure
    [ ["kill", "killed", Text.pack (show (killedCount table))]
    , ["kill", "viable", Text.pack (show (viableCount table))]
    , ["kill", "stillborn", Text.pack (show (stillbornCount table))]
    , ["kill", "ratio", Text.pack (show (killRatioObserved table))]
    , ["kill", "rows", Text.pack (show (length (renderKillTable table)))]
    , ["attribution", "owned-red", Text.pack (show (isAttributed [("M", "a.")] "M" ["a.x", "b.y"]))]
    , ["attribution", "unowned-red", Text.pack (show (isAttributed [("M", "a.")] "M" ["b.y"]))]
    , ["attribution", "no-policy", Text.pack (show (isAttributed [("N", "a.")] "M" ["b.y"]))]
    , ["attribution", "empty-ledger", Text.pack (show (isAttributed [("M", "a.")] "M" []))]
    ]

hygieneRows :: FilePath -> IO [[Text]]
hygieneRows output = do
  let root = output </> "fixture-tree"
  createDirectoryIfMissing True (root </> "src/validation-kernel/Amoebius/Validation/FooRun")
  createDirectoryIfMissing True (root </> "src/gate-spec")
  createDirectoryIfMissing True (root </> "src/doc-check")
  createDirectoryIfMissing True (root </> "src/product")
  TextIO.writeFile (root </> "src/validation-kernel/Amoebius/Validation/Core.hs") "module Core where\n#if defined(X)\nx = 1\n#endif\ny = \"phase-03\"\ncanonicalPhaseIdentities :: Int\ncanonicalPhaseIdentities = 1\n"
  TextIO.writeFile (root </> "src/validation-kernel/Amoebius/Validation/FooRun/Internal.hs") "module FooRun.Internal where\nz = 2\n"
  TextIO.writeFile (root </> "src/gate-spec/Spec.hs") "module Spec where\ndata Substrate = A | B\n"
  TextIO.writeFile (root </> "src/validation-kernel/Amoebius/Validation/Vocab.hs") "module Vocab where\ndata Substrate = E | F\n"
  TextIO.writeFile (root </> "src/product/Vocabulary.hs") "module Vocabulary where\ndata Substrate = C | D\n"
  TextIO.writeFile (root </> "src/doc-check/Check.hs") "module Check where\nw = 3\n"
  report <- hygieneRow root (Just 5) 7000
  clean <- do
    let cleanRoot = output </> "fixture-tree-clean"
    createDirectoryIfMissing True (cleanRoot </> "src/validation-kernel")
    TextIO.writeFile (cleanRoot </> "src/validation-kernel/Core.hs") "module Core where\nx = 1\n"
    hygieneRow cleanRoot Nothing 7000
  realExists <- doesDirectoryExist "src/validation-kernel"
  real <- if realExists then Just <$> hygieneRow "." Nothing 7000 else pure Nothing
  pure
    ( [ ["hygiene", "fixture.kernel-lines", Text.pack (show (hygieneKernelLines report))]
      , ["hygiene", "fixture.cap", Text.pack (show (hygieneKernelCap report))]
      , ["hygiene", "fixture.cpp", Text.pack (show (length (hygieneConditionalCompilation report)))]
      , ["hygiene", "fixture.run-modules", Text.pack (show (hygieneRunModules report))]
      , ["hygiene", "fixture.phase-literals", Text.pack (show (length (hygienePhaseLiterals report)))]
      , ["hygiene", "fixture.phase-tables", Text.pack (show (length (hygienePhaseTables report)))]
      , ["hygiene", "fixture.duplicates", Text.intercalate "," (map fst (hygieneDuplicateVocabulary report))]
      , ["hygiene", "fixture.product-duplicates", Text.intercalate "," (map fst (hygieneProductDuplicateVocabulary report))]
      , ["hygiene", "fixture.problems", Text.pack (show (length (hygieneProblems report)))]
      , ["hygiene", "clean.green", Text.pack (show (hygieneGreen clean))]
      , ["hygiene", "clean.cap", Text.pack (show (hygieneKernelCap clean))]
      , ["hygiene", "vocabulary", Text.intercalate "," (sort vocabularyTypes)]
      ]
        <> maybe [] (\r -> [["hygiene", "real.kernel-lines", Text.pack (show (hygieneKernelLines r))], ["hygiene", "real.green", Text.pack (show (hygieneGreen r))], ["hygiene", "real.doc-check-lines", Text.pack (show (hygieneDocCheckLines r))]]) real
    )

-- A missing legacy analyzer must stop the real entry point before any subject
-- transport runs. The deliberately absent Cabal path cannot supply evidence.
legacyRows :: FilePath -> IO [[Text]]
legacyRows output = do
  root <- makeAbsolute (output </> "fixture-package")
  TextIO.writeFile (root </> "amoebius.cabal") canonicalSpineFixture
  hygiene <- hygieneRow root Nothing 7000
  let ready = ["legacy", "clean-hygiene", Text.pack (show (hygieneGreen hygiene))]
  case canonicalSpine of
    Just (phase, spec) -> do
      rows <- mapM (\(name, enabled, candidateOrdinal) -> do
        let runRoot = root </> ".build" </> "runs" </> Text.unpack name
            config = (defaultRunnerConfig root candidateOrdinal)
              { runnerRunRoot = runRoot, runnerCabal = root </> "must-not-run-cabal"
              , runnerMutantLimit = Just 0, runnerHygienePreflight = enabled }
        result <- runGate config spec
        created <- doesDirectoryExist runRoot
        let observed = either renderRefusal (\outcome -> "captured:" <> Text.intercalate ","
              [renderVerdict (rowVerdict row) | row <- candidateRows (outcomeCandidate outcome), rowCategory row == LegacyClosure]) result
        pure [["legacy", name, observed], ["legacy", name <> ".run-root", Text.pack (show created)]])
        [("required-evidence", True, phase), ("preflight-disabled", False, phase),
         ("unknown-phase", True, Identity.phaseDomainUpperOrdinal + 1)]
      pure (ready : concat rows)
    _ -> pure [ready, ["legacy", "contract", "unavailable"]]

-- Native entry points must preserve stale work and refuse an occupied candidate
-- before any subject transport. Missing analyzers remain explicit on the fresh
-- counterpart; these observations cannot supply a numbered gate result.
freshnessRows :: FilePath -> IO [[Text]]
freshnessRows output = do
  root <- makeAbsolute (output </> "fixture-package")
  case canonicalSpine of
    Just (phase, spec) -> do
      let directory = root </> ".build/runs/stale-dir"
          file = root </> ".build/runs/stale-file"
          absent = root </> ".build/runs/absent-candidate"
          candidate path = (defaultRunnerConfig root phase) {runnerRunRoot = path, runnerCabal = root </> "must-not-run-cabal"}
          observed = either (\refusal -> case refusal of
            RunRootNotFresh path -> "RUN-ROOT-NOT-FRESH:" <> Text.pack (intercalate "/" (splitDirectories (makeRelative root path)))
            _ -> renderRefusal refusal) (const "captured")
          row key value = ["fresh", key, value]
      createDirectoryIfMissing True directory
      TextIO.writeFile (directory </> "sentinel") "keep stale work\n"
      TextIO.writeFile file "keep stale file\n"
      occupiedDirectory <- observed <$> runGate (candidate directory) spec
      directoryBytes <- TextIO.readFile (directory </> "sentinel")
      occupiedFile <- observed <$> runGate (candidate file) spec
      fileBytes <- TextIO.readFile file
      fresh <- observed <$> runGate (candidate absent) spec
      created <- doesPathExist absent
      let config = defaultCustodyConfig root
          parent = runnerRunRoot (defaultRunnerConfig root phase)
      createDirectoryIfMissing True parent
      TextIO.writeFile (parent </> "sentinel") "keep stale work\n"
      custody <- observed <$> runFresh config phase spec Nothing
      retained <- doesFileExist (parent </> "sentinel")
      retainedBytes <- if retained then TextIO.readFile (parent </> "sentinel") else pure "absent"
      parentExists <- doesDirectoryExist parent
      entries <- if parentExists then sort <$> listDirectory parent else pure []
      pure [row "directory-refusal" occupiedDirectory, row "directory-sentinel" (Text.pack (show directoryBytes))
        ,row "file-refusal" occupiedFile, row "file-bytes" (Text.pack (show fileBytes))
        ,row "absent-refusal" fresh, row "absent-created" (Text.pack (show created))
        ,row "custody-refusal" custody, row "custody-sentinel" (Text.pack (show retainedBytes))
        ,row "custody-entries" (Text.pack (show entries))]
    _ -> pure [["fresh", "contract", "unavailable"]]

legacyInventoryRows :: IO [[Text]]
legacyInventoryRows = pure $
  [ [tag, Legacy.renderLegacyId (Legacy.legacyRequirementId requirement), owner,
      Legacy.renderLegacyLifecycle (Legacy.legacyRequirementLifecycle requirement),
      Legacy.renderLegacyScope (Legacy.legacyRequirementScope requirement),
      Legacy.renderLegacyAnalyzerKey (Legacy.legacyRequirementAnalyzer requirement),
      Text.intercalate "," (map Legacy.renderLegacyCaseKey (NonEmpty.toList (Legacy.legacyRequirementCases requirement)))]
  | (tag, requirement) <- [("legacy-inventory", requirement) | requirement <- Legacy.legacyRequirements]
      <> [("legacy-bootstrap", Legacy.legacyBootstrapSourceRequirement)]
  , let owner = case Legacy.legacyRequirementOwner requirement of
          Legacy.PhaseOwner capability -> capability
          Legacy.LaterPhasesTrack -> "later-phases"
  ]
  <> [["legacy-supported", Legacy.renderLegacyId (Legacy.legacyRequirementId requirement),
       Legacy.renderLegacyScope (Legacy.legacyRequirementScope requirement), Text.pack (show (Analyzers.legacyQualificationSupported requirement))]
      | requirement <- Analyzers.legacyRequirementsAt Identity.phaseDomainLowerOrdinal]

captureRows :: IO [[Text]]
captureRows = do
  let green = Candidate 3 "typed_spine" "d" "n" "c" "" [CandidateRow category Green [("k", "v")] | category <- allGateCategories]
      oneRed = green {candidateRows = [CandidateRow category (if category == Mutants then Red else Green) [("k", "v")] | category <- allGateCategories]}
      emptyObservation = green {candidateRows = [CandidateRow category Green [] | category <- allGateCategories]}
      reordered = green {candidateRows = reverse (candidateRows green)}
  pure
    [ ["capture", "all-green", Text.pack (show (candidateGreen green))]
    , ["capture", "one-red", Text.pack (show (candidateGreen oneRed))]
    , ["capture", "empty-observation", Text.pack (show (candidateGreen emptyObservation))]
    , ["capture", "reordered", Text.pack (show (candidateGreen reordered))]
    , ["capture", "rows", Text.pack (show (length (Text.lines (renderCandidate green))))]
    , ["capture", "categories", Text.pack (show (Map.size (Map.fromList [(renderGateCategory c, ()) | c <- allGateCategories])))]
    ]

-- * Custody

cleanFacts :: GateSpec -> PreflightFacts
cleanFacts spec =
  PreflightFacts
    { factsSpec = spec
    , factsSurfaceDigest = "surface"
    , factsAcceptedPostimage = Just "surface"
    , factsSurfaceConsistent = True
    , factsPredecessorCommitted = Just True
    , factsDoneWithoutReceipt = []
    , factsPredecessorsNotReproduced = []
    , factsFrozenFindings = []
    , factsBarrierReceipt = False
    , factsHost = HostFacts [HardwareFree, LinuxCpu]
    , factsHygieneProblems = []
    , factsPreviousSpec = Nothing
    }

preflightRows :: IO [[Text]]
preflightRows = case (mkGateSpec OrdinaryGate legalInput, mkGateSpec HardwareGate legalInput {inputSubstrate = LinuxCpu}, mkGateSpec OrdinaryGate legalInput {inputCases = take 1 (inputCases legalInput)}) of
  (Right spec, Right hardware, Right weaker) ->
    let clean = cleanFacts spec
        row name facts = ["preflight", name, Text.intercalate "," (map (Text.takeWhile (/= ':') . renderPreflightRefusal) (preflight facts))]
     in pure
          [ row "clean" clean
          , row "status-surface-dirty" clean {factsSurfaceDigest = "other"}
          , row "predecessor-not-committed" clean {factsPredecessorCommitted = Just False}
          , row "status-without-receipt" clean {factsDoneWithoutReceipt = [1]}
          , row "predecessor-not-reproduced" clean {factsPredecessorsNotReproduced = [0]}
          , row "frozen-finding" clean {factsFrozenFindings = ["DOC-FROZEN-BODY-CHANGED"]}
          , row "hardware-before-barrier" (cleanFacts hardware) {factsBarrierReceipt = False}
          , row "hardware-after-barrier" (cleanFacts hardware) {factsBarrierReceipt = True}
          , row "substrate-absent" (cleanFacts hardware) {factsBarrierReceipt = True, factsHost = HostFacts [HardwareFree, Apple]}
          , row "kernel-over-budget" clean {factsHygieneProblems = ["KernelOverBudget: 15000 lines against a cap of 14000"]}
          , row "spec-weakened" (cleanFacts weaker) {factsPreviousSpec = Just spec}
          , row "spec-unchanged" clean {factsPreviousSpec = Just spec}
          , row "first-run" clean {factsAcceptedPostimage = Nothing, factsPredecessorCommitted = Nothing}
          , ["preflight", "weakened-detail", Text.intercalate ";" (specWeakened spec weaker)]
          ]
  _ -> pure [["preflight", "fixtures", "refused"]]

storeRows :: FilePath -> IO [[Text]]
storeRows output = do
  let store = Store (output </> "fixture-store")
  createDirectoryIfMissing True (storeRoot store)
  let seed = SeedRecord "abc123" "accept phase 0" "abc123" "gov" "surface" "commit" "now"
      receipt = Receipt 0 "documentation_suite" "abc123" "spec" "rendered\nspec" "cand" "kill" "closure" "repro" "abc123" "gov" "post" "commit" ["w1", "w2"] Nothing Nothing "2026-09-18 00:00:01 UTC"
      resetReceipt = receipt {receiptResetCause = Just ("gap", "LTD-DSL-001"), receiptIssuedAt = "2026-09-18 00:00:00 UTC"}
      receiptPath = storeRoot store </> "pass.tsv"
      resetPath = storeRoot store </> "reset.tsv"
  wroteSeed <- writeSeed store seed
  wroteReceipt <- writeRecord receiptPath (renderReceipt receipt)
  wroteReset <- writeRecord resetPath (renderReceipt resetReceipt)
  readBack <- readSeed store "abc123"
  passBack <- fmap (>>= parseReceipt) (readRecord receiptPath)
  resetBack <- fmap (>>= parseReceipt) (readRecord resetPath)
  latest <- latestGeneration store "abc123"
  other <- latestGeneration store "zzz"
  -- corrupt the receipt payload and read again
  original <- TextIO.readFile receiptPath
  TextIO.writeFile receiptPath (Text.replace "documentation_suite" "documentation_suitx" original)
  tampered <- fmap (>>= parseReceipt) (readRecord receiptPath)
  corrupted <- readRecord receiptPath
  TextIO.writeFile receiptPath original
  restored <- fmap (>>= parseReceipt) (readRecord receiptPath)
  pure
    [ ["store", "write-seed", either id (const "ok") wroteSeed]
    , ["store", "write-receipt", either id (const "ok") wroteReceipt]
    , ["store", "seed-roundtrip", either id (\s -> if s == seed then "equal" else "differs") readBack]
    , ["store", "receipt-roundtrip", if passBack == Right receipt then "equal" else "differs"]
    , ["store", "reset-receipt", either id (const (if resetBack == Right resetReceipt && passBack == Right receipt then "kept-beside-pass" else "lost")) wroteReset]
    , ["store", "latest-generation", maybe "absent" seedEnteredBy latest]
    , ["store", "other-generation", maybe "absent" seedEnteredBy other]
    , ["store", "tampered-receipt", either (Text.takeWhile (/= ':')) (const "accepted") tampered]
    , ["store", "corrupted-record", either (Text.takeWhile (/= ':')) (const "accepted") corrupted]
    , ["store", "restored-receipt", if restored == Right receipt then "equal" else "differs"]
    , ["store", "generation-directory", Text.pack (generationDirectory (Store "/s") "abcdef0123456789zzzz")]
    ]

-- The tracked archive is tested separately from the disposable generation store.
-- Every refusal is observed through the archive reader, not by inspecting the
-- written fixture path or accepting the writer's claim.
archiveRows :: FilePath -> IO [[Text]]
archiveRows output = do
  let root = output </> "fixture-archive"
      generation = Text.replicate 64 "a"
      candidate = Text.unlines ["candidate\tphase=0\tcapability=documentation_suite", "spec-digest\tspec", "row\tgreen"]
      killTable = "mutant\tkilled\n"
      evidence =
        [ ("candidate.tsv", candidate)
        , ("kill-table.tsv", killTable)
        , ("outcome.tsv", "green\tTrue\n")
        , ("oracle-ledger.tsv", "clean\tgreen\n")
        , ("observer.tsv", "run\texit-success\n")
        ]
      receipt = Receipt 0 "documentation_suite" generation "spec" "rendered\nspec"
        (sha256Hex candidate) (sha256Hex killTable) "closure" (Text.replicate 64 "b")
        generation "governance" (Text.replicate 64 "c") "commit" ["w1"] Nothing Nothing "2026-09-23 00:00:00 UTC"
      bundle = archivedBundlePath root receipt evidence
      changedEvidence = [(name, if name == "outcome.tsv" then "green\tTrue\nrun\tsecond\n" else body) | (name, body) <- evidence]
      secondReceipt = receipt {receiptIssuedAt = "2026-09-23 00:00:01 UTC"}
      refusal result = either (Text.takeWhile (/= ':')) (const "accepted") result
  exists <- doesDirectoryExist root
  if exists then removePathForcibly root else pure ()
  written <- writeArchivedReceipt root receipt evidence
  case written of
    Left problem -> pure [["archive", "write", "refused: " <> problem]]
    Right published | published /= bundle -> pure [["archive", "write", "wrong-path"]]
    Right published -> do
      firstRead <- readArchivedBundles root generation
      repeated <- writeArchivedReceipt root receipt evidence
      let observer = bundle </> "observer.tsv"
          candidatePath = bundle </> "candidate.tsv"
      TextIO.writeFile candidatePath "candidate\tchanged\n"
      tampered <- readArchivedBundles root generation
      TextIO.writeFile candidatePath candidate
      removeFile observer
      missing <- readArchivedBundles root generation
      TextIO.writeFile observer "run\texit-success\n"
      queries <- newIORef []
      linked <- readArchivedBundlesWith (\paths -> modifyIORef' queries (<> [paths]) >> pure (observer `elem` paths)) root generation
      trace <- readIORef queries
      rootLinked <- readArchivedBundlesWith (pure . (root `elem`)) root generation
      bundleLinked <- readArchivedBundlesWith (pure . (== [bundle])) root generation
      restored <- readArchivedBundles root generation
      second <- writeArchivedReceipt root secondReceipt changedEvidence
      twoRuns <- readArchivedBundles root generation
      pure
        [ ["archive", "write", "accepted"]
        , ["archive", "roundtrip", if firstRead == Right [(receipt, bundle)] then "exact" else "different"]
        , ["archive", "repeat", if repeated == written then "same" else "different"]
        , ["archive", "tampered-evidence", refusal tampered]
        , ["archive", "missing-file", refusal missing]
        , ["archive", "symlink", refusal linked]
        , ["archive", "symlink-root", refusal rootLinked]
        , ["archive", "symlink-bundle", refusal bundleLinked]
        , ["archive", "symlink-queries", Text.pack (show (map (map (intercalate "/" . filter (/= ".") . splitDirectories . makeRelative root)) trace))]
        , ["archive", "restored", if restored == Right [(receipt, bundle)] then "exact" else "different"]
        , ["archive", "distinct-run-bundle", case (second, twoRuns) of
            (Right secondPath, Right bundles) | published /= secondPath && length bundles == 2 -> "distinct"
            _ -> "missing"]
        ]

-- A red replay revokes the selected run, while preserving older and later runs.
replayVoidRows :: FilePath -> IO [[Text]]
replayVoidRows output = do
  let root = output </> "fixture-void"
      generation = Text.replicate 64 "d"
      candidate = Text.unlines ["candidate\tphase=0\tcapability=documentation_suite", "spec-digest\tspec", "row\tgreen"]
      killTable = "mutant\tkilled\n"
      evidence attempt = [("candidate.tsv", candidate), ("kill-table.tsv", killTable), ("outcome.tsv", "green\tTrue\nattempt\t" <> attempt <> "\n"), ("oracle-ledger.tsv", "clean\tgreen\n"), ("observer.tsv", "run\texit-success\n")]
      receipt = Receipt 0 "documentation_suite" generation "spec" "rendered\nspec"
        (sha256Hex candidate) (sha256Hex killTable) "closure" (Text.replicate 64 "b")
        generation "governance" (Text.replicate 64 "c") "commit" [] Nothing Nothing "2026-09-23 00:00:00 UTC"
      newer = receipt {receiptIssuedAt = "2026-09-23 00:00:01 UTC"}
      recovered = receipt {receiptIssuedAt = "2026-09-23 00:00:02 UTC"}
      failure = Text.replicate 64 "e"
  exists <- doesDirectoryExist root
  if exists then removePathForcibly root else pure ()
  old <- writeArchivedReceipt root receipt (evidence "old")
  latest <- writeArchivedReceipt root newer (evidence "newer")
  case (old, latest) of
    (Right oldPath, Right latestPath) -> do
      before <- readCurrentArchivedBundles root generation
      tied <- writeArchivedReceipt root newer (evidence "tied")
      backdated <- writeArchivedReceipt root receipt (evidence "backdated")
      wrongTarget <- writeReplayVoid root receipt latestPath "gate-red" failure "2026-09-23 00:00:03 UTC"
      invalid <- writeReplayVoid root newer latestPath "gate-red" "short" "2026-09-23 00:00:03 UTC"
      voided <- writeReplayVoid root newer latestPath "gate-red" failure "2026-09-23 00:00:03 UTC"
      case voided of
        Left problem -> pure [["void", "setup", "refused: " <> problem]]
        Right voidPath -> do
          repeated <- writeReplayVoid root newer latestPath "gate-red" failure "2026-09-23 00:00:03 UTC"
          after <- readCurrentArchivedBundles root generation
          history <- readArchivedBundles root generation
          original <- TextIO.readFile voidPath
          TextIO.writeFile voidPath (Text.replace "reason\tgate-red" "reason\trunner-refusal" original)
          tampered <- readCurrentArchivedBundles root generation
          TextIO.writeFile voidPath original
          stillVoided <- readCurrentArchivedBundles root generation
          green <- writeArchivedReceipt root recovered (evidence "recovered")
          current <- readCurrentArchivedBundles root generation
          pure
            [ ["void", "setup", "ready"]
            , ["void", "latest-before-red", if before == Right [(newer, latestPath)] && oldPath /= latestPath then "newer" else "wrong"]
            , ["void", "tied-publication", either id (const "accepted") tied]
            , ["void", "backdated-publication", either id (const "accepted") backdated]
            , ["void", "wrong-target", either id (const "accepted") wrongTarget]
            , ["void", "invalid-failure", either id (const "accepted") invalid]
            , ["void", "write", "accepted"]
            , ["void", "repeat", if repeated == voided then "same" else "different"]
            , ["void", "no-fallback", if after == Right [] && stillVoided == Right [] then "blocked" else "fell-back"]
            , ["void", "history-retained", case history of Right bundles | length bundles == 2 -> "two-bundles"; _ -> "missing"]
            , ["void", "tampered", either (Text.takeWhile (/= ':')) (const "accepted") tampered]
            , ["void", "green-recovery", case (green, current) of (Right path, Right [(accepted, selected)]) | accepted == recovered && selected == path -> "later-green"; _ -> "missing"]
            ]
    _ -> pure [["void", "setup", "refused"]]

-- The recorded frontier can still name older verifier generations after an
-- earlier phase has been replayed. Revocation follows those exact references.
crossGenerationVoidRows :: FilePath -> IO [[Text]]
crossGenerationVoidRows output = case take 3 Identity.phaseOrdinals of
  [phase, downstream, unrelated] -> do
    let repository = output </> "fixture-cross-generation-void"
        root = repository </> "validation-records"
        oldGeneration = Text.replicate 64 "d"
        nextGeneration = Text.replicate 64 "e"
        otherGeneration = Text.replicate 64 "a"
        currentVerifier = Text.replicate 64 "f"
        recordedDigest = Text.replicate 64 "b"
        nextDigest = Text.replicate 64 "c"
        differentDigest = Text.replicate 64 "9"
        candidate ordinal = Text.unlines ["candidate\tphase=" <> Text.pack (show ordinal) <> "\tcapability=fixture", "spec-digest\tspec", "row\tgreen"]
        killTable = "mutant\tkilled\n"
        evidence ordinal label = [("candidate.tsv", candidate ordinal), ("kill-table.tsv", killTable), ("outcome.tsv", "green\tTrue\nattempt\t" <> label <> "\n"), ("oracle-ledger.tsv", "clean\tgreen\n"), ("observer.tsv", "run\texit-success\n")]
        receipt ordinal generation digest label issued = Receipt ordinal "fixture" generation "spec" "rendered"
          (sha256Hex (candidate ordinal)) (sha256Hex killTable) "closure" digest generation "governance"
          (Text.replicate 64 "8") "commit" [label] Nothing Nothing issued
        records =
          [ receipt phase oldGeneration recordedDigest "old" "2026-09-23 00:00:00 UTC"
          , receipt phase oldGeneration recordedDigest "newer-same" "2026-09-23 00:00:01 UTC"
          , receipt phase oldGeneration differentDigest "unrecorded-green" "2026-09-23 00:00:02 UTC"
          , receipt downstream nextGeneration nextDigest "downstream" "2026-09-23 00:00:00 UTC"
          , receipt unrelated otherGeneration currentVerifier "unrelated" "2026-09-23 00:00:00 UTC"
          ]
        surface = StatusSurface [] [] [] [(phase, recordedDigest), (downstream, nextDigest), (unrelated, differentDigest)]
        config = defaultCustodyConfig repository
        witnesses result = either id (Text.intercalate "," . concatMap (receiptWitnesses . fst)) result
    exists <- doesDirectoryExist repository
    if exists then removePathForcibly repository else pure ()
    written <- mapM (\record -> writeArchivedReceipt root record (evidence (receiptPhase record) (Text.intercalate "," (receiptWitnesses record)))) records
    case sequence written of
      Left problem -> pure [["crossvoid", "setup", problem]]
      Right _ -> do
        revoked <- voidFromPhase config currentVerifier surface phase "gate-red" "independent oracle refused the observed run"
        oldCurrent <- readCurrentArchivedBundles root oldGeneration
        nextCurrent <- readCurrentArchivedBundles root nextGeneration
        otherCurrent <- readCurrentArchivedBundles root otherGeneration
        history <- mapM (readArchivedBundles root) [oldGeneration, nextGeneration, otherGeneration]
        absent <- voidFromPhase config currentVerifier (StatusSurface [] [] [] []) phase "gate-red" "missing recorded reference"
        pure
          [ ["crossvoid", "targets", either id (Text.pack . show . length) revoked]
          , ["crossvoid", "unrecorded-green", witnesses oldCurrent]
          , ["crossvoid", "downstream", either id (Text.pack . show . length) nextCurrent]
          , ["crossvoid", "unrelated", witnesses otherCurrent]
          , ["crossvoid", "history", either id (Text.pack . show . sum . map length) (sequence history)]
          , ["crossvoid", "missing", either id (const "accepted") absent]
          ]
  _ -> pure [["crossvoid", "setup", "phase inventory is incomplete"]]

-- The public candidate path must refuse an over-budget tree before resolving tools.
kernelRatchetRows :: FilePath -> IO [[Text]]
kernelRatchetRows output = do
  let repository = output </> "fixture-kernel-ratchet"
      phase = Identity.phaseDomainLowerOrdinal
      countRow value = "observation\tLegacy closure\thygiene.kernel-lines\t" <> value
      record root generation observations reset = do
        let candidate = Text.unlines (["candidate\tphase=" <> Text.pack (show phase) <> "\tcapability=fixture", "spec-digest\tspec"] <> observations)
            killed = "mutant\tkilled\n"
            evidence = [("candidate.tsv", candidate), ("kill-table.tsv", killed), ("outcome.tsv", "green\tTrue\n"), ("oracle-ledger.tsv", "clean\tgreen\n"), ("observer.tsv", "run\texit-success\n")]
            receipt = Receipt phase "fixture" generation "spec" "rendered" (sha256Hex candidate) (sha256Hex killed)
              "closure" generation generation "governance" (Text.replicate 64 "8") "commit" [] reset Nothing "2026-10-15 00:00:00 UTC"
        written <- writeArchivedReceipt (root </> "validation-records") receipt evidence
        pure (receipt, written)
      projection result = either id (maybe "none" (Text.pack . show)) result
      row name result = ["ratchet", name, projection result]
  exists <- doesDirectoryExist repository
  if exists then removePathForcibly repository else pure ()
  createDirectoryIfMissing True repository
  empty <- archivedKernelCap repository
  records <- sequence [record repository (Text.replicate 64 generation) [countRow count] Nothing | (generation, count) <- [("a", "12"), ("b", "5"), ("c", "9")]]
  history <- archivedKernelCap repository
  _ <- record repository (Text.replicate 64 "d") [countRow "1"] (Just ("validator gap", "LTD-DSL-001"))
  reset <- archivedKernelCap repository
  case records of
    [_, (receipt, Right path), _] -> do
      _ <- writeReplayVoid (repository </> "validation-records") receipt path "gate-red" (Text.replicate 64 "e") "2026-10-15 00:00:01 UTC"
      pure ()
    _ -> pure ()
  voided <- archivedKernelCap repository
  createDirectoryIfMissing True (repository </> "src/validation-kernel")
  TextIO.writeFile (repository </> "src/validation-kernel/Core.hs") "module Core where\na = 1\nb = 2\nc = 3\nd = 4\ne = 5\n"
  let config = (defaultCustodyConfig repository) {custodyCompiler = Just (repository </> "must-not-run-ghc"), custodyCabal = Just (repository </> "must-not-run-cabal")}
  guarded <- case mkGateSpec OrdinaryGate legalInput of
    Left problems -> pure (Text.pack (show problems))
    Right spec -> either renderRefusal (const "accepted") <$> runFresh config phase spec Nothing
  invalid <- mapM (\(name, observations) -> do
    let root = output </> ("fixture-ratchet-" <> Text.unpack name)
    present <- doesDirectoryExist root
    if present then removePathForcibly root else pure ()
    _ <- record root (Text.replicate 64 "f") observations Nothing
    row name <$> archivedKernelCap root)
    [("missing", []), ("duplicate", [countRow "5", countRow "5"]), ("malformed", [countRow "5oops"]), ("oversized", [countRow "14001"]), ("overflow", [countRow "18446744073709551621"]), ("noncanonical", [countRow "05"])]
  pure ([row "empty" empty, row "history" history, row "reset" reset, row "void" voided, ["ratchet", "command-guard", guarded]] <> invalid)

statusRows :: FilePath -> IO [[Text]]
statusRows output = do
  let copyRoot = output </> "fixture-plan"
  (documents, _, _) <- discoverDocuments "."
  removeAndWrite copyRoot documents
  surface <- statusSurface copyRoot
  case surface of
    Left problem -> pure [["status", "surface", problem]]
    Right recorded -> do
      let frontier = recordedFrontier recorded
          active = case frontier of
            Just f -> [phase | phase <- Identity.phaseOrdinals, Status.phaseStatusAt f phase == Status.ActiveNotValidated]
            Nothing -> []
      case (frontier, active) of
        (Just f, [current]) | Just next <- Status.frontierAfterPass f current -> do
          let digest = Text.replicate 64 "b"
              existing = Map.fromList (surfaceReceipts recorded)
              successor = Identity.successorOrdinal current
          bare <- patchToFrontier copyRoot next existing
          mapM_ (\(path, contents) -> TextIO.writeFile (copyRoot </> path) contents) bare
          blocks <- either (fail . show) pure (compiledBlocks registeredSpecInputs)
          bareResult <- checkTree blocks copyRoot
          patch <- patchToFrontier copyRoot next (Map.insert current digest existing)
          mapM_ (\(path, contents) -> TextIO.writeFile (copyRoot </> path) contents) patch
          after <- statusSurface copyRoot
          result <- checkTree blocks copyRoot
          let statusOf phase s = maybe "absent" id (lookup phase [(p, status) | (p, _, status) <- surfaceTracker s])
              codes r = nubText (map findingCode (checkFindings r))
          pure
            [ ["status", "recorded-frontier", "one-frontier"]
            , ["status", "surface-digest-stable", if surfaceDigest recorded == either (const "") surfaceDigest after then "same" else "changed"]
            , ["status", "patched-files", Text.pack (show (length bare))]
            , ["status", "bare-receipt-missing", Text.pack (show ("PLAN-STATUS-RECEIPT-MISSING" `elem` codes bareResult))]
            , ["status", "receipted-receipt-missing", Text.pack (show ("PLAN-STATUS-RECEIPT-MISSING" `elem` codes result))]
            , ["status", "receipted-structural-findings", Text.intercalate "," (filter (\c -> not ("DOC-HONESTY" `Text.isPrefixOf` c)) (codes result))]
            , ["status", "after-active", either (const "") (statusOf current) after]
            , ["status", "after-successor", either (const "") (\s -> maybe "none" (\n -> statusOf n s) successor) after]
            , ["status", "after-active-sprints", either (const "") (\s -> if and [status == "**Status**: Done" && "✅" `Text.isSuffixOf` heading | (phase, _, _, heading, status) <- surfaceSprints s, phase == current] then "done" else "not-done") after]
            , ["status", "receipt-recorded", either (const "") (\s -> maybe "absent" id (lookup current (surfaceReceipts s))) after]
            , ["status", "receipt-line", either (const "") (\s -> maybe "" (\(_, _, line) -> line) (lookupPhase current (surfacePhaseLines s))) after]
            ]
        _ -> pure [["status", "recorded-frontier", "no-single-active-frontier"]]
 where
  lookupPhase phase entries = case [entry | entry@(p, _, _) <- entries, p == phase] of
    (entry : _) -> Just entry
    [] -> Nothing
  removeAndWrite root documents = mapM_ (\(path, contents) -> do
    createDirectoryIfMissing True (root </> takeDirectoryText path)
    TextIO.writeFile (root </> path) contents) documents
  takeDirectoryText path = reverse (drop 1 (dropWhile (/= '/') (reverse path)))
  nubText = foldr (\item seen -> if item `elem` seen then seen else item : seen) []

-- The public reset command, observed through the complete persisted surface
-- and archive. Fixture creation is Haskell-owned; these are not phase passes.
resetRows :: FilePath -> IO [[Text]]
resetRows output = do
  root <- makeAbsolute (output </> "fixture-reset")
  prepare root
  before <- TextIO.readFile (root </> "DEVELOPMENT_PLAN/README.md")
  result <- resetGeneration (config root) "DL-0013" "legacy analyzer join missing" "LTD-VAL-001"
  after <- statusSurface root
  tracker <- TextIO.readFile (root </> "DEVELOPMENT_PLAN/README.md")
  documents <- mapM (\identity -> do
    contents <- TextIO.readFile (root </> Identity.phaseIdentityPath identity)
    pure ["reset-projection", Text.pack (show (Identity.phaseIdentityOrdinal identity)), Text.pack (show contents)]) Identity.allPhaseIdentities
  archive <- auditArchivedInventory root
  let records = either (const []) snd archive
      resets = [(receipt, path) | (receipt, path) <- records, receiptResetCause receipt /= Nothing]
      field name value = ["reset", name, value]
      cause = case resets of [(receipt, _)] -> maybe "absent" (\(gap, productGap) -> gap <> "|" <> productGap) (receiptResetCause receipt); _ -> "absent"
      bound = case (resets, after) of ([(receipt, _)], Right surface) -> receiptStatusPostimage receipt == surfaceDigest surface; _ -> False
  blocked <- makeAbsolute (output </> "fixture-reset-blocked-archive")
  prepare blocked
  blockedBefore <- statusSurface blocked
  TextIO.writeFile (blocked </> "validation-records") "archive publication is unavailable\n"
  blockedResult <- resetGeneration (config blocked) "DL-0013" "legacy analyzer join missing" "LTD-VAL-001"
  blockedAfter <- statusSurface blocked
  missing <- makeAbsolute (output </> "fixture-reset-missing-document")
  prepare missing
  let missingPath = maybe (error "fixture phase absent") Identity.phaseIdentityPath (Identity.lookupPhaseIdentity Identity.phaseDomainLowerOrdinal)
  removeFile (missing </> missingPath)
  missingBefore <- statusSurface missing
  missingResult <- resetGeneration (config missing) "DL-0013" "legacy analyzer join missing" "LTD-VAL-001"
  missingAfter <- statusSurface missing
  future <- makeAbsolute (output </> "fixture-reset-future-owner")
  prepare future
  futureBefore <- statusSurface future
  futureResult <- resetGeneration (config future) "DL-0013" "future-owner reset must not advance" "LTD-SEED-001"
  futureAfter <- statusSurface future
  refused <- mapM (\(name, decision, gap, productGap) -> do
    target <- makeAbsolute (output </> ("fixture-reset-" <> name))
    prepare target
    original <- statusSurface target
    outcome <- resetGeneration (config target) decision gap productGap
    current <- statusSurface target
    pure [field (Text.pack name <> ".exit") (Text.pack (show (outcomeExit outcome))), field (Text.pack name <> ".reason") (Text.intercalate "|" (outcomeLines outcome)),
      field (Text.pack name <> ".unchanged") (Text.pack (show (original == current)))])
    [("empty-gap", "DL-0013", "", "LTD-VAL-001"),
     ("unknown-decision", "DL-9999", "gap", "LTD-VAL-001"),
     ("unknown-product", "DL-0013", "gap", "LTD-NONE-999"),
     ("unowned-product", "DL-0013", "gap", "LTD-LIB-002")]
  pure ([field "exit" (Text.pack (show (outcomeExit result))), field "tracker-changed" (Text.pack (show (before /= tracker))),
    ["reset-tracker", Text.pack (show tracker)], field "archive-count" (Text.pack (show (length resets))),
    field "cause" cause, field "postimage" (Text.pack (show bound)),
    field "receipts-remaining" (either id (Text.pack . show . length . surfaceReceipts) after),
    field "no-gate-pass" (Text.pack (show (all ((/= Nothing) . receiptResetCause . fst) records))),
    field "blocked-archive.exit" (Text.pack (show (outcomeExit blockedResult))),
    field "blocked-archive.reason" (Text.intercalate "|" (outcomeLines blockedResult)),
    field "blocked-archive.unchanged" (Text.pack (show (blockedBefore == blockedAfter))),
    field "missing-document.exit" (Text.pack (show (outcomeExit missingResult))),
    field "missing-document.reason" (Text.intercalate "|" (outcomeLines missingResult)),
    field "missing-document.unchanged" (Text.pack (show (missingBefore == missingAfter))),
    field "future-owner.exit" (Text.pack (show (outcomeExit futureResult))),
    field "future-owner.unchanged" (Text.pack (show (futureBefore == futureAfter)))] <> documents <> concat refused)
 where
  config root = (defaultCustodyConfig root) {custodyStore = Store (root </> ".build/store")}
  prepare root = do
    createDirectoryIfMissing True (root </> "DEVELOPMENT_PLAN")
    let active = maybe (error "fixture capability absent") id (Identity.lookupCapabilityOrdinal "extension_admission_attested_scope")
        markers phase = if phase < active then ("✅", "Done") else if phase == active then ("🔄", "Active — NOT VALIDATED") else ("⏸️", "Blocked — NOT VALIDATED")
        status phase = let (marker, value) = markers phase in marker <> " " <> value
        tracker = Text.unlines ["| " <> Text.pack (show phase) <> " | fixture | none | none | — | " <> status phase <> " | — |" | phase <- Identity.phaseOrdinals]
    TextIO.writeFile (root </> "DEVELOPMENT_PLAN/README.md") tracker
    mapM_ (\identity -> do
      let phase = Identity.phaseIdentityOrdinal identity
          number = Text.pack (show phase)
          (marker, value) = markers phase
          sprint which = if phase < active then ("✅", "Done") else if phase == active && which == "1" then (marker, value) else ("⏸️", "Blocked — NOT VALIDATED")
          block which = let (sprintMarker, sprintValue) = sprint which in ["## Sprint " <> number <> "." <> which <> ": Fixture " <> sprintMarker, "**Status**: " <> sprintValue, "sentinel-sprint-" <> number <> "." <> which]
          contents = Text.unlines (["# Fixture " <> number, "", "## Phase Status", "", status phase <> "."]
            <> ["**Receipt**: " <> Text.replicate 64 "a" | phase < active]
            <> ["sentinel-body-" <> number] <> block "1" <> block "2")
      TextIO.writeFile (root </> Identity.phaseIdentityPath identity) contents) Identity.allPhaseIdentities

reproducibleRows :: IO [[Text]]
reproducibleRows = do
  let candidate = Candidate 3 "typed_spine" "d" "nonce-1" "chain-1" "" [CandidateRow category Green [("k", "v")] | category <- allGateCategories]
      sameRowsDifferentRun = candidate {candidateChallenge = "nonce-2", candidateChain = "chain-2", candidateRows = [CandidateRow category Green [("k", "other")] | category <- allGateCategories]}
      oneRed = candidate {candidateRows = [CandidateRow category (if category == Mutants then Red else Green) [("k", "v")] | category <- allGateCategories]}
      first = "alpha\tgreen\t/run/one nonce-one"
      second = "omega\tgreen\tobserved"
      transcript = Text.unlines [first, second]
      locus = Locus "Subject" "src/Subject.hs" 7 BranchSwap "before" "after"
      table = killTable [(locus, Nothing, Killed "oracle")]
      parsed = parseLedger (Just ExitSuccess) transcript
      coreUsing spec current exit bytes mutants = reproducibleCore spec current (parseLedger exit bytes) mutants
      core = coreUsing "spec" candidate (Just ExitSuccess) transcript table
      same name observed = ["reproducible", name, if core == observed then "same" else "differs"]
      usual bytes = coreUsing "spec" candidate (Just ExitSuccess) bytes table
      changedMutant mutated = coreUsing "spec" candidate (Just ExitSuccess) transcript (killTable [mutated])
      admission name exit bytes = ["reproducible", name, Text.pack (show (ledgerGreen (parseLedger exit bytes)))]
  pure ([ same "stable-across-runs" (coreUsing "spec" sameRowsDifferentRun (Just ExitSuccess) transcript table)
    , same "verdict-sensitive" (coreUsing "spec" oneRed (Just ExitSuccess) transcript table)
    , same "ledger-sensitive" (usual (Text.replace "alpha" "beta" transcript))
    , same "spec-sensitive" (coreUsing "spec-2" candidate (Just ExitSuccess) transcript table)
    , same "diagnostic-path-independent" (usual (Text.replace "/run/one" "/different/run/two" transcript))
    , same "diagnostic-nonce-independent" (usual (Text.replace "nonce-one" "nonce-two" transcript))
    , same "diagnostic-fields-independent" (usual (Text.unlines ["alpha\tgreen\t", "omega\tgreen\ta\tb\tc"]))
    , same "row-order-independent" (usual (Text.unlines [second, first]))
    , same "ledger-verdict-sensitive" (usual (Text.replace "alpha\tgreen" "alpha\tred" transcript))
    , same "ledger-row-omitted" (usual (first <> "\n"))
    , same "ledger-row-added" (usual (transcript <> "extra\tgreen\tdetail\n"))
    , same "ledger-exit-sensitive" (coreUsing "spec" candidate (Just (ExitFailure 1)) transcript table)
    , same "ledger-missing-exit-sensitive" (coreUsing "spec" candidate Nothing transcript table)
    , same "mutant-outcome-sensitive" (changedMutant (locus, Nothing, Survived))
    , same "mutant-stage-sensitive" (changedMutant (locus, Nothing, Killed "suite"))
    , same "mutant-location-sensitive" (changedMutant (locus {locusLine = 8}, Nothing, Killed "oracle"))
    , same "mutant-operator-sensitive" (changedMutant (locus {locusOperator = ConstantFlip}, Nothing, Killed "oracle"))
    , ["reproducible", "raw-transcript-retained", Text.pack (show (ledgerDigest parsed == sha256Hex transcript
        && ledgerDigest parsed /= ledgerDigest (parseLedger (Just ExitSuccess) (Text.replace "nonce-one" "nonce-two" transcript))))]
    , admission "valid-ledger" (Just ExitSuccess) transcript
    , admission "valid-observation-tabs" (Just ExitSuccess) "alpha\tgreen\ta\tb\n"
    , admission "red-ledger" (Just ExitSuccess) "alpha\tred\tdetail\n"
    , admission "failed-exit" (Just (ExitFailure 1)) transcript
    , admission "missing-exit" Nothing transcript
    ] <> [admission name (Just ExitSuccess) bytes | (name, bytes) <-
      [("empty-ledger", ""), ("blank-line", transcript <> "\n"), ("garbage-line", transcript <> "garbage\n")
      ,("duplicate-row", transcript <> first <> "\n"), ("empty-name", "\tgreen\tdetail\n")
      ,("unknown-verdict", "alpha\tGREEN\tdetail\n"), ("truncated-row", "alpha\tgreen\n")]])

-- * The package description

packageRows :: IO [[Text]]
packageRows = do
  exists <- doesFileExist "amoebius.cabal"
  if not exists
    then pure [["package", "present", "False"]]
    else do
      bytes <- ByteString.readFile "amoebius.cabal"
      contents <- TextIO.readFile "amoebius.cabal"
      let flags = length [() | line <- Text.lines contents, "flag " `Text.isPrefixOf` line]
          executables = [Text.drop 11 line | line <- Text.lines contents, "executable " `Text.isPrefixOf` line]
      pure $ case parsePackageGraph bytes of
        Left problem -> [["package", "parse", renderSpecProblem problem]]
        Right graph ->
          let closure = maybe Set.empty id (executableClosure graph "amoebius")
              validatorStanzas = ["validation-kernel", "validation-runner", "doc-check", "plan-decisions", "gate-spec"]
              leaks = [stanza | stanza <- validatorStanzas, Set.member stanza closure]
              verifier = maybe Set.empty id (executableClosure graph "amoebius-validate")
           in [ ["package", "product-closure-validator-free", Text.pack (show (null leaks))]
              , ["package", "product-closure-size", Text.pack (show (Set.size closure))]
              , ["package", "verifier-links-runner", Text.pack (show (Set.member "validation-runner" verifier))]
              , ["package", "flags", Text.pack (show flags)]
              , ["package", "executables", Text.intercalate "," (sort executables)]
              , ["package", "libraries", Text.pack (show (Map.size (graphLibraries graph)))]
              ]
