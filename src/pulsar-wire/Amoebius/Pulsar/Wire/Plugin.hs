{-# LANGUAGE OverloadedStrings #-}

-- | Decode the build-time protoc plugin response. This protocol is distinct
-- from the Pulsar message bodies, which are decoded by proto-lens.
module Amoebius.Pulsar.Wire.Plugin (decodePluginResponse) where

import Control.Monad (unless, when)
import Data.Binary.Get qualified as Get
import Data.Bits ((.&.), (.|.), shiftL, shiftR)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as Lazy
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Word (Word64)

data Field = Number Word64 Word64 | Blob Word64 ByteString | Other Word64

-- | Require the complete pair of generated modules, with no insertion-point
-- fragments, duplicate names, error response, or empty contents.
decodePluginResponse :: ByteString -> Either Text [(FilePath, ByteString)]
decodePluginResponse response = do
  when (ByteString.length response > 64 * 1024 * 1024) (Left "plugin response exceeds limit")
  fields <- parseFields response
  unless (all responseShape fields) (Left "plugin response has an invalid field type")
  unless (null [value | Blob 1 value <- fields]) (Left "plugin reported an error")
  files <- traverse decodeFile [value | Blob 15 value <- fields]
  unless (sort (map fst files) == ["Proto/PulsarApi.hs", "Proto/PulsarApi_Fields.hs"])
    (Left "plugin response has an invalid file inventory")
  pure files
 where
  decodeFile contents = do
    fields <- parseFields contents
    unless (all fileShape fields) (Left "plugin file has an invalid field type")
    unless (null [value | Blob 2 value <- fields]) (Left "plugin insertion point refused")
    pathBytes <- only "file name" [value | Blob 1 value <- fields]
    path <- either (const (Left "plugin file name is not UTF-8")) (Right . Text.unpack) (Encoding.decodeUtf8' pathBytes)
    content <- only "file content" [value | Blob 15 value <- fields]
    when (ByteString.null content) (Left "plugin file is empty")
    pure (path, content)
  only _ [value] = Right value
  only label _ = Left ("plugin response has an invalid " <> label)
  responseShape field = case field of
    Blob key _ -> key `notElem` [2, 3, 4]
    Number key _ -> key `notElem` [1, 15]
    Other key -> key `notElem` [1, 2, 3, 4, 15]
  fileShape field = case field of
    Blob _ _ -> True
    Number key _ -> key `notElem` [1, 2, 15, 16]
    Other key -> key `notElem` [1, 2, 15, 16]

parseFields :: ByteString -> Either Text [Field]
parseFields contents = case Get.runGetOrFail (fields (0 :: Int)) (Lazy.fromStrict contents) of
  Left (_, _, problem) -> Left ("plugin response malformed: " <> Text.pack problem)
  Right (remaining, _, result)
    | Lazy.null remaining -> Right result
    | otherwise -> Left "plugin response has trailing bytes"
 where
  fields count = do
    done <- Get.isEmpty
    if done then pure [] else do
      when (count >= 100000) (fail "field count exceeds limit")
      key <- getVarint
      let field = key `shiftR` 3
      when (field == 0) (fail "zero field number")
      value <- case key .&. 7 of
        0 -> Number field <$> getVarint
        1 -> Get.skip 8 >> pure (Other field)
        2 -> do
          size <- getVarint
          when (size > 64 * 1024 * 1024) (fail "field exceeds limit")
          Blob field <$> Get.getByteString (fromIntegral size)
        5 -> Get.skip 4 >> pure (Other field)
        _ -> fail "unsupported wire type"
      (value :) <$> fields (count + 1)
  getVarint = step 0 0
  step offset accumulated = do
    byte <- Get.getWord8
    when (offset == 63 && byte > 1) (fail "varint overflow")
    let value = accumulated .|. (fromIntegral (byte .&. 127) `shiftL` offset)
    if byte < 128 then pure value
      else if offset >= 63 then fail "varint overflow" else step (offset + 7) value
