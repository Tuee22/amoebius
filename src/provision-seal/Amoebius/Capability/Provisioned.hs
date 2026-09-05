-- | Public opaque provision result.  Construction remains owned by
-- 'Amoebius.Capacity.Provision'; this module is the stable import surface for
-- downstream rendering phases.
module Amoebius.Capability.Provisioned
  ( ProvisionedSpec
  , provisionedPlacement
  , provisionedExecution
  , provisionedRuntimeStorage
  , provisionedMonitoring
  , provisionedServiceParts
  , provisionedSchedulerSystem
  , provisionedPulumiExecution
  , provisionedRenderSources
  , provisionedEngineAccelerators
  ) where

import Amoebius.Capacity.Provision
  ( ProvisionedSpec
  , provisionedExecution
  , provisionedEngineAccelerators
  , provisionedMonitoring
  , provisionedPlacement
  , provisionedPulumiExecution
  , provisionedRenderSources
  , provisionedRuntimeStorage
  , provisionedSchedulerSystem
  , provisionedServiceParts
  )
