-- | The public capability vocabulary.  'BoundDeployment' is exported with its
-- selectors and without its constructor: a bound deployment is assembled only by
-- "Amoebius.Capability.Assemble", so no other module can build one from nothing.
module Amoebius.Capability.Types
  ( CapabilityArm (..)
  , EngineRuntime (..)
  , InferenceEngineNeed (..)
  , CapabilityNeed (..)
  , capabilityArm
  , capabilityResourceName
  , renderCapabilityNeedSurface
  , CapabilityProvider (..)
  , ServiceShape (..)
  , mkDistributedShape
  , CapabilityBinding (..)
  , ProviderObject (..)
  , ObjectStoreProducerKind (..)
  , RegistryStorageIntent (..)
  , ProviderIntent (..)
  , ControllerChildEnvelope (..)
  , BoundExecutionSet (..)
  , BoundServiceSpec (..)
  , PriorVolumeProvisionRef (..)
  , PriorRegistryProvisionRef (..)
  , BoundApp (..)
  , BoundDeployment
      ( boundDeploymentTransition
      , boundDeploymentServices
      , boundDeploymentExecutions
      , boundDeploymentControllerExplanations
      , boundPriorVolumeRef
      , boundPriorRegistryRef
      , boundDeploymentApps
      )
  ) where

import Amoebius.Capability.Types.Internal
