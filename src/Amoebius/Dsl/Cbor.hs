{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Dsl.Cbor
  ( CborPayload
  , encodeCbor
  , decodeCbor
  , produceCbor
  ) where

import Amoebius.Dsl.Error (DecodeError (MalformedPayload))
import Codec.Serialise (Serialise, deserialiseOrFail, serialise)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text qualified as Text

newtype CborPayload value = CborPayload LazyByteString.ByteString

encodeCbor :: Serialise value => value -> CborPayload value
encodeCbor = CborPayload . serialise

decodeCbor :: Serialise value => LazyByteString.ByteString -> Either DecodeError value
decodeCbor bytes = case deserialiseOrFail bytes of
  Left problem -> Left (MalformedPayload ("CBOR: " <> Text.pack (show problem)))
  Right value -> Right value

produceCbor :: CborPayload value -> LazyByteString.ByteString
produceCbor (CborPayload bytes) = bytes
