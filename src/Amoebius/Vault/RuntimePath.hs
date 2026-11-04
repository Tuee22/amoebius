{-# LANGUAGE CPP #-}

-- | Production Vault entry points consume only the projected runtime sources.
-- Validation is pure and precedes file reads, prompts, writes, and processes.
module Amoebius.Vault.RuntimePath
  ( VaultRuntimeUse (..)
  , VaultRuntimePath
  , vaultRuntimePath
  , runtimePath
  ) where

import System.FilePath (normalise)

data VaultRuntimeUse = ProjectedJwt | ServerConfiguration | AuditDirectory
  deriving stock (Eq, Show)

newtype VaultRuntimePath = VaultRuntimePath FilePath
  deriving stock (Eq, Show)

runtimePath :: VaultRuntimePath -> FilePath
runtimePath (VaultRuntimePath path) = path

vaultRuntimePath :: VaultRuntimeUse -> FilePath -> Either String VaultRuntimePath
#ifdef VAULT_PKI_UNTRUSTED_RUNTIME_PATH_MUTANT
vaultRuntimePath _ path = Right (VaultRuntimePath path)
#else
vaultRuntimePath purpose path
  | normalise path == expected = Right (VaultRuntimePath expected)
  | otherwise = Left "vault-runtime-path-outside-projection"
 where
  expected = case purpose of
    ProjectedJwt -> "/var/run/secrets/kubernetes.io/serviceaccount/token"
    ServerConfiguration -> "/vault/config/server.hcl"
    AuditDirectory -> "/vault/audit"
#endif
