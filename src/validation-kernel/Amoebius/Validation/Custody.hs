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
import Amoebius.Validation.Runner.Observer (observe, runExit, runStdout, sha256Hex)
import Amoebius.Validation.Runner.Spec (loadPackageGraph, verifySpec)
import Control.Monad (foldM)
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time.Clock (getCurrentTime)
import System.Directory (doesFileExist, makeAbsolute, removePathForcibly)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))

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
runFresh :: CustodyConfig -> Int -> GateSpec -> IO (Either RunnerRefusal GateOutcome)
runFresh config ordinal spec = do
  let runnerSettings = runnerConfig config ordinal
  removePathForcibly (runnerRunRoot runnerSettings)
  runGate runnerSettings spec

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

-- | Gather the preflight facts for a phase.
gatherFacts :: CustodyConfig -> Int -> GateSpec -> IO (Either Text (PreflightFacts, StatusSurface, Maybe SeedRecord, [Receipt]))
gatherFacts config ordinal spec = do
  let root = custodyRoot config
      store = custodyStore config
  surface <- statusSurface root
  case surface of
    Left problem -> pure (Left problem)
    Right recorded -> do
      verifier <- verifierDigest
      seed <- latestGeneration store verifier
      allReceipts <- maybe (pure []) (readReceipts store . seedGeneration) seed
      let receipts = [receipt | receipt <- allReceipts, isNothing (receiptResetCause receipt)]
      host <- hostFacts
      hygiene <- hygieneRow root Nothing (custodyDocCheckCap config)
      let frontier = recordedFrontier recorded
          donePhases = [phase | Just f <- [frontier], phase <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt f phase == Status.Done]
          doneWithout = [phase | phase <- donePhases, phase `notElem` map fst (surfaceReceipts recorded)]
          notReproduced =
            [ phase
            | phase <- donePhases
            , Just digest <- [lookup phase (surfaceReceipts recorded)]
            , not (any (\receipt -> receiptPhase receipt == phase && receiptReproducible receipt == digest && receiptGovernanceDigest receipt == governanceDigest) receipts)
            ]
          lastRecord = case sortOn receiptIssuedAt allReceipts of
            [] -> Nothing
            sorted -> Just (last sorted)
          acceptedPostimage = maybe (seedStatusPostimage <$> seed) (Just . receiptStatusPostimage) lastRecord
          predecessorReceipt = [receipt | Just p <- [PhaseIdentity.predecessorOrdinal ordinal], receipt <- receipts, receiptPhase receipt == p]
      committed <- case predecessorReceipt of
        (receipt : _) -> Just <$> isAncestor root (receiptTreeCommit receipt)
        [] -> pure Nothing
      pure
        ( Right
            ( PreflightFacts
                { factsSpec = spec
                , factsSurfaceDigest = surfaceDigest recorded
                , factsAcceptedPostimage = acceptedPostimage
                , factsPredecessorCommitted = committed
                , factsDoneWithoutReceipt = doneWithout
                , factsPredecessorsNotReproduced = notReproduced
                , factsFrozenFindings = []
                , factsBarrierReceipt = any (\receipt -> Just (receiptPhase receipt) == PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier) receipts
                , factsHost = host
                , factsHygieneProblems = hygieneProblems hygiene
                , factsPreviousSpec = Nothing
                }
            , recorded
            , seed
            , receipts
            )
        )

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

-- | The agent command that mints nothing: preflight, the complete gate, the
-- would-be receipt.
previewPhase :: CustodyConfig -> Int -> IO CommandOutcome
previewPhase config ordinal = case resolveSpec ordinal of
  Left problems -> pure (refuse problems)
  Right (row, spec) -> do
    gathered <- gatherFacts config ordinal spec
    case gathered of
      Left problem -> pure (refuse [problem])
      Right (facts, _, _, _) -> do
        let refusals = preflight facts
        runOutcome <- runFresh config ordinal spec
        pure $ case runOutcome of
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
      Right (facts, recorded, _, _) -> case preflight facts of
        refusals@(_ : _) -> pure (refuse (map renderPreflightRefusal refusals))
        [] -> case recordedFrontier recorded >>= \frontier -> Status.frontierAfterPass frontier ordinal of
          Nothing -> pure (refuse ["the recorded frontier is not open at phase " <> Text.pack (show ordinal)])
          Just next -> do
            runOutcome <- runFresh config ordinal spec
            case runOutcome of
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
      let postimage = sha256Hex (Text.unlines [Text.pack path <> "\n" <> contents | (path, contents) <- patch])
          tableText = Text.unlines (renderKillTable table)
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
              , receiptStatusPostimage = postimage
              , receiptTreeCommit = commit
              , receiptWitnesses = witnessRows
              , receiptResetCause = Nothing
              , receiptDemonstration = Nothing
              , receiptIssuedAt = Text.pack (show now)
              }
      written <- writeReceipt (custodyStore config) receipt
      case written of
        Left problem -> pure (refuse ["receipt not recorded: " <> problem])
        Right () -> do
          mapM_ (\(path, contents) -> TextIO.writeFile (root </> path) contents) patch
          -- The postimage the receipt must name is the surface after the patch.
          after <- statusSurface root
          let postimageAfter = either (const postimage) surfaceDigest after
          _ <- writeReceipt (custodyStore config) receipt {receiptStatusPostimage = postimageAfter}
          pure
            ( CommandOutcome
                ExitSuccess
                ( ["accepted phase " <> Text.pack (show ordinal) <> " (" <> PhaseIdentity.phaseIdentityCapability row <> ")", "claim\t" <> gateClaim spec, "spec-digest\t" <> candidateSpecDigest candidate, "reproducible-digest\t" <> reproducible, "chain\t" <> candidateChain candidate]
                    <> Text.lines tableText
                    <> ["status patch\t" <> Text.pack path | (path, _) <- patch]
                    <> ["receipt\t" <> Text.pack (generationDirectory (custodyStore config) (seedGeneration seed))]
                )
            )

-- | Re-derive the receipt of every Done phase in table order (up to the given
-- ordinal) whose store record is absent or belongs to another generation. A
-- phase whose gate re-derives the digest recorded in its document gets a store
-- record; one that does not stops the replay.
replayThrough :: CustodyConfig -> Maybe Int -> IO CommandOutcome
replayThrough config through = do
  let root = custodyRoot config
      store = custodyStore config
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
            existing <- readReceipts store (seedGeneration seed)
            result <- foldM (replayOne config seed existing recorded verifier) (Right []) donePhases
            pure $ case result of
              Left problem -> refuse problem
              Right lines' -> CommandOutcome ExitSuccess ("replay complete for " <> Text.intercalate "," (map (Text.pack . show) donePhases) : reverse lines')

replayOne :: CustodyConfig -> SeedRecord -> [Receipt] -> StatusSurface -> Text -> Either [Text] [Text] -> Int -> IO (Either [Text] [Text])
replayOne _ _ _ _ _ (Left problem) _ = pure (Left problem)
replayOne config seed existing recorded verifier (Right done) phase =
  case lookup phase (surfaceReceipts recorded) of
    Nothing -> pure (Left (reverse done <> ["STATUS-WITHOUT-RECEIPT: phase " <> Text.pack (show phase) <> " is Done without a receipt line"]))
    Just recordedDigest
      | any (\receipt -> receiptPhase receipt == phase && receiptReproducible receipt == recordedDigest && receiptGovernanceDigest receipt == governanceDigest && isNothing (receiptResetCause receipt)) existing ->
          pure (Right (("phase " <> Text.pack (show phase) <> "\treproduced (stored)") : done))
      | otherwise -> case resolveSpec phase of
          Left problems -> pure (Left (reverse done <> problems))
          Right (row, spec) -> do
            runOutcome <- runFresh config phase spec
            case runOutcome of
              Left refusal -> pure (Left (reverse done <> ["RUNNER: " <> renderRefusal refusal]))
              Right outcome -> do
                closure <- closureFor config spec verifier
                let candidate = outcomeCandidate outcome
                    reproducible = reproducibleDigest (candidateReproducibleCore candidate) closure verifier governanceDigest
                if not (candidateGreen candidate)
                  then pure (Left (reverse done <> ["PredecessorNotReproduced: phase " <> Text.pack (show phase) <> " recorded " <> recordedDigest <> " but its gate is red on the current tree:"] <> [line | line <- renderRows candidate, not ("\tgreen" `Text.isSuffixOf` line)]))
                  else do
                    commit <- headCommit (custodyRoot config)
                    now <- getCurrentTime
                    let tableText = Text.unlines (renderKillTable (outcomeKillTable outcome))
                        receipt =
                          Receipt
                            { receiptPhase = phase
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
                            , receiptStatusPostimage = surfaceDigest recorded
                            , receiptTreeCommit = commit
                            , receiptWitnesses = []
                            , receiptResetCause = Nothing
                            , receiptDemonstration = Nothing
                            , receiptIssuedAt = Text.pack (show now)
                            }
                    written <- writeReceipt (custodyStore config) receipt
                    case written of
                      Left problem -> pure (Left (reverse done <> ["receipt not recorded: " <> problem]))
                      Right ()
                        | reproducible == recordedDigest -> pure (Right (("phase " <> Text.pack (show phase) <> "\treproduced (re-derived " <> Text.take 16 reproducible <> ")") : done))
                        | otherwise -> do
                            -- An identity status projection: only the receipt line changes.
                            surface <- statusSurface (custodyRoot config)
                            case surface >>= maybe (Left "the tracker does not record one frontier") Right . recordedFrontier of
                              Left problem -> pure (Left (reverse done <> [problem]))
                              Right frontier -> do
                                patch <- patchToFrontier (custodyRoot config) frontier (Map.insert phase reproducible (Map.fromList (surfaceReceipts recorded)))
                                mapM_ (\(path, contents) -> TextIO.writeFile (custodyRoot config </> path) contents) patch
                                pure (Right (("phase " <> Text.pack (show phase) <> "\trefreshed (" <> Text.take 16 recordedDigest <> " -> " <> Text.take 16 reproducible <> ")") : done))

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
