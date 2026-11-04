{-# LANGUAGE OverloadedStrings #-}

-- | One bounded, authenticated command per connection. The actual durable
-- store is the sole grant authority. This adapter installs no JVM interceptor
-- and makes no transport encryption or runtime resource-adequacy claim.
module Amoebius.Platform.HistoryCoordinator
  ( HistoryCoordinator, historyCoordinator, serveHistoryCoordinator
  , serveHistoryCoordinatorSocket
  , historyRequestMaximumBytes, historyResponseBytes
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Amoebius.Platform.ZooKeeperHistory
import Amoebius.Platform.ZooKeeperHistoryStore
import Control.Exception (IOException, bracket, bracketOnError, try)
import Control.Monad (forever, unless)
import Data.Aeson
import Data.Aeson.Types (parseEither)
import Data.ByteArray (constEq)
import Data.ByteString qualified as BS
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text.Encoding qualified as Text
import Data.Word (Word8)
import Numeric.Natural (Natural)
import Network.Socket (Socket, accept, close, socketToHandle)
import System.IO (Handle, IOMode (ReadWriteMode), BufferMode (NoBuffering), hClose,
                  hFlush, hSetBinaryMode, hSetBuffering)
import System.Timeout (timeout)

data HistoryCoordinator = HistoryCoordinator HistoryStore (Map.Map Natural BS.ByteString)

historyRequestMaximumBytes, historyResponseBytes :: Int
historyRequestMaximumBytes = 117
historyResponseBytes = 53

-- Keys belong to the exact immutable policy retained by the opened store.
-- Generating/unsealing those credentials and binding callers to members are
-- deployment responsibilities; arbitrary caller-supplied members gain no role.
historyCoordinator :: HistoryStore -> [(Natural, BS.ByteString)] -> Either Text HistoryCoordinator
historyCoordinator store credentials = do
  members <- either (Left . const "history-coordinator-policy-invalid") Right
    (parseEither (withObject "history policy" (.: "members")) (historyPolicyValue (historyStorePolicy store)))
  let keys = Map.fromList credentials
      tokens = fmap snd credentials
  unless (length credentials == Map.size keys && Map.keysSet keys == Set.fromList (members :: [Natural])
    && all (==32) (fmap BS.length tokens) && Set.size (Set.fromList tokens) == length tokens)
    (Left "history-coordinator-credential-domain")
  pure (HistoryCoordinator store keys)

-- One active request, one fixed deadline, no per-connection worker queue.
-- The caller owns the listener's address/backlog and deployment identity.
serveHistoryCoordinatorSocket :: HistoryCoordinator -> Socket -> IO ()
serveHistoryCoordinatorSocket coordinator server = forever $
  bracket connection hClose $ \stream -> do
    hSetBinaryMode stream True
    hSetBuffering stream NoBuffering
    _ <- try @IOException (timeout (30*1000000) (serveHistoryCoordinator coordinator stream))
    pure ()
 where
  connection = bracketOnError (fst <$> accept server) close (`socketToHandle` ReadWriteMode)

serveHistoryCoordinator :: HistoryCoordinator -> Handle -> IO ()
serveHistoryCoordinator (HistoryCoordinator store keys) stream = do
  prefix <- BS.hGet stream 4
  unless (BS.length prefix == 4) (fail "history-request-length-truncated")
  let extent = unsigned prefix
  unless (extent > 0 && extent <= fromIntegral historyRequestMaximumBytes)
    (fail "history-request-length-invalid")
  payload <- BS.hGet stream (fromIntegral extent)
  unless (BS.length payload == fromIntegral extent) (fail "history-request-body-truncated")
  (member, token, nonce, command) <- either (fail . show) pure (decodeRequest payload)
  unless (maybe False (`constEq` token) (Map.lookup member keys)) (fail "history-request-role-denied")
  admitted <- submitHistoryCommand store command
  let decision = either (const 1) (const 0) admitted :: Word8
      response = "AHG1" <> nonce <> rawSha256 payload <> BS.singleton decision
  unless (BS.length response == historyResponseBytes) (fail "history-response-extent-invalid")
  BS.hPut stream response
  hFlush stream

decodeRequest :: BS.ByteString -> Either Text (Natural, BS.ByteString, BS.ByteString, HistoryCommand)
decodeRequest payload = do
  (magic, a) <- takeBytes 4 payload
  unless (magic == "AHC1") (Left "history-request-magic-invalid")
  (memberBytes, b) <- takeBytes 8 a
  let member = unsigned memberBytes
  unless (member <= 9223372036854775807) (Left "history-request-member-invalid")
  (token, c) <- takeBytes 32 b
  (nonce, d) <- takeBytes 16 c
  (opBytes, body) <- takeBytes 1 d
  op <- case BS.unpack opBytes of
    [value] -> Right value
    _ -> Left "history-request-opcode-invalid"
  value <- case op of
    0 -> mutation "reserve" member body False
    1 -> mutation "apply" member body False
    2 -> mutation "append_attempt" member body False
    3 -> mutation "append_attempt" member body True
    4 -> generation "log." member body
    5 -> generation "snapshot." member body
    _ -> Left "history-request-opcode-invalid"
  command <- historyCommandFromValue value
  pure (member, token, nonce, command)
 where
  mutation operation member body hasDigest = do
    (zxid, a) <- takeBytes 8 body
    (extent, b) <- takeBytes 4 a
    (hash, rest) <- takeBytes 32 b
    digest <- if hasDigest then do
      (suffix, trailing) <- takeBytes 12 rest
      unless (BS.null trailing) (Left "history-request-trailing-bytes")
      pure ["digest" .= hexadecimal suffix]
      else do
        unless (BS.null rest) (Left "history-request-trailing-bytes")
        pure []
    pure (object (["operation" .= (operation :: Text), "member" .= member,
      "mutation" .= object ["zxid" .= unsigned zxid, "canonicalBytes" .= unsigned extent,
                            "canonicalSha256" .= hexadecimal hash]] <> digest))
  generation expectedPrefix member body = do
    (extent, a) <- takeBytes 1 body
    (name, trailing) <- takeBytes (fromIntegral (unsigned extent)) a
    unless (BS.null trailing && expectedPrefix `BS.isPrefixOf` name
      && BS.all (\byte -> byte >= 32 && byte <= 126) name)
      (Left "history-request-generation-invalid")
    pure (object ["operation" .= ("open_generation" :: Text), "member" .= member,
                  "name" .= Text.decodeUtf8 name])

takeBytes :: Int -> BS.ByteString -> Either Text (BS.ByteString, BS.ByteString)
takeBytes count bytes = do
  unless (count >= 0 && BS.length bytes >= count) (Left "history-request-field-truncated")
  pure (BS.splitAt count bytes)

unsigned :: BS.ByteString -> Natural
unsigned = BS.foldl' (\total byte -> total*256+fromIntegral byte) 0

hexadecimal :: BS.ByteString -> Text
hexadecimal = Text.decodeUtf8 . Lazy.toStrict . Builder.toLazyByteString . foldMap byte . BS.unpack
 where
  digits = "0123456789abcdef" :: BS.ByteString
  byte value = Builder.word8 (BS.index digits (fromIntegral value `div` 16))
    <> Builder.word8 (BS.index digits (fromIntegral value `mod` 16))

rawSha256 :: BS.ByteString -> BS.ByteString
rawSha256 = SHA256.hash
