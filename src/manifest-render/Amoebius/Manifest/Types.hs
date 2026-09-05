{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Manifest.Types
  ( K8sObjectKind (..)
  , WorkloadKind (..)
  , ObjectMetadata (..)
  , SecurityContext (..)
  , ResourceRequirements (..)
  , PodTemplate (..)
  , ServiceExposure (..)
  , DependencyEdge (..)
  , ObjectSpec (..)
  ) where

import Amoebius.Capacity.Types (ResourceVector (..))
import Control.DeepSeq (NFData)
import Data.Aeson
  ( FromJSON (parseJSON)
  , ToJSON (toJSON)
  , Value
  , object
  , withObject
  , (.:)
  , (.=)
  )
import Data.Map.Strict (Map)
import Data.Set (Set)
import Data.Text (Text)
import Data.Aeson.Types (Parser)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data K8sObjectKind
  = NamespaceKind
  | NodeKind
  | DeploymentKind
  | StatefulSetKind
  | DaemonSetKind
  | JobKind
  | ServiceKind
  | PersistentVolumeKind
  | PersistentVolumeClaimKind
  | StorageClassKind
  | LeaseKind
  | ServiceAccountKind
  | RoleKind
  | RoleBindingKind
  | ClusterRoleKind
  | ClusterRoleBindingKind
  | NetworkPolicyKind
  | HTTPRouteKind
  | GatewayKind
  | ConfigMapKind
  | CustomResourceDefinitionKind
  | CustomResourceKind
  | ResourceQuotaKind
  | LimitRangeKind
  | ValidatingWebhookConfigurationKind
  | MutatingWebhookConfigurationKind
  | ClusterIssuerKind
  | CertificateKind
  | SecretReferenceKind
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data WorkloadKind = DeploymentWorkload | StatefulSetWorkload | DaemonSetWorkload | JobWorkload
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data ObjectMetadata = ObjectMetadata
  { metadataName :: Text
  , metadataNamespace :: Maybe Text
  , metadataLabels :: Map Text Text
  , metadataAnnotations :: Map Text Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

instance ToJSON ResourceRequirements where
  toJSON requirements =
    object
      [ "resourceRequests" .= resourceVectorValue (resourceRequests requirements)
      , "resourceLimits" .= resourceVectorValue (resourceLimits requirements)
      ]

instance FromJSON ResourceRequirements where
  parseJSON = withObject "ResourceRequirements" $ \fields -> do
    requests <- fields .: "resourceRequests" >>= parseResourceVector
    limits <- fields .: "resourceLimits" >>= parseResourceVector
    pure (ResourceRequirements requests limits)

resourceVectorValue :: ResourceVector -> Value
resourceVectorValue resources =
  object
    [ "resourceCpu" .= resourceCpu resources
    , "resourceMemory" .= resourceMemory resources
    , "resourceEphemeralStorage" .= resourceEphemeralStorage resources
    , "resourcePodSlots" .= resourcePodSlots resources
    ]

parseResourceVector :: Value -> Parser ResourceVector
parseResourceVector = withObject "ResourceVector" $ \fields ->
  ResourceVector
    <$> fields .: "resourceCpu"
    <*> fields .: "resourceMemory"
    <*> fields .: "resourceEphemeralStorage"
    <*> fields .: "resourcePodSlots"

data SecurityContext = SecurityContext
  { securityRunAsNonRoot :: Bool
  , securityReadOnlyRootFilesystem :: Bool
  , securityAllowPrivilegeEscalation :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data ResourceRequirements = ResourceRequirements
  { resourceRequests :: ResourceVector
  , resourceLimits :: ResourceVector
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PodTemplate = PodTemplate
  { podSchedulerName :: Text
  , podNodeName :: Maybe Text
  , podSecurityContext :: SecurityContext
  , podResources :: ResourceRequirements
  , podImage :: Text
  , podVolumesBounded :: Bool
  , podAcceleratorClaim :: Maybe Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data ServiceExposure = ClusterInternal | DeclaredEdgeLoadBalancer
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data DependencyEdge = DependencyEdge
  { dependencyFrom :: Text
  , dependencyTo :: Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)

data ObjectSpec
  = NamespaceSpec
  | WorkloadSpec WorkloadKind PodTemplate
  | ServiceSpec ServiceExposure
  | NetworkPolicySpec Bool (Set DependencyEdge)
  | ConfigurationSpec (Map Text Text)
  | GlobalControlSpec (Map Text Text)
  | SecretReferenceSpec Text Text
  | ExtensionSpec (Map Text Value)
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromJSON, NFData, ToJSON)
