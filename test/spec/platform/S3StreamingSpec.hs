{-# LANGUAGE OverloadedStrings #-}

module S3StreamingSpec (verifyS3Streaming) where

import Amoebius.Platform.S3Signing
import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as B
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Data.Time (UTCTime, defaultTimeLocale, parseTimeM)
import Data.Word (Word8)
import Numeric (readHex, showHex)
import System.Exit (die)

-- Only public AWS documentation credentials appear in this authored corpus.
-- Every seed/chunk MAC is an independent literal, never the subject signer.
verifyS3Streaming :: IO ()
verifyS3Streaming = do
  value <- Lazy.readFile "test/oracle/platform_backbone_aws_streaming.json" >>= right . eitherDecode
  right (parseEither corpus value) >>= sequence_

data Frame = Frame B.ByteString B.ByteString B.ByteString

corpus :: Value -> Parser [IO ()]
corpus = withObject "AWS independent streaming corpus" $ \root -> do
  public <- root .: "example_credentials"
  access <- public .: "access_key"
  secret <- public .: "secret_key"
  signing <- root .: "signing"
  method <- signing .: "method"
  target <- signing .: "target"
  scope <- signing .: "scope"
  signed <- signing .: "signed_headers"
  date <- signing .: "timestamp"
  now <- maybe (fail "invalid corpus timestamp") pure
    (parseTimeM True defaultTimeLocale "%Y%m%dT%H%M%SZ" (Text.unpack date) :: Maybe UTCTime)
  profiles <- root .: "payload_profiles" >>= traverse (withObject "payload profile" $ \row ->
    (,) <$> row .: "repeat_byte" <*> row .: "chunk_data_bytes")
  rows <- root .: "cases" :: Parser [Value]
  traverse (withObject "independent streaming case" $ \row -> do
    name <- row .: "id"
    profile <- row .: "payload_profile"
    (byte,lengths) <- maybe (fail "unknown payload profile") pure (Map.lookup (profile :: Text) profiles)
    signatures <- row .: "chunk_signatures"
    unless (length signatures == length lengths+1) (fail "literal frame/signature cardinality mismatch")
    headers <- row .: "headers"
    seed <- row .: "seed_signature"
    mutations <- row .: "wire_mutations" :: Parser [Value]
    let frames = [Frame (B.pack (showHex size "")) (utf8 signature) (BS.replicate size byte)
          | (size,signature) <- zip (lengths::[Int]) signatures] <> [Frame "0" (utf8 (last signatures)) BS.empty]
    encoded <- case mutations of
      [] -> pure (render frames)
      [mutation] -> mutate frames mutation
      _ -> fail "each independent paired wire case selects at most one mutation"
    limits <- row .: "limits"
    maxEncoded <- limits .: "encoded_bytes"
    maxDecoded <- limits .: "decoded_bytes"
    maxFrames <- limits .: "frames_including_zero"
    expected <- row .: "expected"
    wireBytes <- row .: "materialized_encoded_bytes"
    wireHash <- row .: "materialized_encoded_sha256"
    decodedBytes <- row .:? "expected_decoded_bytes"
    decodedHash <- row .:? "expected_decoded_sha256"
    let authorization = "AWS4-HMAC-SHA256 Credential=" <> utf8 access <> "/" <> utf8 scope
          <> ", SignedHeaders=" <> B.intercalate ";" (fmap utf8 signed) <> ", Signature=" <> utf8 seed
        request = SigningRequest (utf8 method) (utf8 target)
          (("authorization",authorization):[(utf8 key,utf8 value) | (key,value) <- Map.toList (headers::Map.Map Text Text)])
    pure $ do
      check name (BS.length encoded == wireBytes && sha256Hex encoded == utf8 wireHash)
      let result = verifyS3ChunkedPayload now (S3Credentials (utf8 access) (utf8 secret)) request
            maxEncoded maxDecoded maxFrames encoded
      check name (either (const "reject") (const "accept") result == (expected::Text))
      case result of
        Left _ -> pure ()
        Right decoded -> check name (Just (BS.length decoded) == decodedBytes && Just (sha256Hex decoded) == fmap utf8 decodedHash)) rows

render :: [Frame] -> B.ByteString
render = BS.concat . fmap (\(Frame size signature bytes) -> size<>";chunk-signature="<>signature<>"\r\n"<>bytes<>"\r\n")

mutate :: [Frame] -> Value -> Parser B.ByteString
mutate frames = withObject "independent wire delta" $ \row -> do
  kind <- row .: "kind" :: Parser Text
  case kind of
    "omit-final" -> pure (render (init frames))
    "drop-tail" -> do count <- row .: "bytes"; pure (BS.take (BS.length (render frames)-count) (render frames))
    "append" -> do
      encoded <- row .: "hex"
      suffix <- decodeHex encoded
      pure (render frames<>suffix)
    "order" -> do
      order <- row .: "frames"
      selected <- traverse (index frames) order
      pure (render selected)
    _ -> do
      position <- row .: "frame"
      Frame size signature bytes <- index frames position
      changed <- case kind of
        "size-text" -> do value <- row .: "value"; pure (Frame (utf8 value) signature bytes)
        "data-byte" -> do
          offset <- row .: "offset"; value <- row .: "value"
          next <- replace bytes offset value
          pure (Frame size signature next)
        "signature-byte" -> do
          offset <- row .: "offset"; value <- row .: "value"
          unless (Text.length value == 1) (fail "signature mutation must select one byte")
          next <- replace signature offset (BS.head (utf8 value))
          pure (Frame size next bytes)
        _ -> fail "unknown wire mutation"
      pure (render (take position frames<>[changed]<>drop (position+1) frames))
 where
  index values offset = if offset >= 0 && offset < length values then pure (values!!offset) else fail "frame index outside corpus"
  replace bytes offset value = do
    unless (offset >= 0 && offset < BS.length bytes) (fail "wire byte index outside corpus")
    pure (BS.take offset bytes<>BS.singleton (value::Word8)<>BS.drop (offset+1) bytes)

decodeHex :: Text -> Parser B.ByteString
decodeHex value = BS.pack <$> go (Text.unpack value)
 where
  go [] = pure []
  go (first:second:rest) = case readHex [first,second] of
    [(byte,"")] -> (byte:) <$> go rest
    _ -> fail "invalid literal hex suffix"
  go _ = fail "odd literal hex suffix"
utf8 :: Text -> B.ByteString
utf8 = TextEncoding.encodeUtf8
check :: Text -> Bool -> IO ()
check name condition = unless condition (die ("independent AWS streaming case: "<>Text.unpack name))
right :: Show problem => Either problem value -> IO value
right = either (die . show) pure
