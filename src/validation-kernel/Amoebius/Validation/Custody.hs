{-# LANGUAGE OverloadedStrings #-}
-- | The command surface of the verifier (gate_runner_doctrine.md section 6;
-- DL-0013). Every command is agent-run. @preview@ runs the complete gate and
-- mints nothing; @accept@ runs it again and, when every row is green, records
-- the receipt, writes its reproducible digest beside the Done status, and
-- applies exactly one phase's status patch; @replay@ re-derives recorded
-- receipts; @reset@ records a receipt-bearing reset; @demo@ records an
-- operator-authored input's digest. A receipt's authority is that it reproduces.
module Amoebius.Validation.Custody
  ( CommandOutcome (..)
  , CustodyConfig (..)
  , acceptPhase
  , defaultCustodyConfig
  , demoFile
  , previewPhase
  , replayThrough
  , resetGeneration
  ) where
import Amoebius.Plan.Decisions qualified as Decisions
import Amoebius.Plan.Legacy qualified as Legacy
import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Plan.StatusFrontier qualified as Status
import Amoebius.Validation.Compatibility (closureDigest)
import Amoebius.Validation.Custody.Preflight
import Amoebius.Validation.Custody.Status
import Amoebius.Validation.Custody.Store
import Amoebius.Validation.GateSpec
import Amoebius.Validation.GateSpec.Registry (specInputFor)
import Amoebius.Validation.Runner
import Amoebius.Validation.Runner.Capture
import Amoebius.Validation.Runner.Hygiene (hygieneProblems, hygieneRow)
import Amoebius.Validation.Runner.Mutants (renderKillTable)
import Amoebius.Validation.Runner.Observer (ObservedRun (..), observe, renderObserved, runExit, runStderr, runStdout, sha256Hex)
import Amoebius.Validation.Runner.Spec (loadPackageGraph, verifySpec)
import Control.Exception (IOException, try)
import Control.Monad (filterM, foldM)
import Data.List (isSuffixOf, sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time.Clock (getCurrentTime)
import System.Directory (doesFileExist, makeAbsolute, removePathForcibly)
import System.Exit (ExitCode (..))
import System.FilePath (makeRelative, (</>))
data CustodyConfig = CustodyConfig
  { custodyRoot :: FilePath
  , custodyStore :: Store
  , custodyDocCheckCap :: Int
  , custodyMutantLimit :: Maybe Int
  , custodyCabal :: Maybe FilePath
  , custodyCompiler :: Maybe FilePath
  }
  deriving (Eq, Show)
defaultCustodyConfig :: FilePath -> CustodyConfig
defaultCustodyConfig root = CustodyConfig root defaultStore 7000 Nothing Nothing Nothing
archiveRoot :: CustodyConfig -> FilePath
archiveRoot config = custodyRoot config </> "validation-records"
data CommandOutcome = CommandOutcome
  { outcomeExit :: ExitCode
  , outcomeLines :: [Text]
  }
  deriving (Eq, Show)
refuse :: [Text] -> CommandOutcome
refuse = CommandOutcome (ExitFailure 1)
roleFor :: Int -> GateRole
roleFor ordinal
  | ordinal == PhaseIdentity.phaseDomainLowerOrdinal = SeedGate
  | Just ordinal == PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier = BarrierGate
  | maybe False (ordinal >=) (PhaseIdentity.roleOrdinal PhaseIdentity.FirstHardware) = HardwareGate
  | otherwise = OrdinaryGate
-- | Resolve an ordinal to its identity row and specification.
resolveSpec :: Int -> Either [Text] (PhaseIdentity.PhaseIdentity, GateSpec)
resolveSpec ordinal = do
  row <- maybe (Left ["PHASE-ABSENT: " <> Text.pack (show ordinal)]) Right (PhaseIdentity.lookupPhaseIdentity ordinal)
  let capability = PhaseIdentity.phaseIdentityCapability row
  input <- maybe (Left ["SPEC-ABSENT: no gate specification is registered for " <> capability]) Right (specInputFor capability)
  spec <- either (Left . map renderSpecRefusal) Right (mkGateSpec (roleFor ordinal) input)
  pure (row, spec)
runnerConfig :: CustodyConfig -> Int -> RunnerConfig
runnerConfig config ordinal =
  (defaultRunnerConfig (custodyRoot config) ordinal)
    { runnerHygienePreflight = False
    , runnerDocCheckCap = custodyDocCheckCap config
    , runnerMutantLimit = custodyMutantLimit config
    , runnerProductBinary = Nothing
    , runnerCabal = fromMaybe "cabal" (custodyCabal config)
    , runnerCompiler = custodyCompiler config
    }
-- | Run the gate in a fresh run root.
runFresh :: CustodyConfig -> Int -> GateSpec -> Maybe Text -> IO (Either RunnerRefusal GateOutcome)
runFresh config ordinal spec predecessor = do
  let runnerSettings = (runnerConfig config ordinal) {runnerPredecessorDigest = predecessor}
  removePathForcibly (runnerRunRoot runnerSettings)
  binary <- case gateBinaryFact spec of
    Nothing -> pure (Right Nothing)
    Just _ -> fmap Just <$> productBinary config
  case binary of
    Left problem -> pure (Left (ProductBinaryUnavailable problem))
    Right path -> runGate runnerSettings {runnerProductBinary = path} spec
-- | Build the shipped executable serially and locate it; a specification with a
-- binary fact runs its public command through this exact file.
productBinary :: CustodyConfig -> IO (Either Text FilePath)
productBinary config = do
  let root = custodyRoot config
      cabal = fromMaybe "cabal" (custodyCabal config)
      compiler = maybe [] (\path -> ["--with-compiler=" <> path]) (custodyCompiler config)
  build <- observe root cabal (["build", "-v0", "--jobs=1"] <> compiler <> ["exe:amoebius"])
  if runExit build /= ExitSuccess
    then pure (Left ("exe:amoebius did not build: " <> Text.take 400 (runStderr build)))
    else do
      located <- observe root cabal (["list-bin", "--jobs=1"] <> compiler <> ["exe:amoebius"])
      let path = Text.unpack (Text.strip (runStdout located))
      present <- doesFileExist path
      pure (if runExit located == ExitSuccess && present then Right path else Left ("exe:amoebius not located: " <> Text.take 200 (runStderr located)))
-- | The predecessor's recorded reproducible digest among the receipts, when the
-- phase has a predecessor.
predecessorDigestFrom :: Int -> StatusSurface -> [Receipt] -> Maybe Text
predecessorDigestFrom ordinal surface receipts = do
  predecessor <- PhaseIdentity.predecessorOrdinal ordinal
  digest <- lookup predecessor (surfaceReceipts surface)
  if any (\receipt -> receiptPhase receipt == predecessor && receiptReproducible receipt == digest && isNothing (receiptResetCause receipt)) receipts
    then Just digest else Nothing
-- | The reproducible digest of a run: the candidate's core plus the closure,
-- verifier, and governance digests.
reproducibleDigest :: Text -> Text -> Text -> Text -> Text
reproducibleDigest core closure verifier governance =
  sha256Hex (Text.unlines ["core\t" <> core, "closure\t" <> closure, "verifier\t" <> verifier, "governance\t" <> governance])
closureFor :: CustodyConfig -> GateSpec -> Text -> IO Text
closureFor config spec verifier = do
  graph <- loadPackageGraph (custodyRoot config)
  verified <- verifySpec (custodyRoot config) spec
  case (graph, verified) of
    (Right g, Right v) -> closureDigest (custodyRoot config) g v verifier governanceDigest
    _ -> pure "closure-unavailable"
isAncestor :: FilePath -> Text -> IO Bool
isAncestor root commit = do
  absolute <- makeAbsolute root
  run <- observe root "git" ["-c", "safe.directory=" <> absolute, "merge-base", "--is-ancestor", Text.unpack commit, "HEAD"]
  pure (runExit run == ExitSuccess)
headCommit :: FilePath -> IO Text
headCommit root = do
  absolute <- makeAbsolute root
  Text.strip . runStdout <$> observe root "git" ["-c", "safe.directory=" <> absolute, "rev-parse", "HEAD"]
archiveCommitted :: CustodyConfig -> FilePath -> IO Bool
archiveCommitted config bundle = do
  let root = custodyRoot config
      path = makeRelative root bundle
      names = ["receipt.tsv", "receipt.tsv.sha256", "candidate.tsv", "kill-table.tsv", "outcome.tsv", "oracle-ledger.tsv", "observer.tsv"]
  tracked <- observe root "git" (["ls-files", "--error-unmatch", "--"] <> map (path </>) names)
  clean <- observe root "git" ["status", "--porcelain", "--", path]
  pure (runExit tracked == ExitSuccess && runExit clean == ExitSuccess && Text.null (Text.strip (runStdout clean)))
-- An uncommitted bundle cannot authenticate itself. Re-run its complete gate
-- before admitting it as a predecessor in this worktree.
predecessorProven :: CustodyConfig -> Text -> StatusSurface -> [Receipt] -> Receipt -> FilePath -> IO Bool
predecessorProven config verifier surface receipts receipt path = do
  ancestor <- isAncestor (custodyRoot config) (receiptTreeCommit receipt)
  durable <- archiveCommitted config path
  if not ancestor then pure False else if durable then pure True
  else if receiptStatusPostimage receipt /= surfaceDigest surface then pure False
  else case resolveSpec (receiptPhase receipt) of
    Left _ -> pure False
    Right (_, spec) -> do
      checked <- runFresh config (receiptPhase receipt) spec (predecessorDigestFrom (receiptPhase receipt) surface receipts)
      closure <- closureFor config spec verifier
      pure $ case checked of
        Right outcome -> let candidate = outcomeCandidate outcome in candidateGreen candidate
          && reproducibleDigest (candidateReproducibleCore candidate) closure verifier governanceDigest == receiptReproducible receipt
        Left _ -> False
-- | Gather the preflight facts for a phase.
gatherFacts :: CustodyConfig -> Int -> GateSpec -> IO (Either Text (PreflightFacts, StatusSurface, Maybe SeedRecord, [Receipt], [(Receipt, FilePath)], Text))
gatherFacts config ordinal spec = do
  audited <- auditArchivedInventory (custodyRoot config)
  either (pure . Left) (gatherFactsChecked config ordinal spec) audited
gatherFactsChecked :: CustodyConfig -> Int -> GateSpec -> Text -> IO (Either Text (PreflightFacts, StatusSurface, Maybe SeedRecord, [Receipt], [(Receipt, FilePath)], Text))
gatherFactsChecked config ordinal spec archiveDigest = do
  let root = custodyRoot config
      store = custodyStore config
  surface <- statusSurface root
  case surface of
    Left problem -> pure (Left problem)
    Right recorded -> do
      verifier <- verifierDigest
      seed <- latestGeneration store verifier
      archived <- readCurrentArchivedBundles (archiveRoot config) verifier
      case archived of
        Left problem -> pure (Left problem)
        Right bundles -> do
          let allReceipts = map fst bundles
          let receipts = [receipt | receipt <- allReceipts, isNothing (receiptResetCause receipt)]
          host <- hostFacts
          hygiene <- hygieneRow root Nothing (custodyDocCheckCap config)
          compatible <- mapM (\phase -> case resolveSpec phase of
            Left _ -> pure (phase, Nothing)
            Right (_, current) -> do
              closure <- closureFor config current verifier
              pure (phase, Just (closure, renderGateSpec current)))
            [phase | Just f <- [recordedFrontier recorded], phase <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt f phase == Status.Done]
          let frontier = recordedFrontier recorded
              donePhases = [phase | Just f <- [frontier], phase <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt f phase == Status.Done]
              doneWithout = [phase | phase <- donePhases, phase `notElem` map fst (surfaceReceipts recorded)]
              notReproduced =
                [ phase
                | phase <- donePhases
                , Just digest <- [lookup phase (surfaceReceipts recorded)]
                , not (any (\receipt -> receiptPhase receipt == phase && receiptReproducible receipt == digest && receiptGovernanceDigest receipt == governanceDigest && Just (Just (receiptClosureDigest receipt, receiptSpecRendered receipt)) == lookup phase compatible) receipts)
                ]
              acceptedPostimage = case sortOn receiptIssuedAt allReceipts of
                [] -> seedStatusPostimage <$> seed
                sorted -> Just (receiptStatusPostimage (last sorted))
              predecessorReceipt =
                [ (receipt, path)
                | Just p <- [PhaseIdentity.predecessorOrdinal ordinal]
                , Just digest <- [lookup p (surfaceReceipts recorded)]
                , (receipt, path) <- bundles
                , receiptPhase receipt == p
                , receiptReproducible receipt == digest
                , Just (Just (receiptClosureDigest receipt, receiptSpecRendered receipt)) == lookup p compatible
                ]
          committed <- case predecessorReceipt of
            matches@(_ : _) -> Just . or <$> mapM (\(receipt, path) -> predecessorProven config verifier recorded receipts receipt path) matches
            [] -> pure Nothing
          pure (Right (PreflightFacts spec (surfaceDigest recorded) acceptedPostimage committed doneWithout notReproduced []
            (any (\receipt -> Just (receiptPhase receipt) == PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier) receipts)
            host (hygieneProblems hygiene) Nothing, recorded, seed, receipts, bundles, archiveDigest))
archiveStable :: CustodyConfig -> [(Receipt, FilePath)] -> Either Text Text -> IO Bool
archiveStable config before previous = do
  audited <- auditArchivedInventory (custodyRoot config)
  verifier <- verifierDigest
  current <- readCurrentArchivedBundles (archiveRoot config) verifier
  pure (case (previous, audited) of (Right old, Right now) -> old == now && current == Right before; _ -> False)
-- | Ensure the generation record for the running verifier exists.
ensureGeneration :: CustodyConfig -> Text -> Text -> StatusSurface -> IO (Either Text SeedRecord)
ensureGeneration config verifier enteredBy recorded = do
  let store = custodyStore config
  existing <- latestGeneration store verifier
  case existing of
    Just seed -> pure (Right seed)
    Nothing -> do
      commit <- headCommit (custodyRoot config)
      now <- getCurrentTime
      let seed =
            SeedRecord
              { seedGeneration = verifier
              , seedEnteredBy = enteredBy
              , seedVerifierDigest = verifier
              , seedGovernanceDigest = governanceDigest
              , seedStatusPostimage = surfaceDigest recorded
              , seedTreeCommit = commit
              , seedIssuedAt = Text.pack (show now)
              }
      written <- writeSeed store seed
      pure (either Left (const (Right seed)) written)
renderRows :: Candidate -> [Text]
renderRows candidate = ["row\t" <> renderGateCategory (rowCategory r) <> "\t" <> renderVerdict (rowVerdict r) | r <- candidateRows candidate]
archiveEvidence :: GateSpec -> GateOutcome -> Either Text [(FilePath, Text)]
archiveEvidence spec outcome = case cleanOracle of
  [] -> Left "ARCHIVE-ORACLE-ABSENT: no clean oracle transcript can be archived"
  (ledger : _) -> Right
    [ ("candidate.tsv", renderCandidate candidate)
    , ("kill-table.tsv", Text.unlines (renderKillTable (outcomeKillTable outcome)))
    , ("outcome.tsv", Text.unlines ["green\tTrue", "spec-digest\t" <> candidateSpecDigest candidate, "chain\t" <> candidateChain candidate, "reproducible-core\t" <> candidateReproducibleCore candidate, "capability\t" <> gateCapability spec, "claim\t" <> gateClaim spec])
    , ("oracle-ledger.tsv", ledger)
    , ("observer.tsv", Text.unlines [key <> "\t" <> value | (index, run) <- zip [1 :: Int ..] (outcomeRuns outcome), (key, value) <- renderObserved ("run." <> Text.pack (show index)) run])
    ]
 where
  candidate = outcomeCandidate outcome
  oracleTarget = "amoebius:test:" <> Text.unpack (oracleExecutableName (gateOracle spec))
  cleanOracle =
    [ runStdout run
    | run <- outcomeRuns outcome
    , oracleTarget `elem` runArgv run
    , any (("clean" </> "suite") `isSuffixOf`) (runArgv run)
    , runExit run == ExitSuccess
    ]
publishReceipt :: CustodyConfig -> GateSpec -> GateOutcome -> [(FilePath, Text)] -> Receipt -> IO (Either Text FilePath)
publishReceipt config spec outcome patch receipt = case archiveEvidence spec outcome of
  Left problem -> pure (Left problem)
  Right evidence -> do
    let root = custodyRoot config
    originals <- mapM (\(path, _) -> (,) path <$> TextIO.readFile (root </> path)) patch
    applied <- try (mapM_ (\(path, contents) -> TextIO.writeFile (root </> path) contents) patch) :: IO (Either IOException ())
    case applied of
      Left problem -> restore originals >> pure (Left (Text.pack (show problem)))
      Right () -> do
        after <- statusSurface root
        archived <- case after of
          Left problem -> pure (Left problem)
          Right surface -> writeArchivedReceipt (archiveRoot config) receipt {receiptStatusPostimage = surfaceDigest surface} evidence
        case archived of
          Left problem -> restore originals >> pure (Left problem)
          Right path -> do
            _ <- writeReceipt (custodyStore config) receipt {receiptStatusPostimage = either (const "") surfaceDigest after}
            pure (Right path)
 where
  restore originals = mapM_ (\(path, contents) -> TextIO.writeFile (custodyRoot config </> path) contents) originals
-- | The agent command that mints nothing: preflight, the complete gate, the
-- would-be receipt.
previewPhase :: CustodyConfig -> Int -> IO CommandOutcome
previewPhase config ordinal = case resolveSpec ordinal of
  Left problems -> pure (refuse problems)
  Right (row, spec) -> do
    gathered <- gatherFacts config ordinal spec
    case gathered of
      Left problem -> pure (refuse [problem])
      Right (facts, recorded, _, receipts, bundles, digest) -> do
        let refusals = preflight facts
        runOutcome <- runFresh config ordinal spec (predecessorDigestFrom ordinal recorded receipts)
        stable <- archiveStable config bundles (Right digest)
        pure $ case runOutcome of
          _ | not stable -> refuse ["archive changed during the candidate gate"]
          Left refusal -> CommandOutcome (ExitFailure 1) (map renderPreflightRefusal refusals <> ["RUNNER: " <> renderRefusal refusal])
          Right outcome ->
            let candidate = outcomeCandidate outcome
                green = null refusals && candidateGreen candidate
             in CommandOutcome
                  (if green then ExitSuccess else ExitFailure 1)
                  ( ["preview phase " <> Text.pack (show ordinal) <> " (" <> PhaseIdentity.phaseIdentityCapability row <> "): " <> (if green then "would pass; nothing minted" else "would not pass")]
                      <> map renderPreflightRefusal refusals
                      <> renderRows candidate
                      <> ["claim\t" <> gateClaim spec, "spec-digest\t" <> candidateSpecDigest candidate, "reproducible-core\t" <> candidateReproducibleCore candidate]
                      <> renderKillTable (outcomeKillTable outcome)
                  )
-- | The command that records a phase: the complete gate, then the receipt and
-- exactly one phase's status patch.
acceptPhase :: CustodyConfig -> Int -> IO CommandOutcome
acceptPhase config ordinal = case resolveSpec ordinal of
  Left problems -> pure (refuse problems)
  Right (row, spec) -> do
    gathered <- gatherFacts config ordinal spec
    case gathered of
      Left problem -> pure (refuse [problem])
      Right (facts, recorded, _, receipts, bundles, digest) -> case preflight facts of
        refusals@(_ : _) -> pure (refuse (map renderPreflightRefusal refusals))
        [] -> case recordedFrontier recorded >>= \frontier -> Status.frontierAfterPass frontier ordinal of
          Nothing -> pure (refuse ["the recorded frontier is not open at phase " <> Text.pack (show ordinal)])
          Just next -> do
            runOutcome <- runFresh config ordinal spec (predecessorDigestFrom ordinal recorded receipts)
            stable <- archiveStable config bundles (Right digest)
            case runOutcome of
              _ | not stable -> pure (refuse ["archive changed during the candidate gate"])
              Left refusal -> pure (refuse ["RUNNER: " <> renderRefusal refusal])
              Right outcome
                | not (candidateGreen (outcomeCandidate outcome)) ->
                    pure (refuse ("the candidate is not green" : [line | line <- renderRows (outcomeCandidate outcome), not ("\tgreen" `Text.isSuffixOf` line)]))
                | otherwise -> issueAccept config ordinal row spec recorded next outcome
issueAccept :: CustodyConfig -> Int -> PhaseIdentity.PhaseIdentity -> GateSpec -> StatusSurface -> Status.StatusFrontier -> GateOutcome -> IO CommandOutcome
issueAccept config ordinal row spec recorded next outcome = do
  let root = custodyRoot config
      candidate = outcomeCandidate outcome
      table = outcomeKillTable outcome
  verifier <- verifierDigest
  closure <- closureFor config spec verifier
  let reproducible = reproducibleDigest (candidateReproducibleCore candidate) closure verifier governanceDigest
  generation <- ensureGeneration config verifier ("accept phase " <> Text.pack (show ordinal)) recorded
  case generation of
    Left problem -> pure (refuse ["generation not recorded: " <> problem])
    Right seed -> do
      let receipts = Map.insert ordinal reproducible (Map.fromList (surfaceReceipts recorded))
      patch <- patchToFrontier root next receipts
      commit <- headCommit root
      now <- getCurrentTime
      let tableText = Text.unlines (renderKillTable table)
          witnessRows = [Text.intercalate " " (take 2 (drop 1 fields) <> drop 3 (take 4 fields)) | line <- Text.lines tableText, let fields = Text.splitOn "\t" line, length fields >= 5, fields !! 3 /= "no-witness"]
          receipt =
            Receipt
              { receiptPhase = ordinal
              , receiptCapability = PhaseIdentity.phaseIdentityCapability row
              , receiptGeneration = seedGeneration seed
              , receiptSpecDigest = candidateSpecDigest candidate
              , receiptSpecRendered = renderGateSpec spec
              , receiptCandidateDigest = sha256Hex (renderCandidate candidate)
              , receiptKillTableDigest = sha256Hex tableText
              , receiptClosureDigest = closure
              , receiptReproducible = reproducible
              , receiptVerifierDigest = verifier
              , receiptGovernanceDigest = governanceDigest
              , receiptStatusPostimage = ""
              , receiptTreeCommit = commit
              , receiptWitnesses = witnessRows
              , receiptResetCause = Nothing
              , receiptDemonstration = Nothing
              , receiptIssuedAt = Text.pack (show now)
              }
      written <- publishReceipt config spec outcome patch receipt
      case written of
        Left problem -> pure (refuse ["receipt not recorded: " <> problem])
        Right archive -> do
          pure
            ( CommandOutcome
                ExitSuccess
                ( ["accepted phase " <> Text.pack (show ordinal) <> " (" <> PhaseIdentity.phaseIdentityCapability row <> ")", "claim\t" <> gateClaim spec, "spec-digest\t" <> candidateSpecDigest candidate, "reproducible-digest\t" <> reproducible, "chain\t" <> candidateChain candidate]
                    <> Text.lines tableText
                    <> ["status patch\t" <> Text.pack path | (path, _) <- patch]
                    <> ["receipt\t" <> Text.pack archive]
                )
            )
-- | Re-run Done gates in numerical order and publish each successful result.
voidFromPhase :: CustodyConfig -> Text -> StatusSurface -> Int -> Text -> Text -> IO (Either Text [FilePath])
voidFromPhase config verifier recorded phase reason failure = do
  current <- readCurrentArchivedBundles (archiveRoot config) verifier
  case current of
    Left problem -> pure (Left problem)
    Right bundles -> do
      now <- Text.pack . show <$> getCurrentTime
      sequence <$> mapM (\(receipt, path) -> writeReplayVoid (archiveRoot config) receipt path reason (sha256Hex failure) now)
        [(receipt, path) | (receipt, path) <- bundles, receiptPhase receipt >= phase
          , lookup (receiptPhase receipt) (surfaceReceipts recorded) == Just (receiptReproducible receipt)]
replayThrough :: CustodyConfig -> Maybe Int -> IO CommandOutcome
replayThrough config through = do
  audited <- auditArchivedInventory (custodyRoot config)
  either (pure . refuse . (: [])) (const (replayThroughChecked config through)) audited
replayThroughChecked :: CustodyConfig -> Maybe Int -> IO CommandOutcome
replayThroughChecked config through = do
  let root = custodyRoot config
  surface <- statusSurface root
  case surface of
    Left problem -> pure (refuse [problem])
    Right recorded -> case recordedFrontier recorded of
      Nothing -> pure (refuse ["the tracker does not record one frontier"])
      Just frontier -> do
        verifier <- verifierDigest
        let donePhases = [phase | phase <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt frontier phase == Status.Done, maybe True (phase <=) through]
        generation <- ensureGeneration config verifier "replay" recorded
        case generation of
          Left problem -> pure (refuse ["generation not recorded: " <> problem])
          Right seed -> do
            result <- foldM (replayOne config seed verifier) (Right []) donePhases
            pure $ case result of
              Left problem -> refuse problem
              Right lines' -> CommandOutcome ExitSuccess ("replay complete for " <> Text.intercalate "," (map (Text.pack . show) donePhases) : reverse lines')
replayOne :: CustodyConfig -> SeedRecord -> Text -> Either [Text] [Text] -> Int -> IO (Either [Text] [Text])
replayOne _ _ _ (Left problem) _ = pure (Left problem)
replayOne config seed verifier (Right done) phase = do
  surface <- statusSurface (custodyRoot config)
  archived <- readCurrentArchivedBundles (archiveRoot config) verifier
  case (surface, archived) of
    (Left problem, _) -> pure (Left (reverse done <> [problem]))
    (_, Left problem) -> pure (Left (reverse done <> [problem]))
    (Right recorded, Right bundles) -> case lookup phase (surfaceReceipts recorded) of
      Nothing -> pure (Left (reverse done <> ["STATUS-WITHOUT-RECEIPT: phase " <> Text.pack (show phase) <> " is Done without a receipt line"]))
      Just recordedDigest -> case (resolveSpec phase, recordedFrontier recorded) of
            (Left problems, _) -> pure (Left (reverse done <> problems))
            (_, Nothing) -> pure (Left (reverse done <> ["the tracker does not record one frontier"]))
            (Right (row, spec), Just frontier) -> do
              predecessors <- filterM (\(receipt, path) -> case resolveSpec (receiptPhase receipt) of
                Left _ -> pure False
                Right (_, priorSpec) -> do
                  closure <- closureFor config priorSpec verifier
                  ancestor <- isAncestor (custodyRoot config) (receiptTreeCommit receipt)
                  durable <- archiveCommitted config path
                  pure (ancestor && receiptClosureDigest receipt == closure && receiptSpecRendered receipt == renderGateSpec priorSpec && (durable || receiptStatusPostimage receipt == surfaceDigest recorded)))
                    [ (receipt, path)
                    | Just predecessor <- [PhaseIdentity.predecessorOrdinal phase]
                    , Just digest <- [lookup predecessor (surfaceReceipts recorded)]
                    , (receipt, path) <- bundles
                    , receiptPhase receipt == predecessor
                    , receiptReproducible receipt == digest
                    ]
              if phase /= PhaseIdentity.phaseDomainLowerOrdinal && (null done || null predecessors)
                then pure (Left (reverse done <> ["PredecessorNotReproduced: no freshly replayed and exact-read immediate predecessor for phase " <> Text.pack (show phase)]))
                else do
                  snapshot <- auditArchivedInventory (custodyRoot config)
                  runOutcome <- runFresh config phase spec (predecessorDigestFrom phase recorded (map fst predecessors))
                  case runOutcome of
                    Left refusal -> do
                      voided <- voidFromPhase config verifier recorded phase "runner-refusal" (renderRefusal refusal)
                      pure (Left (reverse done <> ["RUNNER: " <> renderRefusal refusal] <> either (\problem -> ["void record unavailable: " <> problem]) (const []) voided))
                    Right outcome -> do
                      closure <- closureFor config spec verifier
                      let candidate = outcomeCandidate outcome
                          reproducible = reproducibleDigest (candidateReproducibleCore candidate) closure verifier governanceDigest
                      if not (candidateGreen candidate)
                        then do
                          voided <- voidFromPhase config verifier recorded phase "gate-red" (Text.unlines (renderRows candidate))
                          pure (Left (reverse done <> ["PredecessorNotReproduced: phase " <> Text.pack (show phase) <> " recorded " <> recordedDigest <> " but its gate is red on the current tree:"] <> [line | line <- renderRows candidate, not ("\tgreen" `Text.isSuffixOf` line)] <> either (\problem -> ["void record unavailable: " <> problem]) (const []) voided))
                        else do
                          stable <- archiveStable config bundles snapshot
                          if not stable then pure (Left (reverse done <> ["archive changed during the replay gate"])) else do
                            commit <- headCommit (custodyRoot config)
                            now <- getCurrentTime
                            let tableText = Text.unlines (renderKillTable (outcomeKillTable outcome))
                                receipt = Receipt phase (PhaseIdentity.phaseIdentityCapability row) (seedGeneration seed)
                                  (candidateSpecDigest candidate) (renderGateSpec spec) (sha256Hex (renderCandidate candidate))
                                  (sha256Hex tableText) closure reproducible verifier governanceDigest "" commit [] Nothing Nothing (Text.pack (show now))
                            patch <- patchToFrontier (custodyRoot config) frontier (Map.insert phase reproducible (Map.fromList (surfaceReceipts recorded)))
                            written <- publishReceipt config spec outcome patch receipt
                            pure $ case written of
                              Left problem -> Left (reverse done <> ["receipt not recorded: " <> problem])
                              Right _ -> Right (("phase " <> Text.pack (show phase) <> if reproducible == recordedDigest then "\treproduced (new archive)" else "\trefreshed (" <> Text.take 16 recordedDigest <> " -> " <> Text.take 16 reproducible <> ")") : done)
-- | The receipt-bearing reset: a receipt at the frontier's phase whose reset
-- cause names a validator gap and a product-gap legacy identifier with an owner.
resetGeneration :: CustodyConfig -> Text -> Text -> Text -> IO CommandOutcome
resetGeneration config decision validatorGap productGap =
  case (Decisions.parseDecisionId decision, Legacy.parseLegacyId productGap) of
    (Nothing, _) -> pure (refuse ["DECISION-UNKNOWN: " <> decision])
    (_, Nothing) -> pure (refuse ["PRODUCT-GAP-UNKNOWN: " <> productGap])
    (Just _, Just identifier) -> case Legacy.legacyOwnerOrdinal identifier of
      Nothing -> pure (refuse ["PRODUCT-GAP-UNOWNED: " <> productGap])
      Just owner -> do
        let root = custodyRoot config
        surface <- statusSurface root
        case surface of
          Left problem -> pure (refuse [problem])
          Right recorded -> case recordedFrontier recorded of
            Nothing -> pure (refuse ["the tracker does not record one frontier"])
            Just frontier -> do
              verifier <- verifierDigest
              generation <- ensureGeneration config verifier ("reset " <> decision) recorded
              case generation of
                Left problem -> pure (refuse ["generation not recorded: " <> problem])
                Right seed -> do
                  let phase = Status.completedPrefixDueOrdinal frontier
                  commit <- headCommit root
                  now <- getCurrentTime
                  let receipt =
                        Receipt
                          { receiptPhase = phase
                          , receiptCapability = maybe "" PhaseIdentity.phaseIdentityCapability (PhaseIdentity.lookupPhaseIdentity phase)
                          , receiptGeneration = seedGeneration seed
                          , receiptSpecDigest = "reset"
                          , receiptSpecRendered = ""
                          , receiptCandidateDigest = "reset"
                          , receiptKillTableDigest = "reset"
                          , receiptClosureDigest = "reset"
                          , receiptReproducible = "reset"
                          , receiptVerifierDigest = verifier
                          , receiptGovernanceDigest = governanceDigest
                          , receiptStatusPostimage = surfaceDigest recorded
                          , receiptTreeCommit = commit
                          , receiptWitnesses = []
                          , receiptResetCause = Just (validatorGap, productGap)
                          , receiptDemonstration = Nothing
                          , receiptIssuedAt = Text.pack (show now)
                          }
                  written <- writeReceipt (custodyStore config) receipt
                  pure $ case written of
                    Left problem -> refuse ["reset receipt not recorded: " <> problem]
                    Right () -> CommandOutcome ExitSuccess ["reset recorded under " <> decision <> " naming " <> productGap <> " (owner phase " <> Text.pack (show owner) <> ") at frontier phase " <> Text.pack (show phase)]
-- | Record the digest of an operator-authored input for the barrier's
-- demonstration.
demoFile :: CustodyConfig -> FilePath -> IO CommandOutcome
demoFile config path = do
  exists <- doesFileExist path
  if not exists
    then pure (refuse ["DEMO-FILE-ABSENT: " <> Text.pack path])
    else do
      surface <- statusSurface (custodyRoot config)
      case surface of
        Left problem -> pure (refuse [problem])
        Right recorded -> do
          verifier <- verifierDigest
          generation <- ensureGeneration config verifier "demo" recorded
          case generation of
            Left problem -> pure (refuse ["generation not recorded: " <> problem])
            Right seed -> do
              contents <- TextIO.readFile path
              now <- getCurrentTime
              let digest = sha256Hex contents
              written <- writeRecord (generationDirectory (custodyStore config) (seedGeneration seed) </> "demonstration.tsv") (Text.unlines ["file\t" <> Text.pack path, "digest\t" <> digest, "issued-at\t" <> Text.pack (show now)])
              pure $ case written of
                Left problem -> refuse ["demonstration not recorded: " <> problem]
                Right () -> CommandOutcome ExitSuccess ["operator demonstration recorded: " <> Text.take 16 digest]
