{-# LANGUAGE OverloadedStrings #-}

-- | Project the product's schema declarations to the standard protobuf file
-- descriptor. This is build-tool input, not a Pulsar message-body codec.
module Amoebius.Pulsar.Wire.Descriptor (protocolDescriptorSet, protocolDescriptorSetFrom, protocolPluginRequest, protocolPluginRequestFrom) where

import Amoebius.Pulsar.Wire
import Control.Monad (forM)
import Data.Bits ((.&.), (.|.), shiftR)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as Lazy
import Data.Char (toUpper)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Data.Word (Word64)

-- | One FileDescriptorSet containing the same file that 'renderProtocol'
-- emits. Unknown field types are refused rather than guessed.
protocolDescriptorSet :: Either Text ByteString
protocolDescriptorSet = protocolDescriptorSetFrom protocolDeclarations

-- | Project an explicit declaration value to the same descriptor format.
protocolDescriptorSetFrom :: [ProtocolMessage] -> Either Text ByteString
protocolDescriptorSetFrom = fmap (finish . nested 1 . Builder.byteString) . protocolFileDescriptorFrom

-- | The protoc plugin protocol requests this file and supplies its descriptor.
protocolPluginRequest :: Either Text ByteString
protocolPluginRequest = protocolPluginRequestFrom protocolDeclarations

-- | Prepare a plugin request from the same explicit declaration value.
protocolPluginRequestFrom :: [ProtocolMessage] -> Either Text ByteString
protocolPluginRequestFrom = fmap (\file -> finish (string 1 "PulsarApi.proto" <> bytes 15 file)) . protocolFileDescriptorFrom

protocolFileDescriptorFrom :: [ProtocolMessage] -> Either Text ByteString
protocolFileDescriptorFrom declarations = do
  messages <- traverse message declarations
  pure . finish $
    string 1 "PulsarApi.proto" <> string 2 "pulsar.proto"
    <> foldMap (nested 4) messages <> foldMap (nested 5 . enum) protocolEnums
    <> nested 8 (string 1 "org.apache.pulsar.common.api.proto" <> natural 9 3)
 where
  names = Set.fromList (map protocolMessageName declarations)
  globalEnums = Set.fromList (map protocolEnumName protocolEnums)
  message declaration = do
    fields <- forM (protocolMessageFields declaration) $ \field -> do
      (kind, qualified) <- resolve declaration (protocolFieldType field)
      pure $ string 1 (protocolFieldName field)
        <> natural 3 (fromIntegral (protocolFieldNumber field))
        <> natural 4 (case protocolFieldCardinality field of Optional -> 1; Required -> 2; Repeated -> 3)
        <> natural 5 kind <> maybe mempty (string 6) qualified
        <> maybe mempty (string 7) (protocolFieldDefault field)
        <> string 10 (jsonName (protocolFieldName field))
    pure $ string 1 (protocolMessageName declaration) <> foldMap (nested 2) fields
      <> foldMap (nested 4 . enum) (protocolMessageEnums declaration)
  resolve declaration name = case lookup name primitives of
    Just code -> Right (code, Nothing)
    Nothing | name `Set.member` Set.fromList (map protocolEnumName (protocolMessageEnums declaration)) ->
      Right (14, Just (".pulsar.proto." <> protocolMessageName declaration <> "." <> name))
    Nothing | name `Set.member` globalEnums -> Right (14, Just (".pulsar.proto." <> name))
    Nothing | name `Set.member` names -> Right (11, Just (".pulsar.proto." <> name))
    Nothing -> Left ("unknown protocol field type: " <> protocolMessageName declaration <> "." <> name)
  primitives = [("double",1), ("int64",3), ("uint64",4), ("int32",5), ("bool",8), ("string",9), ("bytes",12), ("uint32",13)]

enum :: ProtocolEnum -> Builder.Builder
enum declaration = string 1 (protocolEnumName declaration) <> foldMap value (protocolEnumValues declaration)
 where value (name, number) = nested 2 (string 1 name <> natural 2 (fromIntegral number))

jsonName :: Text -> Text
jsonName = Text.pack . go False . Text.unpack
 where
  go _ [] = []
  go _ ('_' : rest) = go True rest
  go upper (character : rest) = (if upper then toUpper character else character) : go False rest

finish :: Builder.Builder -> ByteString
finish = Lazy.toStrict . Builder.toLazyByteString

varint :: Word64 -> Builder.Builder
varint value
  | value < 128 = Builder.word8 (fromIntegral value)
  | otherwise = Builder.word8 (fromIntegral (value .&. 127) .|. 128) <> varint (value `shiftR` 7)

natural :: Word64 -> Word64 -> Builder.Builder
natural field value = varint (field * 8) <> varint value

string :: Word64 -> Text -> Builder.Builder
string field = bytes field . Encoding.encodeUtf8

bytes :: Word64 -> ByteString -> Builder.Builder
bytes field value = varint (field * 8 + 2) <> varint (fromIntegral (ByteString.length value)) <> Builder.byteString value

nested :: Word64 -> Builder.Builder -> Builder.Builder
nested field = bytes field . finish
