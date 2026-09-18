

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
issueInternalLeaf sealed root commonName
  | sealed = Left VaultSealed
  | otherwise = Right (mkLeaf root commonName)

mkLeaf :: RootCa -> String -> LeafCertificate
mkLeaf root commonName = LeafCertificate commonName (rootKeyId root)

verifiesAgainst :: RootCa -> LeafCertificate -> Bool
verifiesAgainst root leaf = rootKeyId root == leafIssuerKeyId leaf
