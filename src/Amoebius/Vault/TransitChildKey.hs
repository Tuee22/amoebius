{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Vault.TransitChildKey
  ( ChildTransitKey
  , ChildCiphertext
  , ChildTransitError (..)
  , childTransitKey
  , childTransitKeyName
  , encryptChildSubtree
  , decryptChildSubtree
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Char (isSpace)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text

newtype ChildTransitKey = ChildTransitKey Text
  deriving stock (Eq)

data ChildCiphertext = ChildCiphertext Text ByteString
  deriving stock (Eq)

data ChildTransitError = WrongChildTransitKey
  deriving stock (Eq, Show)

childTransitKey :: Text -> Either Text ChildTransitKey
childTransitKey childId
  | Text.null childId = Left "empty-child-id"
  | Text.any (\character -> character == '/' || isSpace character) childId = Left "invalid-child-id"
  | otherwise = Right (ChildTransitKey ("transit/amoebius-" <> childId <> "-config"))

childTransitKeyName :: ChildTransitKey -> Text
childTransitKeyName (ChildTransitKey name) = name

encryptChildSubtree :: ChildTransitKey -> ByteString -> ChildCiphertext
encryptChildSubtree (ChildTransitKey keyName) plaintext =
  ChildCiphertext keyName (SHA256.hash (Text.encodeUtf8 keyName) <> plaintext)

decryptChildSubtree :: ChildTransitKey -> ChildCiphertext -> Either ChildTransitError ByteString
decryptChildSubtree (ChildTransitKey supplied) (ChildCiphertext owner ciphertext)
  | supplied /= owner = Left WrongChildTransitKey
  | otherwise = Right (ByteString.drop 32 ciphertext)
