{-# LANGUAGE OverloadedStrings #-}

-- | Independently decode the generated FileDescriptorSet and compare its
-- complete semantic content with the separately transcribed wire contract.
module DslWireDescriptor (descriptorRow, requestRow, preparationRows, descriptorMatchesLedgerNumber, requestMatchesLedgerNumber, pluginResponseMatchesGenerated) where

import Control.Exception (IOException, try)
import Control.Monad (guard, unless, when)
import Data.Binary.Get qualified as Get
import Data.Bits ((.&.), (.|.), shiftL, shiftR)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as Lazy
import Data.Char (toUpper)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Word (Word64)
import DslParse (Row, check)
import DslWireSchema (expectedWireSchema, wireEnums, wireMessages)
import System.FilePath ((</>))

data Value = IntegerValue Word64 Word64 | BytesValue Word64 ByteString | FixedValue Word64 deriving (Eq, Show)

descriptorRow :: FilePath -> IO Row
descriptorRow suite = do
  content <- try (ByteString.readFile (suite </> "proto" </> "PulsarApi.desc")) :: IO (Either IOException ByteString)
  let valid = either (const False) (maybe False id . checkDescriptor) content
  pure (check "wire.descriptor" valid "generated descriptor differs from the independent wire contract")

-- | Judge the request even when a plugin refuses it before producing bindings.
requestRow :: FilePath -> IO Row
requestRow path = do
  content <- try (ByteString.readFile path) :: IO (Either IOException ByteString)
  pure (check "wire.plugin-request" (either (const False) (requestMatchesLedgerNumber 1) content) "plugin request differs from the independent wire contract")

-- | Judge both outputs from the same preparation before depending on the plugin.
preparationRows :: FilePath -> IO [Row]
preparationRows directory = do
  schema <- try (ByteString.readFile (directory </> "PulsarApi.proto")) :: IO (Either IOException ByteString)
  request <- requestRow (directory </> "plugin.request")
  pure [check "wire.prepared-schema" (schema == Right (Encoding.encodeUtf8 expectedWireSchema)) "prepared schema differs from the independent wire contract", request]

checkDescriptor :: ByteString -> Maybe Bool
checkDescriptor = checkDescriptorWithLedgerNumber 1

-- | Judge every descriptor entry against the independent schema, changing only
-- the expected number of MessageIdData.ledgerId for a typed negative twin.
descriptorMatchesLedgerNumber :: Word64 -> ByteString -> Bool
descriptorMatchesLedgerNumber number = maybe False id . checkDescriptorWithLedgerNumber number

-- | The plugin receives one named file and its independently checked descriptor.
requestMatchesLedgerNumber :: Word64 -> ByteString -> Bool
requestMatchesLedgerNumber number = maybe False id . checkRequest
 where
  checkRequest bytes = do
    fields <- decode bytes
    guard (map tag fields == [1,15])
    name <- textField 1 fields
    file <- oneBlob 15 fields
    valid <- checkFileWithLedgerNumber number file
    pure (name == "PulsarApi.proto" && valid)

-- | Decode the plugin response independently and compare its complete file bodies.
pluginResponseMatchesGenerated :: ByteString -> [(Text, ByteString)] -> Bool
pluginResponseMatchesGenerated response expected = maybe False id $ do
  fields <- decode response
  let files = [body | BytesValue 15 body <- fields]
      admitted value = case value of
        IntegerValue key _ -> key `notElem` [1,15]
        BytesValue key _ -> key `notElem` [1,2,3,4]
        FixedValue key -> key `notElem` [1,2,3,4,15]
  guard (all admitted fields && length files == 2)
  actual <- traverse file files
  pure (sort actual == sort expected && all (not . ByteString.null . snd) actual)
 where
  file body = do
    fields <- decode body
    let admitted value = case value of
          BytesValue key _ -> key /= 2
          IntegerValue key _ -> key `notElem` [1,2,15,16]
          FixedValue key -> key `notElem` [1,2,15,16]
    guard (all admitted fields)
    (,) <$> textField 1 fields <*> oneBlob 15 fields

checkDescriptorWithLedgerNumber :: Word64 -> ByteString -> Maybe Bool
checkDescriptorWithLedgerNumber ledgerNumber bytes = do
  [BytesValue 1 file] <- decode bytes
  checkFileWithLedgerNumber ledgerNumber file

checkFileWithLedgerNumber :: Word64 -> ByteString -> Maybe Bool
checkFileWithLedgerNumber ledgerNumber file = do
  fields <- decode file
  guard (map tag fields == [1,2] <> replicate (length wireMessages) 4 <> replicate (length wireEnums) 5 <> [8])
  name <- textField 1 fields
  package <- textField 2 fields
  options <- oneBlob 8 fields >>= decode
  javaPackage <- textField 1 options
  optimize <- integerField 9 options
  guard (map tag options == [1,9])
  messages <- traverse decodeMessage [value | BytesValue 4 value <- fields]
  enums <- traverse decodeEnum [value | BytesValue 5 value <- fields]
  original <- traverse expectedMessage wireMessages
  let targets = [number | (name, fields', _) <- original, name == "MessageIdData", (field, number, _, _, _, _, _) <- fields', field == "ledgerId"]
      changeField field@(name, _, cardinality, kind, qualified, initial, json)
        | name == "ledgerId" = (name, ledgerNumber, cardinality, kind, qualified, initial, json)
        | otherwise = field
      changeMessage message@(name, fields', enums')
        | name == "MessageIdData" = (name, map changeField fields', enums')
        | otherwise = message
      expected = map changeMessage original
  guard (targets == [1])
  pure (name == "PulsarApi.proto" && package == "pulsar.proto"
    && javaPackage == "org.apache.pulsar.common.api.proto" && optimize == 3
    && messages == expected && enums == wireEnums)

type FieldContract = (Text, Word64, Word64, Word64, Maybe Text, Maybe Text, Text)
type MessageContract = (Text, [FieldContract], [(Text, [(Text, Int)])])

decodeMessage :: ByteString -> Maybe MessageContract
decodeMessage bytes = do
  fields <- decode bytes
  name <- textField 1 fields
  let fieldBytes = [value | BytesValue 2 value <- fields]
      enumBytes = [value | BytesValue 4 value <- fields]
  guard (map tag fields == [1] <> replicate (length fieldBytes) 2 <> replicate (length enumBytes) 4)
  decodedFields <- traverse decodeField fieldBytes
  decodedEnums <- traverse decodeEnum enumBytes
  pure (name, decodedFields, decodedEnums)

decodeField :: ByteString -> Maybe FieldContract
decodeField bytes = do
  fields <- decode bytes
  let typeNames = [value | BytesValue 6 value <- fields]
      defaults = [value | BytesValue 7 value <- fields]
  guard (length typeNames <= 1 && length defaults <= 1)
  guard (map tag fields == [1,3,4,5] <> replicate (length typeNames) 6 <> replicate (length defaults) 7 <> [10])
  name <- textField 1 fields
  number <- integerField 3 fields
  label <- integerField 4 fields
  kind <- integerField 5 fields
  qualified <- traverse text typeNames
  initial <- traverse text defaults
  json <- textField 10 fields
  pure (name,number,label,kind,first qualified,first initial,json)
 where first [] = Nothing; first [value] = Just value; first _ = Nothing

decodeEnum :: ByteString -> Maybe (Text, [(Text, Int)])
decodeEnum bytes = do
  fields <- decode bytes
  name <- textField 1 fields
  let values = [value | BytesValue 2 value <- fields]
  guard (map tag fields == 1 : replicate (length values) 2)
  entries <- traverse entry values
  pure (name, entries)
 where
  entry bytes' = do
    fields <- decode bytes'
    guard (map tag fields == [1,2])
    (,) <$> textField 1 fields <*> (fromIntegral <$> integerField 2 fields)

expectedMessage :: (Text, [(Text, [(Text, Int)])], [(Text, Text, Text, Int, Maybe Text)]) -> Maybe MessageContract
expectedMessage (name, enums, fields) = do
  expected <- traverse field fields
  pure (name, expected, enums)
 where
  field (label, kind, fieldName, number, initial) = do
    cardinality <- lookup label [("optional",1), ("required",2), ("repeated",3)]
    (code, qualified) <- case lookup kind [("double",1), ("int64",3), ("uint64",4), ("int32",5), ("bool",8), ("string",9), ("bytes",12), ("uint32",13)] of
      Just primitive -> Just (primitive, Nothing)
      Nothing | kind `elem` map fst enums -> Just (14, Just (".pulsar.proto." <> name <> "." <> kind))
      Nothing | kind `elem` map fst wireEnums -> Just (14, Just (".pulsar.proto." <> kind))
      Nothing | kind `elem` [message | (message,_,_) <- wireMessages] -> Just (11, Just (".pulsar.proto." <> kind))
      Nothing -> Nothing
    pure (fieldName, fromIntegral number, cardinality, code, qualified, initial, camel fieldName)
  camel = Text.pack . go False . Text.unpack
  go _ [] = []
  go _ ('_' : rest) = go True rest
  go upper (character : rest) = (if upper then toUpper character else character) : go False rest

tag :: Value -> Word64
tag (IntegerValue field _) = field
tag (BytesValue field _) = field
tag (FixedValue field) = field

oneBlob :: Word64 -> [Value] -> Maybe ByteString
oneBlob key fields = case [value | BytesValue field value <- fields, field == key] of [value] -> Just value; _ -> Nothing

textField :: Word64 -> [Value] -> Maybe Text
textField key fields = oneBlob key fields >>= text

text :: ByteString -> Maybe Text
text = either (const Nothing) Just . Encoding.decodeUtf8'

integerField :: Word64 -> [Value] -> Maybe Word64
integerField key fields = case [value | IntegerValue field value <- fields, field == key] of [value] -> Just value; _ -> Nothing

decode :: ByteString -> Maybe [Value]
decode input = case Get.runGetOrFail (fields (0 :: Int)) (Lazy.fromStrict input) of
  Right (remaining, _, result) | Lazy.null remaining -> Just result
  _ -> Nothing
 where
  fields :: Int -> Get.Get [Value]
  fields count = do
    end <- Get.isEmpty
    if end then pure [] else do
      when (count >= 100000) (fail "too many descriptor fields")
      key <- varint 0 0
      let field = key `shiftR` 3
      unless (field > 0) (fail "zero field")
      value <- case key .&. 7 of
        0 -> IntegerValue field <$> varint 0 0
        1 -> Get.skip 8 >> pure (FixedValue field)
        2 -> do size <- varint 0 0; when (size > 64 * 1024 * 1024) (fail "descriptor field too large"); BytesValue field <$> Get.getByteString (fromIntegral size)
        5 -> Get.skip 4 >> pure (FixedValue field)
        _ -> fail "unexpected descriptor wire type"
      (value :) <$> fields (count + 1)
  varint :: Int -> Word64 -> Get.Get Word64
  varint offset accumulated = do
    byte <- Get.getWord8
    when (offset == 63 && byte > 1) (fail "varint overflow")
    let value = accumulated .|. (fromIntegral (byte .&. 127) `shiftL` offset)
    if byte < 128 then pure value else if offset >= 63 then fail "varint overflow" else varint (offset + 7) value
