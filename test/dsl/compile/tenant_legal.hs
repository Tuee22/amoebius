{-# LANGUAGE OverloadedStrings #-}

-- Positive decode anchor: dhall/examples/legal_deployment_rules.dhall
module TenantLegal where

import Amoebius.Dsl.Ref

data ExecutionResource
data StorageResource

execution :: Ref TenantAlpha ExecutionResource
execution = mkRef TenantAlphaToken "trivial-api"

storage :: Ref TenantAlpha StorageResource
storage = mkRef TenantAlphaToken "trivial-volume"

tenantJoin :: TenantPair TenantAlpha
tenantJoin = sameTenant execution storage
