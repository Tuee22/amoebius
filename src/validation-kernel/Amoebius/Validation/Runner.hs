{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}
-- | One generic gate runner. Suites and oracles provide observations; only this runner mints verdicts.
module Amoebius.Validation.Runner
  ( GateOutcome (..), PassedGate, RunnerConfig (..), RunnerRefusal (..), compiledBlocks, defaultRunnerConfig, reproducibleCore, Ledger
  , parseLedger, ledgerGreen, ledgerDigest, suiteLedger, renderRefusal, roleFor, runGate, specDigest ) where
import Amoebius.Doc.Check (checkTree, discoverDocuments)
import Amoebius.Doc.Render (Negative (..), negativeCatalogue, renderNegative, writeCorpus)
import Amoebius.Doc.Types (CheckResult (..), Finding (..), Observation (..))
import Amoebius.Plan.Legacy qualified as Legacy
import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.BootstrapQualification.Internal
import "amoebius" Amoebius.Validation.BootstrapPredicate (bootstrapSnapshotMatches)
import Amoebius.Validation.GateSpec
import Amoebius.Validation.GateSpec.Registry (registeredSpecInputs)
import Amoebius.Validation.Runner.Binary
import Amoebius.Validation.Runner.Capture
import Amoebius.Validation.Runner.Hygiene
import Amoebius.Validation.Runner.Legacy qualified as Analyzers
import Amoebius.Validation.Runner.Mutants
import Amoebius.Validation.Runner.Observer
import Amoebius.Validation.Runner.Spec
import Control.Exception (finally)
import Control.Monad (forM)
import Data.Map.Strict qualified as Map
import Data.List (sort, transpose)
import Data.Maybe (isJust, isNothing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, doesPathExist, makeAbsolute, removePathForcibly)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
data RunnerConfig = RunnerConfig
  { runnerRoot :: FilePath, runnerRunRoot :: FilePath, runnerPhase :: Int, runnerCabal :: FilePath
  , runnerLastAcceptedKernelLines :: Maybe Int, runnerDocCheckCap :: Int
  , runnerHygienePreflight :: Bool, runnerPredecessorDigest :: Maybe Text, runnerMutantLimit :: Maybe Int
  , runnerCompiler :: Maybe FilePath, runnerPredecessorGate :: Maybe PassedGate } deriving (Eq, Show)
defaultRunnerConfig :: FilePath -> Int -> RunnerConfig
defaultRunnerConfig root phase = RunnerConfig { runnerRoot = root, runnerRunRoot = root </> ".build" </> "runs" </> ("phase-" <> pad phase)
    , runnerPhase = phase, runnerCabal = "cabal"
    , runnerLastAcceptedKernelLines = Nothing, runnerDocCheckCap = 7000, runnerHygienePreflight = True
    , runnerPredecessorDigest = Nothing, runnerMutantLimit = Nothing, runnerCompiler = Nothing, runnerPredecessorGate = Nothing }
 where pad n = let s = show n in if length s < 2 then '0' : s else s
data RunnerRefusal
  = SpecRefused [SpecProblem]
  | PhaseSpecMismatch [Text]
  | HygieneRefused HygieneReport
  | HardwareBeforeBarrier GateSubstrate
  | RunRootNotFresh FilePath | RunRootOutsideFrame FilePath
  | ProductBinaryUnavailable Text
  | KernelRatchetUnavailable Text
  | LegacyInventoryUnavailable Int
  | LegacyAnalyzersUnavailable [Legacy.LegacyId]
  | SourceCaptureRefused Text
  | PredecessorGateUnavailable
  deriving (Eq, Show)
renderRefusal :: RunnerRefusal -> Text
renderRefusal refusal = case refusal of
  SpecRefused problems -> Text.intercalate "; " (map renderSpecProblem problems)
  PhaseSpecMismatch problems -> Text.intercalate "; " problems
  HygieneRefused report -> Text.intercalate "; " (hygieneProblems report)
  HardwareBeforeBarrier substrate -> "HARDWARE-BEFORE-BARRIER: " <> renderSubstrate substrate
  RunRootNotFresh path -> "RUN-ROOT-NOT-FRESH: " <> Text.pack path
  RunRootOutsideFrame path -> "RUN-ROOT-OUTSIDE-FRAME: " <> Text.pack path
  ProductBinaryUnavailable detail -> "PRODUCT-BINARY-UNAVAILABLE: " <> detail
  KernelRatchetUnavailable detail -> "KERNEL-RATCHET-UNAVAILABLE: " <> detail
  LegacyInventoryUnavailable phase -> "LEGACY-INVENTORY-UNAVAILABLE: unknown phase " <> showText phase
  LegacyAnalyzersUnavailable identifiers -> "LEGACY-ANALYZER-UNAVAILABLE: " <> Text.intercalate "," (map Legacy.renderLegacyId identifiers)
  SourceCaptureRefused detail -> "SOURCE-CAPTURE-UNAVAILABLE: " <> detail
  PredecessorGateUnavailable -> "PREDECESSOR-GATE-UNAVAILABLE: an exact-source immediate-predecessor pass is required"
-- Integrated analyzer/custody closure remains required; component counts supply no authority.
legacyAnalyzerGaps :: Int -> [Legacy.LegacyId]
legacyAnalyzerGaps phase = [identifier | requirement <- Legacy.legacyRequirements, let identifier = Legacy.legacyRequirementId requirement, Just owner <- [Legacy.legacyOwnerOrdinal identifier], owner <= phase, not (Analyzers.legacyQualificationSupported requirement)]
data PassedGate = PassedGate Int Text Analyzers.LegacyCollection deriving (Eq, Show)
predecessorMatches :: RunnerConfig -> CapturedSource -> Bool
predecessorMatches config captured = runnerPhase config == PhaseIdentity.phaseDomainLowerOrdinal || (isJust (runnerPredecessorDigest config) && case runnerPredecessorGate config of Just (PassedGate phase source _) -> PhaseIdentity.predecessorOrdinal (runnerPhase config) == Just phase && source == capturedSourceDigest captured; Nothing -> False)
data GateOutcome = GateOutcome
  { outcomeCandidate :: Candidate, outcomeHygiene :: HygieneReport
  , outcomeKillTable :: KillTable, outcomeRuns :: [ObservedRun], outcomePassed :: Maybe PassedGate } deriving (Eq, Show)
specDigest :: GateSpec -> Text
specDigest = sha256Hex . renderGateSpec
runGate :: RunnerConfig -> GateSpec -> IO (Either RunnerRefusal GateOutcome)
runGate config spec = either (Left . SourceCaptureRefused) id <$> sourceAttempt (do
  verified <- verifySpec (runnerRoot config) spec
  case verified of
    Left problems -> pure (Left (SpecRefused problems))
    Right vspec -> do
      hygiene <- hygieneRow (runnerRoot config) (runnerLastAcceptedKernelLines config) (runnerDocCheckCap config)
      runRootExists <- doesPathExist (runnerRunRoot config)
      frameAllowed <- runRootWithinFrame (runnerRoot config) (runnerRunRoot config)
      let preflight =
            [LegacyInventoryUnavailable (runnerPhase config) | not (PhaseIdentity.isPhaseOrdinal (runnerPhase config))]
              <> [HygieneRefused hygiene | runnerHygienePreflight config, not (hygieneGreen hygiene)]
              <> [RunRootNotFresh (runnerRunRoot config) | runRootExists]
              <> [PhaseSpecMismatch problems | Left problems <- [bindPhaseSpec registeredSpecInputs (runnerPhase config) spec]]
              <> [RunRootOutsideFrame (runnerRunRoot config) | not frameAllowed]
              <> [LegacyAnalyzersUnavailable absent | let absent = legacyAnalyzerGaps (runnerPhase config), not (null absent)]
              <> [HardwareBeforeBarrier (gateSubstrate spec) | gateRole spec == HardwareGate, isNothing (runnerPredecessorDigest config)]
      case preflight of
        (refusal : _) -> pure (Left refusal)
        [] -> captureSource (runnerRoot config) >>= either (pure . Left . SourceCaptureRefused) (execute config spec vspec hygiene))
execute :: RunnerConfig -> GateSpec -> VerifiedSpec -> HygieneReport -> CapturedSource -> IO (Either RunnerRefusal GateOutcome)
execute config _ _ _ source | not (predecessorMatches config source) = pure (Left PredecessorGateUnavailable)
execute config spec _ _ openingSource = do
  runRoot <- makeAbsolute (runnerRunRoot config)
  copied <- materializeSource openingSource runRoot
  case copied of
    Left detail -> pure (Left (SourceCaptureRefused detail))
    Right root -> do
      result <- (do
        verified <- verifySpec root spec
        hygiene <- hygieneRow root (runnerLastAcceptedKernelLines config) (runnerDocCheckCap config)
        case verified of
          Left problems -> pure (Left (SpecRefused problems))
          Right vspec | not (hygieneGreen hygiene) -> pure (Left (HygieneRefused hygiene))
                      | otherwise -> executeCopy config {runnerRoot = root, runnerRunRoot = root </> ".build/candidate"} spec vspec hygiene openingSource (runnerRoot config)) `finally` removePathForcibly root
      residue <- doesPathExist root
      pure (if residue then Left (SourceCaptureRefused "owned run root remains after cleanup") else fmap (\outcome -> outcome {outcomeCandidate = (outcomeCandidate outcome) {candidateRows = [if rowCategory row == Cleanroom then row {rowObservations = rowObservations row <> [("cleanroom.root-absent","True")]} else row | row <- candidateRows (outcomeCandidate outcome)]}}) result)
executeCopy :: RunnerConfig -> GateSpec -> VerifiedSpec -> HygieneReport -> CapturedSource -> FilePath -> IO (Either RunnerRefusal GateOutcome)
executeCopy config spec vspec hygiene openingSource liveRoot = do
  let root = runnerRoot config
      runRoot = runnerRunRoot config
      digest = specDigest spec
  createDirectoryIfMissing True runRoot
  let opening = capturedSourceDigest openingSource
  let challengeSeed = sha256Hex (digest <> "\n" <> Text.pack runRoot <> "\n" <> opening)
  nonce@(Nonce nonceText) <- freshNonce runRoot challengeSeed
  graph <- either (const Nothing) Just <$> loadPackageGraph root
  own <- Analyzers.collectLegacy liveRoot (runRoot </> "legacy") (runnerPhase config) (Just (runnerCabal config)) (runnerCompiler config) openingSource
  let legacy = maybe own (\(PassedGate _ _ inherited) -> Analyzers.inheritLegacyCollection openingSource inherited own) (runnerPredecessorGate config)
  (table, mutantRuns) <- case gateSeed spec of
    Just _ -> pure (killTable [], [])
    Nothing -> mutantMatrix config spec vspec graph digest openingSource
  seed <- case gateSeed spec of
    Just _ -> Just <$> runSeedProtocol (defaultSeedProtocol root (runRoot </> "seed-protocol")) {protocolCompiler = runnerCompiler config} challengeSeed
    Nothing -> pure Nothing
  documentation <- case gateSeed spec of
    Just _ -> Just <$> seedDocumentation root (runRoot </> "docs") (runRoot </> "clean" </> "suite")
    Nothing -> pure Nothing
  (custodyRuns, custody) <- case gateSeed spec of
    Just _ -> suiteAndOracle config root (CabalTarget "runner-suite") (OracleExecutable "oracle-runner") (maybe [] seedCustodyProbes (gateSeed spec)) (runRoot </> "custody")
    Nothing -> pure ([], parseLedger (Just ExitSuccess) "")
  -- The shipped binary runs before the clean suite, inside its directory, so the independent oracle can judge what it wrote.
  let binaryRoot = runRoot </> "clean" </> "suite" </> "binary"
  (binaryBuilds, built) <- case gateBinaryFact spec of
    Nothing -> pure ([], Right Nothing)
    Just _ -> do
      (runs, result) <- buildProductBinary root (runnerCabal config) (runnerCompiler config)
      pure (runs, fmap Just result)
  binary <- case (gateBinaryFact spec, built) of
    (Just fact, Right (Just binaryPath)) -> Just <$> runBinaryFact (runnerCabal config) (runnerCompiler config) openingSource root binaryRoot binaryPath fact nonce
    _ -> pure Nothing
  spine <- case gateSpineFact spec of
    Just fact -> Just <$> runSpineFact binaryRoot fact
    Nothing -> pure Nothing
  (cleanRuns, clean) <- suiteAndOracle config root (gateSuite spec) (gateOracle spec) (requiredSuiteRows spec) (runRoot </> "clean")
  let ledger = if isNothing (gateSeed spec) then clean else parseLedger (Just (if ledgerGreen clean && ledgerGreen custody then ExitSuccess else ExitFailure 1)) (Text.concat [runStdout run | runs <- [cleanRuns, custodyRuns], run <- take 1 (reverse runs)])
  closingSource <- captureSource liveRoot
  unchangedCopy <- verifySourceCopy openingSource root
  case (built, unchangedCopy, closingSource) of
    (Left problem, _, _) -> pure (Left (ProductBinaryUnavailable problem))
    (_, Left detail, _) -> pure (Left (SourceCaptureRefused detail))
    (_, _, Left detail) -> pure (Left (SourceCaptureRefused detail))
    (_, _, Right source) -> do
      let closing = capturedSourceDigest source
          productClosure = maybe Set.empty (\g -> maybe Set.empty id (executableClosure g "amoebius")) graph
          seedRuns = maybe [] (\outcome -> maybe [] pure (seedCleanRun outcome) <> [run | (_, Just run, _) <- seedMutantRuns outcome]) seed
          allRuns = capturedSourceRuns openingSource <> Analyzers.legacyCollectionRuns legacy <> seedRuns <> mutantRuns <> custodyRuns <> binaryBuilds <> maybe [] binaryRuns binary <> cleanRuns <> capturedSourceRuns source
          chain = foldl chainDigest challengeSeed allRuns
          captured = capture config spec vspec hygiene digest nonceText chain (opening, closing) table ledger binary spine allRuns seed documentation productClosure legacy openingSource
          candidate = captured {candidateReproducibleCore = reproducibleCore digest captured ledger table}
      mapM_ (\(file, body) -> TextIO.writeFile (runRoot </> file) body) [("candidate.tsv", renderCandidate candidate), ("kill-table.tsv", Text.unlines (renderKillTable table)), ("outcome.tsv", Text.unlines ["green\t" <> Text.pack (show (candidateGreen candidate)), "spec-digest\t" <> digest, "chain\t" <> chain, "reproducible-core\t" <> candidateReproducibleCore candidate, "capability\t" <> gateCapability spec, "claim\t" <> gateClaim spec])]
      pure (Right GateOutcome {outcomeCandidate = candidate, outcomeHygiene = hygiene, outcomeKillTable = table, outcomeRuns = allRuns, outcomePassed = if candidateGreen candidate then Just (PassedGate (runnerPhase config) opening legacy) else Nothing})
-- | Bind stable gate outcomes while excluding nonces, timestamps, and process digests.
reproducibleCore :: Text -> Candidate -> Ledger -> KillTable -> Text
reproducibleCore digest candidate ledger table =
  sha256Hex (renderTsv
    ([ ["spec", digest] ]
      <> [[renderGateCategory (rowCategory row), renderVerdict (rowVerdict row)] | row <- candidateRows candidate]
      <> [["ledger-exit", Text.pack (show (ledgerExit ledger))], ["ledger-valid", Text.pack (show (ledgerValid ledger))]]
      <> sort [["ledger-row", name, verdict] | (name, verdict, _) <- ledgerRows ledger]
      <> [[locusModule locus, Text.pack (locusFile locus) <> ":" <> Text.pack (show (locusLine locus)), renderOperator (locusOperator locus), outcomeText outcome]
          | (locus, _, outcome) <- killRows table]))
 where
  outcomeText outcome = case outcome of
    Killed stage -> "killed@" <> stage
    Survived -> "survived"
    Stillborn _ -> "stillborn"
    Unapplied _ -> "unapplied"
-- | Judge the seed's corpus and named negatives against compiled specification blocks.
data DocumentationOutcome = DocumentationOutcome { documentationFindings :: [Text], documentationNegatives :: [(Text, Bool)] } deriving (Eq, Show)
documentationGreen :: DocumentationOutcome -> Bool
documentationGreen outcome = null (documentationFindings outcome) && not (null (documentationNegatives outcome)) && all snd (documentationNegatives outcome)
seedDocumentation :: FilePath -> FilePath -> FilePath -> IO DocumentationOutcome
seedDocumentation root docsRoot suiteDir = do
  corpus <- either (fail . Text.unpack . Text.unlines) (\blocks -> checkTree blocks root) (compiledBlocks registeredSpecInputs)
  (documents, _, _) <- discoverDocuments root
  negatives <- forM negativeCatalogue $ \negative -> do
    let target = docsRoot </> "negatives" </> Text.unpack (negativeName negative)
    case renderNegative negative documents of
      Left _ -> pure (negative, [], False)
      Right rendered -> do
        writeCorpus target rendered
        result <- either (fail . Text.unpack . Text.unlines) (\blocks -> checkTree blocks target) (compiledBlocks registeredSpecInputs)
        let codes = map findingCode (checkFindings result)
        pure (negative, codes, negativeCode negative `elem` codes)
  createDirectoryIfMissing True suiteDir
  TextIO.writeFile (suiteDir </> "findings.tsv") (renderTsv
    ([ ["finding", findingCode item, Text.pack (findingSubject item), findingDetail item] | item <- checkFindings corpus] <>
     [["observation", observationKey item, observationValue item] | item <- checkObservations corpus]))
  TextIO.writeFile (suiteDir </> "negatives.tsv") (renderTsv
    [[negativeName negative, negativeCode negative, Text.intercalate "," codes, if named then "named-finding-observed" else "named-finding-absent"] | (negative, codes, named) <- negatives])
  pure DocumentationOutcome
      { documentationFindings = [findingCode item <> " " <> Text.pack (findingSubject item) | item <- checkFindings corpus]
      , documentationNegatives = [(negativeName negative, named) | (negative, _, named) <- negatives]
      }
data Ledger = Ledger { ledgerExit :: Maybe ExitCode, ledgerRows :: [(Text, Text, Text)], ledgerDigest :: Text, ledgerValid :: Bool } deriving (Eq, Show)
ledgerGreen :: Ledger -> Bool
ledgerGreen ledger = ledgerValid ledger && ledgerExit ledger == Just ExitSuccess && all (\(_, verdict, _) -> verdict == "green") (ledgerRows ledger)
ledgerRedRows :: Ledger -> [Text]
ledgerRedRows ledger = [name | (name, verdict, _) <- ledgerRows ledger, verdict /= "green"]
parseLedger :: Maybe ExitCode -> Text -> Ledger
parseLedger exit output = Ledger exit rows (sha256Hex output) valid
 where
  fields = map (Text.splitOn "\t") (Text.lines output)
  rows = [(name, verdict, Text.intercalate "\t" observed) | name : verdict : observed@(_ : _) <- fields]
  valid = not (null rows) && length rows == length fields && length rows == Set.size (Set.fromList [name | (name, _, _) <- rows])
    && all (\(name, verdict, _) -> not (Text.null name) && verdict `elem` ["green", "red"]) rows
suiteLedger :: [Text] -> ObservedRun -> ObservedRun -> ObservedRun -> Ledger
suiteLedger required subject oracle probe = let parsed = parseLedger (Just (runExit oracle)) (runStdout oracle) in parsed {ledgerValid = ledgerValid parsed && runExit subject == ExitSuccess && all (isNothing . runSpawnFailure) [subject,oracle,probe] && runExit probe /= ExitSuccess && all (`elem` map (\(name,_,_) -> name) (ledgerRows parsed)) required}
-- | Serial subject, missing-output oracle challenge, and clean oracle observation.
suiteAndOracle :: RunnerConfig -> FilePath -> CabalTarget -> OracleExecutable -> [Text] -> FilePath -> IO ([ObservedRun], Ledger)
suiteAndOracle config treeRoot suiteTarget oracleTarget required workRoot = do
  let suiteDir = workRoot </> "suite"
      suite = "amoebius:test:" <> Text.unpack (cabalTargetName suiteTarget)
      oracle = "amoebius:test:" <> Text.unpack (oracleExecutableName oracleTarget)
  mapM_ (createDirectoryIfMissing True) [suiteDir, workRoot </> "oracle-empty"]
  build <- observeNativeCabal treeRoot (runnerCabal config) (runnerCompiler config) ["build", "-v0", "--builddir=.build/dist-native", suite, oracle]
  if runExit build /= ExitSuccess
    then pure ([build], parseLedger Nothing "")
    else do
      suiteRun <- observeNativeCabal treeRoot (runnerCabal config) (runnerCompiler config) ["run", "-v0", "--builddir=.build/dist-native", suite, "--", suiteDir]
      located <- observeNativeCabal treeRoot (runnerCabal config) (runnerCompiler config) ["list-bin", "--builddir=.build/dist-native", oracle]
      probe <- observe treeRoot (Text.unpack (Text.strip (runStdout located))) [workRoot </> "oracle-empty"]
      oracleRun <- observeNativeCabal treeRoot (runnerCabal config) (runnerCompiler config) ["run", "-v0", "--builddir=.build/dist-native", oracle, "--", suiteDir]
      pure ([build, suiteRun, located, probe, oracleRun], suiteLedger required suiteRun oracleRun probe)
mutantMatrix :: RunnerConfig -> GateSpec -> VerifiedSpec -> Maybe PackageGraph -> Text -> CapturedSource -> IO (KillTable, [ObservedRun])
mutantMatrix config spec vspec graph digest source = do
  let root = runnerRoot config
      policy = gateMutants spec
  perModuleLoci <- forM (stageModules policy) $ \stage -> do
    located <- case (graph, Map.lookup stage (verifiedStanzaOf vspec)) of
      (Just g, Just stanza) -> moduleSourcePath root g stanza stage
      _ -> pure Nothing
    case located of
      Nothing -> pure []
      Just file -> do
        contents <- readSourceText (root </> file)
        let loci = concat [enumerateLoci (productionModuleName stage) file operator contents | operator <- allOperators]
        pure (sampleLoci (digest <> productionModuleName stage) (perModule policy) loci)
  -- Round-robin sampling prevents the gate cap from starving later stage modules.
  let selected = take (maybe (perGateCap policy) (min (perGateCap policy)) (runnerMutantLimit config)) (concat (transpose perModuleLoci))
  results <- forM (zip [1 :: Int ..] selected) $ \(index, locus) -> do
    let copyRoot = runnerRunRoot config </> "mutants" </> show index
    copied <- materializeSource source copyRoot
    applied <- either (pure . Left) (`applyLocus` locus) copied
    case applied of
      Left problem -> pure ((locus, Nothing, Unapplied problem), [])
      Right witness -> do
        (runs, ledger) <- suiteAndOracle config copyRoot (gateSuite spec) (gateOracle spec) (requiredSuiteRows spec) copyRoot
        let outcome
              | any (\run -> runExit run /= ExitSuccess && "build" `elem` runArgv run) runs = Stillborn (Text.take 200 (Text.unlines (map runStderr runs)))
              | not (ledgerValid ledger) || null (ledgerRedRows ledger) || ledgerGreen ledger || not (isAttributed (stageArtefacts policy) (locusModule locus) (ledgerRedRows ledger)) = Survived
              | otherwise = Killed (Text.intercalate "," (take 3 (ledgerRedRows ledger)))
        pure ((locus, Just witness, outcome), runs)
  pure (killTable (map fst results), concatMap snd results)
capture :: RunnerConfig -> GateSpec -> VerifiedSpec -> HygieneReport -> Text -> Text -> Text -> (Text, Text)
  -> KillTable -> Ledger -> Maybe BinaryOutcome -> Maybe SpineOutcome -> [ObservedRun]
  -> Maybe SeedOutcome -> Maybe DocumentationOutcome -> Set.Set Text -> Analyzers.LegacyCollection -> CapturedSource -> Candidate
capture config spec vspec hygiene digest nonce chain (opening, closing) table ledger binary spine runs seedOutcome documentation productClosure legacy openingSource =
  Candidate
    { candidatePhase = runnerPhase config, candidateCapability = gateCapability spec, candidateSpecDigest = digest
    , candidateChallenge = nonce, candidateChain = chain, candidateReproducibleCore = "", candidateRows = map row allGateCategories }
 where
  seed = isJust (gateSeed spec)
  seedOk = maybe False seedGreen seedOutcome && maybe False (all exactlyGreen . seedCustodyProbes) (gateSeed spec)
  docOk = maybe False documentationGreen documentation
  seedObservations = maybe [] renderSeedOutcome seedOutcome
  docObservations = maybe [] (\outcome ->
          [("doc.findings", Text.pack (show (length (documentationFindings outcome)))), ("doc.negatives", Text.intercalate "," [name <> "=" <> (if named then "named" else "absent") | (name, named) <- documentationNegatives outcome])]
            <> [("doc.finding", item) | item <- take 20 (documentationFindings outcome)]
      ) documentation
  positives = [c | c@PositiveControl {} <- gateCases spec]
  negatives = [c | c@PairedNegative {} <- gateCases spec]
  exactlyGreen name = length [() | (observedName, verdict, _) <- ledgerRows ledger, observedName == name, verdict == "green"] == 1
  ledgerCaseGreen item = maybe True (const (exactlyGreen (caseName item))) (Text.stripPrefix "case:" (caseName item))
  fresh = bootstrapSnapshotMatches (Text.unpack opening) (Text.unpack closing)
  observed = all (isNothing . runSpawnFailure) runs && not (null runs)
  stageKilled stage = any (\(locus, _, outcome) -> locusModule locus == productionModuleName stage && isKilled outcome) (killRows table)
  isKilled outcome = case outcome of
    Killed _ -> True
    _ -> False
  mutantsGreen =
    not seed
      && viableCount table > 0
      && killRatioObserved table >= killRatio (gateMutants spec)
      && all stageKilled (stageModules (gateMutants spec))
  productShipsNoValidator = not (Set.null productClosure) && not (any isValidatorStanza (Set.toList productClosure))
  isValidatorStanza stanza = stanza `elem` ["validation-kernel", "validation-runner", "doc-check", "plan-decisions", "gate-spec"]
  binaryGreen = case binary of
    Nothing -> isNothing (gateBinaryFact spec)
    Just outcome -> null (binaryProblems outcome) && not (null (binaryRuns outcome)) && not (null (binaryNonceRecovered outcome)) && all snd (binaryNonceRecovered outcome)
  spineGreen = maybe (isNothing (gateSpineFact spec)) (\o -> spineDigestsEqual o && all (\stage -> any (\(name, verdict, _) -> verdict == "green" && (stage <> ".") `Text.isPrefixOf` name) (ledgerRows ledger)) (spineStageOrder o)) spine
  predecessorGreen = predecessorMatches config openingSource
  legacyDue = Legacy.legacyIdsOwnedBy (runnerPhase config)
  verdictOf condition = if condition then Green else Red
  row category = CandidateRow category verdict observations
   where
    (verdict, observations) = case category of
      Claim -> (Green, [("claim", gateClaim spec), ("spec-digest", digest), ("role", Text.pack (show (gateRole spec)))])
      Subject -> (verdictOf (not (Map.null (verifiedStanzaOf vspec))), [("subject." <> productionModuleName m, stanza) | (m, stanza) <- Map.toList (verifiedStanzaOf vspec)])
      Command -> (Green, [("command", "amoebius-validate preview phase " <> Text.pack (show (runnerPhase config))), ("suite", cabalTargetName (gateSuite spec)), ("oracle", oracleExecutableName (gateOracle spec))])
      Oracle -> (verdictOf (isJust (ledgerExit ledger)), [("oracle.directories", Text.intercalate "," (map Text.pack (verifiedOracleDirectories vspec))), ("oracle.ledger-sha256", ledgerDigest ledger), ("oracle.rows", showText (length (ledgerRows ledger)))])
      PositiveControls -> (verdictOf (not (null positives) && ledgerGreen ledger && all ledgerCaseGreen positives && (not seed || (seedOk && docOk))), [("positive.count", showText (length positives)), ("ledger.red-rows", Text.intercalate "," (ledgerRedRows ledger))] <> docObservations)
      PairedNegatives -> (verdictOf (not (null negatives) && ledgerGreen ledger && all ledgerCaseGreen negatives && (not seed || (seedOk && docOk))), [("negative.count", showText (length negatives)), ("ledger.red-rows", Text.intercalate "," (ledgerRedRows ledger))] <> docObservations)
      Mutants -> (if seed then verdictOf seedOk else verdictOf mutantsGreen, if seed then seedObservations else [("mutants.killed", showText (killedCount table)), ("mutants.viable", showText (viableCount table)), ("mutants.stillborn", showText (stillbornCount table)), ("mutants.ratio", Text.pack (show (killRatioObserved table))), ("mutants.rows", showText (length (killRows table)))] <> [("mutant." <> showText i, line) | (i, line) <- zip [1 :: Int ..] (renderKillTable table)])
      Discovery -> (verdictOf (not (Set.null (verifiedClosure vspec)) && length (verifiedStanzaOf vspec) == length (gateSubjects spec)), [("closure.stanzas", Text.intercalate "," (Set.toList (verifiedClosure vspec))), ("subjects.mapped", showText (Map.size (verifiedStanzaOf vspec))), ("subjects.declared", showText (length (gateSubjects spec)))])
      Challenge -> (verdictOf (if seed then seedOk else binaryGreen && spineGreen), [("challenge.nonce", nonce), ("challenge.kind", if seed then "pure predicate judged by the independent driver" else "runner-perturbed input"), ("challenge.binary", maybe "absent" (\o -> Text.pack (show (binaryNonceRecovered o))) binary), ("challenge.spine", maybe "absent" (\o -> Text.pack (show (spineDigestsEqual o))) spine)] <> maybe [] binaryEvidence binary)
      Observer -> (verdictOf observed, concat [renderObserved ("run." <> showText i) run | (i, run) <- zip [1 :: Int ..] runs])
      AuthorityBypass -> (verdictOf productShipsNoValidator, [("closure.validator-free", Text.pack (show productShipsNoValidator)), ("closure.product", Text.intercalate "," (Set.toList productClosure)), ("subjects.validator", showText (length (filter isValidatorModule (gateSubjects spec))))])
      Freshness -> (verdictOf fresh, [("source.opening", opening), ("source.closing", closing), ("run-root", Text.pack (runnerRunRoot config))])
      Qualification -> (verdictOf (if seed then seedOk else mutantsGreen), [("qualification", if seed then "finite-seed-protocol" else "generated-mutant-matrix"), ("matrix.precedes-clean", "true")] <> (if seed then seedObservations else []))
      Cleanroom -> (verdictOf fresh, [("cleanroom.run-root", Text.pack (runnerRunRoot config)), ("cleanroom.tracked-unchanged", Text.pack (show fresh))])
      LegacyClosure -> (verdictOf (hygieneGreen hygiene && null (Analyzers.auditLegacyCollection (runnerPhase config) openingSource legacy)), renderHygiene hygiene <> [("legacy.due", Text.intercalate "," (map Legacy.renderLegacyId legacyDue))] <> Analyzers.legacyCollectionEvidence legacy)
      Predecessor -> (verdictOf predecessorGreen, [("predecessor", if runnerPhase config == PhaseIdentity.phaseDomainLowerOrdinal then "genesis" else maybe "absent" id (runnerPredecessorDigest config))])
      Residue -> (verdictOf fresh, [("residue.tracked-unchanged", Text.pack (show fresh)), ("residue.unverified", "later-owned capabilities remain UNVERIFIED by construction")])
      PassCriterion -> (verdictOf (all (\c -> rowVerdict (row c) == Green) (filter (/= PassCriterion) allGateCategories)), [("pass-criterion", "qualified-gate-pass")])
