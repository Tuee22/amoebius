{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Release.ReleaseHash
  ( ReleaseHash
  , releaseHashText
  , ReleaseSource (..)
  , releasePreimage
  , deriveReleaseHash
  ) where

import Amoebius.Store.ContentAddress (contentDigest, digestHex)
import Data.ByteString (ByteString)
import Data.List (sort)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding

newtype ReleaseHash = ReleaseHash Text
  deriving stock (Eq, Ord)

instance Show ReleaseHash where
  show = Text.unpack . releaseHashText

releaseHashText :: ReleaseHash -> Text
releaseHashText (ReleaseHash value) = value

data ReleaseSource = ReleaseSource
  { resolvedDeploymentDhall :: Text
  , releaseImageDigests :: [Text]
  , releaseSubstrateFingerprint :: Text
  }
  deriving stock (Eq, Show)

releasePreimage :: ReleaseSource -> ByteString
releasePreimage source = TextEncoding.encodeUtf8 (Text.intercalate "\n" fields)
 where
  fields =
    [resolvedDeploymentDhall source]
      <> sort (releaseImageDigests source)
#ifndef RELEASE_LIFECYCLE_HASH_OMITS_SUBSTRATE_MUTANT
      <> [releaseSubstrateFingerprint source]
#endif

deriveReleaseHash :: ReleaseSource -> ReleaseHash
deriveReleaseHash = ReleaseHash . digestHex . contentDigest . releasePreimage
