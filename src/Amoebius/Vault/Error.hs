{-# LANGUAGE CPP #-}
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
#ifdef PHASE29_ERROR_COLLAPSE_MUTANT
  VaultSecretMissing -> "sealed"
#else
  VaultSecretMissing -> "secret-missing"
#endif
  VaultDecryptDenied -> "decrypt-denied"

-- | Deliberately accepts no path, token, or resolved value.  The tag is the
-- only varying field, so this log cannot become a secret-presence oracle.
redactedErrorLog :: VaultError -> Text
redactedErrorLog failure =
#ifdef PHASE29_ERROR_COLLAPSE_MUTANT
  "vault-read-failed tag=" <> errorTag failure <> " path=amoebius/canary"
#else
  "vault-read-failed tag=" <> errorTag failure <> " detail=redacted"
#endif
