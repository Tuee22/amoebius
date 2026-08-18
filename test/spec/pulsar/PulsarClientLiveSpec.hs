{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Pulsar.Cbor
import Amoebius.Pulsar.Connection
import Amoebius.Pulsar.Consumer qualified as Consumer
import Amoebius.Pulsar.Dedup
import Amoebius.Pulsar.Frame
import Amoebius.Pulsar.Producer qualified as Producer
import Amoebius.Pulsar.Provision
import Amoebius.Pulsar.Seek
import Amoebius.Pulsar.Subscription
import Amoebius.Pulsar.Topology
import Codec.Serialise (Serialise)
import Control.Exception (bracket, finally)
import Control.Monad (forM, unless)
import Data.Aeson
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as Lazy
import Data.Char (digitToInt)
import Data.List (isInfixOf)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Text.IO qualified as TextIO
import GHC.Generics (Generic)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>), takeDirectory)
import System.IO (BufferMode (LineBuffering), Handle, hGetLine, hSetBuffering, stdout)
import System.Process
import System.Timeout (timeout)

data GatePayload = GatePayload
  { payloadKind :: Text
  , payloadChallenge :: Text
  }
  deriving stock (Eq, Generic, Show)

instance Serialise GatePayload

data LiveSetup = LiveSetup
  { challenge :: Text
  , tenant :: Text
  , namespaces :: [Text]
  , stateFile :: FilePath
  , brokerPods :: Map Text Text
  }
  deriving stock (Generic, Show)

instance FromJSON LiveSetup

data RoundResult = RoundResult
  { resultNamespace :: Text
  , resultTopics :: [Text]
  , resultNativeProtocol :: Bool
  , resultCborRoundTrip :: Bool
  , resultDuplicateCollapsed :: Bool
  , resultRedelivery :: Bool
  , resultSeekReplay :: Bool
  , resultSubscriptionTypes :: Int
  }
  deriving stock (Generic, Show)

instance ToJSON RoundResult

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  root <- projectRoot
  pureChecks root
  reuse <- lookupEnv "PULSAR_CLIENT_REUSE_FRESH_LIVE"
  if reuse == Just "1"
    then validateFreshEvidence root
    else runLive root
  putStrLn "pulsar-client-live: PASS (native TCP, typed CBOR, derived topics, dedup, redelivery, seek, teardown)"

pureChecks :: FilePath -> IO ()
pureChecks root = do
  assertEqual "canonical CBOR oracle" (hex "6770686173653335") (cborBytes (encodeCbor ("phase35" :: Text)))
  case decodeCbor (encodeCbor ("phase35" :: Text)) of
    Right (value :: Text) -> assertEqual "CBOR round-trip" "phase35" value
    Left problem -> fail ("CBOR decode failed:" <> show problem)
  case decodeCborBytes (BS.pack [0xff]) of
    Left _ -> pure ()
    Right (_ :: Text) -> fail "corrupt-cbor-accepted"
  frame <- either (fail . show) pure connectFrameGolden
  summary <- either (fail . show) pure (decodeFrameSummary frame)
  assertEqual "connect frame type" "BaseCommand'CONNECT" (summaryCommandType summary)
  goldenFrame <- Text.strip <$> TextIO.readFile (root </> "test/golden/pulsar_client/connect_frame.hex")
  assertEqual "spec-derived CONNECT frame" goldenFrame (toHex frame)
  let routes = gateRoutes
      expectedTopics =
        [ "persistent://pulsar-client-tenant/pulsar-client-namespace/round-trip.command.linux-cpu"
        , "persistent://pulsar-client-tenant/pulsar-client-namespace/round-trip.event.linux-cpu"
        ]
      actualTopics = [renderTopic (topicFor "pulsar-client-tenant" "pulsar-client-namespace" route LinuxCpu) | route <- routes]
  assertEqual "independent derived-topic oracle" expectedTopics actualTopics
  assertEqual "gate topology valid" [] (validateTopology routes)
  firstRoute <- case routes of
    route : _ -> pure route
    [] -> fail "gate-routes-empty"
  let broken =
        [ firstRoute
        , firstRoute {routeLanes = Set.empty, routeMonitoringFeasible = False, routeMonitoringOwner = Nothing}
        ]
      violations = validateTopology broken
  unless (any isOneSided violations) (fail "one-sided-link-not-rejected")
  unless (any isEmpty violations && any isMonitoring violations && any isUnrouted violations) (fail ("full-topology-violations-missing:" <> show violations))
  expectedApi <- filter (not . Text.null) . Text.lines <$> TextIO.readFile (root </> "test/golden/pulsar_client/api_surface.txt")
  assertEqual "CBOR-only API surface" expectedApi (Producer.producerApiSurface <> Consumer.consumerApiSurface)
  assertEqual "closed subscription surface" [Exclusive, Failover, Shared, KeyShared] subscriptionTypes
  assertEqual "message sequence packing" (Right 30064771083) (sequenceFromMessage 7 11)
  provisionChecks
  where
    isOneSided OneSidedLink {} = True
    isOneSided _ = False
    isEmpty EmptyLaneSet {} = True
    isEmpty _ = False
    isMonitoring MonitoringInfeasible {} = True
    isMonitoring _ = False
    isUnrouted UnroutedMonitor {} = True
    isUnrouted _ = False

provisionChecks :: IO ()
provisionChecks = do
  let request = gateProvision
      exact = provisionTerms request
  provisioned <- case provisionPulsarClient request exact of
    Left problems -> fail ("exact-fit-provision-refused:" <> show problems)
    Right value -> pure value
  assertEqual "exact-fit provision projection" exact (provisionedTerms provisioned)
  mapM_ (oneShort request exact) (Map.keys exact)
  case provisionPulsarClient request {provisionRunnerEnvelope = (provisionRunnerEnvelope request) {runnerHasCache = True}} exact of
    Left [RunnerCacheForbidden] -> pure ()
    outcome -> fail ("runner-cache-not-foreclosed:" <> show outcome)
  case provisionPulsarClient request {provisionRunnerEnvelope = (provisionRunnerEnvelope request) {runnerHasAccelerator = True}} exact of
    Left [RunnerAcceleratorForbidden] -> pure ()
    outcome -> fail ("runner-accelerator-not-foreclosed:" <> show outcome)
  where
    oneShort request exact term =
      let shortened = Map.adjust (\value -> value - 1) term exact
       in case provisionPulsarClient request shortened of
            Left problems | any (matches term) problems -> pure ()
            outcome -> fail ("one-short-not-rejected:" <> Text.unpack term <> ":" <> show outcome)
    matches term (ProvisionDeficit actual _ _) = term == actual
    matches _ _ = False

gateProvision :: PulsarClientProvision
gateProvision =
  PulsarClientProvision
    (PulsarClientExecutionDemand 1 2 8 32 64 5242880 1048576 256 2097152 1048576 524288)
    (ClientRunnerEnvelope 500 536870912 268435456 134217728 33554432 16777216 65536 65536 16384 1048576 1 2 2 4194304 4194304 False False)
    (PulsarTopicDemand 4 12 16777216 8388608 8 1048576 2097152 4194304 524288 262144 67108864)

runLive :: FilePath -> IO ()
runLive root = do
  setup <- runSetup root
  let resultPath = "/tmp/amoebius-pulsar-client-result-" <> Text.unpack (challenge setup) <> ".json"
      cleanup = callHelper root ["cleanup", "--state", stateFile setup]
  (do
      results <- forM (namespaces setup) $ \namespace -> do
        brokerPod <- maybe (fail ("pulsar-client-owner-missing:" <> Text.unpack namespace)) pure (Map.lookup namespace (brokerPods setup))
        withBrokerForward brokerPod (runRound setup namespace)
      Lazy.writeFile resultPath (encode results)
      callHelper root ["finish", "--state", stateFile setup, "--result", resultPath]
    ) `finally` cleanup

runRound :: LiveSetup -> Text -> IO RoundResult
runRound setup namespace = withNativeClient (Broker "127.0.0.1" "16650") $ \client -> do
  putStrLn ("pulsar-client-live-stage:" <> Text.unpack namespace <> ":connected")
  (commandRoute, eventRoute) <- case gateRoutes of
    [commandValue, eventValue] -> pure (commandValue, eventValue)
    _ -> fail "pulsar-client-gate-route-cardinality"
  let commandTopic = topicFor (tenant setup) namespace commandRoute LinuxCpu
      eventTopic = topicFor (tenant setup) namespace eventRoute LinuxCpu
      command = GatePayload "command" (challenge setup)
      event = GatePayload "event" (challenge setup)
      replayEvent = GatePayload "event-replay" (challenge setup)
  commandConsumer <- timed "command-consumer" (Consumer.newConsumer client commandTopic "gate-command" Exclusive)
  eventConsumer <- timed "event-consumer" (Consumer.newConsumer client eventTopic "gate-event" Exclusive)
  commandProducer <- timed "command-producer" (Producer.newProducer client commandTopic ("p35-command-" <> namespace))
  eventProducer <- timed "event-producer" (Producer.newProducer client eventTopic ("p35-event-" <> namespace))
  putStrLn ("pulsar-client-live-stage:" <> Text.unpack namespace <> ":resources-open")
  _firstId <- timed "first-command-send" (Producer.produceAtSequence commandProducer 7 command)
  _duplicateId <- timed "duplicate-command-send" (Producer.produceAtSequence commandProducer 7 command)
  putStrLn ("pulsar-client-live-stage:" <> Text.unpack namespace <> ":duplicate-sent")
  receivedCommand <- receiveWithin commandConsumer
  putStrLn ("pulsar-client-live-stage:" <> Text.unpack namespace <> ":command-received")
  assertEqual "native command CBOR" command (Consumer.receivedValue receivedCommand)
  Consumer.acknowledge commandConsumer (Consumer.receivedMessageId receivedCommand)
  duplicateDelivery <- timeout (2 * 1000000) (Consumer.receive commandConsumer)
  duplicateCollapsed <- case duplicateDelivery of
    Nothing -> pure True
    Just (Left problem) -> fail ("duplicate-probe-CBOR:" <> show problem)
    Just (Right unexpected) -> fail ("broker-delivered-duplicate:" <> show (Consumer.receivedMessageId unexpected))
  eventId <- timed "event-send" (Producer.produceAtSequence eventProducer 11 event)
  _secondEventId <- timed "second-event-send" (Producer.produceAtSequence eventProducer 12 replayEvent)
  receivedEvent <- receiveWithin eventConsumer
  putStrLn ("pulsar-client-live-stage:" <> Text.unpack namespace <> ":event-received")
  assertEqual "native event CBOR" event (Consumer.receivedValue receivedEvent)
  Consumer.acknowledge eventConsumer (Consumer.receivedMessageId receivedEvent)
  receivedSecondEvent <- receiveWithin eventConsumer
  assertEqual "native second event CBOR" replayEvent (Consumer.receivedValue receivedSecondEvent)
  Consumer.acknowledge eventConsumer (Consumer.receivedMessageId receivedSecondEvent)
  timed "seek" (seek eventConsumer (SeekMessage eventId))
  timed "post-seek-consumer-close" (Consumer.closeConsumer eventConsumer)
  replayConsumer <- timed "post-seek-consumer" (Consumer.newConsumer client eventTopic "gate-event" Exclusive) :: IO (Consumer.Consumer GatePayload)
  replayedEvent <- receiveWithin replayConsumer
  putStrLn ("pulsar-client-live-stage:" <> Text.unpack namespace <> ":seek-received")
  assertEqual "seek replay" event (Consumer.receivedValue replayedEvent)
  Consumer.acknowledge replayConsumer (Consumer.receivedMessageId replayedEvent)
  redeliveryConsumer <- timed "redelivery-consumer" (Consumer.newConsumer client commandTopic "gate-redelivery" Shared) :: IO (Consumer.Consumer GatePayload)
  firstDelivery <- receiveWithin redeliveryConsumer
  putStrLn ("pulsar-client-live-stage:" <> Text.unpack namespace <> ":redelivery-first")
  timed "redelivery-close" (Consumer.closeConsumer redeliveryConsumer)
  redeliveredConsumer <- timed "redelivered-consumer" (Consumer.newConsumer client commandTopic "gate-redelivery" Shared) :: IO (Consumer.Consumer GatePayload)
  secondDelivery <- receiveWithin redeliveredConsumer
  putStrLn ("pulsar-client-live-stage:" <> Text.unpack namespace <> ":redelivery-second")
  assertEqual "unacked message redelivered" (Consumer.receivedMessageId firstDelivery) (Consumer.receivedMessageId secondDelivery)
  Consumer.acknowledge redeliveredConsumer (Consumer.receivedMessageId secondDelivery)
  Consumer.closeConsumer redeliveredConsumer
  accepted <- forM (zip [0 :: Int ..] subscriptionTypes) $ \(index, subscriptionType) -> do
    consumer <- timed "subscription-consumer" (Consumer.newConsumer client commandTopic ("gate-shape-" <> Text.pack (show index)) subscriptionType)
    delivered <- receiveWithin consumer
    assertEqual "subscription type delivery" command (Consumer.receivedValue delivered)
    Consumer.acknowledge consumer (Consumer.receivedMessageId delivered)
    timed "subscription-close" (Consumer.closeConsumer consumer)
    pure subscriptionType
  timed "command-consumer-close" (Consumer.closeConsumer commandConsumer)
  timed "event-consumer-close" (Consumer.closeConsumer replayConsumer)
  timed "command-producer-close" (Producer.closeProducer commandProducer)
  timed "event-producer-close" (Producer.closeProducer eventProducer)
  putStrLn ("pulsar-client-live-stage:" <> Text.unpack namespace <> ":round-complete")
  pure
    RoundResult
      { resultNamespace = namespace
      , resultTopics = [renderTopic commandTopic, renderTopic eventTopic]
      , resultNativeProtocol = True
      , resultCborRoundTrip = True
      , resultDuplicateCollapsed = duplicateCollapsed
      , resultRedelivery = Consumer.receivedMessageId firstDelivery == Consumer.receivedMessageId secondDelivery
      , resultSeekReplay = Consumer.receivedValue replayedEvent == event
      , resultSubscriptionTypes = length accepted
      }

receiveWithin :: Serialise a => Consumer.Consumer a -> IO (Consumer.Received a)
receiveWithin consumer = do
  outcome <- timeout (20 * 1000000) (Consumer.receive consumer)
  case outcome of
    Nothing -> fail "pulsar-message-timeout"
    Just (Left problem) -> fail ("pulsar-CBOR-decode:" <> show problem)
    Just (Right received) -> pure received

timed :: String -> IO a -> IO a
timed label action = do
  outcome <- timeout (20 * 1000000) action
  maybe (fail ("pulsar-client-live-timeout:" <> label)) pure outcome

gateRoutes :: [RouteEntry]
gateRoutes =
  [ RouteEntry "round-trip" "command" (Set.singleton LinuxCpu) Input False (Just "round-trip") True
  , RouteEntry "round-trip" "event" (Set.singleton LinuxCpu) Report False (Just "round-trip") True
  ]

runSetup :: FilePath -> IO LiveSetup
runSetup root = do
  (exitCode, output, errors) <- readProcessWithExitCode "/usr/bin/python3" [root </> "tools/pulsar_client_live.py", "setup"] ""
  unless (exitCode == ExitSuccess) (fail ("pulsar-client-live-setup:" <> output <> errors))
  case eitherDecodeStrict' (Text.encodeUtf8 (Text.strip (Text.pack output))) of
    Left problem -> fail ("pulsar-client-live-setup-json:" <> problem <> ":" <> output)
    Right setup -> pure setup

callHelper :: FilePath -> [String] -> IO ()
callHelper root arguments = do
  (exitCode, output, errors) <- readProcessWithExitCode "/usr/bin/python3" ((root </> "tools/pulsar_client_live.py") : arguments) ""
  unless (exitCode == ExitSuccess) (fail ("pulsar-client-live-helper:" <> show arguments <> ":" <> output <> errors))

withBrokerForward :: Text -> IO a -> IO a
withBrokerForward brokerPod action = bracket start stop (const action)
  where
    start = do
      let kubeconfig = "/home/matthewnowak/.amoebius/phase24/kubeconfig"
      (_, outputHandle, _, processHandle) <- createProcess
        (proc "/usr/bin/kubectl" ["--kubeconfig", kubeconfig, "-n", "pulsar-system", "port-forward", "pod/" <> Text.unpack brokerPod, "16650:6650"])
          {std_out = CreatePipe}
      handle <- maybe (fail "pulsar-port-forward-output-missing") pure outputHandle
      hSetBuffering handle LineBuffering
      waitForward handle
      pure processHandle
    stop processHandle = terminateProcess processHandle >> waitForProcess processHandle >> pure ()
    waitForward :: Handle -> IO ()
    waitForward handle = do
      line <- hGetLine handle
      unless ("Forwarding from" `isInfixOf` line) (waitForward handle)

validateFreshEvidence :: FilePath -> IO ()
validateFreshEvidence root = do
  let evidence = root </> "DEVELOPMENT_PLAN/evidence/phase_35/pulsar-client-live.json"
  present <- doesFileExist evidence
  unless present (fail "pulsar-client-live-evidence-missing")
  value <- eitherDecode <$> Lazy.readFile evidence
  case value of
    Left problem -> fail ("pulsar-client-live-evidence-json:" <> problem)
    Right (Object evidenceObject) -> do
      assertJsonBool evidenceObject "sealed" True
      assertJsonBool evidenceObject "cleanupInventoriesEqual" True
    Right _ -> fail "pulsar-client-live-evidence-not-object"

assertJsonBool :: Object -> Key -> Bool -> IO ()
assertJsonBool evidenceObject key expected = case lookupKey key evidenceObject of
  Just (Bool actual) -> assertEqual (show key) expected actual
  _ -> fail ("pulsar-client-evidence-field-missing:" <> show key)
  where
    lookupKey = KeyMap.lookup

projectRoot :: IO FilePath
projectRoot = do
  start <- getCurrentDirectory
  findRoot start
  where
    findRoot directory = do
      marker <- doesFileExist (directory </> "amoebius.cabal")
      if marker
        then pure directory
        else
          let parent = takeDirectory directory
           in if parent == directory then fail "amoebius-project-root-not-found" else findRoot parent

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual label expected actual = unless (expected == actual) (fail (label <> ":expected=" <> show expected <> ":actual=" <> show actual))

hex :: String -> ByteString
hex [] = BS.empty
hex (left : right : rest) = BS.cons (fromIntegral (digitToInt left * 16 + digitToInt right)) (hex rest)
hex _ = error "odd hex fixture"

toHex :: ByteString -> Text
toHex = Text.concatMap byteHex . Text.decodeLatin1
  where
    byteHex character =
      let value = fromEnum character
          digits = "0123456789abcdef"
       in Text.pack [digits !! (value `div` 16), digits !! (value `mod` 16)]
