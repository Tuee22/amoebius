{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import Amoebius.Execution.JobTerminalLive
import Amoebius.Pulsar.Connection
import Amoebius.Pulsar.Consumer qualified as Consumer
import Amoebius.Pulsar.Producer qualified as Producer
import Amoebius.Pulsar.Subscription (SubscriptionType (..))
import Amoebius.Pulsar.Topology hiding (StorageBudgetId)
import Amoebius.Store.Budget
import Amoebius.Store.ContentAddress
import Amoebius.Store.Manifest
import Amoebius.Store.Pointer
import Amoebius.Workflow.Orchestrator
import Amoebius.Workflow.Resources
import Amoebius.Workflow.Runtime
import Amoebius.Workflow.Worker
import Codec.Serialise (Serialise)
import Control.Concurrent (forkIO, killThread, threadDelay)
import Control.Exception (SomeException, bracket, catch, finally)
import Control.Monad (forM, forever, unless, when)
import Data.Aeson
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (digitToInt, isSpace)
import Data.Int (Int32)
import Data.List (findIndex, isInfixOf, sort, stripPrefix)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Text.IO qualified as TextIO
import GHC.Generics (Generic)
import Numeric.Natural (Natural)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Environment (getArgs, getExecutablePath, lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>), takeDirectory)
import System.IO (BufferMode (LineBuffering), Handle, hGetLine, hSetBuffering, stdout)
import System.Process
import System.Timeout (timeout)
import Text.Read (readMaybe)

data LiveSetup = LiveSetup
  { challenge :: Text
  , tenant :: Text
  , namespaces :: [Text]
  , bucket :: Text
  , kubeNamespace :: Text
  , brokerPods :: Map Text Text
  , stateFile :: FilePath
  }
  deriving stock (Generic, Show)

instance FromJSON LiveSetup

data StoreResult = StoreResult
  { manifestSha :: Text
  , storePointerHead :: Text
  , storeRedeliveryCount :: Maybe Int
  }
  deriving stock (Generic, Show)

instance FromJSON StoreResult where
  parseJSON = withObject "StoreResult" $ \value ->
    StoreResult <$> value .: "manifestSha" <*> value .: "pointerHead" <*> value .:? "redeliveryCount"

data FetchResult = FetchResult
  { fetchManifestSha :: Text
  , fetchPointerHead :: Text
  , artifactByteEqual :: Bool
  }
  deriving stock (Show)

instance FromJSON FetchResult where
  parseJSON = withObject "FetchResult" $ \value ->
    FetchResult <$> value .: "manifestSha" <*> value .: "pointerHead" <*> value .: "artifactByteEqual"

data BrokerObservation = BrokerObservation
  { observedActiveConsumerName :: Maybe Text
  , observedConsumers :: [Text]
  , observedUnackedMessages :: Int
  , observedBacklogMessages :: Int
  , observedMessageOutCounter :: Int
  , observedMessageInCounter :: Int
  }
  deriving stock (Show)

instance FromJSON BrokerObservation where
  parseJSON = withObject "BrokerObservation" $ \value ->
    BrokerObservation <$> value .: "activeConsumerName" <*> value .: "consumers"
      <*> value .: "unackedMessages" <*> value .: "backlogMessages"
      <*> value .: "messageOutCounter" <*> value .: "messageInCounter"

data RoundResult = RoundResult
  { namespace :: Text
  , experimentNamespace :: Text
  , promotedConsumer :: Text
  , redeliveryCount :: Int
  , externalCommandCount :: Int
  , externalDuplicateObserved :: Bool
  , manifestShaResult :: Text
  , pointerHeadResult :: Text
  , artifactByteEqualResult :: Bool
  , criticalWindow :: Text
  , computeExecuted :: Bool
  , activeBeforeKill :: BrokerObservation
  , activeAfterKill :: BrokerObservation
  }
  deriving stock (Generic, Show)

instance ToJSON RoundResult where
  toJSON result = object
    [ "namespace" .= namespace result
    , "experimentNamespace" .= experimentNamespace result
    , "promotedConsumer" .= promotedConsumer result
    , "redeliveryCount" .= redeliveryCount result
    , "externalCommandCount" .= externalCommandCount result
    , "externalDuplicateObserved" .= externalDuplicateObserved result
    , "manifestSha" .= manifestShaResult result
    , "pointerHead" .= pointerHeadResult result
    , "artifactByteEqual" .= artifactByteEqualResult result
    , "criticalWindow" .= criticalWindow result
    , "computeExecuted" .= computeExecuted result
    , "activeBeforeKill" .= observationValue (activeBeforeKill result)
    , "activeAfterKill" .= observationValue (activeAfterKill result)
    ]
    where
      observationValue observed = object
        [ "activeConsumerName" .= observedActiveConsumerName observed
        , "consumers" .= observedConsumers observed
        , "unackedMessages" .= observedUnackedMessages observed
        , "backlogMessages" .= observedBacklogMessages observed
        , "messageOutCounter" .= observedMessageOutCounter observed
        , "messageInCounter" .= observedMessageInCounter observed
        ]

data ManagedWorker = ManagedWorker
  { workerName :: Text
  , workerOutput :: Handle
  , workerProcess :: ProcessHandle
  }

data BudgetRow = BudgetRow
  { budgetCase :: Text
  , rowCommitted :: Natural
  , rowAdditional :: Natural
  , rowConcurrent :: Natural
  , rowFailedSet :: Natural
  , rowMaxFailedSets :: Natural
  , rowObservedOrphan :: Natural
  , rowHorizon :: Natural
  , rowAge :: Natural
  , rowDeletionObserved :: Bool
  , rowSupply :: Natural
  , rowExpectedPeak :: Natural
  , rowExpected :: Text
  }
  deriving stock (Show)

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  arguments <- getArgs
  case arguments of
    ["--worker", root, statePath, namespaceName, worker, rawPort, challengeValue] ->
      case readMaybe rawPort of
        Nothing -> fail "content-store-workflow-worker-port"
        Just port -> runWorker root statePath (Text.pack namespaceName) (Text.pack worker) port (Text.pack challengeValue)
    [] -> runGate
    _ -> fail ("content-store-workflow-arguments:" <> show arguments)

runGate :: IO ()
runGate = do
  root <- projectRoot
  pureChecks root
  pureOnly <- lookupEnv "CONTENT_STORE_WORKFLOW_PURE_ONLY"
  reuse <- lookupEnv "CONTENT_STORE_WORKFLOW_REUSE_FRESH_LIVE"
  if pureOnly == Just "1"
    then pure ()
    else if reuse == Just "1" then validateFreshEvidence root else runLive root
  putStrLn "content-store-workflow-live: PASS (canonical store, conditional CAS, orphan GC, terminal Job, native Failover takeover, teardown)"

pureChecks :: FilePath -> IO ()
pureChecks root = do
  canonical <- expectedManifest
  let forward = map (uncurry component) workflowComponents
      reverseOrder = reverse forward
  first <- either (fail . Text.unpack) pure (manifest forward)
  second <- either (fail . Text.unpack) pure (manifest reverseOrder)
  assertEqual "canonical-manifest-writer-a" canonical (canonicalManifestBytes first)
  assertEqual "canonical-manifest-writer-b" canonical (canonicalManifestBytes second)
  expectedSha <- Text.strip <$> TextIO.readFile (root </> "test/golden/content_store/manifest_canonical.sha256")
  assertEqual "canonical-manifest-sha" expectedSha (digestHex (manifestContentDigest first))
  oracle <- helperJson root [root </> "tools/content_store_workflow_oracle.py"]
  case oracle of
    Object value -> do
      assertEqual "independent-oracle-hex" (Just (String (toHex canonical))) (KeyMap.lookup "canonicalHex" value)
      assertEqual "independent-oracle-sha" (Just (String expectedSha)) (KeyMap.lookup "canonicalSha256" value)
      assertEqual "independent-oracle-first-mismatch" (Just (Number 24)) (KeyMap.lookup "firstMismatchOffset" value)
    _ -> fail "content-store-workflow-independent-oracle-not-object"
  noncanonical <- readHexCustody (root </> "test/golden/content_store/manifest_noncanonical.cbor")
  assertEqual "noncanonical-first-component-offset" (Just 24) (firstMismatch canonical noncanonical)
  assert (contentDigest noncanonical /= manifestContentDigest first) "noncanonical-key-did-not-differ"
  budgetRows <- loadBudgetRows (root </> "test/golden/content_store/write_budget_boundaries.csv")
  mapM_ checkBudgetRow budgetRows
  pointerChecks first
  terminalChecks
  resourceChecks
  runtimeChecks
  ranks <- filter (not . Text.null) . map Text.strip . Text.lines <$> TextIO.readFile (root </> "test/golden/workflow_runtime/failover_rank.txt")
  assertEqual "independent-failover-rank" ["worker-a", "worker-b", "worker-c"] ranks
  assertEqual "worker-critical-window-order" [StoreArtifact, EmitWorkflowEvent, AcknowledgeCommand] workerCriticalSteps
  assertEqual "forbidden-coordination-surface" [] coordinationSurfaces
  assertEqual "postflight-sweep-domain" ["kubernetes", "minio", "pulsar"] sweepClasses
  topology <- TextIO.readFile (root </> "dhall/test/round_trip_failover.dhall")
  mapM_ (\needle -> assert (needle `Text.isInfixOf` topology) ("topology-missing:" <> Text.unpack needle))
    ["linux-cpu", "worker-a", "worker-b", "worker-c", "content-gateway", "completion-collector"]
  where
    component name payload = Component name (contentDigest payload)

expectedManifest :: IO ByteString
expectedManifest = do
  root <- projectRoot
  readHexCustody (root </> "test/golden/content_store/manifest_canonical.cbor")

pointerChecks :: Manifest -> IO ()
pointerChecks value = do
  let headValue = pointerHead (manifestContentDigest value)
      oldValue = pointerHead (contentDigest "content-store-workflow-old")
  assertEqual "pointer-empty-write" (PointerWrite headValue) (decideAdvance SameOrLexicographicallyGreater Nothing headValue)
  assertEqual "pointer-equal-noop" (PointerAlreadyCommitted headValue) (decideAdvance SameOrLexicographicallyGreater (Just headValue) headValue)
  case decideAdvance SameOrLexicographicallyGreater (Just oldValue) headValue of
    PointerWrite _ -> pure ()
    PointerAdvanceRejected _ _ -> pure ()
    outcome -> fail ("pointer-total-decision:" <> show outcome)
  assertEqual "pointer-body-size" 32 (ByteString.length (pointerHeadBytes headValue))

terminalChecks :: IO ()
terminalChecks = do
  let expected = JobCompletion "execution-1" JobSucceeded "revision-1"
      observation gateway readback deadline release = CompletionObservation "pod-uid-1" True gateway readback deadline release
  assertEqual "terminal-persist" (Right (PersistCompletion expected)) (decideTerminalCleanup expected (observation False Nothing False False))
  assertEqual "terminal-retain-without-readback" (Right (RetainTerminal "pod-uid-1")) (decideTerminalCleanup expected (observation True Nothing True True))
  assertEqual "terminal-completed-noop" (Right (CompletedJobNoOp "pod-uid-1")) (decideTerminalCleanup expected (observation True (Just expected) False False))
  assertEqual "terminal-delete-after-proof" (Right (DeleteVerifiedTerminal "pod-uid-1")) (decideTerminalCleanup expected (observation True (Just expected) True True))
  assertEqual "terminal-mismatch" (Left CompletionReadbackMismatch) (decideTerminalCleanup expected (observation True (Just expected {completionRevision = "wrong"}) True True))
  assert (ByteString.length (canonicalJobCompletion expected) > 32) "completion-canonical-bytes-empty"

resourceChecks :: IO ()
resourceChecks = do
  let demand = phase37RuntimeDemand
      exact = workflowProvisionTerms demand
  provisioned <- either (fail . ("exact-fit-provision:" <>) . show) pure (provisionWorkflowRuntime demand exact)
  assertEqual "provisioned-terms" exact (provisionedTerms provisioned)
  assertEqual "provisioned-source-domain"
    ["orchestrator", "worker-a", "worker-b", "worker-c", "content-gateway", "completion-collector"]
    (map sourceIdentity (provisionedSources provisioned))
  mapM_ (oneShort demand exact) (Map.keys exact)
  case provisionWorkflowRuntime demand {runtimeAcceleratorCount = 1} exact of
    Left [RuntimeAcceleratorForbidden 1] -> pure ()
    outcome -> fail ("linux-cpu-accelerator-not-foreclosed:" <> show outcome)
  where
    oneShort demand exact term =
      let supply = Map.adjust (\value -> value - 1) term exact
       in case provisionWorkflowRuntime demand supply of
            Left errors | any (matches term) errors -> pure ()
            outcome -> fail ("resource-one-short-not-rejected:" <> Text.unpack term <> ":" <> show outcome)
    matches term (ProvisionDeficit actual _ _) = term == actual
    matches _ _ = False

runtimeChecks :: IO ()
runtimeChecks = do
  let work = WorkId "work-1"
      (_, once) = applyWork work emptyRuntimeState
      (secondApplied, twice) = applyWork work once
  assert (not secondApplied && appliedEffectCount twice == 1) "double-application-on-redelivery"
  let active = emptyRuntimeState {openConsumerHandles = Set.singleton "worker-a", activeConsumerName = Just "worker-a"}
      promoted = promoteStandby "worker-a" "worker-b" active
  assertEqual "standby-promotion-active" (Just "worker-b") (activeConsumerName promoted)
  assertEqual "standby-promotion-invariant" (Right ()) (runtimeInvariant promoted)

checkBudgetRow :: BudgetRow -> IO ()
checkBudgetRow row = do
  let demand = ObjectStoreDemand
        (StorageBudgetId "content-store-workflow-content")
        (Set.singleton "bucket/run/blobs/object")
        (rowCommitted row) (rowAdditional row) (rowConcurrent row)
        (rowFailedSet row) (rowMaxFailedSets row) (rowHorizon row)
        (ExclusiveContentWriter "content-gateway")
      observation = BudgetObservation (rowObservedOrphan row) (rowAge row) (rowDeletionObserved row)
      peak = logicalPeakBytes demand observation
      decision = admitObjectStore (rowSupply row) demand observation
      actual = case decision of
        ObjectStoreAdmitted _ -> "allow"
        ObjectStoreCapacityExceeded _ _ -> "deny"
        ObjectStoreDemandInvalid problem -> "invalid:" <> problem
  assertEqual ("write-budget-peak-mismatch:" <> Text.unpack (budgetCase row)) (rowExpectedPeak row) peak
  assertEqual ("write-budget-boundary-mismatch:" <> Text.unpack (budgetCase row)) (rowExpected row) actual

loadBudgetRows :: FilePath -> IO [BudgetRow]
loadBudgetRows path = do
  rows <- drop 1 . filter (not . Text.null) . Text.lines <$> TextIO.readFile path
  mapM parseRow rows
  where
    parseRow line = case Text.splitOn "," line of
      [name, committed, additional, concurrent, failedSet, maxFailed, orphan, horizon, age, deleted, supply, peak, expected] ->
        BudgetRow name <$> natural committed <*> natural additional <*> natural concurrent <*> natural failedSet
          <*> natural maxFailed <*> natural orphan <*> natural horizon <*> natural age <*> boolean deleted
          <*> natural supply <*> natural peak <*> pure expected
      fields -> fail ("budget-row-columns:" <> show fields)
    natural raw = maybe (fail ("budget-natural:" <> Text.unpack raw)) pure (readMaybe (Text.unpack raw))
    boolean "true" = pure True
    boolean "false" = pure False
    boolean raw = fail ("budget-boolean:" <> Text.unpack raw)

runLive :: FilePath -> IO ()
runLive root = do
  setupValue <- helperJson root [root </> "tools/content_store_workflow_live.py", "setup"]
  setup <- case fromJSON setupValue of
    Error problem -> fail ("content-store-workflow-setup-json:" <> problem)
    Success value -> pure value
  let resultPath = "/tmp/amoebius-content-store-workflow-result-" <> Text.unpack (challenge setup) <> ".json"
      cleanup = callHelper root [root </> "tools/content_store_workflow_live.py", "cleanup", "--state", stateFile setup]
  (do
      results <- forM (zip [16651 ..] (namespaces setup)) $ \(port, namespaceName) ->
        runRound root setup namespaceName port
      LazyByteString.writeFile resultPath (encode results)
      callHelper root [root </> "tools/content_store_workflow_live.py", "finish", "--state", stateFile setup, "--result", resultPath]
    ) `finally` cleanup

runRound :: FilePath -> LiveSetup -> Text -> Int -> IO RoundResult
runRound root setup namespaceName port = do
  brokerPod <- maybe (fail ("content-store-workflow-broker-owner:" <> Text.unpack namespaceName)) pure (Map.lookup namespaceName (brokerPods setup))
  withBrokerForward brokerPod port $ do
    workers <- mapM (startWorker root setup namespaceName port) ["worker-a", "worker-b", "worker-c"]
    let stopWorkers = mapM_ stopWorker workers
    flip finally stopWorkers $ do
      (workerA, workerB) <- case workers of
        [firstWorker, secondWorker, _thirdWorker] -> pure (firstWorker, secondWorker)
        _ -> fail "content-store-workflow-worker-domain"
      before <- waitForActive root setup namespaceName "worker-a"
      assertEqual "failover-consumer-rank-domain" ["worker-a", "worker-b", "worker-c"] (observedConsumers before)
      withNativeClient (Broker "127.0.0.1" (show port)) $ \client -> do
        let (commandTopic, eventTopic) = workflowTopics setup namespaceName
            command = WorkflowCommand (WorkId ("work-" <> namespaceName)) (challenge setup)
        eventConsumer <- Consumer.newConsumer client eventTopic "orchestrator-event" Exclusive
        externalConsumer <- Consumer.newConsumer client commandTopic "external-command-observer" Exclusive
        commandProducer <- Producer.newProducer client commandTopic ("orchestrator-command-" <> namespaceName)
        _ <- Producer.produceAtSequence commandProducer 37 command
        external <- receiveWithin externalConsumer
        assertEqual "external-command-body" command (Consumer.receivedValue external)
        Consumer.acknowledge externalConsumer (Consumer.receivedMessageId external)
        duplicate <- timeout (2 * 1000000) (Consumer.receive externalConsumer)
        duplicateObserved <- case duplicate of
          Nothing -> pure False
          Just (Left problem) -> fail ("external-command-CBOR:" <> show problem)
          Just (Right _) -> pure True
        activeLine <- workerLine workerA "STORED_UNACKED"
        _activeStore <- parseTaggedJson "STORED_UNACKED" activeLine :: IO StoreResult
        inWindow <- observeBroker root setup namespaceName
        assertEqual "critical-window-active-consumer" (Just "worker-a") (observedActiveConsumerName inWindow)
        assert
          (max (observedUnackedMessages inWindow) (observedBacklogMessages inWindow) >= 1)
          "critical-window-outstanding-message-not-observed"
        stopWorker workerA
        after <- waitForActive root setup namespaceName "worker-b"
        committedLine <- workerLine workerB "COMMITTED"
        committed <- parseTaggedJson "COMMITTED" committedLine :: IO StoreResult
        event <- receiveWithin eventConsumer
        let workflowEvent = Consumer.receivedValue event
        assert (eventMatchesCommand command workflowEvent) "workflow-event-command-correlation"
        assertEqual "promoted-worker-event" "worker-b" (eventWorkerName workflowEvent)
        Consumer.acknowledge eventConsumer (Consumer.receivedMessageId event)
        fetchValue <- helperJson root
          [ root </> "tools/content_store_workflow_live.py", "fetch", "--state", stateFile setup
          , "--namespace", Text.unpack namespaceName, "--manifest-sha", Text.unpack (manifestSha committed)
          ]
        fetched <- case fromJSON fetchValue of
          Error problem -> fail ("content-store-workflow-fetch-json:" <> problem)
          Success value -> pure value
        assertEqual "fetch-manifest-sha" (manifestSha committed) (fetchManifestSha fetched)
        assertEqual "fetch-pointer-head" (storePointerHead committed) (fetchPointerHead fetched)
        assert (artifactByteEqual fetched) "fetch-artifact-byte-mismatch"
        Consumer.closeConsumer eventConsumer
        Consumer.closeConsumer externalConsumer
        Producer.closeProducer commandProducer
        pure RoundResult
          { namespace = namespaceName, experimentNamespace = namespaceName
          , promotedConsumer = "worker-b", redeliveryCount = maybe 0 id (storeRedeliveryCount committed)
          , externalCommandCount = 1, externalDuplicateObserved = duplicateObserved
          , manifestShaResult = manifestSha committed, pointerHeadResult = storePointerHead committed
          , artifactByteEqualResult = artifactByteEqual fetched
          , criticalWindow = "store-written/event-unacked", computeExecuted = True
          , activeBeforeKill = inWindow, activeAfterKill = after
          }

runWorker :: FilePath -> FilePath -> Text -> Text -> Int -> Text -> IO ()
runWorker root statePath namespaceName name port challengeValue =
  withNativeClient (Broker "127.0.0.1" (show port)) $ \client -> do
    stateRaw <- eitherDecodeFileStrict' statePath
    setupState <- case stateRaw of
      Left problem -> fail ("worker-state-json:" <> problem)
      Right (Object stateObject) -> case KeyMap.lookup "tenant" stateObject of
        Just (String value) -> pure value
        _ -> fail "worker-state-tenant"
      Right _ -> fail "worker-state-object"
    let (realCommandTopic, realEventTopic) = workflowTopicsRaw setupState namespaceName
    consumer <- Consumer.newRankedConsumer client realCommandTopic "workflow-failover" name (workerPriority name) Failover
    putStrLn ("READY " <> Text.unpack name)
    delivery <- receiveWorker consumer
    let command = Consumer.receivedValue delivery :: WorkflowCommand
    assertEqual "worker-command-challenge" challengeValue (commandChallenge command)
    when (workerCriticalSteps /= [StoreArtifact, EmitWorkflowEvent, AcknowledgeCommand]) $
      Consumer.acknowledge consumer (Consumer.receivedMessageId delivery)
    rawStoreResult <- storeThroughGateway root statePath namespaceName
    let storeResult = rawStoreResult {storeRedeliveryCount = Just (Consumer.receivedRedeliveryCount delivery)}
    if name == "worker-a"
      then do
        putStrLn ("STORED_UNACKED " <> jsonText storeResult)
        keepConsumerAlive consumer
      else do
        producer <- Producer.newProducer client realEventTopic ("workflow-event-" <> name)
        let event = WorkflowEvent (commandWorkId command) (hexText (manifestSha storeResult)) name
        _ <- Producer.produceAtSequence producer 73 event
        Consumer.acknowledge consumer (Consumer.receivedMessageId delivery)
        putStrLn ("COMMITTED " <> jsonText storeResult)
        keepConsumerAlive consumer

workerPriority :: Text -> Int32
workerPriority "worker-a" = 0
workerPriority "worker-b" = 1
workerPriority "worker-c" = 2
workerPriority name = error ("content-store-workflow-worker-priority-domain:" <> Text.unpack name)

storeThroughGateway :: FilePath -> FilePath -> Text -> IO StoreResult
storeThroughGateway root statePath namespaceName = do
  value <- manifestFromComponents
  helper <- helperJson root
    [ root </> "tools/content_store_workflow_live.py", "store", "--state", statePath
    , "--namespace", Text.unpack namespaceName
    , "--manifest-hex", Text.unpack (toHex (canonicalManifestBytes value))
    , "--manifest-sha", Text.unpack (digestHex (manifestContentDigest value))
    ]
  case fromJSON helper of
    Error problem -> fail ("content-store-workflow-store-json:" <> problem)
    Success result -> pure result

manifestFromComponents :: IO Manifest
manifestFromComponents =
  either (fail . Text.unpack) pure (manifest [Component name (contentDigest payload) | (name, payload) <- workflowComponents])

workflowTopics :: LiveSetup -> Text -> (Topic, Topic)
workflowTopics setup = workflowTopicsRaw (tenant setup)

workflowTopicsRaw :: Text -> Text -> (Topic, Topic)
workflowTopicsRaw tenantName namespaceName =
  ( topicFor tenantName namespaceName commandRoute LinuxCpu
  , topicFor tenantName namespaceName eventRoute LinuxCpu
  )
  where
    commandRoute = RouteEntry "workflow" "command" (Set.singleton LinuxCpu) Input False (Just "workflow") True
    eventRoute = RouteEntry "workflow" "event" (Set.singleton LinuxCpu) Report False (Just "workflow") True

startWorker :: FilePath -> LiveSetup -> Text -> Int -> Text -> IO ManagedWorker
startWorker root setup namespaceName port name = do
  executable <- getExecutablePath
  (_, outputHandle, _, processHandle) <- createProcess
    (proc executable
      [ "--worker", root, stateFile setup, Text.unpack namespaceName, Text.unpack name
      , show port, Text.unpack (challenge setup)
      ]) {cwd = Just root, std_out = CreatePipe, std_err = Inherit}
  output <- maybe (fail "worker-output-handle-missing") pure outputHandle
  hSetBuffering output LineBuffering
  _ <- workerLine (ManagedWorker name output processHandle) "READY"
  pure (ManagedWorker name output processHandle)

stopWorker :: ManagedWorker -> IO ()
stopWorker worker = do
  running <- getProcessExitCode (workerProcess worker)
  case running of
    Just _ -> pure ()
    Nothing -> terminateProcess (workerProcess worker)
  _ <- waitForProcess (workerProcess worker) `catch` \(_ :: SomeException) -> pure ExitSuccess
  pure ()

workerLine :: ManagedWorker -> String -> IO String
workerLine worker tag = do
  outcome <- timeout (60 * 1000000) (go (workerOutput worker))
  maybe (fail ("worker-line-timeout:" <> Text.unpack (workerName worker) <> ":" <> tag)) pure outcome
  where
    go handle = do
      line <- hGetLine handle
      if tag `isInfixOf` line then pure line else go handle

waitForActive :: FilePath -> LiveSetup -> Text -> Text -> IO BrokerObservation
waitForActive root setup namespaceName expected = poll 90
  where
    expectedConsumers
      | expected == "worker-a" = ["worker-a", "worker-b", "worker-c"]
      | expected == "worker-b" = ["worker-b", "worker-c"]
      | otherwise = [expected]
    poll :: Int -> IO BrokerObservation
    poll 0 = fail ("active-consumer-timeout:" <> Text.unpack expected)
    poll attempts = do
      observed <- observeBroker root setup namespaceName
      if observedActiveConsumerName observed == Just expected && sort (observedConsumers observed) == expectedConsumers
        then pure observed
        else threadDelay 500000 >> poll (attempts - 1)

observeBroker :: FilePath -> LiveSetup -> Text -> IO BrokerObservation
observeBroker root setup namespaceName = do
  value <- helperJson root
    [ root </> "tools/content_store_workflow_live.py", "observe", "--state", stateFile setup
    , "--namespace", Text.unpack namespaceName
    ]
  case fromJSON value of
    Error problem -> fail ("content-store-workflow-observe-json:" <> problem)
    Success result -> pure result

withBrokerForward :: Text -> Int -> IO a -> IO a
withBrokerForward brokerPod port action = bracket start stop (const action)
  where
    start = do
      (_, outputHandle, _, processHandle) <- createProcess
        (proc "/usr/bin/kubectl"
          [ "--kubeconfig", "/home/matthewnowak/.amoebius/phase24/kubeconfig", "-n", "pulsar-system"
          , "port-forward", "pod/" <> Text.unpack brokerPod, show port <> ":6650"
          ]) {std_out = CreatePipe, std_err = Inherit}
      output <- maybe (fail "broker-forward-output-missing") pure outputHandle
      hSetBuffering output LineBuffering
      waitForward output
      pure processHandle
    stop processHandle = terminateProcess processHandle >> (waitForProcess processHandle >> pure ())
    waitForward output = do
      line <- hGetLine output
      unless ("Forwarding from" `isInfixOf` line) (waitForward output)

receiveWithin :: Serialise a => Consumer.Consumer a -> IO (Consumer.Received a)
receiveWithin consumer = do
  result <- timeout (30 * 1000000) (Consumer.receive consumer)
  case result of
    Nothing -> fail "content-store-workflow-pulsar-message-timeout"
    Just (Left problem) -> fail ("content-store-workflow-pulsar-CBOR:" <> show problem)
    Just (Right received) -> pure received

receiveWorker :: Serialise a => Consumer.Consumer a -> IO (Consumer.Received a)
receiveWorker consumer = bracket startTicker killThread $ \_ticker -> do
  result <- Consumer.receive consumer
  case result of
    Left problem -> fail ("content-store-workflow-worker-pulsar-CBOR:" <> show problem)
    Right received -> pure received
  where
    startTicker = forkIO $ forever $ do
      threadDelay (2 * 1000000)
      Consumer.redeliverUnacknowledged consumer
      Consumer.grantPermits consumer 32

keepConsumerAlive :: Serialise a => Consumer.Consumer a -> IO value
keepConsumerAlive consumer = forever $ do
  result <- Consumer.receive consumer
  case result of
    Left problem -> fail ("content-store-workflow-worker-keepalive-CBOR:" <> show problem)
    Right delivery -> Consumer.acknowledge consumer (Consumer.receivedMessageId delivery)

validateFreshEvidence :: FilePath -> IO ()
validateFreshEvidence root = do
  let path = root </> "DEVELOPMENT_PLAN/evidence/phase_37/content-store-workflow-live.json"
  present <- doesFileExist path
  unless present (fail "content-store-workflow-live-evidence-missing")
  decoded <- eitherDecode <$> LazyByteString.readFile path
  case decoded of
    Left problem -> fail ("content-store-workflow-evidence-json:" <> problem)
    Right (Object value) -> do
      assertEqual "content-store-workflow-evidence-sealed" (Just (Bool True)) (KeyMap.lookup "sealed" value)
      assertEqual "content-store-workflow-evidence-register" (Just (Number 3)) (KeyMap.lookup "register" value)
      assertEqual "content-store-workflow-evidence-substrate" (Just (String "linux-cpu")) (KeyMap.lookup "substrate" value)
    Right _ -> fail "content-store-workflow-evidence-not-object"

helperJson :: FilePath -> [String] -> IO Value
helperJson _root arguments = do
  (exitCode, output, errors) <- readProcessWithExitCode "/usr/bin/python3" arguments ""
  unless (exitCode == ExitSuccess) (fail ("content-store-workflow-helper:" <> show arguments <> ":" <> output <> errors))
  case eitherDecodeStrict' (TextEncoding.encodeUtf8 (Text.strip (Text.pack output))) of
    Left problem -> fail ("content-store-workflow-helper-json:" <> problem <> ":" <> output)
    Right value -> pure value

callHelper :: FilePath -> [String] -> IO ()
callHelper _ arguments = do
  (exitCode, output, errors) <- readProcessWithExitCode "/usr/bin/python3" arguments ""
  unless (exitCode == ExitSuccess) (fail ("content-store-workflow-helper-call:" <> show arguments <> ":" <> output <> errors))

parseTaggedJson :: FromJSON a => String -> String -> IO a
parseTaggedJson tag line = case stripPrefix (tag <> " ") (dropWhile isSpace line) of
  Nothing -> fail ("worker-tag-absent:" <> tag <> ":" <> line)
  Just raw -> case eitherDecodeStrict' (TextEncoding.encodeUtf8 (Text.pack raw)) of
        Left problem -> fail ("worker-tagged-json:" <> tag <> ":" <> problem <> ":" <> line)
        Right value -> pure value

jsonText :: ToJSON a => a -> String
jsonText = Text.unpack . TextEncoding.decodeUtf8 . LazyByteString.toStrict . encode

instance ToJSON StoreResult where
  toJSON result = object
    [ "manifestSha" .= manifestSha result
    , "pointerHead" .= storePointerHead result
    , "redeliveryCount" .= storeRedeliveryCount result
    ]

hexText :: Text -> ByteString
hexText = hex . Text.unpack

readHexCustody :: FilePath -> IO ByteString
readHexCustody path = do
  rows <- filter (not . Text.null) . map Text.strip . Text.lines <$> TextIO.readFile path
  let payload = Text.concat [row | row <- rows, not ("#" `Text.isPrefixOf` row)]
  pure (hex (Text.unpack payload))

firstMismatch :: ByteString -> ByteString -> Maybe Int
firstMismatch left right
  | ByteString.length left /= ByteString.length right = Just (min (ByteString.length left) (ByteString.length right))
  | otherwise = findIndex (uncurry (/=)) (ByteString.zip left right)

hex :: String -> ByteString
hex [] = ByteString.empty
hex (left : right : rest) = ByteString.cons (fromIntegral (digitToInt left * 16 + digitToInt right)) (hex rest)
hex _ = error "odd hexadecimal fixture"

toHex :: ByteString -> Text
toHex = Text.concatMap byteHex . TextEncoding.decodeLatin1
  where
    byteHex character =
      let value = fromEnum character
          digits = "0123456789abcdef"
       in Text.pack [digits !! (value `div` 16), digits !! (value `mod` 16)]

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= findRoot
  where
    findRoot directory = do
      marker <- doesFileExist (directory </> "amoebius.cabal")
      if marker then pure directory else do
        let parent = takeDirectory directory
        if parent == directory then fail "amoebius-project-root-not-found" else findRoot parent

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual label expected actual = unless (expected == actual) (fail (label <> ":expected=" <> show expected <> ":actual=" <> show actual))
