{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Immutable publication names.  A human-readable source/content tag is an
-- advertisement key only; workload references are always repository@digest.
module Amoebius.Image.Ref
  ( ImmutableImageRef
  , immutableImageRepository
  , immutableImageTag
  , immutableImageIndexDigest
  , immutableImageTaggedReference
  , immutableImageDigestReference
  , ImageRefError (..)
  , deriveImmutableImageRef
  , renderImageRefError
  ) where

import Control.DeepSeq (NFData)
import Data.Char (isAlphaNum, isAscii)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data ImmutableImageRef = ImmutableImageRef
  { immutableImageRepository :: Text
  , immutableImageTag :: Text
  , immutableImageIndexDigest :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ImageRefError
  = ImageRepositoryInvalid Text
  | ImageSourceDigestInvalid Text
  | ImageContentDigestInvalid Text
  | ImageTagLatestForbidden
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

deriveImmutableImageRef :: Text -> Text -> Text -> Either ImageRefError ImmutableImageRef
deriveImmutableImageRef repository sourceDigest contentDigest = do
  if validRepository repository
    then Right ()
    else Left (ImageRepositoryInvalid repository)
  validateDigest ImageSourceDigestInvalid sourceDigest
  validateDigest ImageContentDigestInvalid contentDigest
  let tag = "source-" <> short sourceDigest <> "-content-" <> short contentDigest
  if tag == "latest"
    then Left ImageTagLatestForbidden
    else
      Right
        ImmutableImageRef
          { immutableImageRepository = repository
          , immutableImageTag = tag
          , immutableImageIndexDigest = contentDigest
          }

immutableImageTaggedReference :: ImmutableImageRef -> Text
immutableImageTaggedReference reference =
  immutableImageRepository reference <> ":" <> immutableImageTag reference

immutableImageDigestReference :: ImmutableImageRef -> Text
immutableImageDigestReference reference =
  immutableImageRepository reference <> "@" <> immutableImageIndexDigest reference

renderImageRefError :: ImageRefError -> Text
renderImageRefError problem = case problem of
  ImageRepositoryInvalid _ -> "ImageRepositoryInvalid"
  ImageSourceDigestInvalid _ -> "ImageSourceDigestInvalid"
  ImageContentDigestInvalid _ -> "ImageContentDigestInvalid"
  ImageTagLatestForbidden -> "ImageTagLatestForbidden"

validateDigest :: (Text -> ImageRefError) -> Text -> Either ImageRefError ()
validateDigest constructor digest =
  if Text.length digest == 71
      && "sha256:" `Text.isPrefixOf` digest
      && Text.all (`elem` ("0123456789abcdef" :: String)) (Text.drop 7 digest)
    then Right ()
    else Left (constructor digest)

validRepository :: Text -> Bool
validRepository repository =
  not (Text.null repository)
    && not (":" `Text.isSuffixOf` repository)
    && not ("@" `Text.isInfixOf` repository)
    && not (":latest" `Text.isSuffixOf` repository)
    && Text.all validCharacter repository
 where
  validCharacter character =
    isAscii character
      && (isAlphaNum character || character `elem` ("./:_-" :: String))

short :: Text -> Text
short = Text.take 12 . Text.drop 7
