{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Platform.Tls
  ( TlsDemand (..)
  , ProvisionedTls
  , provisionTls
  , tlsSecretRef
  ) where

import Amoebius.Platform.Types
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data TlsDemand = TlsDemand
  { tlsVaultSecretRef :: Text
  , tlsEabLiteralPresent :: Bool
  , tlsMaximumOrders :: Natural
  , tlsMaximumRetries :: Natural
  , tlsWorkspaceBytes :: Natural
  , tlsRetainedRevisions :: Natural
  , tlsIssuerResources :: ResourceEnvelope
  }
  deriving stock (Eq, Show)

newtype ProvisionedTls = ProvisionedTls TlsDemand
  deriving stock (Eq, Show)

provisionTls :: TlsDemand -> Either Text ProvisionedTls
provisionTls demand = do
  _ <- validateResourceEnvelope (tlsIssuerResources demand)
  if not ("vault:" `Text.isPrefixOf` tlsVaultSecretRef demand)
    then Left "tls-eab-vault-secret-ref-required"
    else if tlsEabLiteralPresent demand
      then Left "tls-eab-literal-forbidden"
      else if tlsMaximumOrders demand == 0 || tlsMaximumRetries demand == 0 || tlsWorkspaceBytes demand == 0
        then Left "tls-acme-bounds-required"
        else if tlsRetainedRevisions demand < 2
          then Left "tls-prior-revision-required"
          else Right (ProvisionedTls demand)

tlsSecretRef :: ProvisionedTls -> Text
tlsSecretRef (ProvisionedTls demand) = tlsVaultSecretRef demand
