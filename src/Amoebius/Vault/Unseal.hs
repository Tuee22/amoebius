{-# LANGUAGE CPP #-}

module Amoebius.Vault.Unseal
  ( FreshnessWitness
  , UnsealResult (..)
  , observeUnseal
  , permitSecretDependentStartup
  ) where

import Amoebius.Vault.Error (VaultError (..))
import Amoebius.Vault.Init (VaultId)

newtype FreshnessWitness = FreshnessWitness VaultId
  deriving stock (Eq, Show)

data UnsealResult
  = UnsealReady FreshnessWitness
  | UnsealFailed VaultError
  deriving stock (Eq, Show)

observeUnseal :: VaultId -> Bool -> Bool -> UnsealResult
observeUnseal identity initialized sealed
  | not initialized = UnsealFailed VaultUninitialized
  | sealed = UnsealFailed VaultSealed
  | otherwise = UnsealReady (FreshnessWitness identity)

permitSecretDependentStartup :: UnsealResult -> Either VaultError FreshnessWitness
permitSecretDependentStartup result = case result of
  UnsealReady witness -> Right witness
#ifdef VAULT_PKI_STALE_READ_MUTANT
  UnsealFailed _ -> Right (FreshnessWitness (error "stale-vault-identity"))
#else
  UnsealFailed failure -> Left failure
#endif
