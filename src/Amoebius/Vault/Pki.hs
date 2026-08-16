{-# LANGUAGE CPP #-}

module Amoebius.Vault.Pki
  ( RootCa (..)
  , LeafCertificate (..)
  , issueInternalLeaf
  , verifiesAgainst
  ) where

import Amoebius.Vault.Error (VaultError (..))

newtype RootCa = RootCa {rootKeyId :: String}
  deriving stock (Eq, Show)

data LeafCertificate = LeafCertificate
  { leafCommonName :: String
  , leafIssuerKeyId :: String
  }
  deriving stock (Eq, Show)

issueInternalLeaf :: Bool -> RootCa -> String -> Either VaultError LeafCertificate
#ifdef VAULT_PKI_SEALED_ISSUANCE_MUTANT
issueInternalLeaf _ root commonName = Right (mkLeaf root commonName)
#else
issueInternalLeaf sealed root commonName
  | sealed = Left VaultSealed
  | otherwise = Right (mkLeaf root commonName)
#endif

mkLeaf :: RootCa -> String -> LeafCertificate
#ifdef VAULT_PKI_UNRELATED_LEAF_MUTANT
mkLeaf _ commonName = LeafCertificate commonName "unrelated-key"
#else
mkLeaf root commonName = LeafCertificate commonName (rootKeyId root)
#endif

verifiesAgainst :: RootCa -> LeafCertificate -> Bool
verifiesAgainst root leaf = rootKeyId root == leafIssuerKeyId leaf
