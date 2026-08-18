module Amoebius.Pulsar.Internal.Cbor
  ( CborPayload (..)
  ) where

import Data.ByteString (ByteString)

newtype CborPayload = CborPayload ByteString
  deriving stock (Eq, Show)
