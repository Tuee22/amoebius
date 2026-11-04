{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.S3Gateway (runObjectGateway) where

import Amoebius.Platform.ObjectGateway (serveApplication)
import Amoebius.Platform.RegistryTransfer (readGatewayCanary, writeGatewayCanary)
import Amoebius.Platform.S3Admission
import Amoebius.Platform.S3Protocol (deleteObjectKeys, validateHeaderFields, publicResponseHeaders, publicErrorCode)
import Amoebius.Platform.S3Signing
import Amoebius.Vault.Client
import Control.Concurrent
import Control.Exception
import Control.Monad (forever, unless, when)
import Data.Aeson
import Data.Aeson.Types (parseEither)
import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as B
import Data.ByteString.Lazy qualified as Lazy
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Time (UTCTime, getCurrentTime)
import Foreign.C.Error (throwErrnoIfMinus1_)
import Foreign.C.Types (CInt (..))
import Network.Socket
import Numeric (readHex)
import Numeric.Natural (Natural)
import System.Directory (doesFileExist, renameFile)
import System.IO
import System.IO.Error (ioeGetErrorString)
import System.Posix.IO qualified as Posix
import System.Posix.Types (Fd (..))
import System.Timeout (timeout)
import Text.Read (readMaybe)

foreign import ccall unsafe "fsync" c_fsync :: CInt -> IO CInt

data Runtime = Runtime GatewayPolicy (MVar GatewayState) BS.ByteString S3Credentials
  [(BS.ByteString, Writer, S3Credentials)] (VaultTransport IO)

stateRoot, statePath :: FilePath
stateRoot = "/gateway-state"
statePath = stateRoot <> "/state.json"

backendHost :: BS.ByteString
backendHost = "minio-backend.platform-system.svc:9000"

runObjectGateway :: [String] -> IO ()
runObjectGateway [] = bracket
  (Posix.openFd (stateRoot <> "/owner.lock") Posix.ReadWrite Posix.defaultFileFlags {Posix.creat = Just 0o600})
  Posix.closeFd $ \lock -> do
    Posix.setLock lock (Posix.WriteLock, AbsoluteSeek, 0, 0)
    config <- boundedFile "/phase30-gateway/storage.json"
    storageValue <- either (const (fail "gateway-policy-invalid")) pure (eitherDecodeStrict' config)
    policy <- either (const (fail "gateway-policy-invalid")) pure (gatewayPolicyFromStorage storageValue)
    let identity = sha256Hex config
    exists <- doesFileExist statePath
    previous <- if not exists then pure emptyGatewayState else do
      encoded <- boundedFile statePath
      value <- either (const (fail "gateway-state-invalid")) pure (eitherDecodeStrict' encoded)
      (fingerprint, state) <- either (const (fail "gateway-state-invalid")) pure
        (parseEither (withObject "gateway state" (\row -> (,) <$> row .: "policySha256" <*> row .: "state")) value)
      unless (fingerprint == Text.decodeUtf8 identity) (fail "gateway-policy-state-mismatch")
      either (const (fail "gateway-state-invalid")) pure (decodeGatewayState state)
    state <- newMVar (recoverInterrupted previous)
    transport <- pure (mkHttpVaultTransport (HttpVaultAddress "root-vault.vault-system.svc" "8200"))
    jwt <- BS.readFile "/var/run/secrets/kubernetes.io/serviceaccount/token"
    token <- authenticateKubernetes transport (KubernetesIdentity "platform-system" "platform-backbone" "amoebius-platform-backbone") jwt
      >>= either (const (fail "gateway-vault-login-denied")) pure
    let credentials path = S3Credentials
          <$> (readKvField transport token "secret" path "access-key" >>= either (const (fail "gateway-vault-read-denied")) pure)
          <*> (readKvField transport token "secret" path "secret-key" >>= either (const (fail "gateway-vault-read-denied")) pure)
    root <- credentials "phase30/minio"
    registry <- credentials "phase30/writers/registry"
    offload <- credentials "phase30/writers/pulsar-offload"
    let access (S3Credentials key _) = key
        runtime = Runtime policy state identity root
          [(access registry, RegistryWriter, registry), (access offload, OffloadWriter, offload)] transport
    -- Fixed buckets are bootstrap operations by the backend authority, never
    -- producer-controlled CreateBucket requests.
    mapM_ (ensureBucket root) ["registry", "pulsar-offload", "phase30-canary"]
    inventories <- traverse (backendInventory root) ["registry", "pulsar-offload", "phase30-canary"]
    current <- readMVar state
    either (fail . Text.unpack) pure (validateBackendInventory policy current
      (concatMap fst inventories) (concatMap snd inventories))
    persist identity current
    semaphore <- newQSem 1
    done <- newEmptyMVar
    bracket (listener 8081) close $ \application -> bracket (listener 9000) close $ \s3 -> do
      let launch server handler = forkFinally (acceptLoop semaphore server handler) (const (putMVar done ()))
      applicationThread <- launch application (serveApplication transport (storeCanary runtime) (retrieveCanary root))
      s3Thread <- launch s3 (serveS3 runtime)
      takeMVar done `finally` (killThread applicationThread >> killThread s3Thread)
      fail "gateway-listener-stopped"
runObjectGateway _ = fail "usage: object-gateway"

boundedFile :: FilePath -> IO BS.ByteString
boundedFile path = withBinaryFile path ReadMode $ \stream -> do
  bytes <- BS.hGet stream 1048577
  unless (BS.length bytes <= 1048576) (fail "gateway-file-bound-exceeded")
  pure bytes

persist :: BS.ByteString -> GatewayState -> IO ()
persist identity state = do
  let encoded = Lazy.toStrict (encode (object ["policySha256" .= Text.decodeUtf8 identity, "state" .= gatewayStateValue state]))
  unless (BS.length encoded <= 1048576) (fail "gateway-state-bound-exceeded")
  withBinaryFile (statePath <> ".next") WriteMode $ \stream -> BS.hPut stream encoded >> hFlush stream
  syncPath (statePath <> ".next")
  renameFile (statePath <> ".next") statePath
  syncPath stateRoot
 where
  syncPath path = bracket (Posix.openFd path Posix.ReadOnly Posix.defaultFileFlags) Posix.closeFd $ \(Fd descriptor) ->
    throwErrnoIfMinus1_ "gateway-state-sync" (c_fsync descriptor)

-- Reservations are durably written before the action. On an exception the
-- failed generation is durably charged before another operation is admitted.
mutate :: Runtime -> (GatewayState -> Either Text (GatewayState, Reservation))
  -> (Reservation -> IO (Bool, value, GatewayState -> Reservation -> Either Text GatewayState)) -> IO value
mutate (Runtime _ state identity _ _ _) prepare action = do
  outcome <- modifyMVar state $ \old -> mask $ \restore -> case prepare old of
    Left problem -> pure (old, Left (toException (userError (Text.unpack problem))))
    Right (reserved, reservation) -> do
      written <- try @SomeException (persist identity reserved)
      case written of
        Left problem -> pure (reserved, Left problem)
        Right () -> do
          attempted <- try @SomeException (restore (action reservation))
          let transition = case attempted of
                Left _ -> finishWrite reserved reservation False
                Right (success, _, commit) -> if success then commit reserved reservation else finishWrite reserved reservation False
          case transition of
            Left problem -> pure (reserved, Left (toException (userError (Text.unpack problem))))
            Right final -> do
              durable <- try @SomeException (persist identity final)
              case durable of
                Left problem -> pure (reserved, Left problem)
                Right () -> pure (final, case attempted of Left problem -> Left problem; Right (_, result, _) -> Right result)
  either throwIO pure outcome

storeCanary :: Runtime -> BS.ByteString -> IO ()
storeCanary runtime@(Runtime policy _ _ (S3Credentials access secret) _ _) payload =
  mutate runtime (\state -> beginWrite policy state ApplicationWriter "/phase30-canary/admitted-canary"
    (fromIntegral (BS.length payload)) (Text.decodeUtf8 ("sha256:" <> sha256Hex payload))) $ \_ -> do
      writeGatewayCanary access secret payload
      pure (True, (), \state reservation -> finishWrite state reservation True)

retrieveCanary :: S3Credentials -> IO BS.ByteString
retrieveCanary (S3Credentials access secret) = readGatewayCanary access secret

listener :: PortNumber -> IO Socket
listener port = do
  server <- socket AF_INET Stream defaultProtocol
  setSocketOption server ReuseAddr 1
  bind server (SockAddrInet port (tupleToHostAddress (0,0,0,0)))
  listen server 8
  pure server

acceptLoop :: QSem -> Socket -> (Handle -> IO ()) -> IO ()
acceptLoop semaphore server handler = forever $ do
  (connection, _) <- accept server
  bracket (socketToHandle connection ReadWriteMode) hClose $ \stream -> do
    hSetBinaryMode stream True
    hSetBuffering stream NoBuffering
    _ <- try @SomeException $ bracket_ (waitQSem semaphore) (signalQSem semaphore) $ do
      result <- timeout (300 * 1000000) (handler stream)
      when (result == Nothing) (fail "gateway-request-timeout")
    pure ()

serveS3 :: Runtime -> Handle -> IO ()
serveS3 runtime@(Runtime policy _ _ root writers _) client = do
  line <- limitedLine client
  requestHeaders <- readHeaders client
  case B.words line of
    ["GET", "/minio/health/ready", "HTTP/1.1"] -> respond client 200 [] "ready"
    ["GET", "/minio/health/live", "HTTP/1.1"] -> respond client 200 [] "live"
    [method, target, "HTTP/1.1"] -> do
      let request = SigningRequest method target requestHeaders
      now <- getCurrentTime
      case requestAccessKey request >>= \access -> case [entry | entry@(key, _, _) <- writers, key == access] of
        [(_, writer, credentials)] -> verifyS3Signature now credentials request >> pure (writer,credentials)
        _ -> Left "s3-writer-key-denied" of
          Left reason -> hPutStrLn stderr ("gateway-auth-rejected:" <> reason) >> s3Error client 403 "AccessDenied"
          Right (writer,writerCredentials) -> admitted client $ do
            path <- either (const (fail "gateway-uri-invalid")) pure (decodeUri (B.takeWhile (/= '?') target))
            let pathText = Text.decodeUtf8 path
                bucket = Text.takeWhile (/= '/') (Text.drop 1 pathText)
            if not (ownsBucket writer bucket) then s3Error client 403 "AccessDenied" else do
              unless (lookup "transfer-encoding" requestHeaders == Nothing) (fail "gateway-streaming-transfer-encoding-denied")
              (headers,extent,buffered) <- prepareIncomingBody now writerCredentials request client
              query <- queryFields target
              unless (length query == Set.size (Set.fromList (fmap fst query))) (fail "gateway-query-duplicate")
              let backendTarget = stripAuthentication target
                  copySource = lookup "x-amz-copy-source" headers
              unless (lookup "transfer-encoding" headers == Nothing) (fail "gateway-streaming-transfer-encoding-denied")
              case (method, extent, lookup "uploadId" query, lookup "partNumber" query, lookup "uploads" query) of
                (readMethod, Just 0, _, _, _) | readMethod `elem` ["GET", "HEAD"] ->
                  do
                    when (writer == OffloadWriter && readMethod == "GET" && pathText /= "/pulsar-offload")
                      (hPutStrLn stderr "gateway-offload-read")
                    backend root method backendTarget headers 0 (const (pure ())) (forward client method)
                ("PUT", Just bytes, Nothing, Nothing, Nothing) -> admitted client $ do
                  (proof, actualBytes, forwardedHeaders) <- case copySource of
                    Nothing -> do
                      let original = payloadHash headers
                      expected <- either (fail . Text.unpack) pure (expectedObjectDigest policy writer pathText)
                      let effective = if original == "UNSIGNED-PAYLOAD" then maybe original (Text.encodeUtf8 . Text.drop 7) expected else original
                          proof = if effective == "UNSIGNED-PAYLOAD" then "UNSIGNED-PAYLOAD" else "sha256:" <> effective
                          changed = ("x-amz-content-sha256", effective) : filter ((/= "x-amz-content-sha256") . fst) headers
                      pure (Text.decodeUtf8 proof, bytes, changed)
                    Just encodedSource -> do
                      rawSource <- either (const (fail "gateway-copy-source-invalid")) pure (decodeUri encodedSource)
                      let source = if "/" `BS.isPrefixOf` rawSource then rawSource else "/" <> rawSource
                      state <- case runtime of Runtime _ stateVar _ _ _ _ -> readMVar stateVar
                      either (fail . Text.unpack) pure (admitCopySource policy state writer (Text.decodeUtf8 source))
                      body <- backend root "GET" source [] 0 (const (pure ())) collect
                      pure (Text.decodeUtf8 ("sha256:" <> sha256Hex body), fromIntegral (BS.length body), headers)
                  deliver client $ mutate runtime (\state -> beginWrite policy state writer pathText actualBytes proof) $ \_ -> do
                      response <- proxyMutation root client buffered method backendTarget forwardedHeaders bytes
                      pure (successful response, response, \state reservation -> finishWrite state reservation True)
                ("POST", Just 0, Nothing, Nothing, Just _) -> admitted client $ deliver client $
                  mutate runtime (\state -> beginMultipart policy state writer pathText) $ \_ -> do
                    (status, responseHeaders, body) <- backend root method backendTarget headers 0 (const (pure ())) collectResponse
                    let uploadId = xmlField "UploadId" body
                    pure (successful (status, responseHeaders, body), (status, responseHeaders, body), \state reservation ->
                      maybe (Left "gateway-upload-id-absent") (bindMultipart state reservation . Text.decodeUtf8) uploadId)
                ("PUT", Just bytes, Just uploadId, Just part, Nothing) -> admitted client $ deliver client $
                  mutate runtime (\state -> beginPart policy state writer pathText (Text.decodeUtf8 uploadId)
                    (maybe 0 id (readMaybe (B.unpack part))) bytes) $ \_ -> do
                      response <- proxyMutation root client buffered method backendTarget headers bytes
                      pure (successful response, response, \state reservation -> recordPart state reservation (Text.decodeUtf8 uploadId) bytes)
                ("POST", Just bytes, Just uploadId, Nothing, Nothing) | bytes <= 65536 -> admitted client $ deliver client $
                  mutate runtime (\state -> beginComplete policy state writer pathText (Text.decodeUtf8 uploadId)) $ \_ -> do
                    response <- proxyMutation root client buffered method backendTarget headers bytes
                    pure (successful response, response, \state reservation -> completeMultipart state reservation (Text.decodeUtf8 uploadId))
                ("POST", Just bytes, Nothing, Nothing, Nothing)
                  | writer `elem` [RegistryWriter,OffloadWriter] && lookup "delete" query /= Nothing && bytes <= 65536 -> admitted client $ do
                    when (lookup "expect" headers == Just "100-continue") $ BS.hPut client "HTTP/1.1 100 Continue\r\n\r\n" >> hFlush client
                    body <- maybe (BS.hGet client (fromIntegral bytes)) pure buffered
                    unless (fromIntegral (BS.length body) == bytes) (fail "gateway-delete-body-truncated")
                    keys <- either fail pure (deleteObjectKeys body)
                    let paths = fmap (("/" <> bucket <> "/") <>) keys
                    state <- case runtime of Runtime _ stateVar _ _ _ _ -> readMVar stateVar
                    mapM_ (\key -> either (fail . Text.unpack) (const (pure ())) (forgetStoredObject policy state writer key)) paths
                    (status, responseHeaders, responseBody) <- backend root method backendTarget headers bytes (\stream -> BS.hPut stream body) collectResponse
                    when (status >= 200 && status < 300) $ do
                      -- DeleteObjects can return per-key errors in a200 body.
                      -- Independently HEAD every key before releasing its debit.
                      missing <- traverse (\key -> backend root "HEAD" (Text.encodeUtf8 key) [] 0 (const (pure ()))
                        (\code _ _ -> pure (code == 404))) paths
                      unless (and missing) (fail "gateway-delete-cleanup-unobserved")
                      case runtime of
                        Runtime _ stateVar identity _ _ _ -> modifyMVar_ stateVar $ \current -> do
                          next <- either (fail . Text.unpack) pure (foldl (\result key -> result >>= \value -> forgetStoredObject policy value writer key) (Right current) paths)
                          persist identity next
                          pure next
                    respondSafe client status responseHeaders responseBody
                ("DELETE", Just 0, Just uploadId, Nothing, Nothing) -> admitted client $ do
                  state <- case runtime of Runtime _ stateVar _ _ _ _ -> readMVar stateVar
                  either (fail . Text.unpack) (const (pure ()))
                    (finishMultipartAbort policy state writer pathText (Text.decodeUtf8 uploadId))
                  (status,_,body) <- backend root method backendTarget headers 0 (const (pure ())) collectResponse
                  unless (status >= 200 && status < 300 || status == 404 && xmlField "Code" body == Just "NoSuchUpload")
                    (fail "gateway-multipart-abort-backend-denied")
                  gone <- backend root "GET" backendTarget [] 0 (const (pure ())) $ \code responseHeaders' stream -> do
                    responseBody <- readBodyBounded 65536 code responseHeaders' stream
                    pure (code == 404 && xmlField "Code" responseBody == Just "NoSuchUpload")
                  absent <- backend root "HEAD" (Text.encodeUtf8 pathText) [] 0 (const (pure ())) (\code _ _ -> pure (code == 404))
                  unless (gone && absent) (fail "gateway-multipart-abort-cleanup-unobserved")
                  case runtime of
                    Runtime _ stateVar identity _ _ _ -> modifyMVar_ stateVar $ \current -> do
                      next <- either (fail . Text.unpack) pure (finishMultipartAbort policy current writer pathText (Text.decodeUtf8 uploadId))
                      persist identity next
                      pure next
                  respond client 204 [] ""
                ("DELETE", Just 0, Nothing, Nothing, Nothing) -> do
                  -- Validate scope before even an idempotent delete request.
                  state <- case runtime of Runtime _ stateVar _ _ _ _ -> readMVar stateVar
                  case forgetStoredObject policy state writer pathText of
                    Left _ -> s3Error client 403 "AccessDenied"
                    Right _ -> do
                      (status, responseHeaders, body) <- backend root method backendTarget headers 0 (const (pure ())) collectResponse
                      when (status >= 200 && status < 300) $ do
                        missing <- backend root "HEAD" (Text.encodeUtf8 pathText) [] 0 (const (pure ())) (\code _ _ -> pure (code == 404))
                        unless missing (fail "gateway-delete-cleanup-unobserved")
                        case runtime of
                          Runtime _ stateVar identity _ _ _ -> modifyMVar_ stateVar $ \current -> do
                            next <- either (fail . Text.unpack) pure (forgetStoredObject policy current writer pathText)
                            persist identity next
                            pure next
                      respondSafe client status responseHeaders body
                _ -> s3Error client 403 "AccessDenied"
    _ -> s3Error client 400 "InvalidRequest"

admitted :: Handle -> IO () -> IO ()
admitted client action = action `catch` \(problem :: SomeException) ->
  let reason = maybe "AdmissionDenied" (B.pack . ioeGetErrorString) (fromException problem)
      safe = BS.length reason <= 80 && "gateway-" `BS.isPrefixOf` reason
        && B.all (\c -> c >= 'a' && c <= 'z' || c == '-') reason
  in s3Error client 403 (if safe then reason else "AdmissionDenied")

payloadHash :: [(BS.ByteString, BS.ByteString)] -> BS.ByteString
payloadHash headers = maybe (sha256Hex BS.empty) id (lookup "x-amz-content-sha256" headers)

-- AWS content-encoding is distinct from HTTP transfer-encoding. JClouds signs
-- nonrepeatable upload streams chunk by chunk with the writer's credentials.
-- Decode and verify the bounded stream before a backend mutation, then bind
-- the actual decoded hash and length to a fresh ordinary backend signature.
prepareIncomingBody :: UTCTime -> S3Credentials -> SigningRequest -> Handle
  -> IO ([(BS.ByteString,BS.ByteString)],Maybe Natural,Maybe BS.ByteString)
prepareIncomingBody now credentials request client = do
  let headers = signingHeaders request
      extent = maybe (Just 0) (readMaybe . B.unpack) (lookup "content-length" headers)
  case lookup "x-amz-content-sha256" headers of
    Just "STREAMING-AWS4-HMAC-SHA256-PAYLOAD" -> do
      wire <- maybe (fail "gateway-signed-chunk-length-invalid") pure extent
      unless (wire <= 2097152) (fail "gateway-signed-chunk-encoded-bound")
      expected <- maybe (fail "gateway-signed-chunk-length-invalid") pure
        (lookup "x-amz-decoded-content-length" headers >>= readMaybe . B.unpack :: Maybe Natural)
      unless (expected <= 1048576) (fail "gateway-signed-chunk-decoded-bound")
      when (lookup "expect" headers == Just "100-continue") $
        BS.hPut client "HTTP/1.1 100 Continue\r\n\r\n" >> hFlush client
      encoded <- BS.hGet client (fromIntegral wire)
      decoded <- either (const (fail "gateway-signed-chunk-proof-denied")) pure
        (verifyS3ChunkedPayload now credentials request 2097152 1048576 1024 encoded)
      let changed = [("x-amz-content-sha256",sha256Hex decoded),("content-length",B.pack (show (BS.length decoded)))]
            <> filter (\(name,_) -> name `notElem` ["x-amz-content-sha256","content-length","content-encoding",
                 "x-amz-decoded-content-length","expect"]) headers
      hPutStrLn stderr "gateway-signed-chunk-decoded"
      pure (changed,Just (fromIntegral (BS.length decoded)),Just decoded)
    _ -> do
      unless (lookup "content-encoding" headers /= Just "aws-chunked") (fail "gateway-signed-chunk-profile-denied")
      pure (headers,extent,Nothing)

type Response = (Int, [(BS.ByteString, BS.ByteString)], BS.ByteString)

deliver :: Handle -> IO Response -> IO ()
deliver client operation = do
  (status, headers, body) <- operation
  respondSafe client status headers body

successful :: Response -> Bool
successful (status, _, body) = status >= 200 && status < 300 && xmlField "Code" body == Nothing

proxyMutation :: S3Credentials -> Handle -> Maybe BS.ByteString -> BS.ByteString -> BS.ByteString
  -> [(BS.ByteString, BS.ByteString)] -> Natural -> IO Response
proxyMutation credentials client buffered method target headers bytes = do
  when (lookup "expect" headers == Just "100-continue") $ BS.hPut client "HTTP/1.1 100 Continue\r\n\r\n" >> hFlush client
  backend credentials method target headers bytes (\stream -> maybe (copyExactly client bytes stream) (BS.hPut stream) buffered) collectResponse

backend :: S3Credentials -> BS.ByteString -> BS.ByteString -> [(BS.ByteString, BS.ByteString)]
  -> Natural -> (Handle -> IO ()) -> (Int -> [(BS.ByteString, BS.ByteString)] -> Handle -> IO value) -> IO value
backend credentials method target headers bytes send receive = do
  addresses <- getAddrInfo (Just defaultHints {addrSocketType = Stream}) (Just "minio-backend.platform-system.svc") (Just "9000")
  address <- case addresses of first : _ -> pure first; [] -> fail "gateway-backend-unavailable"
  bracket (socket (addrFamily address) Stream defaultProtocol) close $ \connection -> do
    connect connection (addrAddress address)
    bracket (socketToHandle connection ReadWriteMode) hClose $ \stream -> do
      hSetBinaryMode stream True
      hSetBuffering stream NoBuffering
      now <- getCurrentTime
      let extra = filter (\(key, _) -> key `notElem` ["host", "authorization", "connection", "expect", "content-length", "transfer-encoding",
            "x-amz-date", "x-amz-content-sha256", "user-agent", "accept-encoding"]) headers
      signed <- either (const (fail "gateway-backend-signing-denied")) pure
        (signS3HeadersWith now credentials method target backendHost (payloadHash headers) extra)
      BS.hPut stream (method <> " " <> target <> " HTTP/1.1\r\nConnection: close\r\nContent-Length: " <> B.pack (show bytes) <> "\r\n"
        <> BS.concat [key <> ": " <> value <> "\r\n" | (key, value) <- signed] <> "\r\n")
      send stream
      hFlush stream
      (status, responseHeaders) <- readStatus stream
      receive status responseHeaders stream

ensureBucket :: S3Credentials -> BS.ByteString -> IO ()
ensureBucket credentials bucket = backend credentials "PUT" ("/" <> bucket) [] 0 (const (pure ())) $ \status headers stream -> do
  body <- readBodyBounded 65536 status headers stream
  unless (status >= 200 && status < 300 || status == 409 && xmlField "Code" body == Just "BucketAlreadyOwnedByYou")
    (fail "gateway-bucket-bootstrap-failed")

backendInventory :: S3Credentials -> BS.ByteString -> IO ([(Text,Natural)],[(Text,Text)])
backendInventory credentials bucket = do
  objects <- listing "?encoding-type=url&list-type=2&max-keys=1301"
  uploads <- listing "?encoding-type=url&max-uploads=1000&uploads="
  let ownedKey row = do
        encoded <- maybe (Left "gateway-backend-key-absent") Right (xmlField "Key" row)
        decoded <- decodeUri encoded
        pure (Text.decodeUtf8 ("/" <> bucket <> "/" <> decoded))
      objectRow row = do
        key <- ownedKey row
        bytes <- maybe (Left "gateway-backend-size-invalid") Right
          (xmlField "Size" row >>= readMaybe . B.unpack)
        pure (key,bytes)
      uploadRow row = do
        key <- ownedKey row
        upload <- maybe (Left "gateway-backend-upload-id-absent") (Right . Text.decodeUtf8) (xmlField "UploadId" row)
        pure (key,upload)
  residents <- either fail pure (traverse objectRow (xmlRows "Contents" objects))
  multipart <- either fail pure (traverse uploadRow (xmlRows "Upload" uploads))
  pure (residents,multipart)
 where
  listing query = backend credentials "GET" ("/" <> bucket <> query) [] 0 (const (pure ())) $ \status headers stream -> do
    body <- readBodyBounded 262144 status headers stream
    unless (status == 200 && xmlField "IsTruncated" body == Just "false")
      (fail "gateway-backend-inventory-unavailable-or-truncated")
    pure body
  xmlRows tag body = case BS.breakSubstring ("<" <> tag <> ">") body of
    (_,rest) | BS.null rest -> []
    (_,rest) ->
      let after = BS.drop (BS.length tag+2) rest
          (row,remaining) = BS.breakSubstring ("</" <> tag <> ">") after
      in row : if BS.null remaining then [] else xmlRows tag (BS.drop (BS.length tag+3) remaining)

collect :: Int -> [(BS.ByteString, BS.ByteString)] -> Handle -> IO BS.ByteString
collect status headers stream = do
  unless (status == 200) (fail "gateway-copy-read-failed")
  readBodyBounded 65536 status headers stream

collectResponse :: Int -> [(BS.ByteString, BS.ByteString)] -> Handle -> IO (Int, [(BS.ByteString, BS.ByteString)], BS.ByteString)
collectResponse status headers stream = (status, headers,) <$> readBodyBounded 65536 status headers stream

forward :: Handle -> BS.ByteString -> Int -> [(BS.ByteString, BS.ByteString)] -> Handle -> IO ()
forward client method status headers stream
  | status >= 400 = readBodyBounded 65536 status headers stream >>= respondSafe client status headers
  | otherwise = do
      let lengthHeader = lookup "content-length" headers
          framing = maybe (if method == "HEAD" || status == 204 then [] else [("transfer-encoding", "chunked")]) (\n -> [("content-length", n)]) lengthHeader
      writeHead client status (framing <> safeHeaders headers)
      unless (method == "HEAD" || status == 204) $ case lengthHeader >>= readMaybe . B.unpack of
        Just count -> copyExactly stream count client
        Nothing -> readChunks stream $ \chunk -> do
          BS.hPut client (B.pack (showHex (BS.length chunk)) <> "\r\n" <> chunk <> "\r\n")
      when (method /= "HEAD" && status /= 204 && lengthHeader == Nothing) (BS.hPut client "0\r\n\r\n")
      hFlush client

readBodyBounded :: Int -> Int -> [(BS.ByteString, BS.ByteString)] -> Handle -> IO BS.ByteString
readBodyBounded maximumBytes status headers stream
  | status == 204 || status == 304 = pure BS.empty
  | otherwise = case lookup "content-length" headers >>= readMaybe . B.unpack of
      Just count | count >= 0 && count <= maximumBytes -> do
        body <- BS.hGet stream count
        unless (BS.length body == count) (fail "gateway-backend-truncated")
        pure body
      Just _ -> fail "gateway-backend-body-bound-exceeded"
      Nothing -> do
        accumulator <- newMVar BS.empty
        readChunks stream $ \chunk -> modifyMVar_ accumulator $ \found -> do
          unless (BS.length found + BS.length chunk <= maximumBytes) (fail "gateway-backend-body-bound-exceeded")
          pure (found <> chunk)
        readMVar accumulator

copyExactly :: Handle -> Natural -> Handle -> IO ()
copyExactly source bytes target = go bytes
 where
  go 0 = pure ()
  go remaining = do
    chunk <- BS.hGet source (fromIntegral (min 65536 remaining))
    when (BS.null chunk) (fail "gateway-body-truncated")
    BS.hPut target chunk
    go (remaining - fromIntegral (BS.length chunk))

readChunks :: Handle -> (BS.ByteString -> IO ()) -> IO ()
readChunks stream consume = do
  line <- limitedLine stream
  count <- case readHex (B.unpack line) of
    [(size, "")] | size >= 0 && size <= (512 * 1048576 :: Integer) -> pure size
    _ -> fail "gateway-chunk-size-invalid"
  if count == 0 then do
    trailers <- readHeaders stream
    unless (null trailers) (fail "gateway-trailers-denied")
  else do
    let loop 0 = pure ()
        loop remaining = do
          chunk <- BS.hGet stream (fromInteger (min 65536 remaining))
          when (BS.null chunk) (fail "gateway-chunk-truncated")
          consume chunk
          loop (remaining - fromIntegral (BS.length chunk))
    loop count
    ending <- BS.hGet stream 2
    unless (ending == "\r\n") (fail "gateway-chunk-ending-invalid")
    readChunks stream consume

readStatus :: Handle -> IO (Int, [(BS.ByteString, BS.ByteString)])
readStatus stream = do
  line <- limitedLine stream
  headers <- readHeadersWith True stream
  status <- case B.words line of
    _ : code : _ -> maybe (fail "gateway-backend-status-invalid") pure (readMaybe (B.unpack code))
    _ -> fail "gateway-backend-status-invalid"
  if status == 100 then readStatus stream else pure (status, headers)

limitedLine :: Handle -> IO BS.ByteString
limitedLine stream = go [] (0 :: Int)
 where
  go bytes count | count >= 8192 = fail "gateway-header-bound-exceeded"
                 | otherwise = do
      byte <- BS.hGet stream 1
      if byte == "\n" then pure (B.strip (BS.concat (reverse bytes)))
      else if BS.null byte then fail "gateway-header-truncated" else go (byte : bytes) (count + 1)

readHeaders :: Handle -> IO [(BS.ByteString, BS.ByteString)]
readHeaders = readHeadersWith False

readHeadersWith :: Bool -> Handle -> IO [(BS.ByteString, BS.ByteString)]
readHeadersWith response stream = go 0 >>= \headers -> either fail (const (pure headers)) (validateHeaderFields response headers)
 where
  go count = do
    unless (count < (32 :: Int)) (fail "gateway-header-count-exceeded")
    line <- limitedLine stream
    if BS.null line then pure [] else do
      let (rawName, rawValue) = B.break (== ':') line
          name = B.map (\c -> if c >= 'A' && c <= 'Z' then toEnum (fromEnum c + 32) else c) rawName
      unless (not (BS.null name) && not (BS.null rawValue)
        && B.all (\c -> c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-') name
        && BS.all (\byte -> byte == 9 || byte >= 32 && byte < 127) (BS.drop 1 rawValue)) (fail "gateway-header-invalid")
      rest <- go (count + 1)
      pure ((name, B.strip (BS.drop 1 rawValue)) : rest)

queryFields :: BS.ByteString -> IO [(BS.ByteString, BS.ByteString)]
queryFields target = traverse decodePair (filter (not . BS.null) (B.split '&' (BS.drop 1 (B.dropWhile (/= '?') target))))
 where
  decodePair raw = let (key, value) = B.break (== '=') raw in
    either (const (fail "gateway-query-invalid")) pure ((,) <$> decodeUri key <*> decodeUri (BS.drop 1 value))

stripAuthentication :: BS.ByteString -> BS.ByteString
stripAuthentication target =
  let (path, query) = B.break (== '?') target
      fields = filter (not . BS.isPrefixOf "X-Amz-") (B.split '&' (BS.drop 1 query))
  in path <> if null fields || fields == [BS.empty] then BS.empty else "?" <> B.intercalate "&" fields

safeHeaders :: [(BS.ByteString, BS.ByteString)] -> [(BS.ByteString, BS.ByteString)]
safeHeaders = publicResponseHeaders

respondSafe :: Handle -> Int -> [(BS.ByteString, BS.ByteString)] -> BS.ByteString -> IO ()
respondSafe client status headers body
  | status >= 400 = s3Error client status (publicErrorCode (xmlField "Code" body))
  | otherwise = respond client status (safeHeaders headers) body

s3Error :: Handle -> Int -> BS.ByteString -> IO ()
s3Error client status code = respond client status [("content-type", "application/xml")]
  ("<Error><Code>" <> code <> "</Code></Error>")

respond :: Handle -> Int -> [(BS.ByteString, BS.ByteString)] -> BS.ByteString -> IO ()
respond stream status headers body = do
  writeHead stream status (("content-length", B.pack (show (BS.length body))) : headers)
  BS.hPut stream body
  hFlush stream

writeHead :: Handle -> Int -> [(BS.ByteString, BS.ByteString)] -> IO ()
writeHead stream status headers = BS.hPut stream ("HTTP/1.1 " <> B.pack (show status) <> " Response\r\nConnection: close\r\n"
  <> BS.concat [key <> ": " <> value <> "\r\n" | (key, value) <- headers] <> "\r\n")

xmlField :: BS.ByteString -> BS.ByteString -> Maybe BS.ByteString
xmlField name body =
  let (_, found) = BS.breakSubstring ("<" <> name <> ">") body
      (value, ending) = BS.breakSubstring ("</" <> name <> ">") (BS.drop (BS.length name + 2) found)
  in if BS.null found || BS.null ending then Nothing else Just value

showHex :: Int -> String
showHex value | value < 16 = ["0123456789abcdef" !! value]
              | otherwise = showHex (value `div` 16) <> showHex (value `mod` 16)
