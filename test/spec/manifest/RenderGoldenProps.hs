{-# LANGUAGE OverloadedStrings #-}

module RenderGoldenProps
  ( renderInvariantFailures
  , runRenderGoldenProps
  ) where

import Amoebius.Capacity.Provision (ProvisionedSpec, provisionedRenderSources)
import Amoebius.Capacity.RenderSource
  ( K8sObjectIdentity (K8sObjectIdentity)
  , ProvisionedPartWitness (..)
  , ProvisionedRenderSource
  , provisionedRenderSourceMap
  , renderSourceActivation
  , renderSourceFields
  , renderSourceIdentity
  , renderSourceReconcileMode
  , renderSourceWitness
  )
import Amoebius.Capacity.Types (ResourceVector (..))
import Amoebius.Capability.Types qualified as Capability
import Amoebius.Manifest (renderAll)
import Amoebius.Manifest.K8sObject
import BindFixtures (CapabilityFixture (..), capabilityFixtures)
import Control.Monad (unless)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import DepGraphOracle (expectedAllowEdges)
import ProvisionFixtures (provisionFixture)
import Numeric.Natural (Natural)
import Test.QuickCheck
  ( Arbitrary (arbitrary)
  , Args (chatty, maxSuccess)
  , Property
  , checkCoverage
  , chooseInt
  , counterexample
  , cover
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )
import Text.Read (readMaybe)

renderInvariantFailures :: ProvisionedSpec -> [K8sObject] -> [Text]
renderInvariantFailures sealed objects =
  domainFailures <> concatMap validateObject objects <> stageFailures <> ingressFailures
 where
  sourceMap = provisionedRenderSourceMap (provisionedRenderSources sealed)
  objectMap = Map.fromList [(objectIdentity object, object) | object <- objects]
  domainFailures =
    [ "render-domain"
    | Map.keysSet sourceMap /= Map.keysSet objectMap || Map.size objectMap /= length objects
    ]
  stageFailures =
    [ "activation-domain"
    | Set.fromList (fmap objectActivation objects) /= Set.fromList [minBound .. maxBound]
    ]
  ingressFailures = concatMap validateIngress objects

  validateObject object = case Map.lookup (objectIdentity object) sourceMap of
    Nothing -> ["unknown-object"]
    Just source ->
      identityFailures source object
        <> namespaceFailures source object
        <> apiVersionFailures source object
        <> activationFailures source object
        <> kindFailures source object
        <> specFailures source object

identityFailures :: ProvisionedRenderSource -> K8sObject -> [Text]
identityFailures source object =
  [ "source-annotation"
  | Map.lookup "amoebius.io/source" (metadataAnnotations (objectMetadata object)) /= Just rawIdentity
  ]
 where
  K8sObjectIdentity rawIdentity = renderSourceIdentity source

namespaceFailures :: ProvisionedRenderSource -> K8sObject -> [Text]
namespaceFailures source object =
  [ "namespace-projection"
  | metadataNamespace (objectMetadata object) /= expectedNamespace
  ]
 where
  expectedNamespace = case renderSourceWitness source of
    NamespacePart -> Nothing
    ManagedCapacityAdmissionPart -> Nothing
    CapacitySchedulerPart -> Just "amoebius-capacity-scheduler"
    BootstrapAddonCutoverPart -> Just "amoebius-capacity-scheduler"
    _ -> Just (expectedCapabilityNamespace (objectIdentity object))

expectedCapabilityNamespace :: K8sObjectIdentity -> Text
expectedCapabilityNamespace (K8sObjectIdentity identity) = case Text.takeWhile (/= '/') identity of
  "objectstore" -> "amoebius-minio"
  "secretstore" -> "amoebius-vault"
  "messagebus" -> "amoebius-pulsar"
  "sql" -> "amoebius-postgres"
  "identity" -> "amoebius-keycloak"
  "observability" -> "amoebius-observability"
  "registry" -> "amoebius-registry"
  "edge" -> "amoebius-edge"
  "inferenceengine" -> "amoebius-inference"
  capability -> "amoebius-" <> Text.toLower (Text.replace "_" "-" capability)

apiVersionFailures :: ProvisionedRenderSource -> K8sObject -> [Text]
apiVersionFailures source object =
  [ "api-version-projection"
  | objectApiVersion object /= expectedApiVersion (expectedKind source)
  ]

expectedApiVersion :: K8sObjectKind -> String
expectedApiVersion kind = case kind of
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

activationFailures :: ProvisionedRenderSource -> K8sObject -> [Text]
activationFailures source object =
  [ "activation" | objectActivation object /= renderSourceActivation source ]
    <> ["reconcile-mode" | objectReconcileMode object /= renderSourceReconcileMode source]

kindFailures :: ProvisionedRenderSource -> K8sObject -> [Text]
kindFailures source object = ["kind-projection" | objectKind object /= expectedKind source]

expectedKind :: ProvisionedRenderSource -> K8sObjectKind
expectedKind source = case renderSourceWitness source of
  NamespacePart -> NamespaceKind
  CapacitySchedulerPart -> DeploymentKind
  BootstrapAddonCutoverPart -> ConfigMapKind
  ManagedCapacityAdmissionPart -> ValidatingWebhookConfigurationKind
  ServiceConfigurationPart _ -> ConfigMapKind
  ServiceEndpointPart _ -> ServiceKind
  ServicePolicyPart _ -> NetworkPolicyKind
  ServiceWorkloadPart _ -> case Map.lookup "kind" (renderSourceFields source) of
    Just "StatefulSet" -> StatefulSetKind
    Just "DaemonSet" -> DaemonSetKind
    Just "EngineWorkload" -> DaemonSetKind
    Just "Job" -> JobKind
    Just "HostProcess" -> CustomResourceKind
    _ -> DeploymentKind

specFailures :: ProvisionedRenderSource -> K8sObject -> [Text]
specFailures source object = case objectSpec object of
  WorkloadSpec workloadKind pod ->
    workloadKindFailures object workloadKind
      <> podFailures source pod
  NetworkPolicySpec defaultDeny edges ->
    ["network-policy-default-deny" | not defaultDeny]
      <> ["network-policy-edge-set" | edges /= expectedAllowEdges object]
  ServiceSpec exposure -> ["service-exposure" | not (validExposure object exposure)]
  _ -> []

workloadKindFailures :: K8sObject -> WorkloadKind -> [Text]
workloadKindFailures object workloadKind =
  [ "controller-kind"
  | (objectKind object, workloadKind)
      `notElem`
        [ (DeploymentKind, DeploymentWorkload)
        , (StatefulSetKind, StatefulSetWorkload)
        , (DaemonSetKind, DaemonSetWorkload)
        , (JobKind, JobWorkload)
        ]
  ]

podFailures :: ProvisionedRenderSource -> PodTemplate -> [Text]
podFailures source pod =
  securityFailures
    <> resourceFailures
    <> schedulerFailures
    <> imageFailures
    <> volumeFailures
    <> acceleratorFailures
 where
  security = podSecurityContext pod
  securityFailures =
    [ "security-context"
    | not (securityRunAsNonRoot security)
        || not (securityReadOnlyRootFilesystem security)
        || securityAllowPrivilegeEscalation security
    ]
  ResourceRequirements requests limits = podResources pod
  expected = expectedResources (renderSourceFields source)
  resourceFailures =
    [ "resource-projection"
    | requests /= expected || limits /= expected || not (nonZeroResources requests)
    ]
  schedulerFailures =
    [ "scheduler-or-node-name"
    | podNodeName pod /= Nothing
        || podSchedulerName pod /= expectedScheduler (renderSourceWitness source)
    ]
  imageFailures = ["image-digest" | not ("@sha256:" `Text.isInfixOf` podImage pod)]
  volumeFailures = ["bounded-volumes" | not (podVolumesBounded pod)]
  acceleratorFailures =
    [ "accelerator-claim"
    | podAcceleratorClaim pod /= expectedAccelerator (renderSourceFields source)
    ]

expectedResources :: Map.Map Text Text -> ResourceVector
expectedResources fields =
  ResourceVector
    (positive "cpu")
    (positive "memory")
    (positive "ephemeral-storage")
    (positive "pod-slots")
 where
  positive key = case Map.lookup key fields >>= readMaybe . Text.unpack of
    Just value -> max 1 value
    Nothing -> 1

nonZeroResources :: ResourceVector -> Bool
nonZeroResources resources =
  resourceCpu resources > 0
    && resourceMemory resources > 0
    && resourceEphemeralStorage resources > 0
    && resourcePodSlots resources > 0

expectedScheduler :: ProvisionedPartWitness -> Text
expectedScheduler witness = case witness of
  CapacitySchedulerPart -> "default-scheduler"
  _ -> "amoebius-capacity"

expectedAccelerator :: Map.Map Text Text -> Maybe Natural
expectedAccelerator fields
  | Map.lookup "kind" fields == Just "EngineWorkload" = Just 1
  | otherwise = Nothing

validExposure :: K8sObject -> ServiceExposure -> Bool
validExposure object exposure = case exposure of
  ClusterInternal -> True
  DeclaredEdgeLoadBalancer -> Map.lookup "amoebius.io/owner" (metadataLabels (objectMetadata object)) == Just "public-edge"

validateIngress :: K8sObject -> [Text]
validateIngress object = case objectKind object of
  HTTPRouteKind -> case objectSpec object of
    ExtensionSpec fields -> ["httproute-parent" | Map.lookup "parent" fields /= Just "keycloak-gateway"]
    _ -> ["httproute-parent"]
  _ -> []

newtype GeneratedRenderCase = GeneratedRenderCase Int
  deriving stock (Show)

instance Arbitrary GeneratedRenderCase where
  arbitrary = GeneratedRenderCase <$> chooseInt (0, length capabilityFixtures * 2 - 1)

runRenderGoldenProps :: IO ()
runRenderGoldenProps = do
  result <- quickCheckWithResult stdArgs {chatty = False, maxSuccess = 1200} propLegalRender
  unless (isSuccess result) (fail ("Phase-33 render property failed: " <> show result))
  putStrLn "render-properties: TESTED sampled (9 capability arms and 2 shapes, each >=4%)"

propLegalRender :: GeneratedRenderCase -> Property
propLegalRender (GeneratedRenderCase selected) =
  checkCoverage
    $ foldr coverArm (cover 40 distributed "distributed" (cover 40 (not distributed) "single" assertion)) capabilityFixtures
 where
  fixtureIndex = selected `div` 2
  distributed = odd selected
  shape = if distributed then Capability.Distributed 3 else Capability.SingleNode
  fixture = capabilityFixtures !! fixtureIndex
  coverArm row next = cover 4 (fixtureSlug row == fixtureSlug fixture) (Text.unpack (fixtureSlug row)) next
  assertion = case provisionFixture fixture shape of
    Left problem -> counterexample (show problem) (property False)
    Right sealed ->
      let failures = renderInvariantFailures sealed (renderAll sealed)
       in counterexample (show failures) (property (null failures))
