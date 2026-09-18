{-# LANGUAGE OverloadedStrings #-}

-- | The command surface of the verifier (gate_runner_doctrine.md section 6). The
-- agent command @preview@ runs the complete gate and mints nothing. The human
-- commands @accept@, @reset@, @govern@, @demo@, and @reseed@ issue signed records
-- into the generation store and, for @accept@, apply exactly one phase's status
-- patch. Every command reports its refusals as typed values rendered here.
module Amoebius.Validation.Custody
  ( CommandOutcome (..)
  , CustodyConfig (..)
  , acceptPhase
  , defaultCustodyConfig
  , demoFile
  , govern
  , previewPhase
  , reseed
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
import Data.List (intercalate, sortOn)
import Data.Maybe (fromMaybe, isJust, isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time.Clock (getCurrentTime)
import System.Directory (createDirectoryIfMissing, doesFileExist, makeAbsolute, renamePath)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath (takeDirectory, (</>))
import System.Posix.Process (ProcessStatus (..), forkProcess, getProcessStatus)
import System.Posix.User (getUserEntryForName, homeDirectory, setGroupID, setUserID)
import Text.Read (readMaybe)

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

-- | Resolve an ordinal to its role and specification.
resolveSpec :: Int -> Either [Text] (PhaseIdentity.PhaseIdentity, GateSpec)
resolveSpec ordinal = do
  row <- maybe (Left ["PHASE-ABSENT: " <> Text.pack (show ordinal)]) Right (PhaseIdentity.lookupPhaseIdentity ordinal)
  let capability = PhaseIdentity.phaseIdentityCapability row
      role
        | ordinal == PhaseIdentity.phaseDomainLowerOrdinal = SeedGate
        | Just ordinal == PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier = BarrierGate
        | maybe False (ordinal >=) (PhaseIdentity.roleOrdinal PhaseIdentity.FirstHardware) = HardwareGate
        | otherwise = OrdinaryGate
  input <- maybe (Left ["SPEC-ABSENT: no gate specification is registered for " <> capability]) Right (specInputFor capability)
  spec <- either (Left . map renderSpecRefusal) Right (mkGateSpec role input)
  pure (row, spec)

-- | Gather the preflight facts for a phase.
gatherFacts :: CustodyConfig -> Int -> GateSpec -> IO (Either Text (PreflightFacts, Maybe SeedRecord, [Receipt]))
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
          doneWithout = [phase | Just f <- [frontier], phase <- PhaseIdentity.phaseOrdinals, Status.phaseStatusAt f phase == Status.Done, phase `notElem` map receiptPhase receipts]
          lastReceipt = case sortOn receiptIssuedAt allReceipts of
            [] -> Nothing
            sorted -> Just (last sorted)
          acceptedPostimage = maybe (seedStatusPostimage <$> seed) (Just . receiptStatusPostimage) lastReceipt
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
                , factsGenerationPresent = isJust seed
                , factsPredecessorCommitted = committed
                , factsDoneWithoutReceipt = doneWithout
                , factsVerifierDigest = verifier
                , factsSeedVerifierDigest = seedVerifierDigest <$> seed
                , factsGovernanceDigest = governanceDigest
                , factsSeedGovernanceDigest = seedGovernanceDigest <$> seed
                , factsFrozenFindings = []
                , factsBarrierReceipt = any (\receipt -> Just (receiptPhase receipt) == PhaseIdentity.roleOrdinal PhaseIdentity.DslBarrier) receipts
                , factsHost = host
                , factsHygieneProblems = hygieneProblems hygiene
                , factsPreviousSpec = Nothing
                }
            , seed
            , receipts
            )
        )

isAncestor :: FilePath -> Text -> IO Bool
isAncestor root commit = do
  absolute <- makeAbsolute root
  run <- observe root "git" ["-c", "safe.directory=" <> absolute, "merge-base", "--is-ancestor", Text.unpack commit, "HEAD"]
  pure (runExit run == ExitSuccess)

headCommit :: FilePath -> IO Text
headCommit root = do
  absolute <- makeAbsolute root
  Text.strip . runStdout <$> observe root "git" ["-c", "safe.directory=" <> absolute, "rev-parse", "HEAD"]

-- | The agent command: preflight, the complete gate, the would-be receipt; nothing
-- is written outside the run root.
previewPhase :: CustodyConfig -> Int -> IO CommandOutcome
previewPhase config ordinal = case resolveSpec ordinal of
  Left problems -> pure (refuse problems)
  Right (row, spec) -> do
    gathered <- gatherFacts config ordinal spec
    case gathered of
      Left problem -> pure (refuse [problem])
      Right (facts, seed, _) -> do
        let refusals = preflight facts
        runOutcome <- runGate (runnerConfig config ordinal seed) spec
        pure $ case runOutcome of
          Left refusal ->
            CommandOutcome (ExitFailure 1) (map renderPreflightRefusal refusals <> ["RUNNER: " <> renderRefusal refusal])
          Right outcome ->
            let candidate = outcomeCandidate outcome
                green = null refusals && candidateGreen candidate
             in CommandOutcome
                  (if green then ExitSuccess else ExitFailure 1)
                  ( ["preview phase " <> Text.pack (show ordinal) <> " (" <> PhaseIdentity.phaseIdentityCapability row <> "): " <> (if green then "would pass; nothing minted" else "would not pass")]
                      <> map renderPreflightRefusal refusals
                      <> ["row\t" <> renderGateCategory (rowCategory r) <> "\t" <> renderVerdict (rowVerdict r) | r <- candidateRows candidate]
                      <> ["claim\t" <> gateClaim spec, "spec-digest\t" <> candidateSpecDigest candidate]
                      <> renderKillTable (outcomeKillTable outcome)
                  )

runnerConfig :: CustodyConfig -> Int -> Maybe SeedRecord -> RunnerConfig
runnerConfig config ordinal _ =
  (defaultRunnerConfig (custodyRoot config) ordinal)
    { runnerHygienePreflight = False
    , runnerDocCheckCap = custodyDocCheckCap config
    , runnerMutantLimit = custodyMutantLimit config
    , runnerProductBinary = Nothing
    , runnerCabal = fromMaybe "cabal" (custodyCabal config)
    , runnerCompiler = custodyCompiler config
    }

-- | Run the gate as the human who invoked sudo, never as root: fork, drop to the
-- caller's identity with the caller's home and tool paths, run the gate, and
-- leave the candidate, kill table, and outcome beneath the run root for the
-- privileged parent to read. Root never compiles, and the caller's build store
-- is the one the preview used.
runGateAsCaller :: CustodyConfig -> Int -> GateSpec -> IO (Either Text (Text, Text, Text, Text))
runGateAsCaller config ordinal spec = do
  uidText <- lookupEnv "SUDO_UID"
  gidText <- lookupEnv "SUDO_GID"
  user <- lookupEnv "SUDO_USER"
  case (uidText >>= readMaybe, gidText >>= readMaybe, user) of
    (Just uid, Just gid, Just name) -> do
      entry <- getUserEntryForName name
      let home = homeDirectory entry
          runRoot = runnerRunRoot (runnerConfig config ordinal Nothing)
          toolDirs = concat [[takeDirectory path] | Just path <- [custodyCabal config, custodyCompiler config]]
          pathValue = intercalate ":" (toolDirs <> [home </> ".ghcup" </> "bin", home </> ".cabal" </> "bin", "/usr/local/bin", "/usr/bin", "/bin"])
      child <- forkProcess $ do
        setGroupID (fromIntegral (gid :: Int))
        setUserID (fromIntegral (uid :: Int))
        setEnv "HOME" home
        setEnv "PATH" pathValue
        unsetEnv "CABAL_DIR"
        unsetEnv "XDG_CACHE_HOME"
        outcome <- runGate (runnerConfig config ordinal Nothing) spec
        case outcome of
          Left refusal -> do
            createDirectoryIfMissing True runRoot
            TextIO.writeFile (runRoot </> "outcome.tsv") ("refused\t" <> renderRefusal refusal <> "\n")
            exitWith (ExitFailure 1)
          Right result -> exitWith (if candidateGreen (outcomeCandidate result) then ExitSuccess else ExitFailure 1)
      status <- getProcessStatus True False child
      outcomeExists <- doesFileExist (runRoot </> "outcome.tsv")
      if not outcomeExists
        then pure (Left ("the gate run as " <> Text.pack name <> " left no outcome; status " <> Text.pack (show status)))
        else do
          fields <- map (Text.breakOn "\t") . Text.lines <$> TextIO.readFile (runRoot </> "outcome.tsv")
          let field key = Text.drop 1 <$> lookup key fields
          case (field "refused", field "green", field "spec-digest", field "chain") of
            (Just refusal, _, _, _) -> pure (Left ("RUNNER: " <> refusal))
            (_, Just "True", Just digest, Just chain) | status == Just (Exited ExitSuccess) -> do
              candidate <- TextIO.readFile (runRoot </> "candidate.tsv")
              table <- TextIO.readFile (runRoot </> "kill-table.tsv")
              pure (Right (digest, candidate, table, chain))
            _ -> do
              candidate <- TextIO.readFile (runRoot </> "candidate.tsv")
              pure (Left ("the candidate is not green:\n" <> Text.unlines [line | line <- Text.lines candidate, "row\t" `Text.isPrefixOf` line, not ("\tgreen" `Text.isSuffixOf` line)]))
    _ -> pure (Left "ISSUER-NO-SUDO-CALLER: accept runs the gate as the user who invoked sudo; SUDO_UID, SUDO_GID, and SUDO_USER are required")

-- | The human command: everything preview does, then a signed receipt and exactly
-- one phase's status patch. Refuses from an agent session or a non-root identity.
acceptPhase :: CustodyConfig -> Int -> IO CommandOutcome
acceptPhase config ordinal = do
  issuer <- issuerRefusal
  case (issuer, resolveSpec ordinal) of
    (Just problem, _) -> pure (refuse [problem])
    (_, Left problems) -> pure (refuse problems)
    (Nothing, Right (row, spec)) -> do
      gathered <- gatherFacts config ordinal spec
      case gathered of
        Left problem -> pure (refuse [problem])
        Right (facts, Nothing, _) -> pure (refuse (map renderPreflightRefusal (preflight facts) <> ["GENERATION-ABSENT"]))
        Right (facts, Just seed, _) ->
          case preflight facts of
            refusals@(_ : _) -> pure (refuse (map renderPreflightRefusal refusals))
            [] -> do
              runOutcome <- runGateAsCaller config ordinal spec
              case runOutcome of
                Left problem -> pure (refuse [problem])
                Right (digest, candidate, table, chain) -> issueAccept config ordinal row spec seed digest candidate table chain

issueAccept :: CustodyConfig -> Int -> PhaseIdentity.PhaseIdentity -> GateSpec -> SeedRecord -> Text -> Text -> Text -> Text -> IO CommandOutcome
issueAccept config ordinal row spec seed specDigestValue candidateText tableText chain = do
  let root = custodyRoot config
  surface <- statusSurface root
  case surface >>= maybe (Left "the tracker does not record one frontier") Right . recordedFrontier of
    Left problem -> pure (refuse [problem])
    Right frontier -> case Status.frontierAfterPass frontier ordinal of
      Nothing -> pure (refuse ["the recorded frontier is not open at this phase"])
      Just next -> do
        patch <- patchToFrontier root next
        graph <- loadPackageGraph root
        verified <- verifySpec root spec
        closure <- case (graph, verified) of
          (Right g, Right v) -> closureDigest root g v (seedVerifierDigest seed) governanceDigest
          _ -> pure "closure-unavailable"
        commit <- headCommit root
        now <- getCurrentTime
        let postimage = sha256Hex (Text.unlines [Text.pack path <> "\n" <> contents | (path, contents) <- patch])
            witnessRows = [Text.intercalate " " (take 2 (drop 1 fields) <> drop 3 (take 4 fields)) | line <- Text.lines tableText, let fields = Text.splitOn "\t" line, length fields >= 5, fields !! 3 /= "no-witness"]
            receipt =
              Receipt
                { receiptPhase = ordinal
                , receiptCapability = PhaseIdentity.phaseIdentityCapability row
                , receiptGeneration = seedGeneration seed
                , receiptSpecDigest = specDigestValue
                , receiptSpecRendered = renderGateSpec spec
                , receiptCandidateDigest = sha256Hex candidateText
                , receiptKillTableDigest = sha256Hex tableText
                , receiptClosureDigest = closure
                , receiptVerifierDigest = seedVerifierDigest seed
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
          Left problem -> pure (refuse ["receipt not issued: " <> problem])
          Right () -> do
            mapM_ (\(path, contents) -> TextIO.writeFile (root </> path) contents) patch
            pure
              ( CommandOutcome
                  ExitSuccess
                  ( ["accepted phase " <> Text.pack (show ordinal) <> " (" <> PhaseIdentity.phaseIdentityCapability row <> ")", "claim\t" <> gateClaim spec, "spec-digest\t" <> specDigestValue, "chain\t" <> chain]
                      <> Text.lines tableText
                      <> ["status patch\t" <> Text.pack path | (path, _) <- patch]
                      <> ["receipt\t" <> Text.pack (generationDirectory (custodyStore config) (seedGeneration seed))]
                  )
              )

-- | The human root act that installs a generation at the verifier's content
-- address, archiving any prior generation directory and never deleting it.
reseed :: CustodyConfig -> Text -> IO CommandOutcome
reseed config decision = do
  issuer <- issuerRefusal
  case (issuer, Decisions.parseDecisionId decision) of
    (Just problem, _) -> pure (refuse [problem])
    (_, Nothing) -> pure (refuse ["DECISION-UNKNOWN: " <> decision])
    (Nothing, Just _) -> do
      let root = custodyRoot config
          store = custodyStore config
      verifier <- verifierDigest
      surface <- statusSurface root
      case surface of
        Left problem -> pure (refuse [problem])
        Right recorded -> do
          existing <- listGenerations store
          now <- getCurrentTime
          archived <- mapM (\name -> do
            let stamp = filter (`notElem` (" :" :: String)) (show now)
            renamePath (storeRoot store </> name) (storeRoot store </> ("archived-" <> name <> "-" <> stamp))
            pure (Text.pack name)) existing
          commit <- headCommit root
          keyExists <- doesFileExist (storeRoot store </> "issuer.key")
          let seed =
                SeedRecord
                  { seedGeneration = verifier
                  , seedDecision = decision
                  , seedVerifierDigest = verifier
                  , seedGovernanceDigest = governanceDigest
                  , seedStatusPostimage = surfaceDigest recorded
                  , seedTreeCommit = commit
                  , seedIssuedAt = Text.pack (show now)
                  }
          if not keyExists
            then pure (refuse ["ISSUER-KEY-ABSENT: " <> Text.pack (storeRoot store </> "issuer.key")])
            else do
              createDirectoryIfMissing True (takeDirectory (generationDirectory store verifier))
              written <- writeSeed store seed
              pure $ case written of
                Left problem -> refuse ["seed not written: " <> problem]
                Right () -> CommandOutcome ExitSuccess (["reseeded generation " <> Text.take 16 verifier <> " under " <> decision] <> ["archived\t" <> name | name <- archived])

-- | The receipt-bearing reset: a receipt at the frontier's phase whose reset
-- cause names a validator gap and a product-gap legacy identifier with an owner.
resetGeneration :: CustodyConfig -> Text -> Text -> Text -> IO CommandOutcome
resetGeneration config decision validatorGap productGap = do
  issuer <- issuerRefusal
  case (issuer, Decisions.parseDecisionId decision, Legacy.parseLegacyId productGap) of
    (Just problem, _, _) -> pure (refuse [problem])
    (_, Nothing, _) -> pure (refuse ["DECISION-UNKNOWN: " <> decision])
    (_, _, Nothing) -> pure (refuse ["PRODUCT-GAP-UNKNOWN: " <> productGap])
    (Nothing, Just _, Just identifier) -> case Legacy.legacyOwnerOrdinal identifier of
      Nothing -> pure (refuse ["PRODUCT-GAP-UNOWNED: " <> productGap])
      Just owner -> do
        let root = custodyRoot config
            store = custodyStore config
        verifier <- verifierDigest
        seed <- latestGeneration store verifier
        surface <- statusSurface root
        case (seed, surface) of
          (Nothing, _) -> pure (refuse ["GENERATION-ABSENT"])
          (_, Left problem) -> pure (refuse [problem])
          (Just record, Right recorded) -> case recordedFrontier recorded of
           Nothing -> pure (refuse ["the tracker does not record one frontier"])
           Just frontier -> do
            let phase = Status.completedPrefixDueOrdinal frontier
            commit <- headCommit root
            now <- getCurrentTime
            let receipt =
                  Receipt
                    { receiptPhase = phase
                    , receiptCapability = maybe "" PhaseIdentity.phaseIdentityCapability (PhaseIdentity.lookupPhaseIdentity phase)
                    , receiptGeneration = seedGeneration record
                    , receiptSpecDigest = "reset"
                    , receiptSpecRendered = ""
                    , receiptCandidateDigest = "reset"
                    , receiptKillTableDigest = "reset"
                    , receiptClosureDigest = "reset"
                    , receiptVerifierDigest = verifier
                    , receiptGovernanceDigest = governanceDigest
                    , receiptStatusPostimage = surfaceDigest recorded
                    , receiptTreeCommit = commit
                    , receiptWitnesses = []
                    , receiptResetCause = Just (validatorGap, productGap)
                    , receiptDemonstration = Nothing
                    , receiptIssuedAt = Text.pack (show now)
                    }
            written <- writeReceipt store receipt
            pure $ case written of
              Left problem -> refuse ["reset receipt not issued: " <> problem]
              Right () -> CommandOutcome ExitSuccess ["reset recorded under " <> decision <> " naming " <> productGap <> " (owner phase " <> Text.pack (show owner) <> ") at frontier phase " <> Text.pack (show phase)]

-- | Accept a governance change: re-seal the frozen baseline under a decision by
-- writing a governance record into the current generation.
govern :: CustodyConfig -> Text -> IO CommandOutcome
govern config decision = do
  issuer <- issuerRefusal
  case (issuer, Decisions.parseDecisionId decision) of
    (Just problem, _) -> pure (refuse [problem])
    (_, Nothing) -> pure (refuse ["DECISION-UNKNOWN: " <> decision])
    (Nothing, Just _) -> do
      let store = custodyStore config
      verifier <- verifierDigest
      seed <- latestGeneration store verifier
      case seed of
        Nothing -> pure (refuse ["GENERATION-ABSENT"])
        Just record -> do
          now <- getCurrentTime
          written <- writeSigned store (generationDirectory store (seedGeneration record) </> "governance.tsv") (Text.unlines ["decision\t" <> decision, "governance-digest\t" <> governanceDigest, "issued-at\t" <> Text.pack (show now)])
          pure $ case written of
            Left problem -> refuse ["governance not recorded: " <> problem]
            Right () -> CommandOutcome ExitSuccess ["governance re-sealed under " <> decision <> ": " <> Text.take 16 governanceDigest]

-- | Sign an operator-authored input for the barrier's demonstration.
demoFile :: CustodyConfig -> FilePath -> IO CommandOutcome
demoFile config path = do
  issuer <- issuerRefusal
  exists <- doesFileExist path
  case (issuer, exists) of
    (Just problem, _) -> pure (refuse [problem])
    (_, False) -> pure (refuse ["DEMO-FILE-ABSENT: " <> Text.pack path])
    (Nothing, True) -> do
      let store = custodyStore config
      verifier <- verifierDigest
      seed <- latestGeneration store verifier
      contents <- TextIO.readFile path
      case seed of
        Nothing -> pure (refuse ["GENERATION-ABSENT"])
        Just record -> do
          now <- getCurrentTime
          let digest = sha256Hex contents
          written <- writeSigned store (generationDirectory store (seedGeneration record) </> "demonstration.tsv") (Text.unlines ["file\t" <> Text.pack path, "digest\t" <> digest, "issued-at\t" <> Text.pack (show now)])
          pure $ case written of
            Left problem -> refuse ["demonstration not signed: " <> problem]
            Right () -> CommandOutcome ExitSuccess ["operator demonstration signed: " <> Text.take 16 digest]

