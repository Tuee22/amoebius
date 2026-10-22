{-# LANGUAGE OverloadedStrings #-}
-- | Verifier commands and reproducible receipt custody (gate_runner_doctrine.md section 6; DL-0013).
module Amoebius.Validation.Custody
  ( CommandOutcome (..), CustodyConfig (..), defaultCustodyConfig, acceptPhase, demoFile, previewPhase, replayThrough
  , resetGeneration, runFresh, voidFromPhase, receiptCompatibility ) where
import Amoebius.Toolchain.Acquire qualified as Tools
import Amoebius.Plan.Decisions qualified as Decisions
import Amoebius.Plan.Legacy qualified as Legacy
import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Amoebius.Plan.StatusFrontier qualified as Status
import Amoebius.Validation.Compatibility (closureDigest)
import Amoebius.Validation.Custody.Preflight
import Amoebius.Validation.Custody.Status
import Amoebius.Validation.Custody.Store
import Amoebius.Validation.GateSpec
import Amoebius.Validation.GateSpec.Registry (registeredSpecInputs)
import Amoebius.Validation.Runner
import Amoebius.Validation.Runner.Capture
import Amoebius.Validation.Runner.Hygiene (hygieneGreen, hygieneProblems, hygieneRow, readSourceText, sourceAttempt)
import Amoebius.Validation.Runner.Mutants (renderKillTable)
import Amoebius.Validation.Runner.Observer (ObservedRun (..), observe, renderObserved, sha256Hex)
import Amoebius.Validation.Runner.Spec (loadPackageGraph, verifySpec, resolveSpec)
import Control.Exception (IOException, try)
import Control.Monad (filterM, foldM)
import Data.List (isSuffixOf, sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isJust, isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time.Clock (getCurrentTime)
import System.Directory (doesFileExist, makeAbsolute)
import System.Exit (ExitCode (..))
import System.FilePath (makeRelative, (</>))
data CustodyConfig = CustodyConfig
  { custodyRoot :: FilePath, custodyStore :: Store, custodyDocCheckCap :: Int
  , custodyMutantLimit :: Maybe Int, custodyCabal :: Maybe FilePath, custodyCompiler :: Maybe FilePath } deriving (Eq, Show)
defaultCustodyConfig :: FilePath -> CustodyConfig
defaultCustodyConfig root = CustodyConfig root (Store ".build/certification") 7000 Nothing Nothing Nothing
archiveRoot :: CustodyConfig -> FilePath
archiveRoot config = custodyRoot config </> "validation-records"
data CommandOutcome = CommandOutcome
  { outcomeExit :: ExitCode, outcomeLines :: [Text] } deriving (Eq, Show)
receiptCompatibility :: Int -> Text -> Text -> Text -> Maybe (Text, Text) -> Receipt -> Either Text ()
receiptCompatibility phase digest verifier governance expected receipt = case [reason | (valid,reason) <- [(receiptPhase receipt == phase && receiptReproducible receipt == digest && Just (receiptCapability receipt) == fmap PhaseIdentity.phaseIdentityCapability (PhaseIdentity.lookupPhaseIdentity phase),"ReceiptIdentityMismatch"),(receiptGeneration receipt == verifier && receiptVerifierDigest receipt == verifier,"ReceiptVerifierMismatch"),(receiptGovernanceDigest receipt == governance,"ReceiptGovernanceMismatch"),(maybe False (\(closure,_) -> Text.length closure == 64 && Text.all (\c -> c `elem` ("0123456789abcdef" :: String)) closure) expected,"ReceiptClosureUnavailable"),(fmap fst expected == Just (receiptClosureDigest receipt),"ReceiptClosureMismatch"),(fmap snd expected == Just (receiptSpecRendered receipt),"ReceiptSpecificationMismatch")],not valid] of [] -> Right (); reason : _ -> Left reason
refuse :: [Text] -> CommandOutcome
refuse = CommandOutcome (ExitFailure 1)
runnerConfig :: CustodyConfig -> Int -> RunnerConfig
runnerConfig config ordinal =
  (defaultRunnerConfig (custodyRoot config) ordinal)
    { runnerHygienePreflight = False, runnerDocCheckCap = custodyDocCheckCap config
    , runnerMutantLimit = custodyMutantLimit config, runnerCabal = fromMaybe "cabal" (custodyCabal config)
    , runnerCompiler = custodyCompiler config }
-- | Run the gate in a fresh run root.
runFresh :: CustodyConfig -> Int -> GateSpec -> Maybe (Text, PassedGate) -> IO (Either RunnerRefusal GateOutcome)
runFresh config ordinal spec predecessor = either (Left . SourceCaptureRefused) id <$> sourceAttempt (withResult (archivedKernelCap (custodyRoot config)) (pure . Left . KernelRatchetUnavailable) $ \cap -> do
      hygiene <- hygieneRow (custodyRoot config) cap (custodyDocCheckCap config)
      if not (hygieneGreen hygiene) then pure (Left (HygieneRefused hygiene)) else runBound cap)
 where
  runBound cap = withResult (Tools.selectToolchain (custodyRoot config) (Tools.ToolchainPaths Nothing (custodyCompiler config) (custodyCabal config)))
      (pure . Left . ProductBinaryUnavailable . Text.intercalate "; " . map Tools.renderRefusal) $ \selected -> do
        let native = config {custodyCompiler = Just (Tools.acquisitionCompiler selected), custodyCabal = Just (Tools.acquisitionPackageTool selected)}
            settings = (runnerConfig native ordinal) {runnerPredecessorDigest = fmap fst predecessor, runnerPredecessorGate = fmap snd predecessor, runnerLastAcceptedKernelLines = cap}
        now <- getCurrentTime
        runGate settings {runnerRunRoot = runnerRunRoot settings </> Text.unpack (sha256Hex (Text.pack (show now)))} spec
-- Reproduce the recorded immediate predecessor; metadata alone supplies no handle.
reproducePredecessor :: CustodyConfig -> Text -> StatusSurface -> [(Receipt, FilePath)] -> Int -> IO (Maybe (Text, PassedGate))
reproducePredecessor config verifier surface bundles ordinal = case [(receipt, path) | Just predecessor <- [PhaseIdentity.predecessorOrdinal ordinal], Just digest <- [lookup predecessor (surfaceReceipts surface)], (receipt, path) <- bundles, receiptPhase receipt == predecessor, receiptReproducible receipt == digest, isNothing (receiptResetCause receipt)] of
  [(receipt, path)] -> fmap (\passed -> (receiptReproducible receipt, passed)) <$> predecessorProven config verifier surface bundles receipt path
  _ -> pure Nothing
-- | Bind candidate core, closure, verifier and governance in a reproducible digest.
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
gitObserved :: FilePath -> [String] -> IO ObservedRun
gitObserved root args = makeAbsolute root >>= \absolute -> observe root "git" (["-c", "safe.directory=" <> absolute] <> args)
isAncestor :: FilePath -> Text -> IO Bool
isAncestor root commit = (== ExitSuccess) . runExit <$> gitObserved root ["merge-base", "--is-ancestor", Text.unpack commit, "HEAD"]
headCommit :: FilePath -> IO Text
headCommit root = Text.strip . runStdout <$> gitObserved root ["rev-parse", "HEAD"]
archiveCommitted :: CustodyConfig -> FilePath -> IO Bool
archiveCommitted config bundle = do
  let root = custodyRoot config
      path = makeRelative root bundle
      names = ["receipt.tsv", "receipt.tsv.sha256", "candidate.tsv", "kill-table.tsv", "outcome.tsv", "oracle-ledger.tsv", "observer.tsv"]
  tracked <- observe root "git" (["ls-files", "--error-unmatch", "--"] <> map (path </>) names)
  clean <- observe root "git" ["status", "--porcelain", "--", path]
  pure (runExit tracked == ExitSuccess && runExit clean == ExitSuccess && Text.null (Text.strip (runStdout clean)))
-- Re-run the complete predecessor before issuing an exact-source handle.
predecessorProven :: CustodyConfig -> Text -> StatusSurface -> [(Receipt, FilePath)] -> Receipt -> FilePath -> IO (Maybe PassedGate)
predecessorProven config verifier surface bundles receipt path = do
  ancestor <- isAncestor (custodyRoot config) (receiptTreeCommit receipt)
  durable <- archiveCommitted config path
  if not ancestor || (not durable && receiptStatusPostimage receipt /= surfaceDigest surface) then pure Nothing
  else case resolveSpec registeredSpecInputs (receiptPhase receipt) of
    Left _ -> pure Nothing
    Right (_, spec) -> do
      predecessor <- reproducePredecessor config verifier surface bundles (receiptPhase receipt)
      checked <- runFresh config (receiptPhase receipt) spec predecessor
      closure <- closureFor config spec verifier
      pure $ case checked of
        Right outcome | reproducibleDigest (candidateReproducibleCore (outcomeCandidate outcome)) closure verifier governanceDigest == receiptReproducible receipt -> outcomePassed outcome
        _ -> Nothing
-- | Gather the preflight facts for a phase.
gatherFacts :: CustodyConfig -> Int -> GateSpec -> IO (Either Text (PreflightFacts, StatusSurface, Maybe SeedRecord, [Receipt], [(Receipt, FilePath)], Text, Maybe (Text, PassedGate)))
gatherFacts config ordinal spec = do
  checked <- (,) <$> auditArchivedInventory (custodyRoot config) <*> archivedKernelCap (custodyRoot config)
  case checked of
    (Left problem, _) -> pure (Left problem)
    (_, Left problem) -> pure (Left problem)
    (Right (digest, _), Right cap) -> gatherFactsChecked config ordinal spec digest cap
gatherFactsChecked :: CustodyConfig -> Int -> GateSpec -> Text -> Maybe Int -> IO (Either Text (PreflightFacts, StatusSurface, Maybe SeedRecord, [Receipt], [(Receipt, FilePath)], Text, Maybe (Text, PassedGate)))
gatherFactsChecked config ordinal spec archiveDigest cap = do
  let root = custodyRoot config
      store = custodyStore config
  withResult (statusSurface root) (pure . Left) $ \recorded -> do
      verifier <- verifierDigest
      seed <- latestGeneration store verifier
      withResult (readCurrentArchivedBundles (archiveRoot config) verifier) (pure . Left) $ \bundles -> do
          let allReceipts = map fst bundles
          let receipts = [receipt | receipt <- allReceipts, isNothing (receiptResetCause receipt)]
          let barrier = any (\receipt -> Just (receiptPhase receipt) == PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier && lookup (receiptPhase receipt) (surfaceReceipts recorded) == Just (receiptReproducible receipt)) receipts
          hygiene <- hygieneRow root cap (custodyDocCheckCap config)
          compatible <- mapM (\phase -> case resolveSpec registeredSpecInputs phase of
            Left _ -> pure (phase, Nothing)
            Right (_, current) -> do
              closure <- closureFor config current verifier
              pure (phase, Just (closure, renderGateSpec current)))
            [phase | Just f <- [recordedFrontier recorded], phase <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt f phase == Status.Done]
          let frontier = recordedFrontier recorded
              donePhases = [phase | Just f <- [frontier], phase <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt f phase == Status.Done]
              doneWithout = [phase | phase <- donePhases, phase `notElem` map fst (surfaceReceipts recorded)]
              receiptMatches phase digest receipt = receiptCompatibility phase digest verifier governanceDigest (lookup phase compatible >>= id) receipt == Right ()
              notReproduced = [phase | phase <- donePhases
                , Just digest <- [lookup phase (surfaceReceipts recorded)]
                , not (any (receiptMatches phase digest) receipts)]
              acceptedPostimage = case sortOn receiptIssuedAt allReceipts of [] -> seedStatusPostimage <$> seed; sorted -> Just (receiptStatusPostimage (last sorted))
          predecessor <- if null notReproduced && null doneWithout && (gateRole spec /= HardwareGate || barrier) then reproducePredecessor config verifier recorded bundles ordinal else pure Nothing
          let committed = if ordinal == PhaseIdentity.phaseDomainLowerOrdinal || not (null notReproduced && null doneWithout) then Nothing else Just (isJust predecessor)
          host <- if gateRole spec == HardwareGate && surfaceConsistent recorded && barrier && null notReproduced && null doneWithout && committed == Just True then hostFacts else pure (HostFacts [HardwareFree])
          pure (Right (PreflightFacts spec (surfaceDigest recorded) acceptedPostimage (surfaceConsistent recorded) committed doneWithout notReproduced []
            barrier
            host (hygieneProblems hygiene) Nothing, recorded, seed, receipts, bundles, archiveDigest, predecessor))
archiveStable :: CustodyConfig -> [(Receipt, FilePath)] -> Either Text Text -> IO Bool
archiveStable config before previous = (\audited current -> case (previous, audited) of (Right old, Right (now, _)) -> old == now && current == Right before; _ -> False)
  <$> auditArchivedInventory (custodyRoot config) <*> (verifierDigest >>= readCurrentArchivedBundles (archiveRoot config))
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
      let seed = SeedRecord
            { seedGeneration = verifier, seedEnteredBy = enteredBy, seedVerifierDigest = verifier
            , seedGovernanceDigest = governanceDigest, seedStatusPostimage = surfaceDigest recorded
            , seedTreeCommit = commit, seedIssuedAt = Text.pack (show now) }
      written <- writeSeed store seed
      pure (either Left (const (Right seed)) written)
renderRows :: Candidate -> [Text]
renderRows candidate = ["row\t" <> renderGateCategory (rowCategory r) <> "\t" <> renderVerdict (rowVerdict r) | r <- candidateRows candidate]
archiveEvidence :: GateSpec -> GateOutcome -> Either Text [(FilePath, Text)]
archiveEvidence spec outcome = case cleanOracle of
  [] -> Left "ARCHIVE-ORACLE-ABSENT: no clean oracle transcript can be archived"
  ledgers | length ledgers == (if isNothing (gateSeed spec) then 1 else 2) -> Right
    [ ("candidate.tsv", renderCandidate candidate)
    , ("kill-table.tsv", Text.unlines (renderKillTable (outcomeKillTable outcome)))
    , ("outcome.tsv", Text.unlines ["green\tTrue", "spec-digest\t" <> candidateSpecDigest candidate, "chain\t" <> candidateChain candidate, "reproducible-core\t" <> candidateReproducibleCore candidate, "capability\t" <> gateCapability spec, "claim\t" <> gateClaim spec])
    , ("oracle-ledger.tsv", Text.concat (reverse ledgers))
    , ("observer.tsv", Text.unlines [key <> "\t" <> value | (index, run) <- zip [1 :: Int ..] (outcomeRuns outcome), (key, value) <- renderObserved ("run." <> Text.pack (show index)) run])
    ]
  _ -> Left "ARCHIVE-ORACLE-CARDINALITY: clean oracle transcripts are missing or repeated"
 where
  candidate = outcomeCandidate outcome
  oracleTarget = "amoebius:test:" <> Text.unpack (oracleExecutableName (gateOracle spec))
  cleanOracle =
    [ runStdout run
    | run <- outcomeRuns outcome
    , any (\(target, scope) -> target `elem` runArgv run && any (scope `isSuffixOf`) (runArgv run)) ((oracleTarget, "clean" </> "suite") : [("amoebius:test:oracle-runner", "custody" </> "suite") | not (isNothing (gateSeed spec))])
    , runExit run == ExitSuccess
    ]
publishReceipt :: CustodyConfig -> GateSpec -> GateOutcome -> [(FilePath, Text)] -> Receipt -> IO (Either Text FilePath)
publishReceipt config spec outcome patch receipt = either (pure . Left) (publishEvidenceReceipt config patch receipt) (archiveEvidence spec outcome)
publishEvidenceReceipt :: CustodyConfig -> [(FilePath, Text)] -> Receipt -> [(FilePath, Text)] -> IO (Either Text FilePath)
publishEvidenceReceipt config patch receipt evidence = do
    let root = custodyRoot config
    originals <- mapM (\(path, _) -> (,) path <$> readSourceText (root </> path)) patch
    applied <- try (mapM_ (\(path, contents) -> TextIO.writeFile (root </> path) contents) patch) :: IO (Either IOException ())
    case applied of
      Left problem -> restore originals >> pure (Left (Text.pack (show problem)))
      Right () -> do
        after <- statusSurface root
        archived <- case after of
          Left problem -> pure (Left problem)
          Right surface | surfaceConsistent surface -> writeArchivedReceipt (archiveRoot config) receipt {receiptStatusPostimage = surfaceDigest surface} evidence
          _ -> pure (Left "status projection is incomplete or inconsistent")
        case archived of
          Left problem -> restore originals >> pure (Left problem)
          Right path -> pure (Right path)
 where
  restore originals = mapM_ (\(path, contents) -> TextIO.writeFile (custodyRoot config </> path) contents) originals
-- | Preflight and the complete gate, without minting a receipt.
previewPhase :: CustodyConfig -> Int -> IO CommandOutcome
previewPhase config ordinal = case resolveSpec registeredSpecInputs ordinal of
  Left problems -> pure (refuse problems)
  Right (row, spec) -> withResult (gatherFacts config ordinal spec) (pure . refuse . pure) $ \(facts, _, _, _, bundles, digest, predecessor) -> do
        let refusals = preflight facts
        runOutcome <- runFresh config ordinal spec predecessor
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
-- | Run the complete gate, publish its receipt, and patch exactly one phase's status.
acceptPhase :: CustodyConfig -> Int -> IO CommandOutcome
acceptPhase config ordinal = case resolveSpec registeredSpecInputs ordinal of
  Left problems -> pure (refuse problems)
  Right (row, spec) -> withResult (gatherFacts config ordinal spec) (pure . refuse . pure) $ \(facts, recorded, _, _, bundles, digest, predecessor) -> case preflight facts of
        refusals@(_ : _) -> pure (refuse (map renderPreflightRefusal refusals))
        [] -> case recordedFrontier recorded >>= \frontier -> Status.frontierAfterPass frontier ordinal of
          Nothing -> pure (refuse ["the recorded frontier is not open at phase " <> Text.pack (show ordinal)])
          Just next -> do
            runOutcome <- runFresh config ordinal spec predecessor
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
  withResult (ensureGeneration config verifier ("accept phase " <> Text.pack (show ordinal)) recorded) (pure . refuse . pure . ("generation not recorded: " <>)) $ \seed -> do
      let receipts = Map.insert ordinal reproducible (Map.fromList (surfaceReceipts recorded))
      patch <- patchToFrontier root next receipts
      commit <- headCommit root
      now <- getCurrentTime
      let tableText = Text.unlines (renderKillTable table)
          witnessRows = [Text.intercalate " " (take 2 (drop 1 fields) <> drop 3 (take 4 fields)) | line <- Text.lines tableText, let fields = Text.splitOn "\t" line, length fields >= 5, fields !! 3 /= "no-witness"]
          receipt = receiptFromGate seed spec outcome closure reproducible commit (Text.pack (show now)) witnessRows
      withResult (publishReceipt config spec outcome patch receipt) (pure . refuse . pure . ("receipt not recorded: " <>)) $ \archive -> pure (CommandOutcome ExitSuccess
          (["accepted phase " <> Text.pack (show ordinal) <> " (" <> PhaseIdentity.phaseIdentityCapability row <> ")", "claim\t" <> gateClaim spec, "spec-digest\t" <> candidateSpecDigest candidate, "reproducible-digest\t" <> reproducible, "chain\t" <> candidateChain candidate]
            <> Text.lines tableText <> ["status patch\t" <> Text.pack path | (path, _) <- patch] <> ["receipt\t" <> Text.pack archive]))
receiptFromGate :: SeedRecord -> GateSpec -> GateOutcome -> Text -> Text -> Text -> Text -> [Text] -> Receipt
receiptFromGate seed spec outcome closure reproducible commit issued witnesses =
  Receipt (candidatePhase candidate) (gateCapability spec) (seedGeneration seed)
    (candidateSpecDigest candidate) (renderGateSpec spec) (sha256Hex (renderCandidate candidate))
    (sha256Hex (Text.unlines (renderKillTable (outcomeKillTable outcome)))) closure reproducible
    (seedVerifierDigest seed) governanceDigest "" commit witnesses Nothing Nothing issued
 where candidate = outcomeCandidate outcome
-- | Re-run Done gates in numerical order and publish each successful result.
voidFromPhase :: CustodyConfig -> Text -> StatusSurface -> Int -> Text -> Text -> IO (Either Text [FilePath])
voidFromPhase config _ recorded phase reason failure = withResult (fmap (fmap snd) (auditArchivedInventory (custodyRoot config))) (pure . Left) $ \bundles ->
    if not (any (\(receipt, _) -> receiptPhase receipt == phase && lookup phase (surfaceReceipts recorded) == Just (receiptReproducible receipt)) bundles) then pure (Left "recorded receipt is absent from the archive")
    else getCurrentTime >>= \now ->
      sequence <$> mapM (\(receipt, path) -> writeReplayVoid (archiveRoot config) receipt path reason (sha256Hex failure) (Text.pack (show now)))
        [(receipt, path) | (receipt, path) <- bundles, receiptPhase receipt >= phase
          , lookup (receiptPhase receipt) (surfaceReceipts recorded) == Just (receiptReproducible receipt)]
replayThrough :: CustodyConfig -> Maybe Int -> IO CommandOutcome
replayThrough config through = withResult (auditArchivedInventory (custodyRoot config)) (pure . refuse . pure) (const (replayThroughChecked config through))
replayThroughChecked :: CustodyConfig -> Maybe Int -> IO CommandOutcome
replayThroughChecked config through = do
  let root = custodyRoot config
  withResult (statusSurface root) (pure . refuse . pure) $ \recorded -> case recordedFrontier recorded of
      Nothing -> pure (refuse ["the tracker does not record one frontier"])
      Just frontier -> do
        verifier <- verifierDigest
        let donePhases = [phase | phase <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt frontier phase == Status.Done, maybe True (phase <=) through]
        withResult (ensureGeneration config verifier "replay" recorded) (pure . refuse . pure . ("generation not recorded: " <>)) $ \seed -> do
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
      Just recordedDigest -> case (resolveSpec registeredSpecInputs phase, recordedFrontier recorded) of
            (Left problems, _) -> pure (Left (reverse done <> problems))
            (_, Nothing) -> pure (Left (reverse done <> ["the tracker does not record one frontier"]))
            (Right (_, spec), Just frontier) -> do
              predecessors <- filterM (\(receipt, path) -> case resolveSpec registeredSpecInputs (receiptPhase receipt) of
                Left _ -> pure False
                Right (_, priorSpec) -> do
                  closure <- closureFor config priorSpec verifier
                  ancestor <- isAncestor (custodyRoot config) (receiptTreeCommit receipt)
                  durable <- archiveCommitted config path
                  pure (ancestor && receiptClosureDigest receipt == closure && receiptSpecRendered receipt == renderGateSpec priorSpec && (durable || receiptStatusPostimage receipt == surfaceDigest recorded)))
                    [(receipt, path) | Just predecessor <- [PhaseIdentity.predecessorOrdinal phase]
                    , Just digest <- [lookup predecessor (surfaceReceipts recorded)], (receipt, path) <- bundles
                    , receiptPhase receipt == predecessor, receiptReproducible receipt == digest]
              if phase /= PhaseIdentity.phaseDomainLowerOrdinal && (null done || null predecessors)
                then pure (Left (reverse done <> ["PredecessorNotReproduced: no freshly replayed and exact-read immediate predecessor for phase " <> Text.pack (show phase)]))
                else do
                  snapshot <- fmap (fmap fst) (auditArchivedInventory (custodyRoot config))
                  predecessor <- reproducePredecessor config verifier recorded bundles phase
                  runOutcome <- runFresh config phase spec predecessor
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
                            let receipt = receiptFromGate seed spec outcome closure reproducible commit (Text.pack (show now)) []
                            patch <- patchToFrontier (custodyRoot config) frontier (Map.insert phase reproducible (Map.fromList (surfaceReceipts recorded)))
                            written <- publishReceipt config spec outcome patch receipt
                            pure $ case written of
                              Left problem -> Left (reverse done <> ["receipt not recorded: " <> problem])
                              Right _ -> Right (("phase " <> Text.pack (show phase) <> if reproducible == recordedDigest then "\treproduced (new archive)" else "\trefreshed (" <> Text.take 16 recordedDigest <> " -> " <> Text.take 16 reproducible <> ")") : done)
-- | Receipt-bearing reset naming a validator gap and an owned product-gap identifier.
resetGeneration :: CustodyConfig -> Text -> Text -> Text -> IO CommandOutcome
resetGeneration config decision validatorGap productGap =
  if Text.null (Text.strip validatorGap) then pure (refuse ["VALIDATOR-GAP-ABSENT"]) else case (Decisions.parseDecisionId decision, Legacy.parseLegacyId productGap) of
    (Nothing, _) -> pure (refuse ["DECISION-UNKNOWN: " <> decision])
    (_, Nothing) -> pure (refuse ["PRODUCT-GAP-UNKNOWN: " <> productGap])
    (Just _, Just identifier) -> case Legacy.legacyOwnerOrdinal identifier of
      Nothing -> pure (refuse ["PRODUCT-GAP-UNOWNED: " <> productGap])
      Just owner -> do
        let root = custodyRoot config
        withResult (statusSurface root) (pure . refuse . pure) $ \recorded -> case recordedFrontier recorded of
            Nothing -> pure (refuse ["the tracker does not record one frontier"])
            Just frontier -> do
              verifier <- verifierDigest
              withResult (ensureGeneration config verifier ("reset " <> decision) recorded) (pure . refuse . pure . ("generation not recorded: " <>)) $ \seed -> do
                  let phase = minimum (owner : [p | p <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt frontier p /= Status.Done])
                  case (Status.frontierForGate phase, PhaseIdentity.lookupPhaseIdentity phase) of
                    (Just next, Just identity) -> do
                      patch <- patchToFrontier root next (Map.fromList (surfaceReceipts recorded))
                      commit <- headCommit root
                      now <- getCurrentTime
                      let spec = Text.unlines ["record\tamoebius-status-reset.v1", "decision\t" <> Text.pack (show decision),
                            "validator-gap\t" <> Text.pack (show validatorGap), "product-gap\t" <> productGap,
                            "status-preimage\t" <> surfaceDigest recorded, "target\t" <> Text.pack (show phase)]
                          digest = sha256Hex spec
                          candidate = Text.unlines ["candidate\tphase=" <> Text.pack (show phase) <> "\tcapability=" <> PhaseIdentity.phaseIdentityCapability identity,
                            "spec-digest\t" <> digest, spec]
                          killed = "record\tstatus-reset; no gate or mutation matrix executed\n"
                          evidence = [("candidate.tsv", candidate), ("kill-table.tsv", killed), ("outcome.tsv", "reset\tapplied\n"),
                            ("oracle-ledger.tsv", "record\treset event; not a gate verdict\n"), ("observer.tsv", "status-preimage\t" <> surfaceDigest recorded <> "\n")]
                          reproducible = reproducibleDigest (sha256Hex candidate) digest verifier governanceDigest
                          receipt = Receipt phase (PhaseIdentity.phaseIdentityCapability identity) (seedGeneration seed) digest spec (sha256Hex candidate)
                            (sha256Hex killed) digest reproducible verifier governanceDigest "" commit [] (Just (validatorGap, productGap)) Nothing (Text.pack (show now))
                      written <- publishEvidenceReceipt config patch receipt evidence
                      pure $ case written of
                        Left problem -> refuse ["reset receipt not recorded: " <> problem]
                        Right path -> CommandOutcome ExitSuccess ["reset recorded under " <> decision <> " naming " <> productGap <> " at frontier phase " <> Text.pack (show phase), "receipt\t" <> Text.pack path]
                    _ -> pure (refuse ["reset target has no phase identity"])
-- | Record the operator-authored barrier demonstration input digest.
demoFile :: CustodyConfig -> FilePath -> IO CommandOutcome
demoFile config path = do
  exists <- doesFileExist path
  if not exists
    then pure (refuse ["DEMO-FILE-ABSENT: " <> Text.pack path])
    else do
      withResult (statusSurface (custodyRoot config)) (pure . refuse . pure) $ \recorded -> do
          verifier <- verifierDigest
          withResult (ensureGeneration config verifier "demo" recorded) (pure . refuse . pure . ("generation not recorded: " <>)) $ \seed -> do
              contents <- readSourceText path
              now <- getCurrentTime
              let digest = sha256Hex contents
              written <- writeRecord (generationDirectory (custodyStore config) (seedGeneration seed) </> "demonstration.tsv") (Text.unlines ["file\t" <> Text.pack path, "digest\t" <> digest, "issued-at\t" <> Text.pack (show now)])
              pure $ case written of
                Left problem -> refuse ["demonstration not recorded: " <> problem]
                Right () -> CommandOutcome ExitSuccess ["operator demonstration recorded: " <> Text.take 16 digest]
