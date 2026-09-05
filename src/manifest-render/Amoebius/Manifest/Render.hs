{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Manifest.Render
  ( renderSourcePrivate
  , BootstrapRenderSource (..)
  , renderBootstrapSourcePrivate
  ) where

import Amoebius.Capacity.RenderSource
  ( K8sObjectIdentity (K8sObjectIdentity)
  , ProvisionedPartWitness (..)
  , ProvisionedRenderSource
  , ReconcileMode (..)
  , RenderActivation (..)
  , RenderSourceOwner (..)
  , renderSourceActivation
  , renderSourceFields
  , renderSourceIdentity
  , renderSourceOwner
  , renderSourceReconcileMode
  , renderSourceWitness
  )
import Amoebius.Capacity.Types (ResourceVector (..))
import Amoebius.Manifest.K8sObject
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)
import Text.Read (readMaybe)

-- | Package-private Phase-25 cycle-break input.  It deliberately lives in
-- the private serializer module: callers can obtain bootstrap objects only
-- through 'ProvisionedBootstrapRegistry', never through a public per-service
-- render function.
data BootstrapRenderSource = BootstrapRenderSource
  { bootstrapRenderIdentity :: K8sObjectIdentity
  , bootstrapRenderKind :: K8sObjectKind
  , bootstrapRenderNamespace :: Maybe Text
  , bootstrapRenderFields :: Map Text Text
  , bootstrapRenderSourceDigest :: Text
  }
  deriving stock (Eq, Show)

renderBootstrapSourcePrivate :: BootstrapRenderSource -> K8sObject
renderBootstrapSourcePrivate source =
  K8sObject
    { objectIdentity = bootstrapRenderIdentity source
    , objectApiVersion = apiVersionFor (bootstrapRenderKind source)
    , objectKind = bootstrapRenderKind source
    , objectMetadata =
        ObjectMetadata
          { metadataName = objectName (bootstrapRenderIdentity source)
          , metadataNamespace = bootstrapRenderNamespace source
          , metadataLabels = Map.fromList [("app.kubernetes.io/managed-by", "amoebius"), ("amoebius.io/bootstrap", "registry")]
          , metadataAnnotations = Map.singleton "amoebius.io/source-digest" (bootstrapRenderSourceDigest source)
          }
    , objectSpec = bootstrapSpec source
    , objectActivation = Immediate
    , objectReconcileMode = ServerSideApply
    }

bootstrapSpec :: BootstrapRenderSource -> ObjectSpec
bootstrapSpec source = case bootstrapRenderKind source of
  NamespaceKind -> NamespaceSpec
  ConfigMapKind -> ConfigurationSpec fields
  ServiceKind -> ServiceSpec ClusterInternal
  DeploymentKind ->
    WorkloadSpec
      DeploymentWorkload
      PodTemplate
        { podSchedulerName = "default-scheduler"
        , podNodeName = Map.lookup "node-name" fields
        , podSecurityContext = SecurityContext True True False
        , podResources = ResourceRequirements resources limits
        , podImage = Map.findWithDefault "invalid@sha256:missing" "image" fields
        , podVolumesBounded = Map.member "empty-dir-size-limit" fields || Map.lookup "role" fields == Just "mutation-proxy"
        , podAcceleratorClaim = Nothing
        }
  _ -> GlobalControlSpec fields
 where
  fields = bootstrapRenderFields source
  resources =
    ResourceVector
      (natural "cpu-request" fields)
      (natural "memory-request" fields)
      (natural "ephemeral-request" fields)
      1
  limits =
    ResourceVector
      (natural "cpu-limit" fields)
      (natural "memory-limit" fields)
      (natural "ephemeral-limit" fields)
      1

natural :: Text -> Map Text Text -> Natural
natural key fields = case Map.lookup key fields >>= readMaybe . Text.unpack of
  Just value -> value
  Nothing -> 0

renderSourcePrivate :: ProvisionedRenderSource -> K8sObject
renderSourcePrivate source =
  K8sObject
    { objectIdentity = renderSourceIdentity source
    , objectApiVersion = apiVersionFor kind
    , objectKind = kind
    , objectMetadata = metadataFor source
    , objectSpec = specFor source kind
    , objectActivation = renderSourceActivation source
    , objectReconcileMode = renderSourceReconcileMode source
    }
 where
  kind = kindFor source

kindFor :: ProvisionedRenderSource -> K8sObjectKind
kindFor source = case renderSourceWitness source of
  NamespacePart -> NamespaceKind
  CapacitySchedulerPart -> DeploymentKind
  BootstrapAddonCutoverPart -> ConfigMapKind
  ManagedCapacityAdmissionPart -> ValidatingWebhookConfigurationKind
  ServiceConfigurationPart _ -> ConfigMapKind
  ServiceEndpointPart _ -> ServiceKind
  ServicePolicyPart _ -> NetworkPolicyKind
  ServiceWorkloadPart _ -> workloadObjectKind (Map.findWithDefault "Deployment" "kind" (renderSourceFields source))

workloadObjectKind :: Text -> K8sObjectKind
workloadObjectKind raw = case raw of
  "StatefulSet" -> StatefulSetKind
  "DaemonSet" -> DaemonSetKind
  "EngineWorkload" -> DaemonSetKind
  "Job" -> JobKind
  "HostProcess" -> CustomResourceKind
  _ -> DeploymentKind

apiVersionFor :: K8sObjectKind -> String
apiVersionFor kind = case kind of
  NamespaceKind -> "v1"
  ServiceKind -> "v1"
  ConfigMapKind -> "v1"
  PersistentVolumeKind -> "v1"
  PersistentVolumeClaimKind -> "v1"
  ResourceQuotaKind -> "v1"
  LimitRangeKind -> "v1"
  SecretReferenceKind -> "v1"
  DeploymentKind -> "apps/v1"
  StatefulSetKind -> "apps/v1"
  DaemonSetKind -> "apps/v1"
  JobKind -> "batch/v1"
  NetworkPolicyKind -> "networking.k8s.io/v1"
  ValidatingWebhookConfigurationKind -> "admissionregistration.k8s.io/v1"
  MutatingWebhookConfigurationKind -> "admissionregistration.k8s.io/v1"
  LeaseKind -> "coordination.k8s.io/v1"
  HTTPRouteKind -> "gateway.networking.k8s.io/v1"
  GatewayKind -> "gateway.networking.k8s.io/v1"
  CustomResourceDefinitionKind -> "apiextensions.k8s.io/v1"
  _ -> "amoebius.io/v1"

metadataFor :: ProvisionedRenderSource -> ObjectMetadata
metadataFor source =
  ObjectMetadata
    { metadataName = objectName (renderSourceIdentity source)
          , metadataNamespace = namespaceFor (renderSourceIdentity source) (renderSourceWitness source)
    , metadataLabels = Map.fromList [("app.kubernetes.io/managed-by", "amoebius"), ("amoebius.io/owner", ownerText (renderSourceOwner source))]
    , metadataAnnotations = rendererAnnotations identity (renderSourceActivation source)
    }
 where
  K8sObjectIdentity identity = renderSourceIdentity source

namespaceFor :: K8sObjectIdentity -> ProvisionedPartWitness -> Maybe Text
namespaceFor identity witness = case witness of
  NamespacePart -> Nothing
  ManagedCapacityAdmissionPart -> Nothing
  CapacitySchedulerPart -> Just "amoebius-capacity-scheduler"
  BootstrapAddonCutoverPart -> Just "amoebius-capacity-scheduler"
  _ -> Just (capabilityNamespace identity)

capabilityNamespace :: K8sObjectIdentity -> Text
capabilityNamespace (K8sObjectIdentity identity) = case Text.takeWhile (/= '/') identity of
  "objectstore" -> "amoebius-minio"
  "secretstore" -> "amoebius-vault"
  "messagebus" -> "amoebius-pulsar"
  "sql" -> "amoebius-postgres"
  "identity" -> "amoebius-keycloak"
  "observability" -> "amoebius-observability"
  "registry" -> "amoebius-registry"
  "edge" -> "amoebius-edge"
  "inferenceengine" -> "amoebius-inference"
  capability -> "amoebius-" <> sanitize capability

specFor :: ProvisionedRenderSource -> K8sObjectKind -> ObjectSpec
specFor source kind = case kind of
  NamespaceKind -> NamespaceSpec
  DeploymentKind -> WorkloadSpec rendererDeploymentKind (podFor source)
  StatefulSetKind -> WorkloadSpec StatefulSetWorkload (podFor source)
  DaemonSetKind -> WorkloadSpec DaemonSetWorkload (podFor source)
  JobKind -> WorkloadSpec JobWorkload (podFor source)
  ServiceKind -> ServiceSpec (serviceExposure source)
  NetworkPolicyKind -> NetworkPolicySpec True (Set.singleton (dependencyEdge source))
  ConfigMapKind -> ConfigurationSpec (renderSourceFields source)
  ValidatingWebhookConfigurationKind -> GlobalControlSpec (Map.singleton "failurePolicy" "Fail")
  CustomResourceKind -> ExtensionSpec Map.empty
  _ -> GlobalControlSpec (renderSourceFields source)

podFor :: ProvisionedRenderSource -> PodTemplate
podFor source =
  PodTemplate
    { podSchedulerName = case renderSourceWitness source of CapacitySchedulerPart -> "default-scheduler"; _ -> "amoebius-capacity"
    , podNodeName = Nothing
    , podSecurityContext = rendererSecurityContext
    , podResources = rendererResources resources
    , podImage = rendererImage identity
    , podVolumesBounded = rendererVolumesBounded
    , podAcceleratorClaim = rendererAcceleratorClaim fields
    }
 where
  identity = renderSourceIdentity source
  fields = renderSourceFields source
  resources =
    ResourceVector
      (positiveNatural "cpu" fields)
      (positiveNatural "memory" fields)
      (positiveNatural "ephemeral-storage" fields)
      (positiveNatural "pod-slots" fields)

positiveNatural :: Text -> Map Text Text -> Natural
positiveNatural key fields = case Map.lookup key fields >>= readMaybe . Text.unpack of
  Just value -> max 1 value
  Nothing -> 1

serviceExposure :: ProvisionedRenderSource -> ServiceExposure
#ifdef RENDER_WILD_INGRESS_MUTANT
serviceExposure _ = DeclaredEdgeLoadBalancer
#else
serviceExposure source = case renderSourceOwner source of
  CapabilityServiceOwner "public-edge" -> DeclaredEdgeLoadBalancer
  _ -> ClusterInternal
#endif

dependencyEdge :: ProvisionedRenderSource -> DependencyEdge
#ifdef RENDER_UNDECLARED_ALLOW_EDGE_MUTANT
dependencyEdge _ = DependencyEdge "undeclared" "target"
#else
dependencyEdge source = case renderSourceOwner source of
  CapabilityServiceOwner service -> DependencyEdge service service
  DeploymentGlobalOwner -> DependencyEdge "amoebius-system" "amoebius-system"
#endif

rendererAnnotations :: Text -> RenderActivation -> Map Text Text
#ifdef RENDER_DURABLE_SIZE_MUTANT
rendererAnnotations _ activation = Map.singleton "amoebius.io/activation" (Text.pack (show activation))
#else
rendererAnnotations identity activation = Map.fromList [("amoebius.io/source", identity), ("amoebius.io/activation", Text.pack (show activation))]
#endif

rendererDeploymentKind :: WorkloadKind
#ifdef RENDER_CONTROLLER_PROJECTION_MUTANT
rendererDeploymentKind = StatefulSetWorkload
#else
rendererDeploymentKind = DeploymentWorkload
#endif

rendererSecurityContext :: SecurityContext
#ifdef RENDER_EPHEMERAL_ROOTFS_MUTANT
rendererSecurityContext = SecurityContext True False False
#elif defined(RENDER_UNHARDENED_POD_MUTANT)
rendererSecurityContext = SecurityContext False True True
#else
rendererSecurityContext = SecurityContext True True False
#endif

rendererResources :: ResourceVector -> ResourceRequirements
#if defined(RENDER_RESOURCE_PROJECTION_MUTANT) || defined(RENDER_MONITORING_PROJECTION_MUTANT)
rendererResources resources = ResourceRequirements (resources {resourceCpu = 0}) resources
#elif defined(RENDER_MEMORY_VOLUME_LIFECYCLE_MUTANT)
rendererResources resources = ResourceRequirements (resources {resourceMemory = 0}) resources
#else
rendererResources resources = ResourceRequirements resources resources
#endif

rendererImage :: K8sObjectIdentity -> Text
#ifdef RENDER_IMAGE_PLATFORM_MUTANT
rendererImage _ = "mutable:latest"
#else
rendererImage identity = "registry.amoebius.invalid/" <> objectName identity <> "@sha256:provisioned"
#endif

rendererVolumesBounded :: Bool
#ifdef RENDER_UNBOUNDED_SCRATCH_MUTANT
rendererVolumesBounded = False
#else
rendererVolumesBounded = True
#endif

rendererAcceleratorClaim :: Map Text Text -> Maybe Natural
#ifdef RENDER_ACCELERATOR_PROJECTION_MUTANT
rendererAcceleratorClaim _ = Nothing
#else
rendererAcceleratorClaim fields = if Map.lookup "kind" fields == Just "EngineWorkload" then Just 1 else Nothing
#endif

ownerText :: RenderSourceOwner -> Text
ownerText owner = case owner of
  DeploymentGlobalOwner -> "deployment-global"
  CapabilityServiceOwner service -> service

objectName :: K8sObjectIdentity -> Text
objectName (K8sObjectIdentity identity) = case reverse (Text.splitOn "/" identity) of
  [] -> sanitize identity
  name : _ -> sanitize name

sanitize :: Text -> Text
sanitize = Text.map (\character -> if character == '_' then '-' else character) . Text.toLower
