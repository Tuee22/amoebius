{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Manifest.Types
  ( K8sObjectKind (..)
  , kubernetesKindName
  , kindFromKubernetesName
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

-- | The name a Kubernetes API server reads out of an object's @kind@ field.
--
-- This is the one site that decides it. The constructor name is not the wire
-- name -- @SecretReferenceKind@ names amoebius's reference to a @Secret@, and
-- the object a cluster receives is a @Secret@ -- so a derived spelling would be
-- wrong for exactly the case a reader would not check. The case is total, and
-- @-Werror=incomplete-patterns@ makes a new kind name itself here rather than
-- silently inheriting a spelling.
kubernetesKindName :: K8sObjectKind -> Text
kubernetesKindName kind = case kind of
  NamespaceKind -> "Namespace"
  NodeKind -> "Node"
  DeploymentKind -> "Deployment"
  StatefulSetKind -> "StatefulSet"
  DaemonSetKind -> "DaemonSet"
  JobKind -> "Job"
  ServiceKind -> "Service"
  PersistentVolumeKind -> "PersistentVolume"
  PersistentVolumeClaimKind -> "PersistentVolumeClaim"
  StorageClassKind -> "StorageClass"
  LeaseKind -> "Lease"
  ServiceAccountKind -> "ServiceAccount"
  RoleKind -> "Role"
  RoleBindingKind -> "RoleBinding"
  ClusterRoleKind -> "ClusterRole"
  ClusterRoleBindingKind -> "ClusterRoleBinding"
  NetworkPolicyKind -> "NetworkPolicy"
  HTTPRouteKind -> "HTTPRoute"
  GatewayKind -> "Gateway"
  ConfigMapKind -> "ConfigMap"
  CustomResourceDefinitionKind -> "CustomResourceDefinition"
  CustomResourceKind -> "CustomResource"
  ResourceQuotaKind -> "ResourceQuota"
  LimitRangeKind -> "LimitRange"
  ValidatingWebhookConfigurationKind -> "ValidatingWebhookConfiguration"
  MutatingWebhookConfigurationKind -> "MutatingWebhookConfiguration"
  ClusterIssuerKind -> "ClusterIssuer"
  CertificateKind -> "Certificate"
  SecretReferenceKind -> "Secret"

-- | The inverse of 'kubernetesKindName', derived from it rather than restated,
-- so the two directions cannot disagree.
kindFromKubernetesName :: Text -> Maybe K8sObjectKind
kindFromKubernetesName name =
  case [kind | kind <- [minBound .. maxBound], kubernetesKindName kind == name] of
    [kind] -> Just kind
    _ -> Nothing

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
