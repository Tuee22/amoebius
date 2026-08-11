module Amoebius.Pulsar.Cbor
  ( CborPayload
  , DecodeError (..)
  , encodeCbor
  , decodeCbor
  , decodeCborBytes
  , cborBytes
  ) where

import Amoebius.Pulsar.Internal.Cbor (CborPayload (..))
import Codec.Serialise (DeserialiseFailure, Serialise, deserialiseOrFail, serialise)
import Data.ByteString (ByteString)
import Data.ByteString.Lazy qualified as Lazy

newtype DecodeError = DecodeError String
  deriving stock (Eq, Show)

encodeCbor :: Serialise a => a -> CborPayload
encodeCbor = CborPayload . Lazy.toStrict . serialise

decodeCbor :: Serialise a => CborPayload -> Either DecodeError a
decodeCbor (CborPayload bytes) =
  either (Left . DecodeError . renderFailure) Right (deserialiseOrFail (Lazy.fromStrict bytes))
  where
    renderFailure :: DeserialiseFailure -> String
    renderFailure = show

decodeCborBytes :: Serialise a => ByteString -> Either DecodeError a
decodeCborBytes = decodeCbor . CborPayload

cborBytes :: CborPayload -> ByteString
cborBytes (CborPayload bytes) = bytes
