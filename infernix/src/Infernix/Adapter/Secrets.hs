{-# LANGUAGE OverloadedStrings #-}

module Infernix.Adapter.Secrets
  ( TenantScope
  , tenantA
  , tenantB
  , tenantScopeText
  , ServiceCredential
  , leastPrivilegeCredential
  , credentialScope
  , credentialSecretRef
  , credentialHasProviderAuthority
  ) where

import Data.Text (Text)

newtype TenantScope = TenantScope Text
  deriving stock (Eq, Ord, Show)

tenantA :: TenantScope
tenantA = TenantScope "tenant-a"

tenantB :: TenantScope
tenantB = TenantScope "tenant-b"

tenantScopeText :: TenantScope -> Text
tenantScopeText (TenantScope value) = value

-- The credential contains a Vault name and authenticated scope, never secret
-- bytes or provider credentials.
data ServiceCredential = ServiceCredential TenantScope Text
  deriving stock (Eq, Show)

leastPrivilegeCredential :: TenantScope -> ServiceCredential
leastPrivilegeCredential scope =
  ServiceCredential scope ("secret/data/infernix/phase49/" <> tenantScopeText scope)

credentialScope :: ServiceCredential -> TenantScope
credentialScope (ServiceCredential scope _) = scope

credentialSecretRef :: ServiceCredential -> Text
credentialSecretRef (ServiceCredential _ name) = name

credentialHasProviderAuthority :: ServiceCredential -> Bool
credentialHasProviderAuthority _ = False
