{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The Phase-11 capability vocabulary and the wholly-unprovisioned output
-- of representational binding.  Products and deployment shapes are absent
-- from 'CapabilityNeed'; they enter only through 'CapabilityBinding'.
module Amoebius.Capability.Types
  ( CapabilityArm (..)
  , EngineRuntime (..)
  , InferenceEngineNeed (..)
  , CapabilityNeed (..)
  , capabilityArm
  , capabilityResourceName
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
  , BoundDeployment (..)
  , ExtensionName (..)
  , ExtensionDescriptor (..)
  ) where

import Amoebius.Capacity.Execution
  ( BoundExecutionUnit
  , ExecutionTransitionSource
  )
import Amoebius.Dsl.Error (DecodeError (OutOfDomainArm))
import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Set (Set)
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data CapabilityArm
  = ObjectStore
  | SecretStore
  | MessageBus
  | Sql
  | Identity
  | Observability
  | Registry
  | Edge
  | InferenceEngine
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | A named catalog lane.  There is intentionally no URL or download arm.
data EngineRuntime
  = AppleMetal Text
  | Cuda Text
  | LinuxCpu Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data InferenceEngineNeed = InferenceEngineNeed
  { inferenceResourceName :: Text
  , inferenceProfile :: Text
  , inferenceRuntime :: EngineRuntime
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | Application-facing resource needs.  Constructor names are capabilities,
-- never provider products.  Shape is deliberately not a field here.
data CapabilityNeed
  = ObjectStoreNeed Text
  | SecretStoreNeed Text
  | MessageBusNeed Text
  | SqlNeed Text
  | IdentityNeed Text
  | ObservabilityNeed Text
  | RegistryNeed Text
  | EdgeNeed Text
  | InferenceEngineCapabilityNeed InferenceEngineNeed
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

capabilityArm :: CapabilityNeed -> CapabilityArm
capabilityArm need = case need of
  ObjectStoreNeed _ -> ObjectStore
  SecretStoreNeed _ -> SecretStore
  MessageBusNeed _ -> MessageBus
  SqlNeed _ -> Sql
  IdentityNeed _ -> Identity
  ObservabilityNeed _ -> Observability
  RegistryNeed _ -> Registry
  EdgeNeed _ -> Edge
  InferenceEngineCapabilityNeed _ -> InferenceEngine

capabilityResourceName :: CapabilityNeed -> Text
capabilityResourceName need = case need of
  ObjectStoreNeed name -> name
  SecretStoreNeed name -> name
  MessageBusNeed name -> name
  SqlNeed name -> name
  IdentityNeed name -> name
  ObservabilityNeed name -> name
  RegistryNeed name -> name
  EdgeNeed name -> name
  InferenceEngineCapabilityNeed inference -> inferenceResourceName inference

-- | The provider union has one built arm today.  Alternate values are
-- rejected during Gate-2 refinement instead of surviving as pending work.
data CapabilityProvider = CanonicalProvider
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ServiceShape = SingleNode | Distributed Natural
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

mkDistributedShape :: Natural -> Either DecodeError ServiceShape
mkDistributedShape nodes
  | nodes >= 2 = Right (Distributed nodes)
  | otherwise = Left (OutOfDomainArm "capability.binding.shape.Distributed.nodes>=2")

data CapabilityBinding = CapabilityBinding
  { bindingProvider :: CapabilityProvider
  , bindingShape :: ServiceShape
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | An explicitly expanded provider object.  A distributed shape contains
-- one concrete member object per node; no replica scalar stands in for them.
data ProviderObject = ProviderObject
  { providerObjectIdentity :: Text
  , providerObjectKind :: Text
  , providerObjectRole :: Text
  , providerObjectOwner :: Maybe Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ObjectStoreProducerKind = ApplicationBuckets | RegistryProducer
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

newtype RegistryStorageIntent = RegistryStorageIntent
  { registryStorageResource :: Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | Typed logical inputs retained for Phase 12.  They are not capacity or
-- storage witnesses and no fold has run at this boundary.
data ProviderIntent
  = ObjectStoreProducerIntent ObjectStoreProducerKind Text
  | RegistryStorageProducerIntent ObjectStoreProducerKind RegistryStorageIntent
  | ObjectStoreGatewayIntent Text
  | StorageMigrationIntent Text
  | SchemaMigrationIntent Text
  | PatroniSqlIntent Text
  | ObservabilityIntent Text
  | GenericCapabilityIntent CapabilityArm Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | Private evidence that a controller descriptor expanded a particular
-- runnable exactly once.  The child is also present in the canonical set;
-- this envelope explains that unit and is never a second capacity debit.
data ControllerChildEnvelope = ControllerChildEnvelope
  { childIdentity :: Text
  , childSourceObject :: Text
  , childExpanderVersion :: Text
  , childExecutionUnit :: BoundExecutionUnit
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype BoundExecutionSet = BoundExecutionSet
  { boundExecutionUnits :: Map Text BoundExecutionUnit
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BoundServiceSpec = BoundServiceSpec
  { boundCapabilityNeed :: CapabilityNeed
  , boundProvider :: CapabilityProvider
  , boundShape :: ServiceShape
  , boundProviderProduct :: Text
  , boundProviderGraph :: [ProviderObject]
  , boundServiceExecutions :: BoundExecutionSet
  , boundControllerChildren :: [ControllerChildEnvelope]
  , boundProviderIntents :: [ProviderIntent]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype PriorVolumeProvisionRef = PriorVolumeProvisionRef Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

newtype PriorRegistryProvisionRef = PriorRegistryProvisionRef Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

-- | The deployment carries only unresolved source references and bound
-- representations.  Provisioning results have no field and no constructor
-- here; Phase 12 owns that transition.
data BoundDeployment = BoundDeployment
  { boundDeploymentTransition :: ExecutionTransitionSource
  , boundDeploymentServices :: Map Text BoundServiceSpec
  , boundDeploymentExecutions :: BoundExecutionSet
  , boundDeploymentControllerExplanations :: [ControllerChildEnvelope]
  , boundPriorVolumeRef :: Maybe PriorVolumeProvisionRef
  , boundPriorRegistryRef :: Maybe PriorRegistryProvisionRef
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ExtensionName = InfernixExtension | JitMLExtension
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ExtensionDescriptor = ExtensionDescriptor
  { extensionName :: ExtensionName
  , extensionProvides :: Set CapabilityArm
  , extensionRequires :: Set CapabilityArm
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)
