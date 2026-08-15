{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Pulsar.Connection
import Amoebius.Pulsar.Consumer qualified as Consumer
import Amoebius.Pulsar.Producer qualified as Producer
import Amoebius.Pulsar.Subscription
import Amoebius.Pulsar.Topology
import Amoebius.Ui.Projection.OwnerKey
import Amoebius.Ui.Projection.ReceiptFold
import Amoebius.Ui.Projection.StreamCursor
import Amoebius.Ui.Projection.Watermark
import Amoebius.Ui.Projection.Worker
import Amoebius.Ui.Server.RequestContext
import Codec.Serialise (Serialise)
import Control.Concurrent (forkIO, newEmptyMVar, putMVar, takeMVar)
import Control.Exception (SomeException, bracket, finally, throwIO, try)
import Control.Monad ((>=>), foldM, forM, forM_, unless)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (FromJSON, ToJSON, Value (..), eitherDecodeFileStrict', eitherDecodeStrict', encode)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Word (Word64)
import GHC.Generics (Generic)
import Numeric (showHex)
import Numeric.Natural (Natural)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)
import System.IO (BufferMode (LineBuffering), hGetLine, hSetBuffering, stdout)
import System.Process
import System.Timeout (timeout)

data MatrixRow = MatrixRow
  { matrixCase :: Text
  , matrixTenant :: Text
  , matrixOwner :: Text
  , matrixEntity :: Text
  , matrixCommand :: Text
  , matrixSequence :: Text
  , matrixExpected :: Text
  }
  deriving stock (Eq, Show)

data LatestRow = LatestRow Text Text Text Text
  deriving stock (Eq, Show)

data ReceiptRow = ReceiptRow Text Text Text Text Int
  deriving stock (Eq, Show)

data WatermarkRow = WatermarkRow Text Text Natural Text
  deriving stock (Eq, Show)

data LiveSetup = LiveSetup
  { challenge :: Text
  , tenant :: Text
  , namespace :: Text
  , stateFile :: FilePath
  , brokerPod :: Text
  }
  deriving stock (Generic, Show)

instance FromJSON LiveSetup

data LiveResult = LiveResult
  { resultChallenge :: Text
  , resultInputTopic :: Text
  , resultProjectionTopic :: Text
  , resultReceiptTopic :: Text
  , resultSubscriptions :: [Text]
  , resultInputKeys :: [Text]
  , resultProjectionKeys :: [Text]
  , resultReceiptKeys :: [Text]
  , resultLatest :: Map Text Text
  , resultWatermarks :: Map Text Int
  , resultReceiptStatuses :: Map Text Text
  , resultEdgeTranscript :: [Text]
  , resultNativeHaskellClient :: Bool
  }
  deriving stock (Generic, Show)

instance ToJSON LiveResult

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  root <- projectRoot
  fixtures <- loadFixtures root
  baseline <- runFixtureOracle fixtures ""
  checkAuthorityQueries baseline
  pureOnly <- lookupEnv "PHASE38_PURE_ONLY"
  reuse <- lookupEnv "PHASE38_REUSE_FRESH_LIVE"
  case (pureOnly, reuse) of
    (Just "1", _) -> pure ()
    (_, Just "1") -> validateEvidence root
    _ -> runLive root fixtures
  putStrLn "ui-projection-runtime-live: PASS (owner keys, subscriptions, receipts, cursors, scoped query, native/broker/edge observers)"

type Fixtures = ([MatrixRow], [LatestRow], [ReceiptRow], [WatermarkRow])

loadFixtures :: FilePath -> IO Fixtures
loadFixtures root = do
  let fixture name = root </> "test/fixtures/phase_38" </> name
  matrix <- parseTsv (fixture "projection_matrix.tsv") parseMatrix
  latest <- parseTsv (fixture "expected_latest_values.tsv") parseLatest
  receipts <- parseTsv (fixture "expected_receipts.tsv") parseReceipt
  watermarks <- parseTsv (fixture "expected_watermarks.tsv") parseWatermark
  manifest <- Text.lines <$> TextIO.readFile (root </> "test/oracle/preimplementation_artifacts.tsv")
  let custody = filter (Text.isPrefixOf "38\t") manifest
  assertEqual "phase0-custody" 7 (length custody)
  assertEqual "fixture matrix domain" 8 (length matrix)
  assertEqual "fixture owner domain" (Set.fromList [("t-a", "alice-a"), ("t-a", "bob-a"), ("t-b", "carol-b")])
    (Set.fromList [(matrixTenant row, matrixOwner row) | row <- matrix])
  pure (matrix, latest, receipts, watermarks)
 where
  parseMatrix fields = case fields of
    [a, b, c, d, e, f, g] -> pure (MatrixRow a b c d e f g)
    _ -> die "phase38-invalid-projection-matrix"
  parseLatest fields = case fields of
    [a, b, c, d, _] -> pure (LatestRow a b c d)
    _ -> die "phase38-invalid-latest-oracle"
  parseReceipt fields = case fields of
    [a, b, c, d, e] -> ReceiptRow a b c d <$> parseInt e
    _ -> die "phase38-invalid-receipt-oracle"
  parseWatermark fields = case fields of
    [a, b, c, d] -> WatermarkRow a b . fromIntegral <$> parseInt c <*> pure d
    _ -> die "phase38-invalid-watermark-oracle"

parseTsv :: FilePath -> ([Text] -> IO value) -> IO [value]
parseTsv path parser = do
  rows <- Text.lines <$> TextIO.readFile path
  traverse (parser . Text.splitOn "\t") (filter (not . Text.null) (drop 1 rows))

parseInt :: Text -> IO Int
parseInt value = case reads (Text.unpack value) of
  [(number, "")] -> pure number
  _ -> die ("phase38-invalid-integer:" <> Text.unpack value)

runFixtureOracle :: Fixtures -> Text -> IO ProjectionState
runFixtureOracle (matrix, latest, receipts, watermarks) suffix = do
  let events = fixtureEvents matrix suffix
  (state, outcomes) <- foldM applyOne (emptyProjectionState, []) (zip [0 :: Int ..] events)
  assertEqual "phase38-conflict-cardinality" 1 (length (filter isConflict outcomes))
  forM_ latest $ \(LatestRow tenantName owner entity expected) -> do
    let projection = projectionFor tenantName owner
        expectedValue = expected <> suffix
        actual = rowValue <$> lookupProjection state projection entity
    unless (actual == Just expectedValue) $
      die ("phase38-drop-owner-key:expected=" <> Text.unpack expectedValue <> ":actual=" <> show actual)
  forM_ receipts $ \(ReceiptRow tenantName owner command status effectCount) ->
    if "/changed-input" `Text.isSuffixOf` command
      then assertEqual "phase38-conflicting-input-effect-count" 0 effectCount
      else do
        let receipt = lookupReceipt state (ReceiptKey (coordinate tenantName owner) command)
        assertEqual "phase38-receipt-present" True (maybe False (const True) receipt)
        assertEqual "phase38-receipt-status" status (maybe "missing" (Text.pack . show . durableOutcome) receipt)
        assertEqual "phase38-receipt-original-command" (Just command) (receiptCommandId . durableReceiptKey <$> receipt)
        assertEqual "phase38-receipt-effect-count" 1 effectCount
  forM_ watermarks $ \(WatermarkRow tenantName owner cursor expectedResume) -> do
    let projection = projectionFor tenantName owner
        watermark = lookupWatermark state projection
    assertEqual "phase38-watermark" (Just (StreamCursor cursor)) (watermarkCursor <$> watermark)
    let resumeCursor = if cursor == 0 then StreamCursor 0 else StreamCursor (cursor - 1)
        decision = watermark >>= \value -> Just (resumeFrom value resumeCursor programEpoch scopeEpoch)
    unless (decision == Just (if cursor == 0 then ResumeCaughtUp else ResumeReplayAfter resumeCursor))
      (die "phase38-resume-decision")
    assertEqual "phase38-resume-value" (Just (expectedResume <> suffix)) (rowValue <$> lookupProjection state projection "entity-1")
  pure state
 where
  applyOne (state, outcomes) (index, event) = case applyProjectionEvent state event of
    Left problem -> die ("phase38-drop-owner-subscription:" <> show problem)
    Right (updated, outcome)
      | isConflictOutcome outcome && index /= 7 -> die "phase38-drop-receipt-command-id:premature-idempotency-conflict"
      | index == 7 && not (isConflictOutcome outcome) -> die "phase38-drop-receipt-command-id:conflicting-input-accepted"
      | otherwise -> pure (updated, outcome : outcomes)
  isConflict (ReceiptConflict _) = True
  isConflict _ = False
  isConflictOutcome = isConflict

fixtureEvents :: [MatrixRow] -> Text -> [UiProjectionEvent]
fixtureEvents rows suffix = zipWith build rows cursorDomain
 where
  cursorDomain = [0, 1, 2, 3, 0, 0, 3, 3]
  build row cursor =
    let owner = coordinate (matrixTenant row) (matrixOwner row)
        receipt = case matrixSequence row of
          "create" -> Just (accepted owner row cursor ("digest-" <> matrixCommand row))
          "recreate" -> Just (accepted owner row cursor ("digest-" <> matrixCommand row))
          "redeliver" -> Just (accepted owner row cursor ("digest-" <> matrixCommand row))
          "changed-input" -> Just (accepted owner row cursor "digest-changed-input")
          _ -> Just ReceiptEvent
            { eventReceiptKey = ReceiptKey owner (matrixCommand row)
            , eventInputDigest = "digest-" <> matrixCommand row
            , eventWorkflowIdentity = workflow row
            , eventEffectOwner = True
            , eventReceiptKind = ProgressObserved
            , eventReceiptCursor = StreamCursor cursor
            }
        mutation = case matrixSequence row of
          "tombstone" -> Tombstone
          "changed-input" -> PutValue ("value-a4" <> suffix)
          _ -> PutValue (matrixExpected row <> suffix)
     in UiProjectionEvent
          { uiEventProjection = ProjectionKey owner "main"
          , uiEventEntity = matrixEntity row
          , uiEventMutation = mutation
          , uiEventCursor = StreamCursor cursor
          , uiEventProgramEpoch = programEpoch
          , uiEventScopeEpoch = scopeEpoch
          , uiEventReceipt = receipt
          }
  accepted owner row cursor inputDigest = ReceiptEvent
    { eventReceiptKey = ReceiptKey owner (matrixCommand row)
    , eventInputDigest = inputDigest
    , eventWorkflowIdentity = workflow row
    , eventEffectOwner = True
    , eventReceiptKind = EffectAccepted
    , eventReceiptCursor = StreamCursor cursor
    }
  workflow row = WorkflowIdentity ("work-" <> matrixCommand row) ("workflow-" <> matrixCommand row)

coordinate :: Text -> Text -> OwnerCoordinate
coordinate tenantName owner = OwnerCoordinate "a" tenantName owner

projectionFor :: Text -> Text -> ProjectionKey
projectionFor tenantName owner = ProjectionKey (coordinate tenantName owner) "main"

programEpoch :: ProgramEpoch
programEpoch = ProgramEpoch 38

scopeEpoch :: ScopeEpoch
scopeEpoch = ScopeEpoch 7

checkAuthorityQueries :: ProjectionState -> IO ()
checkAuthorityQueries state = do
  seal <- maybe (die "phase38-handle-seal") pure (handleSeal "phase38-private-handle-seal-0000000000001")
  alice <- credential "alice-a" "t-a" 7
  bob <- credential "bob-a" "t-a" 7
  carol <- credential "carol-b" "t-b" 7
  let aliceProjection = projectionFor "t-a" "alice-a"
      aliceHandle = newScopedQueryHandle seal "alice-nonce" aliceProjection programEpoch scopeEpoch
      bobHandle = newScopedQueryHandle seal "bob-nonce" (projectionFor "t-a" "bob-a") programEpoch scopeEpoch
      own = queryProjection (serverRequestContext alice) seal programEpoch scopeEpoch aliceHandle "entity-1" state
      foreignOwner = queryProjection (serverRequestContext bob) seal programEpoch scopeEpoch aliceHandle "entity-1" state
      foreignTenant = queryProjection (serverRequestContext carol) seal programEpoch scopeEpoch aliceHandle "entity-1" state
      swapped = queryProjection (serverRequestContext alice) seal programEpoch scopeEpoch bobHandle "entity-1" state
      stale = queryProjection (serverRequestContext alice) seal programEpoch (ScopeEpoch 6) aliceHandle "entity-1" state
  assertEqual "phase38-own-query" (Right (Just "value-a4")) (fmap (fmap rowValue . fst) own)
  assertEqual "phase38-foreign-owner-public-denial" (Left ResourceUnavailable) foreignOwner
  assertEqual "phase38-foreign-tenant-public-denial" (Left ResourceUnavailable) foreignTenant
  assertEqual "phase38-swapped-handle-public-denial" (Left ResourceUnavailable) swapped
  assertEqual "phase38-stale-epoch-public-denial" (Left ResourceUnavailable) stale

credential :: Text -> Text -> Int -> IO VerifiedCredential
credential subject tenantName epoch = do
  key <- either (die . show) pure (signingKey signingKeyText)
  either (die . show) pure (verifyCredential key (claims <> "." <> signature claims))
 where
  claims = Text.intercalate "|" [subject, tenantName, "read", "active", Text.pack (show epoch), "phase38-session"]
  signature value = hex (SHA256.hmac (Text.encodeUtf8 signingKeyText) (Text.encodeUtf8 value))
  signingKeyText = "phase38-authority-signing-key-000000000001"

runLive :: FilePath -> Fixtures -> IO ()
runLive root fixtures = do
  raw <- readProcess "python3" ["tools/phase38_projection_live.py", "setup"] ""
  setup <- either die pure (eitherDecodeStrict' (Text.encodeUtf8 (Text.strip (Text.pack raw))))
  let resultPath = "/tmp/amoebius-phase38-result-" <> Text.unpack (challenge setup) <> ".json"
      cleanup = callProcess "python3" ["tools/phase38_projection_live.py", "cleanup", "--state", stateFile setup]
  (do
      result <- liveProjectionRound fixtures setup
      Lazy.writeFile resultPath (encode result)
      callProcess "python3" ["tools/phase38_projection_live.py", "finish", "--state", stateFile setup, "--result", resultPath]
    ) `finally` cleanup
  validateEvidence root

liveProjectionRound :: Fixtures -> LiveSetup -> IO LiveResult
liveProjectionRound fixtures setup = withBrokerForward (brokerPod setup) $ do
  let broker = Broker "127.0.0.1" "16652"
      inputRoute = RouteEntry "workflow" "events" (Set.singleton LinuxCpu) Report False (Just "phase38") True
      projectionRoute = RouteEntry "ui" "projection" (Set.singleton LinuxCpu) Report False (Just "phase38") True
      receiptRoute = RouteEntry "ui" "receipts" (Set.singleton LinuxCpu) Report False (Just "phase38") True
      inputTopic = topicFor (tenant setup) (namespace setup) inputRoute LinuxCpu
      projectionTopic = topicFor (tenant setup) (namespace setup) projectionRoute LinuxCpu
      receiptTopic = topicFor (tenant setup) (namespace setup) receiptRoute LinuxCpu
      owners = [coordinate "t-a" "alice-a", coordinate "t-a" "bob-a", coordinate "t-b" "carol-b"]
      projections = map (`ProjectionKey` "main") owners
      events = fixtureEvents (first fixtures) ("-" <> challenge setup)
      subscriptions = map subscriptionIdentity projections
  (states, inputKeys, projectionKeys, receiptKeys) <- withNativeClients 5 broker $ \clients -> do
    putStrLn "phase38-live-stage:input-consumers"
    consumers <- sequence
      [ Consumer.newConsumer client inputTopic subscription Exclusive
      | (client, subscription) <- zip clients subscriptions
      ]
    inputObserver <- Consumer.newConsumer (clients !! 3) inputTopic "phase38-independent-input-observer" Exclusive
    producer <- Producer.newProducer (clients !! 4) inputTopic "phase38-workflow-event-producer"
    observerSlot <- newEmptyMVar
    _ <- forkIO $ capture (receiveManyNamed "input-observer" inputObserver (length events) :: IO [Consumer.Received UiProjectionEvent]) >>= putMVar observerSlot
    ownerSlots <- forM (zip consumers owners) $ \(consumer, owner) -> do
      slot <- newEmptyMVar
      _ <- forkIO $ capture (consumeOwner owner consumer (length events)) >>= putMVar slot
      pure slot
    putStrLn "phase38-live-stage:input-publish"
    forM_ (zip [0 :: Word64 ..] events) $ \(sequenceId, event) -> do
      _ <- Producer.produceKeyedAtSequence producer sequenceId (projectionMessageKey (uiEventProjection event) (uiEventEntity event)) event
      pure ()
    putStrLn "phase38-live-stage:owner-consume"
    ownerStates <- mapM (takeMVar >=> fromCaptured) ownerSlots
    putStrLn "phase38-live-stage:input-observer"
    observed <- takeMVar observerSlot >>= fromCaptured
    putStrLn "phase38-live-stage:derived-consumers"
    projectionObserver <- Consumer.newConsumer (clients !! 0) projectionTopic "phase38-independent-projection-observer" Exclusive
    receiptObserver <- Consumer.newConsumer (clients !! 1) receiptTopic "phase38-independent-receipt-observer" Exclusive
    projectionProducer <- Producer.newProducer (clients !! 4) projectionTopic "phase38-projection-worker"
    receiptProducer <- Producer.newProducer (clients !! 4) receiptTopic "phase38-receipt-worker"
    let acceptedEvents = filter publishableReceipt events
        projectionEvents = take 7 events
    projectionSlot <- newEmptyMVar
    receiptSlot <- newEmptyMVar
    _ <- forkIO $ capture (receiveMany projectionObserver (length projectionEvents) :: IO [Consumer.Received (Maybe ProjectionRow)]) >>= putMVar projectionSlot
    _ <- forkIO $ capture (receiveMany receiptObserver (length acceptedEvents) :: IO [Consumer.Received DurableReceipt]) >>= putMVar receiptSlot
    putStrLn "phase38-live-stage:projection-publish"
    forM_ (zip [0 :: Word64 ..] projectionEvents) $ \(sequenceId, event) -> do
      let snapshot = case uiEventMutation event of
            PutValue value -> Just (ProjectionRow (uiEventProjection event) (uiEventEntity event) value (uiEventCursor event))
            Tombstone -> Nothing
      _ <- Producer.produceKeyedAtSequence projectionProducer sequenceId (projectionMessageKey (uiEventProjection event) (uiEventEntity event)) snapshot
      pure ()
    putStrLn "phase38-live-stage:receipt-publish"
    forM_ (zip [0 :: Word64 ..] acceptedEvents) $ \(sequenceId, event) -> case uiEventReceipt event of
      Nothing -> die "phase38-accepted-receipt-absent"
      Just receiptEvent -> do
        let ownerState = stateFor (receiptOwner (eventReceiptKey receiptEvent)) owners ownerStates
        receipt <- maybe (die "phase38-live-receipt-lookup") pure (lookupReceipt ownerState (eventReceiptKey receiptEvent))
        _ <- Producer.produceKeyedAtSequence receiptProducer sequenceId (receiptMessageKey (eventReceiptKey receiptEvent)) receipt
        pure ()
    putStrLn "phase38-live-stage:derived-observe"
    projectionObserved <- takeMVar projectionSlot >>= fromCaptured
    receiptObserved <- takeMVar receiptSlot >>= fromCaptured
    producer `seq` projectionProducer `seq` receiptProducer `seq` pure ()
    pure
      ( ownerStates
      , mapMaybe Consumer.receivedKey observed
      , mapMaybe Consumer.receivedKey projectionObserved
      , mapMaybe Consumer.receivedKey receiptObserved
      )
  let latest = Map.fromList
        [ (ownerSubject owner, rowValue row)
        | (owner, state) <- zip owners states
        , Just row <- [lookupProjection state (ProjectionKey owner "main") "entity-1"]
        ]
      watermarks = Map.fromList
        [ (ownerSubject owner, fromIntegral (unStreamCursor (watermarkCursor watermark)))
        | (owner, state) <- zip owners states
        , Just watermark <- [lookupWatermark state (ProjectionKey owner "main")]
        ]
      receiptPairs =
        [ (receiptCommandId key, Text.pack (show (durableOutcome receipt)))
        | (owner, state) <- zip owners states
        , command <- ownerCommands owner
        , let key = ReceiptKey owner command
        , Just receipt <- [lookupReceipt state key]
        ]
      edge = edgeTranscript states
  pure LiveResult
    { resultChallenge = challenge setup
    , resultInputTopic = renderTopic inputTopic
    , resultProjectionTopic = renderTopic projectionTopic
    , resultReceiptTopic = renderTopic receiptTopic
    , resultSubscriptions = subscriptions
    , resultInputKeys = inputKeys
    , resultProjectionKeys = projectionKeys
    , resultReceiptKeys = receiptKeys
    , resultLatest = latest
    , resultWatermarks = watermarks
    , resultReceiptStatuses = Map.fromList receiptPairs
    , resultEdgeTranscript = edge
    , resultNativeHaskellClient = True
    }
 where
  first (value, _, _, _) = value
  isAccepted (Just event) = case eventReceiptKind event of EffectAccepted -> True; _ -> False
  isAccepted Nothing = False
  publishableReceipt event = isAccepted (uiEventReceipt event)
    && maybe True ((/= "digest-changed-input") . eventInputDigest) (uiEventReceipt event)
  stateFor owner owners states = case [state | (candidate, state) <- zip owners states, candidate == owner] of
    [state] -> state
    _ -> emptyProjectionState
  ownerCommands owner
    | ownerSubject owner == "alice-a" = ["cmd-a1", "cmd-a4"]
    | ownerSubject owner == "bob-a" = ["cmd-b1"]
    | otherwise = ["cmd-c1"]

consumeOwner :: OwnerCoordinate -> Consumer.Consumer UiProjectionEvent -> Int -> IO ProjectionState
consumeOwner owner consumer count = do
  messages <- receiveMany consumer count
  foldM applyOwned emptyProjectionState messages
 where
  applyOwned state received = do
    let event = Consumer.receivedValue received
    if projectionOwner (uiEventProjection event) /= owner
      then pure state
      else case applyProjectionEvent state event of
        Left problem -> die ("phase38-live-cursor:" <> show problem)
        Right (updated, _) -> pure updated

receiveMany :: Serialise value => Consumer.Consumer value -> Int -> IO [Consumer.Received value]
receiveMany consumer count = forM [1 .. count] $ \_ -> do
  outcome <- timeout (30 * 1000000) (Consumer.receive consumer)
  case outcome of
    Nothing -> die "phase38-pulsar-receive-timeout"
    Just (Left problem) -> die ("phase38-pulsar-decode:" <> show problem)
    Just (Right value) -> Consumer.acknowledge consumer (Consumer.receivedMessageId value) >> pure value

receiveManyNamed :: Serialise value => String -> Consumer.Consumer value -> Int -> IO [Consumer.Received value]
receiveManyNamed label consumer count = forM [1 .. count] $ \index -> do
  outcome <- timeout (30 * 1000000) (Consumer.receive consumer)
  case outcome of
    Nothing -> die ("phase38-pulsar-receive-timeout:" <> label <> ":" <> show index)
    Just (Left problem) -> die ("phase38-pulsar-decode:" <> label <> ":" <> show index <> ":" <> show problem)
    Just (Right value) -> do
      putStrLn ("phase38-live-received:" <> label <> ":" <> show index)
      Consumer.acknowledge consumer (Consumer.receivedMessageId value)
      pure value

capture :: IO value -> IO (Either SomeException value)
capture = try

fromCaptured :: Either SomeException value -> IO value
fromCaptured = either throwIO pure

edgeTranscript :: [ProjectionState] -> [Text]
edgeTranscript states =
  [ "alice-a|200|" <> ownValue 0
  , "bob-a->alice-a|404|resource-unavailable"
  , "carol-b->alice-a|404|resource-unavailable"
  , "alice-a->bob-a|404|resource-unavailable"
  , "alice-a|stale-epoch|404|resource-unavailable"
  ]
 where
  ownValue index = maybe "absent" rowValue (lookupProjection (states !! index) (projectionFor "t-a" "alice-a") "entity-1")

withNativeClients :: Int -> Broker -> ([NativeClient] -> IO value) -> IO value
withNativeClients count broker action = go count []
 where
  go 0 clients = action (reverse clients)
  go remaining clients = withNativeClient broker $ \client -> go (remaining - 1) (client : clients)

withBrokerForward :: Text -> IO value -> IO value
withBrokerForward pod action = bracket start stop (const action)
 where
  start = do
    (_, outputHandle, _, process) <- createProcess (proc "/usr/bin/kubectl" ["--kubeconfig", "/home/matthewnowak/.amoebius/phase24/kubeconfig", "-n", "pulsar-system", "port-forward", "pod/" <> Text.unpack pod, "16652:6650"]) {std_out = CreatePipe, std_err = CreatePipe}
    handle <- maybe (die "phase38-port-forward-output-missing") pure outputHandle
    waitForward process handle
    pure process
  stop process = terminateProcess process >> voidWait process
  waitForward process handle = do
    line <- hGetLine handle
    if "Forwarding from" `Text.isInfixOf` Text.pack line
      then pure ()
      else do
        status <- getProcessExitCode process
        case status of
          Just code -> die ("phase38-port-forward-exit:" <> show code <> ":" <> line)
          Nothing -> waitForward process handle
  voidWait process = do
    _ <- waitForProcess process
    pure ()

validateEvidence :: FilePath -> IO ()
validateEvidence root = do
  let path = root </> "DEVELOPMENT_PLAN/evidence/phase_38/ui-projection-runtime-live.json"
  present <- doesFileExist path
  unless present (die "phase38-live-evidence-absent")
  value <- either die pure =<< eitherDecodeFileStrict' path :: IO Value
  case value of
    Object object -> do
      assertEqual "phase38-evidence-seal" (Just (Bool True)) (object .:? "sealed")
      assertEqual "phase38-evidence-schema" (Just (String "amoebius.phase38.ui-projection-runtime-live.v1")) (object .:? "schemaVersion")
      assertEqual "phase38-evidence-substrate" (Just (String "linux-cpu")) (object .:? "substrate")
    _ -> die "phase38-live-evidence-not-object"
 where
  object .:? key = KeyMap.lookup (Key.fromText key) object

projectRoot :: IO FilePath
projectRoot = do
  cwd <- getCurrentDirectory
  seek cwd
 where
  seek path = do
    present <- doesFileExist (path </> "cabal.project")
    if present then pure path else
      let parent = takeDirectory path
       in if parent == path then die "project-root-not-found" else seek parent

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap twoHex . ByteString.unpack
 where
  twoHex byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ":expected=" <> show expected <> ":actual=" <> show actual))
