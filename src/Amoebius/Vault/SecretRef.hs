{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Vault.SecretRef
  ( SecretRef
  , vaultSecretRef
  , transitKeyRef
  , secretMount
  , secretPath
  , secretField
  , transitKeyName
  , foldSecretRef
  ) where

import Data.Char (isAlphaNum)
import Data.Text (Text)
import qualified Data.Text as Text

data SecretRef
  = VaultSecretRef
      { secretMount :: Text
      , secretPath :: Text
      , secretField :: Text
      }
  | TransitKeyRef
      { transitKeyName :: Text
      }
  deriving stock (Eq, Ord, Show)

vaultSecretRef :: Text -> Text -> Text -> Either Text SecretRef
vaultSecretRef mount path field
  | not (validSegment mount) = Left "invalid-vault-mount"
  | not (validPath path) = Left "invalid-vault-path"
  | not (validSegment field) = Left "invalid-vault-field"
  | otherwise = Right (VaultSecretRef mount path field)

transitKeyRef :: Text -> Either Text SecretRef
transitKeyRef key
  | validSegment key = Right (TransitKeyRef key)
  | otherwise = Left "invalid-transit-key"

foldSecretRef :: (Text -> Text -> Text -> value) -> (Text -> value) -> SecretRef -> value
foldSecretRef onVault onTransit reference = case reference of
  VaultSecretRef mount path field -> onVault mount path field
  TransitKeyRef key -> onTransit key

validSegment :: Text -> Bool
validSegment value =
  not (Text.null value)
    && Text.all (\character -> isAlphaNum character || character `elem` ("-_." :: String)) value

validPath :: Text -> Bool
validPath value =
  not (Text.null value)
    && not (Text.isPrefixOf "/" value)
    && not (Text.isSuffixOf "/" value)
    && all validSegment (Text.splitOn "/" value)
