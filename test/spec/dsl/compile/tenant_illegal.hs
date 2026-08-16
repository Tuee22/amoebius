{-# LANGUAGE OverloadedStrings #-}

-- Negative twin of tenant_legal.hs: only the storage tenant index differs.
module TenantIllegal where

import Amoebius.Dsl.Ref

data ExecutionResource
data StorageResource

execution :: Ref TenantAlpha ExecutionResource
execution = mkRef TenantAlphaToken "trivial-api"

storage :: Ref TenantBeta StorageResource
storage = mkRef TenantBetaToken "trivial-volume"

tenantJoin :: TenantPair TenantAlpha
tenantJoin = sameTenant execution storage
