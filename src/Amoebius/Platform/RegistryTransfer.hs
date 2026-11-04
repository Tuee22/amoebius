{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Bounded filesystem-to-S3 transfer. Credentials are resolved in memory from
-- Vault using this pod's projected identity. Neither payloads nor credentials
-- are put in argv, environment, reports, or a writable configuration file.
module Amoebius.Platform.RegistryTransfer
  ( runRegistryTransferCommand, writeGatewayCanary, readGatewayCanary ) where

import Amoebius.Vault.Client
import Amoebius.Platform.ObjectGatewayPolicy
import Control.Exception (bracket)
import Control.Monad (forM, unless, when)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson
import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as B
import Data.ByteString.Lazy qualified as Lazy
import Data.List (nub)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Time (defaultTimeLocale, formatTime, getCurrentTime)
import Network.Socket
import System.FilePath ((</>), splitDirectories)
import System.IO
import System.Timeout (timeout)
import Text.Read (readMaybe)

data TransferObject = TransferObject Text Integer Text
instance FromJSON TransferObject where
  parseJSON = withObject "transfer object" $ \v -> TransferObject <$> v .: "key" <*> v .: "bytes" <*> v .: "sha256"

data TransferPlan = TransferPlan String Int String FilePath [TransferObject] Bool
instance FromJSON TransferPlan where
  parseJSON = withObject "registry transfer" $ \v -> TransferPlan
    <$> v .: "endpointHost" <*> v .: "endpointPort" <*> v .: "bucket" <*> v .: "sourceRoot" <*> v .: "objects" <*> v .:? "verifyOnly" .!= False

runRegistryTransferCommand :: [String] -> IO ()
runRegistryTransferCommand [configuration] = do
  encoded <- withBinaryFile configuration ReadMode (`BS.hGet` 1048577)
  when (BS.length encoded > 1048576) (fail "transfer-plan-too-large")
  plan@(TransferPlan host port bucket root objects verifyOnly) <- either (const (fail "transfer-plan-invalid")) pure (eitherDecodeStrict' encoded)
  unless (host == "minio.platform-system.svc" && port == 9000 && bucket == "registry" && root == "/source"
    && not (null objects) && length objects <= 1024 && length (nub [key | TransferObject key _ _ <- objects]) == length objects)
    (fail "transfer-plan-scope-invalid")
  mapM_ validateObject objects
  -- Verify every source before the first target write, including links.
  mapM_ (verifySource root) objects
  jwt <- BS.readFile "/var/run/secrets/kubernetes.io/serviceaccount/token"
  let transport = mkHttpVaultTransport (HttpVaultAddress "root-vault.vault-system.svc" "8200")
  token <- authenticateKubernetes transport (KubernetesIdentity "platform-system" "registry-writer" "amoebius-registry-writer") jwt
    >>= either (const (fail "transfer-vault-login-denied")) pure
  access <- readKvField transport token "secret" "phase30/writers/registry" "access-key" >>= either (const (fail "transfer-vault-access-denied")) pure
  secret <- readKvField transport token "secret" "phase30/writers/registry" "secret-key" >>= either (const (fail "transfer-vault-secret-denied")) pure
  rows <- forM objects $ \item@(TransferObject key bytes digest) -> do
    unless verifyOnly $ bounded $ request plan access secret "PUT" item $ \connection ->
      withBinaryFile (root </> Text.unpack key) ReadMode (copyExactly bytes connection)
    bounded $ request plan access secret "GET" item (verifyResponse bytes digest)
    pure (object ["key" .= key, "bytes" .= bytes, "sha256" .= digest])
  Lazy.putStr (encode (object ["objects" .= rows, "objectCount" .= length rows,
    "verified" .= True, "streamBufferBytes" .= (65536 :: Int), "observer" .= ("native-transfer-job" :: Text)]))
runRegistryTransferCommand _ = fail "usage: registry-transfer PUBLIC_CONFIG_PATH"

-- The application gateway has one exact physical key. Its full-size overwrite
-- needs one resident, one inflight and one failed generation in the provision.
-- These helpers share the bounded SigV4 transport, never the gateway's policy.
writeGatewayCanary :: BS.ByteString -> BS.ByteString -> BS.ByteString -> IO ()
writeGatewayCanary access secret payload = do
  unless (BS.length payload == canarySize) (fail "gateway-canary-extent-invalid")
  let item = TransferObject (applicationGatewayKey standardApplicationGateway) (fromIntegral canarySize)
        (Text.decodeUtf8 ("sha256:" <> hex (SHA256.hash payload)))
  bounded $ request canaryPlan access secret "PUT" item (\connection -> BS.hPut connection payload)

readGatewayCanary :: BS.ByteString -> BS.ByteString -> IO BS.ByteString
readGatewayCanary access secret = do
  result <- newIORef BS.empty
  bounded $ request canaryPlan access secret "GET"
    (TransferObject (applicationGatewayKey standardApplicationGateway) (fromIntegral canarySize) "") $ \connection -> do
    payload <- BS.hGet connection canarySize
    unless (BS.length payload == canarySize) (fail "gateway-canary-truncated")
    writeIORef result payload
  readIORef result

canaryPlan :: TransferPlan
canaryPlan = TransferPlan "minio-backend.platform-system.svc" 9000
  (Text.unpack (applicationGatewayBucket standardApplicationGateway)) "/unused" [] False

canarySize :: Int
canarySize = fromIntegral (applicationGatewayObjectBytes standardApplicationGateway)

validateObject :: TransferObject -> IO ()
validateObject (TransferObject key bytes digest) =
  unless (bytes > 0 && not (Text.null key) && not (Text.isPrefixOf "/" key)
    && all (`notElem` [".", ".."]) (splitDirectories (Text.unpack key))
    && Text.all (\c -> c `elem` ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/_-." :: String)) key
    && Text.length digest == 71 && Text.isPrefixOf "sha256:" digest
    && Text.all (`elem` ("0123456789abcdef" :: String)) (Text.drop 7 digest)) (fail "transfer-object-invalid")

verifySource :: FilePath -> TransferObject -> IO ()
verifySource root (TransferObject key bytes digest) = withBinaryFile (root </> Text.unpack key) ReadMode $ \source -> do
  size <- hFileSize source
  unless (size == bytes) (fail "transfer-source-size-mismatch")
  actual <- hashExactly source bytes
  unless (actual == Text.encodeUtf8 digest) (fail "transfer-source-digest-mismatch")

bounded :: IO value -> IO value
bounded action = timeout (300 * 1000000) action >>= maybe (fail "transfer-request-timeout") pure

-- The server's content-length is checked before any GET body is consumed.
-- PUT responses are small and discarded; no unbounded response buffering.
request :: TransferPlan -> BS.ByteString -> BS.ByteString -> BS.ByteString -> TransferObject -> (Handle -> IO ()) -> IO ()
request (TransferPlan host port bucket _ _ _) access secret method (TransferObject key bytes digest) consume = do
  now <- getCurrentTime
  let day = B.pack (formatTime defaultTimeLocale "%Y%m%d" now)
      date = B.pack (formatTime defaultTimeLocale "%Y%m%dT%H%M%SZ" now)
      authority = B.pack (host <> ":" <> show port)
      uri = B.pack ("/" <> bucket <> "/") <> Text.encodeUtf8 key
      payloadHash = if method == "PUT" then Text.encodeUtf8 (Text.drop 7 digest) else hex (SHA256.hash BS.empty)
      headers = "host:" <> authority <> "\nx-amz-content-sha256:" <> payloadHash <> "\nx-amz-date:" <> date <> "\n"
      signed = "host;x-amz-content-sha256;x-amz-date"
      canonical = BS.intercalate "\n" [method, uri, "", headers, signed, payloadHash]
      scope = day <> "/us-east-1/s3/aws4_request"
      toSign = BS.intercalate "\n" ["AWS4-HMAC-SHA256", date, scope, hex (SHA256.hash canonical)]
      dateKey = SHA256.hmac ("AWS4" <> secret) day
      signingKey = foldl SHA256.hmac dateKey ["us-east-1", "s3", "aws4_request"]
      authorization = "AWS4-HMAC-SHA256 Credential=" <> access <> "/" <> scope <> ", SignedHeaders=" <> signed <> ", Signature=" <> hex (SHA256.hmac signingKey toSign)
      lengthBytes = if method == "PUT" then bytes else 0
      wire = method <> " " <> uri <> " HTTP/1.1\r\nHost: " <> authority
        <> "\r\nConnection: close\r\nx-amz-date: " <> date <> "\r\nx-amz-content-sha256: " <> payloadHash
        <> "\r\nAuthorization: " <> authorization <> "\r\nContent-Length: " <> B.pack (show lengthBytes) <> "\r\n\r\n"
  addresses <- getAddrInfo (Just defaultHints {addrSocketType = Stream}) (Just host) (Just (show port))
  address <- case addresses of first : _ -> pure first; [] -> fail "transfer-endpoint-unresolved"
  bracket (open address) hClose $ \connection -> do
    BS.hPut connection wire
    when (method == "PUT") (consume connection >> hFlush connection)
    status <- limitedLine connection
    unless (B.take 12 status == "HTTP/1.1 200") (fail "transfer-target-http-error")
    responseHeaders <- readHeaders connection 0
    when (method == "GET") $ do
      let contentLength = lookup "content-length" responseHeaders >>= readMaybe . B.unpack
      unless (contentLength == Just bytes) (fail "transfer-target-size-mismatch")
      consume connection
 where
  open address = do
    socketValue <- socket (addrFamily address) Stream defaultProtocol
    connect socketValue (addrAddress address)
    connection <- socketToHandle socketValue ReadWriteMode
    hSetBinaryMode connection True
    hSetBuffering connection NoBuffering
    pure connection

limitedLine :: Handle -> IO BS.ByteString
limitedLine connection = go [] 0
 where
  go accumulated count
    | count >= (8192 :: Int) = fail "transfer-response-header-too-long"
    | otherwise = do
        byte <- BS.hGet connection 1
        if byte == "\n" then pure (BS.concat (reverse accumulated))
        else if BS.null byte then fail "transfer-response-header-truncated"
        else go (byte : accumulated) (count + 1)

readHeaders :: Handle -> Int -> IO [(BS.ByteString, BS.ByteString)]
readHeaders connection count = do
  when (count >= 64) (fail "transfer-response-header-count")
  line <- limitedLine connection
  if line == "\r" then pure [] else do
    let (name, value) = B.break (== ':') line
    rest <- readHeaders connection (count + 1)
    pure ((B.map lower name, B.strip (BS.drop 1 value)) : rest)
 where lower character = if character >= 'A' && character <= 'Z' then toEnum (fromEnum character + 32) else character

copyExactly :: Integer -> Handle -> Handle -> IO ()
copyExactly bytes destination source = go bytes
 where
  go remaining | remaining == 0 = pure ()
  go remaining = do
    chunk <- BS.hGetSome source (fromInteger (min remaining 65536))
    when (BS.null chunk) (fail "transfer-source-truncated")
    BS.hPut destination chunk
    go (remaining - fromIntegral (BS.length chunk))

hashExactly :: Handle -> Integer -> IO BS.ByteString
hashExactly source = go SHA256.init
 where
  go !context !remaining | remaining == 0 = pure ("sha256:" <> hex (SHA256.finalize context))
  go !context !remaining = do
    chunk <- BS.hGetSome source (fromInteger (min remaining 65536))
    when (BS.null chunk) (fail "transfer-body-truncated")
    go (SHA256.update context chunk) (remaining - fromIntegral (BS.length chunk))

verifyResponse :: Integer -> Text -> Handle -> IO ()
verifyResponse bytes digest connection = do
  actual <- hashExactly connection bytes
  unless (actual == Text.encodeUtf8 digest) (fail "transfer-target-digest-mismatch")

hex :: BS.ByteString -> BS.ByteString
hex = B.pack . concatMap (\byte -> [digits !! fromIntegral (byte `div` 16), digits !! fromIntegral (byte `mod` 16)]) . BS.unpack
 where digits = "0123456789abcdef"
