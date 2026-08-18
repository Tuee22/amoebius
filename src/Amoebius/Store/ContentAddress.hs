{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Store.ContentAddress
  ( ContentDigest
  , contentDigest
  , digestBytes
  , digestHex
  , digestFromBytes
  , contentKey
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric (showHex)

newtype ContentDigest = ContentDigest ByteString
  deriving stock (Eq, Ord)

instance Show ContentDigest where
  show = Text.unpack . digestHex

contentDigest :: ByteString -> ContentDigest
contentDigest = ContentDigest . SHA256.hash

digestBytes :: ContentDigest -> ByteString
digestBytes (ContentDigest bytes) = bytes

digestHex :: ContentDigest -> Text
digestHex (ContentDigest bytes) = Text.pack (concatMap byteHex (ByteString.unpack bytes))
  where
    byteHex byte = case showHex byte "" of
      [digit] -> ['0', digit]
      digits -> digits

digestFromBytes :: ByteString -> Either Text ContentDigest
digestFromBytes bytes
  | ByteString.length bytes == 32 = Right (ContentDigest bytes)
  | otherwise = Left "ContentDigestMustContainExactly32Bytes"

contentKey :: Text -> Text -> ContentDigest -> Text
contentKey namespace objectClass digest =
  namespace <> "/" <> objectClass <> "/" <> digestHex digest
