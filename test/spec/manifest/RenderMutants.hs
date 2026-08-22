{-# LANGUAGE OverloadedStrings #-}

module RenderMutants
  ( renderMutants
  , runRenderMutant
  ) where

import Amoebius.Capacity.Types (ResourceVector (..))
import Amoebius.Capability.Types (ServiceShape (Distributed))
import Amoebius.Manifest (renderAll)
import Amoebius.Manifest.K8sObject
import BindFixtures (CapabilityFixture (..), capabilityFixtures)
import Data.List (find)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import ProvisionFixtures (provisionFixture)
import RenderGoldenProps (renderInvariantFailures)

renderMutants :: [Text]
renderMutants =
  [ "mutant_resource_projection"
  , "mutant_ephemeral_rootfs"
  , "mutant_unbounded_scratch"
  , "mutant_memory_volume_lifecycle"
  , "mutant_image_platform"
  , "mutant_durable_size"
  , "mutant_accelerator_projection"
  , "mutant_controller_projection"
  , "mutant_monitoring_projection"
  , "mutant_unhardened_pod"
  , "mutant_wild_ingress"
  , "mutant_undeclared_allow_edge"
  ]

runRenderMutant :: Text -> IO Bool
runRenderMutant mutant = pure $ case mutant of
  "mutant_monitoring_projection" -> catchesWith "resource-projection" "observability" mutateResources
  "mutant_resource_projection" -> catchesWith "resource-projection" "inferenceengine" mutateResources
  "mutant_ephemeral_rootfs" -> catchesWith "security-context" "inferenceengine" mutateRootFilesystem
  "mutant_unbounded_scratch" -> catchesWith "bounded-volumes" "inferenceengine" mutateVolumes
  "mutant_memory_volume_lifecycle" -> catchesWith "resource-projection" "inferenceengine" mutateMemory
  "mutant_image_platform" -> catchesWith "image-digest" "inferenceengine" mutateImage
  "mutant_durable_size" -> catchesWith "source-annotation" "sql" mutateSourceAnnotation
  "mutant_accelerator_projection" -> catchesWith "accelerator-claim" "inferenceengine" mutateAccelerator
  "mutant_controller_projection" -> catchesWith "controller-kind" "inferenceengine" mutateController
  "mutant_unhardened_pod" -> catchesWith "security-context" "inferenceengine" mutateSecurity
  "mutant_wild_ingress" -> catchesWith "service-exposure" "objectstore" mutateService
  "mutant_undeclared_allow_edge" -> catchesWith "network-policy-edge-set" "inferenceengine" mutatePolicy
  _ -> False

type RenderMutation = [K8sObject] -> [K8sObject]

catchesWith :: Text -> Text -> RenderMutation -> Bool
catchesWith expected slug mutation = case find ((== slug) . fixtureSlug) capabilityFixtures of
  Nothing -> False
  Just fixture -> case provisionFixture fixture (Distributed 3) of
    Left _ -> False
    Right sealed ->
      let original = renderInvariantFailures sealed (renderAll sealed)
          changed = renderInvariantFailures sealed (mutation (renderAll sealed))
       in null original && changed == [expected]

mutateResources :: RenderMutation
mutateResources = mutateFirstPod $ \pod -> pod {podResources = ResourceRequirements (ResourceVector 0 1 1 1) (ResourceVector 1 1 1 1)}
mutateRootFilesystem :: RenderMutation
mutateRootFilesystem = mutateFirstPod $ \pod -> pod {podSecurityContext = (podSecurityContext pod) {securityReadOnlyRootFilesystem = False}}
mutateVolumes :: RenderMutation
mutateVolumes = mutateFirstPod $ \pod -> pod {podVolumesBounded = False}
mutateMemory :: RenderMutation
mutateMemory = mutateFirstPod $ \pod -> pod {podResources = ResourceRequirements (ResourceVector 1 0 1 1) (ResourceVector 1 1 1 1)}
mutateImage :: RenderMutation
mutateImage = mutateFirstPod $ \pod -> pod {podImage = "mutable:latest"}
mutateAccelerator :: RenderMutation
mutateAccelerator = mutateFirst isAcceleratorPod $ \object -> case objectSpec object of
  WorkloadSpec kind pod -> object {objectSpec = WorkloadSpec kind pod {podAcceleratorClaim = Nothing}}
  _ -> object
mutateSecurity :: RenderMutation
mutateSecurity = mutateFirstPod $ \pod -> pod {podSecurityContext = SecurityContext False True True}

mutateSourceAnnotation :: RenderMutation
mutateSourceAnnotation = mutateFirst (const True) $ \object -> object {objectMetadata = (objectMetadata object) {metadataAnnotations = Map.delete "amoebius.io/source" (metadataAnnotations (objectMetadata object))}}
mutateController :: RenderMutation
mutateController = mutateFirst isWorkload $ \object -> case objectSpec object of
  WorkloadSpec DeploymentWorkload pod -> object {objectSpec = WorkloadSpec StatefulSetWorkload pod}
  WorkloadSpec _ pod -> object {objectSpec = WorkloadSpec DeploymentWorkload pod}
  _ -> object
mutateService :: RenderMutation
mutateService = mutateFirst isInternalService $ \object -> object {objectSpec = ServiceSpec DeclaredEdgeLoadBalancer}
mutatePolicy :: RenderMutation
mutatePolicy = mutateFirst isPolicy $ \object -> case objectSpec object of
  NetworkPolicySpec defaultDeny edges -> object {objectSpec = NetworkPolicySpec defaultDeny (Set.insert (DependencyEdge "undeclared" "target") edges)}
  _ -> object

mutateFirstPod :: (PodTemplate -> PodTemplate) -> RenderMutation
mutateFirstPod mutation = mutateFirst isWorkload $ \object -> case objectSpec object of
  WorkloadSpec kind pod -> object {objectSpec = WorkloadSpec kind (mutation pod)}
  _ -> object

isWorkload :: K8sObject -> Bool
isWorkload object = case objectSpec object of WorkloadSpec {} -> True; _ -> False
isAcceleratorPod :: K8sObject -> Bool
isAcceleratorPod object = case objectSpec object of WorkloadSpec _ pod -> podAcceleratorClaim pod /= Nothing; _ -> False
isInternalService :: K8sObject -> Bool
isInternalService object = objectSpec object == ServiceSpec ClusterInternal
isPolicy :: K8sObject -> Bool
isPolicy object = case objectSpec object of NetworkPolicySpec {} -> True; _ -> False

mutateFirst :: (value -> Bool) -> (value -> value) -> [value] -> [value]
mutateFirst predicate mutation objects = case objects of
  [] -> []
  first : remaining
    | predicate first -> mutation first : remaining
    | otherwise -> first : mutateFirst predicate mutation remaining
