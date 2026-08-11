{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Pulsar.Connection
import Amoebius.Pulsar.Consumer qualified as Consumer
import Amoebius.Pulsar.Producer qualified as Producer
import Amoebius.Pulsar.Subscription
import Amoebius.Pulsar.Topology
import Amoebius.Ui.Server.RequestContext
import Amoebius.Ui.Server.ScopedAuthority
import Codec.Serialise (Serialise)
import Control.Exception (bracket, finally)
import Control.Monad (forM_, unless)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (FromJSON, ToJSON, Value (..), eitherDecodeFileStrict', eitherDecodeStrict', encode)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Text.IO qualified as TextIO
import GHC.Generics (Generic)
import Numeric (showHex)
import System.Directory (doesFileExist, getCurrentDirectory)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)
import System.IO (BufferMode (LineBuffering), hGetLine, hSetBuffering, stdout)
import System.Process
import System.Timeout (timeout)

data MatrixRow = MatrixRow
  { matrixCase :: Text
  , matrixProvider :: Text
  , matrixOperation :: ScopedOperation
  , matrixAuthoritySubject :: Text
  , matrixAuthorityTenant :: Text
  , matrixResourceTenant :: Text
  , matrixResourceOwner :: Text
  , matrixBodyTenant :: Text
  , matrixGrant :: GrantState
  , matrixExpectedPublic :: Text
  }
  deriving stock (Eq, Show)

data IsolationPayload = IsolationPayload
  { payloadChallenge :: Text
  , payloadTenant :: Text
  , payloadSubject :: Text
  }
  deriving stock (Eq, Generic, Show)

instance Serialise IsolationPayload

data LiveSetup = LiveSetup
  { challenge :: Text
  , tenant :: Text
  , namespaces :: [Text]
  , stateFile :: FilePath
  , brokerPods :: Map Text Text
  , identities :: Map Text Text
  }
  deriving stock (Generic, Show)

instance FromJSON LiveSetup

data PulsarResult = PulsarResult
  { resultNamespace :: Text
  , resultTopic :: Text
  , resultChallenge :: Text
  , resultNativeHaskellClient :: Bool
  , resultMessages :: Int
  }
  deriving stock (Generic, Show)

instance ToJSON PulsarResult

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  root <- projectRoot
  rows <- loadMatrix (root </> "test/fixtures/live_isolation/user_tenant_access_matrix.tsv")
  checkMatrix rows
  checkProvision
  reuse <- lookupEnv "PHASE36_REUSE_FRESH_LIVE"
  if reuse == Just "1"
    then validateEvidence root
    else runLive root
  putStrLn "user-tenant-isolation-live: PASS (Keycloak authority, scoped provider requests, RLS/prefix/topic isolation, CNI bypass refusal, teardown)"

checkMatrix :: [MatrixRow] -> IO ()
checkMatrix rows = do
  assertEqual "matrix row count" 17 (length rows)
  assertEqual "provider set" (Set.fromList ["Postgres", "Minio", "Pulsar"]) (Set.fromList (map matrixProvider rows))
  forM_ rows $ \row -> do
    credential <- testCredential (matrixAuthoritySubject row) (matrixAuthorityTenant row)
    let audience
          | matrixResourceOwner row == "*" = TenantAudience (matrixResourceTenant row) (matrixCase row)
          | otherwise = SubjectAudience (matrixResourceTenant row) (matrixResourceOwner row) (matrixCase row)
        hostile = HostileCallerFields (matrixBodyTenant row) "forged-subject"
        actual = either (const "denied") (const "allowed") (authorizeProviderRequest credential hostile audience (matrixGrant row) (matrixOperation row))
    unless (actual == matrixExpectedPublic row) (die ("matrix-mismatch:" <> Text.unpack (matrixCase row) <> ":expected=" <> Text.unpack (matrixExpectedPublic row) <> ":actual=" <> Text.unpack actual))

checkProvision :: IO ()
checkProvision = do
  let demand = ProbeDemand 3 750 805306368 402653184 24 262144 8 1048576 1048576 5
      exact = ProbeSupply 3 750 805306368 402653184 24 262144 8 1048576 1048576 5
      shortRows =
        [ exact {supplyPodSlots = 2}
        , exact {supplyCpuMillis = 749}
        , exact {supplyMemoryBytes = 805306367}
        , exact {supplyEphemeralBytes = 402653183}
        , exact {supplyApiObjects = 23}
        , exact {supplyEtcdBytes = 262143}
        , exact {supplySqlRows = 7}
        , exact {supplyObjectBytes = 1048575}
        , exact {supplyMessageBytes = 1048575}
        , exact {supplyObserverSlots = 4}
        ]
  assertEqual "probe exact fit" (Right ()) (provisionProbe demand exact)
  forM_ shortRows $ \supply -> case provisionProbe demand supply of
    Left [_] -> pure ()
    outcome -> die ("probe-one-short-not-rejected:" <> show outcome)

runLive :: FilePath -> IO ()
runLive root = do
  raw <- readProcess "python3" ["tools/phase36_isolation_live.py", "setup"] ""
  setup <- either die pure (eitherDecodeStrict' (Text.encodeUtf8 (Text.strip (Text.pack raw))))
  let resultPath = "/tmp/amoebius-phase36-result-" <> Text.unpack (challenge setup) <> ".json"
      cleanup = callProcess "python3" ["tools/phase36_isolation_live.py", "cleanup", "--state", stateFile setup]
  (do
      results <- mapM (runPulsarRound setup) (namespaces setup)
      Lazy.writeFile resultPath (encode results)
      callProcess "python3" ["tools/phase36_isolation_live.py", "finish", "--state", stateFile setup, "--result", resultPath]
    ) `finally` cleanup
  validateEvidence root

runPulsarRound :: LiveSetup -> Text -> IO PulsarResult
runPulsarRound setup namespace = do
  brokerPod <- maybe (die ("broker-owner-missing:" <> Text.unpack namespace)) pure (Map.lookup namespace (brokerPods setup))
  subject <- maybe (die ("identity-missing:" <> Text.unpack namespace)) pure (Map.lookup namespace (identities setup))
  credential <- testCredential subject namespace
  request <- either (const (die "allowed-pulsar-request-denied")) pure
    (authorizeProviderRequest credential (HostileCallerFields "hostile-body-tenant" "forged") (SubjectAudience namespace subject "isolation-events") NoGrant Produce)
  assertEqual "provider tenant is authority-derived" namespace (providerRequestTenant request)
  let route = RouteEntry "isolation" "events" (Set.singleton LinuxCpu) Report False (Just "phase36") True
      topic = topicFor (tenant setup) namespace route LinuxCpu
      payload = IsolationPayload (challenge setup) namespace subject
  withBrokerForward brokerPod $ withNativeClient (Broker "127.0.0.1" "16651") $ \client -> do
    consumer <- Consumer.newConsumer client topic ("p36-" <> namespace) Exclusive
    producer <- Producer.newProducer client topic ("p36-" <> namespace <> "-producer")
    _ <- Producer.produceAtSequence producer 1 payload
    received <- receiveWithin consumer
    assertEqual "native scoped CBOR" payload (Consumer.receivedValue received)
    Consumer.acknowledge consumer (Consumer.receivedMessageId received)
    Consumer.closeConsumer consumer
    Producer.closeProducer producer
  pure PulsarResult
    { resultNamespace = namespace
    , resultTopic = renderTopic topic
    , resultChallenge = challenge setup
    , resultNativeHaskellClient = True
    , resultMessages = 1
    }

receiveWithin :: Consumer.Consumer IsolationPayload -> IO (Consumer.Received IsolationPayload)
receiveWithin consumer = do
  outcome <- timeout (30 * 1000000) (Consumer.receive consumer)
  case outcome of
    Nothing -> die "pulsar-receive-timeout"
    Just (Left problem) -> die ("pulsar-decode:" <> show problem)
    Just (Right value) -> pure value

validateEvidence :: FilePath -> IO ()
validateEvidence root = do
  let path = root </> "DEVELOPMENT_PLAN/evidence/phase_36/user-tenant-isolation-live.json"
  present <- doesFileExist path
  unless present (die "phase36-live-evidence-absent")
  value <- either die pure =<< eitherDecodeFileStrict' path :: IO Value
  case value of
    Object object -> do
      assertEqual "evidence seal" (Just (Bool True)) (object .:? "sealed")
      assertEqual "evidence schema" (Just (String "amoebius.phase36.user-tenant-isolation.v1")) (object .:? "schemaVersion")
    _ -> die "phase36-live-evidence-not-object"
 where
  object .:? key = KeyMap.lookup (Key.fromText key) object

loadMatrix :: FilePath -> IO [MatrixRow]
loadMatrix path = do
  source <- Text.lines <$> TextIO.readFile path
  traverse parseRow (drop 1 source)
 where
  parseRow line = case Text.splitOn "\t" line of
    [caseName, provider, operation, subject, authorityTenant, resourceTenant, owner, bodyTenant, grant, expectedPublic, _] ->
      MatrixRow caseName provider <$> parseRead "operation" operation <*> pure subject <*> pure authorityTenant <*> pure resourceTenant <*> pure owner <*> pure bodyTenant <*> parseRead "grant" grant <*> pure expectedPublic
    _ -> die ("invalid-matrix-row:" <> Text.unpack line)
  parseRead label value = case reads (Text.unpack value) of
    [(parsed, "")] -> pure parsed
    _ -> die (label <> ":" <> Text.unpack value)

testCredential :: Text -> Text -> IO VerifiedCredential
testCredential subject tenantName = do
  key <- either (die . show) pure (signingKey signingKeyText)
  either (die . show) pure (verifyCredential key (claims <> "." <> signature claims))
 where
  claims = Text.intercalate "|" [subject, tenantName, "write", "active", "36", "phase36-session"]
  signature value = hex (SHA256.hmac (Text.encodeUtf8 signingKeyText) (Text.encodeUtf8 value))
  signingKeyText = "phase36-authority-signing-key-000000000001"

hex :: ByteString.ByteString -> Text
hex = Text.pack . concatMap twoHex . ByteString.unpack
 where
  twoHex byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

withBrokerForward :: Text -> IO value -> IO value
withBrokerForward pod action = bracket start stop (const action)
 where
  start = do
    (_, outputHandle, _, process) <- createProcess (proc "/usr/bin/kubectl" ["--kubeconfig", "/home/matthewnowak/.amoebius/phase24/kubeconfig", "-n", "pulsar-system", "port-forward", "pod/" <> Text.unpack pod, "16651:6650"]) {std_out = CreatePipe, std_err = CreatePipe}
    handle <- maybe (die "port-forward-output-missing") pure outputHandle
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
          Just code -> die ("port-forward-exit:" <> show code <> ":" <> line)
          Nothing -> waitForward process handle
  voidWait process = do
    _ <- waitForProcess process
    pure ()

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

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ":expected=" <> show expected <> ":actual=" <> show actual))
