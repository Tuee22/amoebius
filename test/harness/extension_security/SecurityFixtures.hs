{-# LANGUAGE OverloadedStrings #-}

module SecurityFixtures
  ( fixtureKeyText
  , signedEnvelope
  , baselineStore
  ) where

import Amoebius.Extension.Laws.Security
  ( SecurityStore
  , SignedIdentityEnvelope (SignedIdentityEnvelope)
  , emptySecurityStore
  , insertResource
  )
import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Builder qualified as Builder
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric (showHex)

fixtureKeyText :: Text
fixtureKeyText = "security-law-fixture-key"

signedEnvelope :: Text -> Text -> SignedIdentityEnvelope
signedEnvelope tenant subject = SignedIdentityEnvelope tenant subject signature
 where
  signature = digest (frame (fmap Encoding.encodeUtf8 [fixtureKeyText, tenant, subject]))

baselineStore :: SecurityStore
baselineStore =
  insertResource "tenant-b" "bob" "foreign-record" "foreign-value"
    (insertResource "tenant-a" "alice" "own-record" "own-value" emptySecurityStore)

frame :: [ByteString] -> ByteString
frame = LazyByteString.toStrict . Builder.toLazyByteString . foldMap framed
 where
  framed bytes = Builder.word64BE (fromIntegral (ByteString.length bytes)) <> Builder.byteString bytes

digest :: ByteString -> Text
digest bytes = Text.pack (concatMap hexByte (ByteString.unpack (SHA256.hash bytes)))

hexByte :: (Integral byte, Show byte) => byte -> String
hexByte byte = case showHex byte "" of
  [single] -> ['0', single]
  digits -> digits
