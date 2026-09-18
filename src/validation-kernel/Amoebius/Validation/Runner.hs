{-# LANGUAGE OverloadedStrings #-}

-- | The one generic gate runner (gate_runner_doctrine.md section 3). It consumes
-- one 'GateSpec', runs its six stages in order under the process observer, and
-- fills the eighteen-row candidate from its own observations. It holds every
-- verdict; a suite prints bytes and an oracle prints a ledger, and neither can
-- mint a row.
module Amoebius.Validation.Runner
  ( GateOutcome (..)
  , RunnerConfig (..)
  , RunnerRefusal (..)
  , compiledBlocks
  , defaultRunnerConfig
  , reproducibleCore
  , renderRefusal
  , runGate
  , specDigest
  ) where

import Amoebius.Doc.Check (checkTree, discoverDocuments)
import Amoebius.Doc.Render (Negative (..), negativeCatalogue, renderNegative, writeCorpus)
import Amoebius.Doc.Types (CheckResult (..), Finding (..), Observation (..))
import Amoebius.Plan.Legacy qualified as Legacy
import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Validation.BootstrapQualification.Internal
import Amoebius.Validation.GateSpec
import Amoebius.Validation.GateSpec.Registry (specInputFor)
import Amoebius.Validation.Runner.Binary
import Amoebius.Validation.Runner.Capture
import Amoebius.Validation.Runner.Hygiene
import Amoebius.Validation.Runner.Mutants
import Amoebius.Validation.Runner.Observer
import Amoebius.Validation.Runner.Spec
import Control.Monad (forM, forM_, unless)
import Data.Map.Strict qualified as Map
import Data.Maybe (isJust, isNothing)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (copyFile, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, makeAbsolute)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, (</>))

data RunnerConfig = RunnerConfig
  { runnerRoot :: FilePath
  , runnerRunRoot :: FilePath
  , runnerPhase :: Int
  , runnerCabal :: FilePath
  , runnerProductBinary :: Maybe FilePath
  , runnerLastAcceptedKernelLines :: Maybe Int
  , runnerDocCheckCap :: Int
  , runnerHygienePreflight :: Bool
  , runnerPredecessorDigest :: Maybe Text
  , runnerMutantLimit :: Maybe Int
  , runnerCompiler :: Maybe FilePath
  }
  deriving (Eq, Show)

defaultRunnerConfig :: FilePath -> Int -> RunnerConfig
defaultRunnerConfig root phase =
  RunnerConfig
    { runnerRoot = root
    , runnerRunRoot = root </> ".build" </> "runs" </> ("phase-" <> pad phase)
    , runnerPhase = phase
    , runnerCabal = "cabal"
    , runnerProductBinary = Nothing
    , runnerLastAcceptedKernelLines = Nothing
    , runnerDocCheckCap = 7000
    , runnerHygienePreflight = True
    , runnerPredecessorDigest = Nothing
    , runnerMutantLimit = Nothing
    , runnerCompiler = Nothing
    }
 where
  pad n = let s = show n in if length s < 2 then '0' : s else s

data RunnerRefusal
  = SpecRefused [SpecProblem]
  | HygieneRefused HygieneReport
  | HardwareBeforeBarrier Substrate
  | RunRootNotFresh FilePath
  deriving (Eq, Show)

renderRefusal :: RunnerRefusal -> Text
renderRefusal refusal = case refusal of
  SpecRefused problems -> Text.intercalate "; " (map renderSpecProblem problems)
  HygieneRefused report -> Text.intercalate "; " (hygieneProblems report)
  HardwareBeforeBarrier substrate -> "HARDWARE-BEFORE-BARRIER: " <> renderSubstrate substrate
  RunRootNotFresh path -> "RUN-ROOT-NOT-FRESH: " <> Text.pack path

data GateOutcome = GateOutcome
  { outcomeCandidate :: Candidate
  , outcomeHygiene :: HygieneReport
  , outcomeKillTable :: KillTable
  , outcomeRuns :: [ObservedRun]
  }
  deriving (Eq, Show)

specDigest :: GateSpec -> Text
specDigest = sha256Hex . renderGateSpec

-- | Run one gate. Refusals happen before any subject runs; afterwards every
-- stage records into the candidate and the verdict is the candidate's rows.
runGate :: RunnerConfig -> GateSpec -> IO (Either RunnerRefusal GateOutcome)
runGate config spec = do
  verified <- verifySpec (runnerRoot config) spec
  case verified of
    Left problems -> pure (Left (SpecRefused problems))
    Right vspec -> do
      hygiene <- hygieneRow (runnerRoot config) (runnerLastAcceptedKernelLines config) (runnerDocCheckCap config)
      runRootExists <- doesDirectoryExist (runnerRunRoot config)
      let preflight =
            [HygieneRefused hygiene | runnerHygienePreflight config, not (hygieneGreen hygiene)]
              <> [HardwareBeforeBarrier (gateSubstrate spec) | gateRole spec == HardwareGate, isNothing (runnerPredecessorDigest config)]
              <> [RunRootNotFresh (runnerRunRoot config) | runRootExists]
      case preflight of
        (refusal : _) -> pure (Left refusal)
        [] -> Right <$> execute config spec vspec hygiene

execute :: RunnerConfig -> GateSpec -> VerifiedSpec -> HygieneReport -> IO GateOutcome
execute config spec vspec hygiene = do
  let root = runnerRoot config
      runRoot = runnerRunRoot config
      digest = specDigest spec
  createDirectoryIfMissing True runRoot
  opening <- treeDigest root
  let challengeSeed = sha256Hex (digest <> "\n" <> Text.pack runRoot <> "\n" <> opening)
  nonce@(Nonce nonceText) <- freshNonce runRoot challengeSeed
  graph <- either (const Nothing) Just <$> loadPackageGraph root
  -- Stage 3 first: the matrix precedes the clean candidate in the same run. The
  -- seed role runs its finite predicate protocol and the documentation claim
  -- instead of a generated matrix; their ledgers land in the suite directory so
  -- the area's oracle judges them with the suite's own bytes.
  (table, mutantRuns) <- case gateSeed spec of
    Just _ -> pure (killTable [], [])
    Nothing -> mutantMatrix config spec vspec graph digest
  seed <- case gateSeed spec of
    Just _ -> Just <$> runSeedProtocol (defaultSeedProtocol root (runRoot </> "seed-protocol")) {protocolCompiler = runnerCompiler config} challengeSeed
    Nothing -> pure Nothing
  documentation <- case gateSeed spec of
    Just _ -> Just <$> seedDocumentation root (runRoot </> "docs") (runRoot </> "clean" </> "suite")
    Nothing -> pure Nothing
  -- Stage 2: the clean run.
  (cleanRuns, ledger) <- cleanRun config spec (runRoot </> "clean")
  -- Stage 4: perturbation.
  binary <- case (gateBinaryFact spec, runnerProductBinary config) of
    (Just fact, Just binaryPath) -> Just <$> runBinaryFact root (runRoot </> "binary") binaryPath fact nonce
    _ -> pure Nothing
  spine <- case gateSpineFact spec of
    Just fact -> Just <$> runSpineFact (runRoot </> "binary") fact
    Nothing -> pure Nothing
  closing <- treeDigest root
  let productClosure = maybe Set.empty (\g -> maybe Set.empty id (executableClosure g "amoebius")) graph
      seedRuns = maybe [] (\outcome -> maybe [] pure (seedCleanRun outcome) <> [run | (_, Just run, _) <- seedMutantRuns outcome]) seed
      allRuns = seedRuns <> mutantRuns <> cleanRuns <> maybe [] (maybe [] pure . binaryRun) binary
      chain = foldl chainDigest challengeSeed allRuns
      captured = capture config spec vspec hygiene digest nonceText chain (opening, closing) table ledger binary spine allRuns seed documentation productClosure
      candidate = captured {candidateReproducibleCore = reproducibleCore digest captured (ledgerDigest ledger) table}
  TextIO.writeFile (runRoot </> "candidate.tsv") (renderCandidate candidate)
  TextIO.writeFile (runRoot </> "kill-table.tsv") (Text.unlines (renderKillTable table))
  TextIO.writeFile
    (runRoot </> "outcome.tsv")
    (Text.unlines ["green\t" <> Text.pack (show (candidateGreen candidate)), "spec-digest\t" <> digest, "chain\t" <> chain, "reproducible-core\t" <> candidateReproducibleCore candidate, "capability\t" <> gateCapability spec, "claim\t" <> gateClaim spec])
  pure GateOutcome {outcomeCandidate = candidate, outcomeHygiene = hygiene, outcomeKillTable = table, outcomeRuns = allRuns}

-- | The reproducible core of a candidate (DL-0013): the specification digest, the
-- ordered row verdicts, the oracle ledger digest, and every mutant's locus and
-- outcome. Nonces, chains, timestamps, and process digests are excluded, so a
-- later run of the same gate on the same tree re-derives the same core.
reproducibleCore :: Text -> Candidate -> Text -> KillTable -> Text
reproducibleCore digest candidate ledgerDigestValue table =
  sha256Hex
    ( Text.unlines
        ( ["spec\t" <> digest]
            <> [renderGateCategory (rowCategory row) <> "\t" <> renderVerdict (rowVerdict row) | row <- candidateRows candidate]
            <> ["ledger\t" <> ledgerDigestValue]
            <> [ locusModule locus <> "\t" <> Text.pack (locusFile locus) <> ":" <> Text.pack (show (locusLine locus)) <> "\t" <> renderOperator (locusOperator locus) <> "\t" <> outcomeText outcome
               | (locus, _, outcome) <- killRows table
               ]
        )
    )
 where
  outcomeText outcome = case outcome of
    Killed stage -> "killed@" <> stage
    Survived -> "survived"
    Stillborn _ -> "stillborn"
    Unapplied _ -> "unapplied"

-- | The seed's documentation claim: zero findings over the corpus and the named
-- finding on every rendered negative, judged against the compiled specification
-- blocks the registry supplies. Both ledgers are written into the suite
-- directory in the verifier's own format.
data DocumentationOutcome = DocumentationOutcome
  { documentationFindings :: [Text]
  , documentationNegatives :: [(Text, Bool)]
  }
  deriving (Eq, Show)

documentationGreen :: DocumentationOutcome -> Bool
documentationGreen outcome = null (documentationFindings outcome) && not (null (documentationNegatives outcome)) && all snd (documentationNegatives outcome)

-- | The compiled gate-specification blocks for every registered phase.
compiledBlocks :: [(Int, Text)]
compiledBlocks =
  [ (PhaseIdentity.phaseIdentityOrdinal row, renderGateSpec spec)
  | row <- PhaseIdentity.allPhaseIdentities
  , Just input <- [specInputFor (PhaseIdentity.phaseIdentityCapability row)]
  , Right spec <- [mkGateSpec (roleFor (PhaseIdentity.phaseIdentityOrdinal row)) input]
  ]

roleFor :: Int -> GateRole
roleFor ordinal
  | ordinal == PhaseIdentity.phaseDomainLowerOrdinal = SeedGate
  | Just ordinal == PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier = BarrierGate
  | maybe False (ordinal >=) (PhaseIdentity.roleOrdinal PhaseIdentity.FirstHardware) = HardwareGate
  | otherwise = OrdinaryGate

seedDocumentation :: FilePath -> FilePath -> FilePath -> IO DocumentationOutcome
seedDocumentation root docsRoot suiteDir = do
  corpus <- checkTree compiledBlocks root
  (documents, _, _) <- discoverDocuments root
  negatives <- forM negativeCatalogue $ \negative -> do
    let target = docsRoot </> "negatives" </> Text.unpack (negativeName negative)
    case renderNegative negative documents of
      Left _ -> pure (negative, [], False)
      Right rendered -> do
        writeCorpus target rendered
        result <- checkTree compiledBlocks target
        let codes = map findingCode (checkFindings result)
        pure (negative, codes, negativeCode negative `elem` codes)
  createDirectoryIfMissing True suiteDir
  TextIO.writeFile
    (suiteDir </> "findings.tsv")
    ( Text.unlines
        ( [Text.intercalate "\t" ["finding", findingCode item, Text.pack (findingSubject item), findingDetail item] | item <- checkFindings corpus]
            <> [Text.intercalate "\t" ["observation", observationKey item, observationValue item] | item <- checkObservations corpus]
        )
    )
  TextIO.writeFile
    (suiteDir </> "negatives.tsv")
    (Text.unlines [Text.intercalate "\t" [negativeName negative, negativeCode negative, Text.intercalate "," codes, if named then "named-finding-observed" else "named-finding-absent"] | (negative, codes, named) <- negatives])
  pure
    DocumentationOutcome
      { documentationFindings = [findingCode item <> " " <> Text.pack (findingSubject item) | item <- checkFindings corpus]
      , documentationNegatives = [(negativeName negative, named) | (negative, _, named) <- negatives]
      }

-- | The oracle ledger as the runner reads it: exit, rows, and the red rows.
data Ledger = Ledger
  { ledgerExit :: Maybe ExitCode
  , ledgerRows :: [(Text, Text, Text)]
  , ledgerDigest :: Text
  }
  deriving (Eq, Show)

ledgerGreen :: Ledger -> Bool
ledgerGreen ledger = ledgerExit ledger == Just ExitSuccess && not (null (ledgerRows ledger)) && all (\(_, verdict, _) -> verdict == "green") (ledgerRows ledger)

ledgerRedRows :: Ledger -> [Text]
ledgerRedRows ledger = [name | (name, verdict, _) <- ledgerRows ledger, verdict /= "green"]

parseLedger :: Maybe ExitCode -> Text -> Ledger
parseLedger exit output =
  Ledger
    { ledgerExit = exit
    , ledgerRows = [(name, verdict, observed) | line <- Text.lines output, (name : verdict : rest) <- [Text.splitOn "\t" line], let observed = Text.intercalate "\t" rest]
    , ledgerDigest = sha256Hex output
    }

-- | Build the suite serially, run it into the suite directory, and run the oracle
-- over that directory, all under the observer.
cleanRun :: RunnerConfig -> GateSpec -> FilePath -> IO ([ObservedRun], Ledger)
cleanRun config spec workRoot = suiteAndOracle config (runnerRoot config) spec workRoot

suiteAndOracle :: RunnerConfig -> FilePath -> GateSpec -> FilePath -> IO ([ObservedRun], Ledger)
suiteAndOracle config treeRoot spec workRoot = do
  let suiteDir = workRoot </> "suite"
      suite = "amoebius:test:" <> Text.unpack (cabalTargetName (gateSuite spec))
      oracle = "amoebius:test:" <> Text.unpack (oracleExecutableName (gateOracle spec))
  createDirectoryIfMissing True suiteDir
  build <- observe treeRoot (runnerCabal config) ["build", "-v0", "--jobs=1", suite, oracle]
  if runExit build /= ExitSuccess
    then pure ([build], parseLedger Nothing "")
    else do
      suiteRun <- observe treeRoot (runnerCabal config) ["run", "-v0", "--jobs=1", suite, "--", suiteDir]
      oracleRun <- observe treeRoot (runnerCabal config) ["run", "-v0", "--jobs=1", oracle, "--", suiteDir]
      pure ([build, suiteRun, oracleRun], parseLedger (Just (runExit oracleRun)) (runStdout oracleRun))

-- | Generate, apply, rebuild, and judge the sampled mutants, one copy of the
-- tracked tree per mutant beneath the run root.
mutantMatrix :: RunnerConfig -> GateSpec -> VerifiedSpec -> Maybe PackageGraph -> Text -> IO (KillTable, [ObservedRun])
mutantMatrix config spec vspec graph digest = do
  let root = runnerRoot config
      policy = gateMutants spec
  perModuleLoci <- forM (stageModules policy) $ \stage -> do
    located <- case (graph, Map.lookup stage (verifiedStanzaOf vspec)) of
      (Just g, Just stanza) -> moduleSourcePath root g stanza stage
      _ -> pure Nothing
    case located of
      Nothing -> pure []
      Just file -> do
        source <- TextIO.readFile (root </> file)
        let loci = concat [enumerateLoci (productionModuleName stage) file operator source | operator <- allOperators]
        pure (sampleLoci (digest <> productionModuleName stage) (perModule policy) loci)
  let selected = take (maybe (perGateCap policy) (min (perGateCap policy)) (runnerMutantLimit config)) (concat perModuleLoci)
  tracked <- trackedFiles root
  results <- forM (zip [1 :: Int ..] selected) $ \(index, locus) -> do
    let copyRoot = runnerRunRoot config </> "mutants" </> show index
    copyTree root copyRoot tracked
    applied <- applyLocus copyRoot locus
    case applied of
      Left problem -> pure ((locus, Nothing, Unapplied problem), [])
      Right witness -> do
        (runs, ledger) <- suiteAndOracle config copyRoot spec copyRoot
        let outcome
              | any (\run -> runExit run /= ExitSuccess && "build" `elem` runArgv run) runs = Stillborn (Text.take 200 (Text.unlines (map runStderr runs)))
              | ledgerGreen ledger = Survived
              | otherwise = Killed (Text.intercalate "," (take 3 (ledgerRedRows ledger)))
        pure ((locus, Just witness, outcome), runs)
  pure (killTable (map fst results), concatMap snd results)

trackedFiles :: FilePath -> IO [FilePath]
trackedFiles root = do
  absolute <- makeAbsolute root
  listing <- observe root "git" ["-c", "safe.directory=" <> absolute, "ls-files", "-z"]
  pure (filter (not . null) (map Text.unpack (Text.splitOn "\0" (runStdout listing))))

copyTree :: FilePath -> FilePath -> [FilePath] -> IO ()
copyTree from to files = forM_ files $ \file -> do
  exists <- doesFileExist (from </> file)
  unless (not exists) $ do
    createDirectoryIfMissing True (takeDirectory (to </> file))
    copyFile (from </> file) (to </> file)

-- | The digest of every tracked file's bytes, used for opening/closing freshness.
treeDigest :: FilePath -> IO Text
treeDigest root = do
  files <- trackedFiles root
  digests <- forM files $ \file -> do
    exists <- doesFileExist (root </> file)
    if exists then (\contents -> Text.pack file <> " " <> sha256Hex contents) <$> TextIO.readFile (root </> file) else pure (Text.pack file <> " absent")
  pure (sha256Hex (Text.unlines digests))

capture
  :: RunnerConfig
  -> GateSpec
  -> VerifiedSpec
  -> HygieneReport
  -> Text
  -> Text
  -> Text
  -> (Text, Text)
  -> KillTable
  -> Ledger
  -> Maybe BinaryOutcome
  -> Maybe SpineOutcome
  -> [ObservedRun]
  -> Maybe SeedOutcome
  -> Maybe DocumentationOutcome
  -> Set.Set Text
  -> Candidate
capture config spec vspec hygiene digest nonce chain (opening, closing) table ledger binary spine runs seedOutcome documentation productClosure =
  Candidate
    { candidatePhase = runnerPhase config
    , candidateCapability = gateCapability spec
    , candidateSpecDigest = digest
    , candidateChallenge = nonce
    , candidateChain = chain
    , candidateReproducibleCore = ""
    , candidateRows = map row allGateCategories
    }
 where
  seed = isJust (gateSeed spec)
  seedOk = maybe False seedGreen seedOutcome
  docOk = maybe False documentationGreen documentation
  seedObservations = maybe [] renderSeedOutcome seedOutcome
  docObservations =
    maybe
      []
      ( \outcome ->
          [("doc.findings", Text.pack (show (length (documentationFindings outcome)))), ("doc.negatives", Text.intercalate "," [name <> "=" <> (if named then "named" else "absent") | (name, named) <- documentationNegatives outcome])]
            <> [("doc.finding", item) | item <- take 20 (documentationFindings outcome)]
      )
      documentation
  positives = [c | c@PositiveControl {} <- gateCases spec]
  negatives = [c | c@PairedNegative {} <- gateCases spec]
  fresh = opening == closing
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
    Just outcome -> null (binaryProblems outcome) && not (null (binaryNonceRecovered outcome)) && all snd (binaryNonceRecovered outcome) && maybe False ((== ExitSuccess) . runExit) (binaryRun outcome)
  spineGreen = maybe (isNothing (gateSpineFact spec)) spineDigestsEqual spine
  predecessorGreen = runnerPhase config == PhaseIdentity.phaseDomainLowerOrdinal || isJust (runnerPredecessorDigest config)
  legacyDue = Legacy.legacyIdsOwnedBy (runnerPhase config)
  verdictOf condition = if condition then Green else Red
  row category = CandidateRow category verdict observations
   where
    (verdict, observations) = case category of
      Claim -> (Green, [("claim", gateClaim spec), ("spec-digest", digest), ("role", Text.pack (show (gateRole spec)))])
      Subject -> (verdictOf (not (Map.null (verifiedStanzaOf vspec))), [("subject." <> productionModuleName m, stanza) | (m, stanza) <- Map.toList (verifiedStanzaOf vspec)])
      Command -> (Green, [("command", "amoebius-validate preview phase " <> Text.pack (show (runnerPhase config))), ("suite", cabalTargetName (gateSuite spec)), ("oracle", oracleExecutableName (gateOracle spec))])
      Oracle -> (verdictOf (isJust (ledgerExit ledger)), [("oracle.directories", Text.intercalate "," (map Text.pack (verifiedOracleDirectories vspec))), ("oracle.ledger-sha256", ledgerDigest ledger), ("oracle.rows", showText (length (ledgerRows ledger)))])
      PositiveControls -> (verdictOf (not (null positives) && ledgerGreen ledger && (not seed || (seedOk && docOk))), [("positive.count", showText (length positives)), ("ledger.red-rows", Text.intercalate "," (ledgerRedRows ledger))] <> docObservations)
      PairedNegatives -> (verdictOf (not (null negatives) && ledgerGreen ledger && (not seed || (seedOk && docOk))), [("negative.count", showText (length negatives)), ("ledger.red-rows", Text.intercalate "," (ledgerRedRows ledger))] <> docObservations)
      Mutants -> (if seed then verdictOf seedOk else verdictOf mutantsGreen, if seed then seedObservations else [("mutants.killed", showText (killedCount table)), ("mutants.viable", showText (viableCount table)), ("mutants.stillborn", showText (stillbornCount table)), ("mutants.ratio", Text.pack (show (killRatioObserved table))), ("mutants.rows", showText (length (killRows table)))] <> [("mutant." <> showText i, line) | (i, line) <- zip [1 :: Int ..] (renderKillTable table)])
      Discovery -> (verdictOf (not (Set.null (verifiedClosure vspec)) && length (verifiedStanzaOf vspec) == length (gateSubjects spec)), [("closure.stanzas", Text.intercalate "," (Set.toList (verifiedClosure vspec))), ("subjects.mapped", showText (Map.size (verifiedStanzaOf vspec))), ("subjects.declared", showText (length (gateSubjects spec)))])
      Challenge -> (verdictOf (if seed then seedOk else binaryGreen && spineGreen), [("challenge.nonce", nonce), ("challenge.kind", if seed then "pure predicate judged by the independent driver" else "runner-perturbed input"), ("challenge.binary", maybe "absent" (\o -> Text.pack (show (binaryNonceRecovered o))) binary), ("challenge.spine", maybe "absent" (\o -> Text.pack (show (spineDigestsEqual o))) spine)])
      Observer -> (verdictOf observed, concat [renderObserved ("run." <> showText i) run | (i, run) <- zip [1 :: Int ..] runs])
      AuthorityBypass -> (verdictOf productShipsNoValidator, [("closure.validator-free", Text.pack (show productShipsNoValidator)), ("closure.product", Text.intercalate "," (Set.toList productClosure)), ("subjects.validator", showText (length (filter isValidatorModule (gateSubjects spec))))])
      Freshness -> (verdictOf fresh, [("source.opening", opening), ("source.closing", closing), ("run-root", Text.pack (runnerRunRoot config))])
      Qualification -> (verdictOf (if seed then seedOk else mutantsGreen), [("qualification", if seed then "finite-seed-protocol" else "generated-mutant-matrix"), ("matrix.precedes-clean", "true")] <> (if seed then seedObservations else []))
      Cleanroom -> (verdictOf fresh, [("cleanroom.run-root", Text.pack (runnerRunRoot config)), ("cleanroom.tracked-unchanged", Text.pack (show fresh))])
      LegacyClosure -> (verdictOf (hygieneGreen hygiene), renderHygiene hygiene <> [("legacy.due", Text.intercalate "," (map Legacy.renderLegacyId legacyDue))])
      Predecessor -> (verdictOf predecessorGreen, [("predecessor", if runnerPhase config == PhaseIdentity.phaseDomainLowerOrdinal then "genesis" else maybe "absent" id (runnerPredecessorDigest config))])
      Residue -> (verdictOf fresh, [("residue.tracked-unchanged", Text.pack (show fresh)), ("residue.unverified", "later-owned capabilities remain UNVERIFIED by construction")])
      PassCriterion -> (verdictOf (all (\c -> rowVerdict (row c) == Green) (filter (/= PassCriterion) allGateCategories)), [("pass-criterion", "qualified-gate-pass")])

showText :: Int -> Text
showText = Text.pack . show
