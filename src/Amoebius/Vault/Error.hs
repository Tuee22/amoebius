{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Vault.Error
  ( VaultError (..)
  , errorTag
  , redactedErrorLog
  ) where

import Data.Text (Text)

data VaultError
  = VaultUnavailable
  | VaultUninitialized
  | VaultSealed
  | VaultPolicyMissing
  | VaultSecretMissing
  | VaultDecryptDenied
  deriving stock (Bounded, Enum, Eq, Ord, Show)

errorTag :: VaultError -> Text
errorTag failure = case failure of
  VaultUnavailable -> "unavailable"
  VaultUninitialized -> "uninitialized"
  VaultSealed -> "sealed"
  VaultPolicyMissing -> "policy-missing"
  VaultSecretMissing -> "secret-missing"
  VaultDecryptDenied -> "decrypt-denied"

-- | Deliberately accepts no path, token, or resolved value.  The tag is the
-- only varying field, so this log cannot become a secret-presence oracle.
redactedErrorLog :: VaultError -> Text
redactedErrorLog failure =
  "vault-read-failed tag=" <> errorTag failure <> " detail=redacted"
