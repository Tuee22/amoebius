{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Image.BaseChannel
  ( BaseChannel
  , BaseChannelError (..)
  , BaseResolution
  , resolvedChannel
  , resolvedDigest
  , resolvedVia
  , ResolutionSource (..)
  , mkBaseChannel
  , mkBaseResolution
  , renderBaseChannel
  ) where

import Data.Char (isSpace)
import Data.Text (Text)
import Data.Text qualified as Text

newtype BaseChannel = BaseChannel Text
  deriving stock (Eq, Ord, Show)

renderBaseChannel :: BaseChannel -> Text
renderBaseChannel (BaseChannel channel) = channel

data ResolutionSource
  = CanonicalRegistry
  | MirrorAfterRateLimit
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data BaseResolution = BaseResolution BaseChannel Text ResolutionSource
  deriving stock (Eq, Show)

resolvedChannel :: BaseResolution -> BaseChannel
resolvedChannel (BaseResolution channel _ _) = channel
resolvedDigest :: BaseResolution -> Text
resolvedDigest (BaseResolution _ digest _) = digest
resolvedVia :: BaseResolution -> ResolutionSource
resolvedVia (BaseResolution _ _ source) = source

data BaseChannelError
  = BaseChannelEmpty
  | BaseChannelContainsDigest
  | BaseChannelMissingTag
  | BaseChannelInvalidCharacter
  | BaseResolutionDigestInvalid Text
  deriving stock (Eq, Show)

mkBaseChannel :: Text -> Either BaseChannelError BaseChannel
mkBaseChannel value
  | Text.null value = Left BaseChannelEmpty
  | Text.any isSpace value || Text.any (`elem` ['"', '\'', '\\']) value = Left BaseChannelInvalidCharacter
  | "@" `Text.isInfixOf` value || "sha256:" `Text.isInfixOf` Text.toLower value = Left BaseChannelContainsDigest
  | not (":" `Text.isInfixOf` lastPathComponent value) = Left BaseChannelMissingTag
  | otherwise = Right (BaseChannel value)

mkBaseResolution :: BaseChannel -> Text -> ResolutionSource -> Either BaseChannelError BaseResolution
mkBaseResolution channel digest source
  | validDigest digest = Right (BaseResolution channel digest source)
  | otherwise = Left (BaseResolutionDigestInvalid digest)

lastPathComponent :: Text -> Text
lastPathComponent = snd . Text.breakOnEnd "/"

validDigest :: Text -> Bool
validDigest value =
  Text.length value == 71
    && "sha256:" `Text.isPrefixOf` value
    && Text.all (`elem` ("0123456789abcdef" :: String)) (Text.drop 7 value)
