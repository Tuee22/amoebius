{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Store.Manifest
  ( Component (..)
  , Manifest
  , manifest
  , manifestComponents
  , canonicalManifestBytes
  , manifestContentDigest
  , manifestKey
  ) where

import Amoebius.Store.ContentAddress
import Codec.CBOR.Encoding (encodeBytes, encodeListLen, encodeString)
import Codec.CBOR.Write (toStrictByteString)
import Data.ByteString (ByteString)
import Data.List (sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

data Component = Component
  { componentName :: Text
  , componentDigest :: ContentDigest
  }
  deriving stock (Eq, Show)

newtype Manifest = Manifest [Component]
  deriving stock (Eq, Show)

manifest :: [Component] -> Either Text Manifest
manifest components
  | null components = Left "ManifestMustContainAtLeastOneComponent"
  | any (Text.null . componentName) components = Left "ManifestComponentNameMustBeNonEmpty"
  | hasDuplicateNames ordered = Left "ManifestComponentNamesMustBeUnique"
  | otherwise = Right (Manifest ordered)
  where
#ifdef PHASE37_INSERTION_ORDER_ENCODER_MUTANT
    ordered = components
#else
    ordered = sortOn (TextEncoding.encodeUtf8 . componentName) components
#endif
    hasDuplicateNames values =
      let names = map componentName values
       in any (uncurry (==)) (zip names (drop 1 names))

manifestComponents :: Manifest -> [Component]
manifestComponents (Manifest components) = components

canonicalManifestBytes :: Manifest -> ByteString
canonicalManifestBytes (Manifest components) = toStrictByteString encoding
  where
    encoding =
      encodeListLen 2
        <> encodeString "amoebius.manifest.v1"
        <> encodeListLen (fromIntegral (length components))
        <> foldMap encodeComponent components
    encodeComponent component =
      encodeListLen 2
        <> encodeString (componentName component)
        <> encodeBytes (digestBytes (componentDigest component))

manifestContentDigest :: Manifest -> ContentDigest
manifestContentDigest = contentDigest . canonicalManifestBytes

manifestKey :: Text -> Manifest -> Text
manifestKey namespace value = contentKey namespace "manifests" (manifestContentDigest value)
