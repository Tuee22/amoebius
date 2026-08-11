module Amoebius.Pulsar.Internal.Frame
  ( FrameError (..)
  , frameMaxSize
  , encodeSimple
  , encodePayload
  , decodeWireFrame
  , receiveWireFrame
  , sendWireFrame
  ) where

import Amoebius.Pulsar.Internal.Types (WireFrame (..))
import Proto.PulsarApi (BaseCommand, MessageMetadata)
import Control.Monad (when)
import Data.Binary.Get qualified as Binary
import Data.Binary.Put qualified as Binary
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as Lazy
import Data.Digest.CRC32C (crc32c)
import Data.ProtoLens.Encoding qualified as Proto
import Data.Word (Word16, Word32)
import Network.Socket (Socket)
import Network.Socket.ByteString qualified as Socket

data FrameError
  = FrameTooLarge Int
  | TruncatedFrame Int Int
  | TotalSizeMismatch Int Int
  | CommandDecodeError String
  | MetadataDecodeError String
  | MissingPayloadMagic
  | ChecksumMismatch Word32 Word32
  deriving stock (Eq, Show)

frameMaxSize :: Int
frameMaxSize = 5 * 1024 * 1024

word16 :: Word16 -> ByteString
word16 = Lazy.toStrict . Binary.runPut . Binary.putWord16be

word32 :: Word32 -> ByteString
word32 = Lazy.toStrict . Binary.runPut . Binary.putWord32be

readWord16 :: ByteString -> Word16
readWord16 = Binary.runGet Binary.getWord16be . Lazy.fromStrict

readWord32 :: ByteString -> Word32
readWord32 = Binary.runGet Binary.getWord32be . Lazy.fromStrict

encodeSimple :: BaseCommand -> Either FrameError ByteString
encodeSimple command =
  let encoded = Proto.encodeMessage command
      total = 4 + BS.length encoded
   in if total > frameMaxSize
        then Left (FrameTooLarge total)
        else Right (word32 (fromIntegral total) <> word32 (fromIntegral (BS.length encoded)) <> encoded)

encodePayload :: BaseCommand -> MessageMetadata -> ByteString -> Either FrameError ByteString
encodePayload command metadata payload =
  let encodedCommand = Proto.encodeMessage command
      encodedMetadata = Proto.encodeMessage metadata
      checked = word32 (fromIntegral (BS.length encodedMetadata)) <> encodedMetadata <> payload
      tailBytes = word16 0x0e01 <> word32 (crc32c checked) <> checked
      total = 4 + BS.length encodedCommand + BS.length tailBytes
   in if total > frameMaxSize
        then Left (FrameTooLarge total)
        else Right (word32 (fromIntegral total) <> word32 (fromIntegral (BS.length encodedCommand)) <> encodedCommand <> tailBytes)

stripBrokerEntryMetadata :: ByteString -> Either FrameError ByteString
stripBrokerEntryMetadata bytes
  | BS.length bytes >= 6 && readWord16 (BS.take 2 bytes) == 0x0e02 =
      let metadataSize = fromIntegral (readWord32 (BS.take 4 (BS.drop 2 bytes)))
          remaining = BS.drop 6 bytes
       in if BS.length remaining < metadataSize
            then Left (TruncatedFrame metadataSize (BS.length remaining))
            else Right (BS.drop metadataSize remaining)
  | otherwise = Right bytes

decodeWireFrame :: ByteString -> Either FrameError WireFrame
decodeWireFrame bytes = do
  when (BS.length bytes < 8) (Left (TruncatedFrame 8 (BS.length bytes)))
  let total = fromIntegral (readWord32 (BS.take 4 bytes))
      actual = BS.length bytes - 4
  when (total /= actual) (Left (TotalSizeMismatch total actual))
  when (total > frameMaxSize) (Left (FrameTooLarge total))
  let commandSize = fromIntegral (readWord32 (BS.take 4 (BS.drop 4 bytes)))
      commandBytes = BS.take commandSize (BS.drop 8 bytes)
      tail0 = BS.drop (8 + commandSize) bytes
  when (BS.length commandBytes /= commandSize) (Left (TruncatedFrame commandSize (BS.length commandBytes)))
  command <- either (Left . CommandDecodeError) Right (Proto.decodeMessage commandBytes)
  if BS.null tail0
    then Right (WireFrame command Nothing Nothing)
    else do
      tailBytes <- stripBrokerEntryMetadata tail0
      when (BS.length tailBytes < 10 || readWord16 (BS.take 2 tailBytes) /= 0x0e01) (Left MissingPayloadMagic)
      let expectedChecksum = readWord32 (BS.take 4 (BS.drop 2 tailBytes))
          checked = BS.drop 6 tailBytes
          observedChecksum = crc32c checked
      when (expectedChecksum /= observedChecksum) (Left (ChecksumMismatch expectedChecksum observedChecksum))
      when (BS.length checked < 4) (Left (TruncatedFrame 4 (BS.length checked)))
      let metadataSize = fromIntegral (readWord32 (BS.take 4 checked))
          metadataBytes = BS.take metadataSize (BS.drop 4 checked)
          payload = BS.drop (4 + metadataSize) checked
      when (BS.length metadataBytes /= metadataSize) (Left (TruncatedFrame metadataSize (BS.length metadataBytes)))
      metadata <- either (Left . MetadataDecodeError) Right (Proto.decodeMessage metadataBytes)
      Right (WireFrame command (Just metadata) (Just payload))

receiveExactly :: Socket -> Int -> IO ByteString
receiveExactly socket expected = go expected []
  where
    go 0 pieces = pure (BS.concat (reverse pieces))
    go remaining pieces = do
      piece <- Socket.recv socket remaining
      if BS.null piece
        then ioError (userError ("pulsar-frame-eof:" <> show expected <> ":" <> show (expected - remaining)))
        else go (remaining - BS.length piece) (piece : pieces)

receiveWireFrame :: Socket -> IO WireFrame
receiveWireFrame socket = do
  prefix <- receiveExactly socket 4
  let total = fromIntegral (readWord32 prefix)
  when (total > frameMaxSize) (ioError (userError ("pulsar-frame-too-large:" <> show total)))
  body <- receiveExactly socket total
  either (ioError . userError . ("pulsar-frame-decode:" <>) . show) pure (decodeWireFrame (prefix <> body))

sendWireFrame :: Socket -> Either FrameError ByteString -> IO ()
sendWireFrame socket encoded =
  either (ioError . userError . ("pulsar-frame-encode:" <>) . show) (Socket.sendAll socket) encoded
