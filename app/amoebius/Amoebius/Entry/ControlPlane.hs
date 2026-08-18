{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Entry.ControlPlane (runControlPlaneDaemon) where

import Amoebius.ControlPlane.AdminApi
import Amoebius.ControlPlane.Deploy
import Amoebius.ControlPlane.Reconcile (ObjectIdentity (..))
import Amoebius.ControlPlane.Daemon (ControlPlaneStateKind)
import Amoebius.Dsl.Decode (decodeCluster)
import Amoebius.Dsl.Error (DecodeError (..), decodeErrorTag)
import Control.Concurrent (MVar, forkFinally, newMVar, withMVar)
import Control.Exception (bracket, finally)
import Control.Monad (forever, unless, void)
import Data.Aeson (FromJSON (..), ToJSON, Value, eitherDecodeStrict', encode, object, withObject, (.:), (.:?), (.!=), (.=))
import Data.Aeson.Types (Pair)
import Data.ByteString qualified as StrictByteString
import Data.ByteString.Char8 qualified as Char8
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import GHC.Generics (Generic)
import Network.Socket
import Network.Socket.ByteString qualified as Socket
import System.Directory (removeFile)
import System.Exit (ExitCode (..), die)
import System.IO (hFlush, stdout)
import System.Process (proc, readCreateProcessWithExitCode)

helperPath :: FilePath
helperPath = "/live-dsl-deploy-artifacts/phase33_runtime_helper.py"

uploadPath :: FilePath
uploadPath = "/live-dsl-deploy-dhall/examples/live-dsl-deploy-upload.dhall"

data AdminRequest = AdminRequest
  { password :: Text
  , dhallSource :: Maybe Text
  , probes :: [SecretCapabilityProbe]
  , kvVerb :: Maybe Text
  , kvName :: Maybe Text
  , kvValue :: Maybe Text
  }
  deriving stock (Generic)

instance FromJSON AdminRequest where
  parseJSON = withObject "AdminRequest" $ \value ->
    AdminRequest
      <$> value .: "password"
      <*> value .:? "dhall"
      <*> value .:? "probes" .!= []
      <*> value .:? "verb"
      <*> value .:? "name"
      <*> value .:? "value"

data HttpRequest = HttpRequest
  { requestMethod :: StrictByteString.ByteString
  , requestPath :: StrictByteString.ByteString
  , requestHeaders :: Map StrictByteString.ByteString StrictByteString.ByteString
  , requestBody :: StrictByteString.ByteString
  }

runControlPlaneDaemon :: [String] -> IO ()
runControlPlaneDaemon _options = withSocketsDo $ do
  podUid <- Text.strip <$> TextIO.readFile "/etc/podinfo/uid"
  unless (not (Text.null podUid)) (die "control-plane-pod-uid-empty")
  recovered <- helperRequired ["recover-state"] ""
  ready <- newIORef False
  adminLock <- newMVar ()
  authorityLock <- newMVar ()
  logEvent podUid "prerequisites-ready" ["durableState" .= Text.strip (Text.pack recovered)]
  bracket openServer close (serve podUid ready adminLock authorityLock)

openServer :: IO Socket
openServer = do
  socketValue <- socket AF_INET Stream defaultProtocol
  setSocketOption socketValue ReuseAddr 1
  bind socketValue (SockAddrInet 18080 0)
  listen socketValue 32
  pure socketValue

serve :: Text -> IORef Bool -> MVar () -> MVar () -> Socket -> IO ()
serve podUid ready adminLock authorityLock server = forever $ do
  connection <- fst <$> accept server
  void $ forkFinally
    (do
      request <- receiveRequest connection
      responseBytes <- handleRequest podUid ready adminLock authorityLock request
      Socket.sendAll connection responseBytes)
    (const (close connection))

handleRequest :: Text -> IORef Bool -> MVar () -> MVar () -> HttpRequest -> IO StrictByteString.ByteString
handleRequest podUid ready adminLock authorityLock request = case (requestMethod request, requestPath request) of
  ("GET", "/healthz") -> pure (response 200 "text/plain" "healthy\n")
  ("GET", "/readyz") -> do
    serving <- withMVar authorityLock $ \_ -> refreshAuthority podUid ready
    pure (response (if serving then 200 else 503) "text/plain" (if serving then "ready\n" else "not-ready\n"))
  ("GET", "/metrics") -> pure (response 200 "text/plain" "amoebius_control_plane_daemon_ready 1\namoebius_control_plane_daemon_replicas 1\n")
  ("POST", "/v1/vault/init") -> withMVar adminLock $ \_ -> adminEndpoint VaultInit "vault-init" podUid ready authorityLock request
  ("POST", "/v1/vault/unseal") -> withMVar adminLock $ \_ -> adminEndpoint VaultUnseal "vault-unseal" podUid ready authorityLock request
  ("POST", "/v1/dhall/update") -> withMVar adminLock $ \_ -> dhallEndpoint podUid ready authorityLock request
  ("POST", "/v1/kv") -> withMVar adminLock $ \_ -> adminEndpoint KvCrud "kv" podUid ready authorityLock request
  _ -> pure (jsonResponse 404 (object ["tag" .= ("admin-endpoint-not-found" :: Text)]))

refreshAuthority :: Text -> IORef Bool -> IO Bool
refreshAuthority podUid ready = do
  outcome <- runHelper ["lease-acquire", Text.unpack podUid] ""
  case outcome of
    Left _ -> writeIORef ready False >> pure False
    Right _ -> do
      wasReady <- readIORef ready
      unless wasReady (logEvent podUid "lease-acquired" [])
      writeIORef ready True
      pure True

adminEndpoint :: EndpointFamily -> String -> Text -> IORef Bool -> MVar () -> HttpRequest -> IO StrictByteString.ByteString
adminEndpoint endpoint operation podUid ready authorityLock request = withAdmission endpoint request $ \_ -> do
  withFreshAuthority podUid ready authorityLock $ do
    outcome <- runHelper [operation] (Char8.unpack (requestBody request))
    case outcome of
      Left problem -> pure (jsonResponse 400 (object ["tag" .= ("admin-operation-refused" :: Text), "detail" .= problem]))
      Right result -> do
        writeIORef ready True
        logEvent podUid (Text.pack operation) []
        pure (response 200 "application/json" (Char8.pack result))

dhallEndpoint :: Text -> IORef Bool -> MVar () -> HttpRequest -> IO StrictByteString.ByteString
dhallEndpoint podUid ready authorityLock request = withAdmission DhallUpdate request $ \decoded ->
  case admitDhallUpdate (probes decoded) of
    Left problem -> pure (jsonResponse 422 (object ["tag" .= admissionErrorTag problem]))
    Right _ -> withFreshAuthority podUid ready authorityLock $ case dhallSource decoded of
        Nothing -> pure (jsonResponse 400 (object ["tag" .= ("dhall-source-absent" :: Text)]))
        Just source -> do
          TextIO.writeFile uploadPath source
          decodedSpec <- decodeCluster uploadPath `finally` removeFile uploadPath
          case decodedSpec of
            Left problem ->
              pure (jsonResponse 422 (object ["gate" .= rejectionGate problem, "tag" .= decodeErrorTag problem]))
            Right _ -> case provisionDeploy (deployDemand uploadPath) of
              Left problem ->
                pure (jsonResponse 422 (object ["tag" .= ("ProvisionError" :: Text), "detail" .= show problem]))
              Right _ -> do
                persisted <- runHelper ["persist-state"] (Char8.unpack (requestBody request))
                reconciled <- runHelper ["reconcile"] (Char8.unpack (requestBody request))
                case (persisted, reconciled) of
                  (Right durable, Right enactment) -> do
                    logEvent podUid "dhall-update" ["durableState" .= Text.strip (Text.pack durable)]
                    case (decodeHelperValue durable, decodeHelperValue enactment) of
                      (Right durableValue, Right enactmentValue) ->
                        pure (jsonResponse 200 (object ["result" .= ("converged" :: Text), "durable" .= durableValue, "enact" .= enactmentValue]))
                      _ -> pure (jsonResponse 500 (object ["tag" .= ("helper-json-invalid" :: Text)]))
                  (Left problem, _) -> pure (jsonResponse 500 (object ["tag" .= ("state-persist-failed" :: Text), "detail" .= problem]))
                  (_, Left problem) -> pure (jsonResponse 500 (object ["tag" .= ("reconcile-failed" :: Text), "detail" .= problem]))

withFreshAuthority :: Text -> IORef Bool -> MVar () -> IO StrictByteString.ByteString -> IO StrictByteString.ByteString
withFreshAuthority podUid ready authorityLock continuation = do
  held <- withMVar authorityLock $ \_ -> refreshAuthority podUid ready
  if held
    then continuation
    else pure (jsonResponse 503 (object ["tag" .= ("control-plane-lease-not-held" :: Text)]))

withAdmission :: EndpointFamily -> HttpRequest -> (AdminRequest -> IO StrictByteString.ByteString) -> IO StrictByteString.ByteString
withAdmission endpoint request continuation = case parseReach request of
  Left tag -> pure (jsonResponse 403 (object ["tag" .= tag]))
  Right reach -> case authorizeReach endpoint reach of
    Refuse tag -> pure (jsonResponse 403 (object ["tag" .= tag]))
    Admit -> case eitherDecodeStrict' (requestBody request) of
      Left _ -> pure (jsonResponse 400 (object ["tag" .= ("admin-json-invalid" :: Text)]))
      Right decoded
        | Text.null (password decoded) -> pure (jsonResponse 401 (object ["tag" .= ("operator-password-required" :: Text)]))
        | otherwise -> continuation decoded

parseReach :: HttpRequest -> Either Text ReachClass
parseReach request = case Map.lookup "x-amoebius-reach" (requestHeaders request) of
  Just "NodeLocal" -> Right NodeLocal
  Just "AuthenticatedFabric" -> Right AuthenticatedFabric
  Just "Lan" -> Right Lan
  Just "WildIngress" -> Right WildIngress
  _ -> Left "admin-reach-unclassified"

deployDemand :: FilePath -> DeployDemand
deployDemand path = DeployDemand
  { deployDhallPath = path
  , deployTargetAuthenticated = True
  , deployCapacityFits = True
  , deployEnvelopes = Set.fromList [minBound .. maxBound]
  , deployProducerArms = Set.fromList [minBound .. maxBound]
  , deployStateKinds = Set.fromList [minBound .. maxBound :: ControlPlaneStateKind]
  , deployDesiredObjects = Set.fromList (fmap ObjectIdentity desiredObjects)
  }

desiredObjects :: [Text]
desiredObjects =
  [ "ConfigMap/edge-system/keycloak-ingress-envoy"
  , "Deployment/edge-system/envoy"
  , "Deployment/observability/prometheus-query-proxy"
  , "Deployment/edge-system/live-dsl-deploy-trivial"
  , "HTTPRoute/edge-system/live-dsl-deploy-trivial"
  , "Service/observability/prometheus-query-proxy"
  , "Service/edge-system/live-dsl-deploy-trivial"
  ]

rejectionGate :: DecodeError -> Text
rejectionGate problem = case problem of
  DhallFailure _ -> "Gate-1"
  _ -> "Gate-2"

receiveRequest :: Socket -> IO HttpRequest
receiveRequest connection = do
  initial <- receiveUntilHeaders connection StrictByteString.empty
  let (headerBytes, initialBody) = splitHeaders initial
      headerLines = Char8.lines (Char8.filter (/= '\r') headerBytes)
      (method, path) = case headerLines of
        first : _ -> case Char8.words first of
          methodValue : pathValue : _ -> (methodValue, pathValue)
          _ -> ("", "")
        _ -> ("", "")
      headers = Map.fromList (mapMaybeHeader (drop 1 headerLines))
      contentLength = maybe 0 readLength (Map.lookup "content-length" headers)
  body <- receiveBody connection contentLength initialBody
  pure (HttpRequest method path headers body)

receiveUntilHeaders :: Socket -> StrictByteString.ByteString -> IO StrictByteString.ByteString
receiveUntilHeaders connection accumulated
  | "\r\n\r\n" `StrictByteString.isInfixOf` accumulated = pure accumulated
  | StrictByteString.length accumulated > 8388608 = pure accumulated
  | otherwise = do
      chunk <- Socket.recv connection 65536
      if StrictByteString.null chunk then pure accumulated else receiveUntilHeaders connection (accumulated <> chunk)

splitHeaders :: StrictByteString.ByteString -> (StrictByteString.ByteString, StrictByteString.ByteString)
splitHeaders payload =
  let (headers, remainder) = Char8.breakSubstring "\r\n\r\n" payload
   in (headers, StrictByteString.drop 4 remainder)

receiveBody :: Socket -> Int -> StrictByteString.ByteString -> IO StrictByteString.ByteString
receiveBody connection expected accumulated
  | StrictByteString.length accumulated >= expected = pure (StrictByteString.take expected accumulated)
  | otherwise = do
      chunk <- Socket.recv connection (min 65536 (expected - StrictByteString.length accumulated))
      if StrictByteString.null chunk then pure accumulated else receiveBody connection expected (accumulated <> chunk)

mapMaybeHeader :: [StrictByteString.ByteString] -> [(StrictByteString.ByteString, StrictByteString.ByteString)]
mapMaybeHeader = foldr parse []
 where
  parse line rest = case Char8.break (== ':') line of
    (name, value)
      | not (StrictByteString.null value) -> (Char8.map lowerAscii name, Char8.dropWhile (== ' ') (StrictByteString.drop 1 value)) : rest
    _ -> rest
  lowerAscii character
    | character >= 'A' && character <= 'Z' = toEnum (fromEnum character + 32)
    | otherwise = character

readLength :: StrictByteString.ByteString -> Int
readLength raw = case Char8.readInt raw of
  Just (value, _) -> max 0 value
  Nothing -> 0

response :: Int -> StrictByteString.ByteString -> StrictByteString.ByteString -> StrictByteString.ByteString
response status contentType body =
  "HTTP/1.1 " <> statusLine status <> "\r\nContent-Type: " <> contentType
    <> "\r\nContent-Length: " <> Char8.pack (show (StrictByteString.length body))
    <> "\r\nConnection: close\r\n\r\n" <> body

jsonResponse :: ToJSON value => Int -> value -> StrictByteString.ByteString
jsonResponse status = response status "application/json" . LazyByteString.toStrict . encode

statusLine :: Int -> StrictByteString.ByteString
statusLine value = case value of
  200 -> "200 OK"
  400 -> "400 Bad Request"
  401 -> "401 Unauthorized"
  403 -> "403 Forbidden"
  404 -> "404 Not Found"
  422 -> "422 Unprocessable Entity"
  500 -> "500 Internal Server Error"
  503 -> "503 Service Unavailable"
  _ -> Char8.pack (show value)

runHelper :: [String] -> String -> IO (Either Text String)
runHelper arguments input = do
  (exitCode, output, errors) <- readCreateProcessWithExitCode (proc "/usr/bin/python3" (helperPath : arguments)) input
  pure $ case exitCode of
    ExitSuccess -> Right output
    ExitFailure code -> Left ("helper-exit-" <> Text.pack (show code) <> ":" <> Text.take 256 (Text.pack errors))

helperRequired :: [String] -> String -> IO String
helperRequired arguments input = runHelper arguments input >>= either (die . Text.unpack) pure

decodeHelperValue :: String -> Either String Value
decodeHelperValue = eitherDecodeStrict' . Char8.pack

logEvent :: Text -> Text -> [Pair] -> IO ()
logEvent podUid event fields = do
  LazyByteString.putStr (encode (object (["event" .= event, "podUid" .= podUid] <> fields)) <> "\n")
  hFlush stdout
