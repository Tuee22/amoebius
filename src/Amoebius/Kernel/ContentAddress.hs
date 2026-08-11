{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Total, constructor-hidden content names.  Callers supply content, never a
-- name.  The durable store and the ephemeral JIT cache share this primitive.
module Amoebius.Kernel.ContentAddress
  ( ContentAddress (contentAddress)
  , BlobSha
  , ManifestSha
  , blobShaText
  , manifestShaText
  , manifestContentAddress
  , canonicalFields
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as Char8
import Data.List (intersperse, sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric (showHex)

newtype BlobSha = BlobSha Text
  deriving stock (Eq, Ord, Show)

newtype ManifestSha = ManifestSha Text
  deriving stock (Eq, Ord, Show)

class ContentAddress a where
  contentAddress :: a -> BlobSha

instance ContentAddress ByteString where
  contentAddress = BlobSha . digest

blobShaText :: BlobSha -> Text
blobShaText (BlobSha value) = value

manifestShaText :: ManifestSha -> Text
manifestShaText (ManifestSha value) = value

manifestContentAddress :: [(Text, Text)] -> ManifestSha
manifestContentAddress = ManifestSha . digest . canonicalFields

canonicalFields :: [(Text, Text)] -> ByteString
canonicalFields fields =
  Char8.pack "{" <> mconcat (intersperse (Char8.pack ",") (map render ordered)) <> Char8.pack "}"
 where
#ifdef PHASE48_CONTENT_ORDER_LEAK_MUTANT
  ordered = fields
#else
  ordered = sortOn fst fields
#endif
  render (key, value) = Char8.pack (show (Text.unpack key)) <> Char8.pack ":" <> Char8.pack (show (Text.unpack value))

digest :: ByteString -> Text
digest bytes = "sha256:" <> Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash bytes)))
 where
  hexByte byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits
