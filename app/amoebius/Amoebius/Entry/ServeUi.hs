{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Entry.ServeUi
  ( runServeUi
  ) where

import Amoebius.Ui.Realtime.Envelope (UiRealtimeEnvelope (..))
import Amoebius.Ui.Server.Dispatch
  ( ActionRequest (..)
  , BoundaryMutant (..)
  , BoundaryResponse (..)
  , HandlerBinding (..)
  , HandlerContract (..)
  , HandlerInvocation (..)
  , UiServerAbi (..)
  , admitServerPlan
  , authorizeAndDispatch
  , parseBoundaryMutant
  , publicResponse
  , unavailableResponse
  )
import Amoebius.Ui.Server.RequestContext
  ( CredentialError
  , SigningKey
  , serverRequestContext
  , signingKey
  , verifyCredential
  )
import Amoebius.Ui.Server.SecurityHeaders (contentTypeForPath, productionSecurityHeaders)
import Amoebius.Ui.Server.WebSocket (RegistrationInput (..), validateRegistration)
import Control.Concurrent (MVar, forkFinally, newMVar, withMVar)
import Control.Exception (bracket, displayException)
import Control.Monad (forever, unless, void)
import Crypto.Hash (Digest, SHA1, hash)
import qualified Data.Aeson as Aeson
import Data.ByteArray (convert)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Base64 as Base64
import qualified Data.ByteString.Char8 as ByteString8
import Data.IORef (IORef, atomicModifyIORef', newIORef)
import qualified Data.Aeson.Key as AesonKey
import qualified Data.Aeson.KeyMap as AesonKeyMap
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Network.Socket
  ( Family (AF_INET)
  , PortNumber
  , SockAddr (SockAddrInet)
  , Socket
  , SocketOption (ReuseAddr)
  , SocketType (Stream)
  , accept
  , bind
  , close
  , connect
  , defaultProtocol
  , getSocketName
  , listen
  , setSocketOption
  , socket
  , tupleToHostAddress
  , withSocketsDo
  )
import qualified Network.Socket.ByteString as Socket
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import Text.Read (readMaybe)

data ServeConfig = ServeConfig
  { configPortFile :: FilePath
  , configHandlerPort :: PortNumber
  , configSigningKey :: SigningKey
  , configSigningKeyText :: Text
  , configCurrentEpoch :: Int
  , configSessionNonce :: Text
  , configAuditFile :: FilePath
  , configRegistryCount :: Int
  , configHandlerContract :: Text
  , configAbi :: Text
  , configCoordinatorAvailable :: Bool
  , configClientPlan :: Text
  , configUiBundle :: Text
  , configPlanDigest :: Text
  , configChallengeFile :: Maybe FilePath
  , configMutant :: BoundaryMutant
  }

data HttpRequest = HttpRequest
  { requestMethod :: Text
  , requestTarget :: Text
  , requestHeaders :: [(Text, Text)]
  , requestBody :: Text
  }

runServeUi :: [String] -> IO ()
runServeUi arguments = withSocketsDo $ do
  config <- either fail pure =<< parseConfig arguments
  unless (startupAdmitted config) $ do
    putStrLn "serve-ui: startup refused"
    exitFailure
  usedIdempotency <- newIORef Set.empty
  usedNonces <- newIORef Set.empty
  readyHandles <- newIORef Map.empty
  auditLock <- newMVar ()
  bracket openListener close $ \listener -> do
    address <- getSocketName listener
    port <- case address of
      SockAddrInet value _ -> pure value
      _ -> fail "serve-ui listener is not IPv4"
    writeFile (configPortFile config) (show port <> "\n")
    putStrLn "serve-ui: READY"
    forever $ do
      (connection, _) <- accept listener
      void (forkFinally
        (serveConnection config usedIdempotency usedNonces readyHandles auditLock connection)
        (\outcome -> do
          close connection
          case outcome of
            Left problem -> hPutStrLn stderr ("serve-ui connection refused: " <> displayException problem)
            Right () -> pure ()))

startupAdmitted :: ServeConfig -> Bool
startupAdmitted config = case admitServerPlan (configMutant config) abi required linked of
  Right () -> True
  Left _ -> False
  where
    contract = HandlerContract "request-v1" "response-v1"
    required = [("handler-main", contract)]
    linked = replicate (configRegistryCount config)
      (HandlerBinding "handler-main" (if configHandlerContract config == "match" then contract else HandlerContract "wrong" "wrong"))
    abi = if configAbi config == "ui-server-v1" then UiServerV1 else UnsupportedUiServerAbi (configAbi config)

openListener :: IO Socket
openListener = do
  listener <- socket AF_INET Stream defaultProtocol
  setSocketOption listener ReuseAddr 1
  bind listener (SockAddrInet 0 (tupleToHostAddress (127, 0, 0, 1)))
  listen listener 32
  pure listener

serveConnection
  :: ServeConfig
  -> IORef (Set.Set Text)
  -> IORef (Set.Set Text)
  -> IORef (Map.Map Text (Text, Text))
  -> MVar ()
  -> Socket
  -> IO ()
serveConnection config idempotencyKeys usedNonces readyHandles auditLock connection = do
  request <- receiveRequest connection
  if header "upgrade" request == Just "websocket"
    then serveWebSocket config usedNonces auditLock connection request
    else serveHttp config idempotencyKeys readyHandles auditLock connection request

serveHttp
  :: ServeConfig
  -> IORef (Set.Set Text)
  -> IORef (Map.Map Text (Text, Text))
  -> MVar ()
  -> Socket
  -> HttpRequest
  -> IO ()
serveHttp config idempotencyKeys readyHandles auditLock connection request = do
  (response, invocation) <- routeHttp config request
  (checkedResponse, checkedInvocation) <- validateReadyHandle readyHandles response invocation
  (dispatched, handlerResponse) <- case checkedInvocation of
    Nothing -> pure (False, Nothing)
    Just effect -> dispatchOnce config idempotencyKeys effect
  case (checkedInvocation, handlerResponse >>= jsonTextField "handle") of
    (Just effect, Just handle) | invocationHandler effect == "workflow-observe" ->
      atomicModifyIORef' readyHandles (\known -> (Map.insert handle (invocationTenant effect, invocationSubject effect) known, ()))
    _ -> pure ()
  let finalResponse = case handlerResponse of
        Just body | body /= "{}" && not (Text.null body) -> checkedResponse {responseBody = body}
        _ -> checkedResponse
  appendAudit auditLock config request finalResponse dispatched
  sendResponse config connection (requestTarget request) finalResponse

routeHttp :: ServeConfig -> HttpRequest -> IO (BoundaryResponse, Maybe HandlerInvocation)
routeHttp config request
  | requestMethod request == "GET" = do
      response <- routeGet config (pathOnly (requestTarget request))
      pure (response, Nothing)
  | requestMethod request == "POST" && "/ui/action/" `Text.isPrefixOf` path = case bearerToken request of
      Nothing -> pure (unavailableResponse, Nothing)
      Just token -> case verifyCredential (configSigningKey config) token of
        Left _ -> pure (unavailableResponse, Nothing)
        Right credential -> do
          let context = serverRequestContext credential
              action = ActionRequest
                { actionCase = Text.drop 11 path
                , actionPath = path
                , actionOrigin = maybe "" normalizeOrigin (header "origin" request)
                , actionCsrf = maybe "" id (header "x-csrf" request)
                , actionPresentedEpoch = maybe (-1) id (header "x-authority-epoch" request >>= readInt)
                , actionSpoofedTenant = header "x-tenant" request
                , actionIdempotencyKey = maybe "" id (header "idempotency-key" request)
                , actionBody = requestBody request
                }
          pure (authorizeAndDispatch (configMutant config) (configCurrentEpoch config) "tenant-a" "alice" "csrf-v1" credential context action)
  | otherwise = pure (unavailableResponse, Nothing)
  where
    path = pathOnly (requestTarget request)

routeGet :: ServeConfig -> Text -> IO BoundaryResponse
routeGet config path = case contentTypeForPath path of
  Just _ -> pure (publicResponse (publicBody config path))
  Nothing
    | path == "/ui/current-digest" -> pure (publicResponse ("{\"digest\":\"" <> configPlanDigest config <> "\"}"))
    | path == "/ui/challenge" -> do
        challenge <- case configChallengeFile config of
          Nothing -> pure (configSessionNonce config)
          Just challengePath -> Text.strip . Text.pack <$> readFile challengePath
        pure (publicResponse ("{\"nonce\":\"" <> challenge <> "\"}"))
    | configMutant config == ServeServerPlanAsClientAsset && path == "/ui/server-plan/known-digest" ->
        pure (publicResponse "private-canary:ui-server-plan-secret")
    | otherwise -> pure unavailableResponse

publicBody :: ServeConfig -> Text -> Text
publicBody config path = case path of
  "/" -> "<!doctype html><script type=module src=/ui.js></script>"
  "/index.html" -> "<!doctype html><script type=module src=/ui.js></script>"
  "/ui.js" -> configUiBundle config
  "/ui.css" -> "body{font-family:sans-serif}"
  "/ui/client-plan" -> configClientPlan config
  _ -> ""

dispatchOnce :: ServeConfig -> IORef (Set.Set Text) -> HandlerInvocation -> IO (Bool, Maybe Text)
dispatchOnce config keys invocation = do
  let key = invocationIdempotencyKey invocation
  duplicate <- atomicModifyIORef' keys $ \known ->
    if Set.member key known && configMutant config /= NewIdempotencyKeyOnRetry
      then (known, True)
      else (Set.insert key known, False)
  if duplicate
    then pure (False, Nothing)
    else do
      response <- sendHandlerInvocation config invocation
      pure (True, Just response)

sendHandlerInvocation :: ServeConfig -> HandlerInvocation -> IO Text
sendHandlerInvocation config invocation = bracket open close $ \connection -> do
  connect connection (SockAddrInet (configHandlerPort config) (tupleToHostAddress (127, 0, 0, 1)))
  Socket.sendAll connection (Text.encodeUtf8 payload)
  Text.decodeUtf8 <$> Socket.recv connection 65536
  where
    open = socket AF_INET Stream defaultProtocol
    payload = Text.intercalate "\t"
      [ configSigningKeyText config
      , invocationCase invocation
      , invocationHandler invocation
      , invocationTenant invocation
      , invocationSubject invocation
      , invocationIdempotencyKey invocation
      , invocationBody invocation
      ] <> "\n"

validateReadyHandle
  :: IORef (Map.Map Text (Text, Text))
  -> BoundaryResponse
  -> Maybe HandlerInvocation
  -> IO (BoundaryResponse, Maybe HandlerInvocation)
validateReadyHandle readyHandles response invocation = case invocation of
  Just effect | invocationHandler effect == "artifact-use" -> do
    known <- atomicModifyIORef' readyHandles (\value -> (value, value))
    let supplied = jsonTextField "handle" (invocationBody effect)
        expectedOwner = (invocationTenant effect, invocationSubject effect)
    pure $ case supplied >>= (`Map.lookup` known) of
      Just owner | owner == expectedOwner -> (response, invocation)
      _ -> (BoundaryResponse 409 "NotReady" "" "artifact-not-ready" "own", Nothing)
  _ -> pure (response, invocation)

jsonTextField :: Text -> Text -> Maybe Text
jsonTextField name payload = do
  value <- Aeson.decodeStrict' (Text.encodeUtf8 payload)
  case value of
    Aeson.Object objectValue -> case AesonKeyMap.lookup (AesonKey.fromText name) objectValue of
      Just (Aeson.String textValue) -> Just textValue
      _ -> Nothing
    _ -> Nothing

serveWebSocket :: ServeConfig -> IORef (Set.Set Text) -> MVar () -> Socket -> HttpRequest -> IO ()
serveWebSocket config usedNonces auditLock connection request = case bearerToken request of
  Nothing -> sendResponse config connection (requestTarget request) unavailableResponse
  Just token -> case verifyCredential (configSigningKey config) token of
    Left _ -> sendResponse config connection (requestTarget request) unavailableResponse
    Right credential -> do
      let context = serverRequestContext credential
          requestedNonce = maybe "" id (header "x-session-nonce" request)
          envelope = UiRealtimeEnvelope
            { envelopeApplication = maybe "" id (header "x-envelope-application" request)
            , envelopeSession = maybe "" id (header "x-envelope-session" request)
            , envelopeSubjectEpoch = maybe (-1) id (header "x-envelope-subject-epoch" request >>= readInt)
            , envelopeScope = maybe "" id (header "x-envelope-scope" request)
            , envelopeScopeEpoch = maybe (-1) id (header "x-envelope-scope-epoch" request >>= readInt)
            , envelopeProgram = maybe "" id (header "x-envelope-program" request)
            , envelopeAbi = maybe "" id (header "x-envelope-abi" request)
            , envelopeStream = maybe "" id (header "x-envelope-stream" request)
            , envelopeCursor = maybe (-1) id (header "x-envelope-cursor" request >>= readInt)
            }
          registration = RegistrationInput
            { registrationOrigin = maybe "" normalizeOrigin (header "origin" request)
            , registrationSubprotocol = maybe "" id (header "sec-websocket-protocol" request)
            , registrationNonce = requestedNonce
            , registrationProgram = maybe "" id (header "x-program" request)
            , registrationAbi = maybe "" id (header "x-abi" request)
            , registrationScope = maybe "" id (header "x-scope" request)
            , registrationCoordinatorAvailable = configCoordinatorAvailable config
            , registrationEnvelope = envelope
            }
      replayed <- atomicModifyIORef' usedNonces $ \known ->
        if Set.member requestedNonce known then (known, True) else (known, False)
      case if replayed || requestedNonce /= configSessionNonce config then Left () else either (const (Left ())) Right
        (validateRegistration (configCurrentEpoch config) "plan-single-v1" "ui-server-v1" credential context registration) of
        Left () -> sendResponse config connection (requestTarget request) (BoundaryResponse 409 "ReloadRequired" "" "websocket-denied" "own")
        Right _ -> do
          atomicModifyIORef' usedNonces (\known -> (Set.insert requestedNonce known, ()))
          withMVar auditLock (\() -> appendFile (configAuditFile config) "websocket-register\taccepted\n")
          sendWebSocketUpgrade config connection request

sendWebSocketUpgrade :: ServeConfig -> Socket -> HttpRequest -> IO ()
sendWebSocketUpgrade config connection request = do
  let websocketKey = maybe "" id (header "sec-websocket-key" request)
      acceptValue = websocketAccept websocketKey
      baseHeaders = productionHeaders config
      headers = baseHeaders <>
        [ ("Upgrade", "websocket")
        , ("Connection", "Upgrade")
        , ("Sec-WebSocket-Accept", acceptValue)
        , ("Sec-WebSocket-Protocol", "amoebius-ui-v1")
        ]
      payload = "HTTP/1.1 101 Switching Protocols\r\n" <> renderHeaders headers <> "\r\n"
  Socket.sendAll connection (Text.encodeUtf8 payload)

websocketAccept :: Text -> Text
websocketAccept key = Text.decodeUtf8 (Base64.encode digestBytes)
  where
    digest :: Digest SHA1
    digest = hash (Text.encodeUtf8 (key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
    digestBytes :: ByteString.ByteString
    digestBytes = convert digest

sendResponse :: ServeConfig -> Socket -> Text -> BoundaryResponse -> IO ()
sendResponse config connection target response = do
  let body = responseBody response
      path = pathOnly target
      contentType = maybe "application/json" id (contentTypeForPath path)
      headers = productionHeaders config <>
        [ ("Content-Type", contentType)
        , ("Cache-Control", "no-store")
        , ("Content-Length", Text.pack (show (ByteString.length (Text.encodeUtf8 body))))
        , ("Connection", "close")
        , ("X-Amoebius-Result", responseTag response)
        ]
      payload = Text.concat
        [ "HTTP/1.1 "
        , Text.pack (show (responseStatus response))
        , " "
        , reason (responseStatus response)
        , "\r\n"
        , renderHeaders headers
        , "\r\n"
        , body
        ]
  Socket.sendAll connection (Text.encodeUtf8 payload)

productionHeaders :: ServeConfig -> [(Text, Text)]
productionHeaders config
  | configMutant config == DropCspHeader = filter ((/= "Content-Security-Policy") . fst) productionSecurityHeaders
  | otherwise = productionSecurityHeaders

renderHeaders :: [(Text, Text)] -> Text
renderHeaders = Text.concat . map (\(name, value) -> name <> ": " <> value <> "\r\n")

reason :: Int -> Text
reason status = case status of
  101 -> "Switching Protocols"
  200 -> "OK"
  202 -> "Accepted"
  403 -> "Forbidden"
  404 -> "Not Found"
  409 -> "Conflict"
  503 -> "Service Unavailable"
  _ -> "Error"

appendAudit :: MVar () -> ServeConfig -> HttpRequest -> BoundaryResponse -> Bool -> IO ()
appendAudit auditLock config request response dispatched =
  withMVar auditLock (\() -> appendFile (configAuditFile config) (Text.unpack line))
  where
    line = Text.intercalate "\t"
      [ pathOnly (requestTarget request)
      , responseAuditClass response
      , responseAuditScope response
      , if dispatched then "effect" else "no-effect"
      ] <> "\n"

receiveRequest :: Socket -> IO HttpRequest
receiveRequest connection = do
  prefix <- receiveUntilHeaders connection ByteString.empty
  let (headerBytes, initialBody) = splitHeaderBody prefix
      headerLines = map stripCarriage (ByteString8.lines headerBytes)
  case headerLines of
    [] -> fail "empty HTTP request"
    requestLine : rawHeaders -> do
      let parsedHeaders = mapMaybeHeader rawHeaders
          contentLength = maybe 0 id (lookup "content-length" parsedHeaders >>= readInt)
      rest <- receiveBody connection (contentLength - ByteString.length initialBody) ByteString.empty
      let completeBody = ByteString.take contentLength (initialBody <> rest)
      case words (ByteString8.unpack requestLine) of
        method : target : _ -> pure HttpRequest
          { requestMethod = Text.pack method
          , requestTarget = Text.pack target
          , requestHeaders = parsedHeaders
          , requestBody = Text.decodeUtf8 completeBody
          }
        _ -> fail "malformed HTTP request line"

receiveUntilHeaders :: Socket -> ByteString.ByteString -> IO ByteString.ByteString
receiveUntilHeaders connection accumulated
  | "\r\n\r\n" `ByteString.isInfixOf` accumulated = pure accumulated
  | ByteString.length accumulated > 65536 = fail "HTTP headers exceed bound"
  | otherwise = do
      chunk <- Socket.recv connection 4096
      if ByteString.null chunk then pure accumulated else receiveUntilHeaders connection (accumulated <> chunk)

receiveBody :: Socket -> Int -> ByteString.ByteString -> IO ByteString.ByteString
receiveBody _ remaining accumulated | remaining <= 0 = pure accumulated
receiveBody connection remaining accumulated = do
  chunk <- Socket.recv connection (min 4096 remaining)
  if ByteString.null chunk
    then pure accumulated
    else receiveBody connection (remaining - ByteString.length chunk) (accumulated <> chunk)

splitHeaderBody :: ByteString.ByteString -> (ByteString.ByteString, ByteString.ByteString)
splitHeaderBody payload = case ByteString8.breakSubstring "\r\n\r\n" payload of
  (headers, suffix) -> (headers, ByteString.drop 4 suffix)

stripCarriage :: ByteString.ByteString -> ByteString.ByteString
stripCarriage value = maybe value fst (ByteString8.unsnoc value >>= \(prefix, suffix) -> if suffix == '\r' then Just (prefix, suffix) else Nothing)

mapMaybeHeader :: [ByteString.ByteString] -> [(Text, Text)]
mapMaybeHeader = foldr parse []
  where
    parse line rows = case ByteString8.break (== ':') line of
      (name, suffix)
        | not (ByteString.null suffix) ->
            (Text.toLower (Text.decodeUtf8 name), Text.strip (Text.decodeUtf8 (ByteString.drop 1 suffix))) : rows
      _ -> rows

header :: Text -> HttpRequest -> Maybe Text
header name request = lookup name (requestHeaders request)

bearerToken :: HttpRequest -> Maybe Text
bearerToken request = Text.stripPrefix "Bearer " =<< header "authorization" request

normalizeOrigin :: Text -> Text
normalizeOrigin value
  | value == "same-origin" = value
  | "127.0.0.1" `Text.isInfixOf` value = "same-origin"
  | otherwise = "foreign"

pathOnly :: Text -> Text
pathOnly = Text.takeWhile (/= '?')

readInt :: Text -> Maybe Int
readInt = readMaybe . Text.unpack

parseConfig :: [String] -> IO (Either String ServeConfig)
parseConfig arguments = do
  mutantText <- maybe "" Text.pack <$> lookupEnv "AMOEBIUS_PHASE22_MUTANT"
  let options = pairs arguments
      required name = maybe (Left ("missing " <> name)) Right (lookup name options)
  handlerPortContent <- case lookup "--handler-port-file" options of
    Nothing -> pure ""
    Just path -> readFile path
  clientPlanContent <- case lookup "--client-plan-file" options of
    Nothing -> pure "{\"digest\":\"plan-single-v1\"}"
    Just path -> readFile path
  uiBundleContent <- case lookup "--ui-bundle-file" options of
    Nothing -> pure "globalThis.amoebiusUi=true"
    Just path -> readFile path
  pure $ do
    portFile <- required "--port-file"
    _handlerPortFile <- required "--handler-port-file"
    keyText <- Text.pack <$> required "--signing-key"
    key <- either (Left . showCredentialError) Right (signingKey keyText)
    epoch <- required "--current-epoch" >>= maybe (Left "invalid --current-epoch") Right . readMaybe
    nonce <- Text.pack <$> required "--session-nonce"
    auditFile <- required "--audit-file"
    registryCount <- optionalInt options "--registry-count" 1
    contract <- Text.pack <$> optional options "--handler-contract" "match"
    abi <- Text.pack <$> optional options "--abi" "ui-server-v1"
    coordinator <- optional options "--coordinator" "available"
    planDigest <- Text.pack <$> optional options "--plan-digest" "plan-single-v1"
    challengeFile <- Right (lookup "--challenge-file" options)
    handlerPort <- maybe (Left "invalid handler port") Right
      ((readMaybe =<< firstLine handlerPortContent) :: Maybe PortNumber)
    mutant <- if Text.null mutantText then Right NoBoundaryMutant else maybe (Left "unknown Phase-22 mutant") Right (parseBoundaryMutant mutantText)
    Right ServeConfig
      { configPortFile = portFile
      , configHandlerPort = handlerPort
      , configSigningKey = key
      , configSigningKeyText = keyText
      , configCurrentEpoch = epoch
      , configSessionNonce = nonce
      , configAuditFile = auditFile
      , configRegistryCount = registryCount
      , configHandlerContract = contract
      , configAbi = abi
      , configCoordinatorAvailable = coordinator == "available"
      , configClientPlan = Text.strip (Text.pack clientPlanContent)
      , configUiBundle = Text.pack uiBundleContent
      , configPlanDigest = planDigest
      , configChallengeFile = challengeFile
      , configMutant = mutant
      }

firstLine :: String -> Maybe String
firstLine content = case lines content of
  value : _ -> Just value
  [] -> Nothing

optional :: [(String, String)] -> String -> String -> Either String String
optional options name fallback = Right (maybe fallback id (lookup name options))

optionalInt :: [(String, String)] -> String -> Int -> Either String Int
optionalInt options name fallback = case lookup name options of
  Nothing -> Right fallback
  Just value -> maybe (Left ("invalid " <> name)) Right (readMaybe value)

pairs :: [String] -> [(String, String)]
pairs values = case values of
  name : value : rest -> (name, value) : pairs rest
  _ -> []

showCredentialError :: CredentialError -> String
showCredentialError = show
