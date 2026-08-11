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
  "mutant_monitoring_projection" -> catchesWith "observability" mutateResources
  "mutant_resource_projection" -> catchesWith "inferenceengine" mutateResources
  "mutant_ephemeral_rootfs" -> catchesWith "inferenceengine" mutateRootFilesystem
  "mutant_unbounded_scratch" -> catchesWith "inferenceengine" mutateVolumes
  "mutant_memory_volume_lifecycle" -> catchesWith "inferenceengine" mutateMemory
  "mutant_image_platform" -> catchesWith "inferenceengine" mutateImage
  "mutant_durable_size" -> catchesWith "sql" mutateSourceAnnotation
  "mutant_accelerator_projection" -> catchesWith "inferenceengine" mutateAccelerator
  "mutant_controller_projection" -> catchesWith "inferenceengine" mutateController
  "mutant_unhardened_pod" -> catchesWith "inferenceengine" mutateSecurity
  "mutant_wild_ingress" -> catchesWith "objectstore" mutateService
  "mutant_undeclared_allow_edge" -> catchesWith "inferenceengine" mutatePolicy
  _ -> False

catchesWith slug mutation = case find ((== slug) . fixtureSlug) capabilityFixtures of
  Nothing -> False
  Just fixture -> case provisionFixture fixture (Distributed 3) of
    Left _ -> False
    Right sealed -> not (null (renderInvariantFailures sealed (mutation (renderAll sealed))))

mutateResources = mutateFirstPod $ \pod -> pod {podResources = ResourceRequirements (ResourceVector 0 1 1 1) (ResourceVector 1 1 1 1)}
mutateRootFilesystem = mutateFirstPod $ \pod -> pod {podSecurityContext = (podSecurityContext pod) {securityReadOnlyRootFilesystem = False}}
mutateVolumes = mutateFirstPod $ \pod -> pod {podVolumesBounded = False}
mutateMemory = mutateFirstPod $ \pod -> pod {podResources = ResourceRequirements (ResourceVector 1 0 1 1) (ResourceVector 1 1 1 1)}
mutateImage = mutateFirstPod $ \pod -> pod {podImage = "mutable:latest"}
mutateAccelerator = mutateFirst isAcceleratorPod $ \object -> case objectSpec object of
  WorkloadSpec kind pod -> object {objectSpec = WorkloadSpec kind pod {podAcceleratorClaim = Nothing}}
  _ -> object
mutateSecurity = mutateFirstPod $ \pod -> pod {podSecurityContext = SecurityContext False True True}

mutateSourceAnnotation = mutateFirst (const True) $ \object -> object {objectMetadata = (objectMetadata object) {metadataAnnotations = Map.delete "amoebius.io/source" (metadataAnnotations (objectMetadata object))}}
mutateController = mutateFirst isWorkload $ \object -> object {objectKind = ServiceKind}
mutateService = mutateFirst isInternalService $ \object -> object {objectSpec = ServiceSpec DeclaredEdgeLoadBalancer}
mutatePolicy = mutateFirst isPolicy $ \object -> case objectSpec object of
  NetworkPolicySpec defaultDeny edges -> object {objectSpec = NetworkPolicySpec defaultDeny (Set.insert (DependencyEdge "undeclared" "target") edges)}
  _ -> object

mutateFirstPod mutation = mutateFirst isWorkload $ \object -> case objectSpec object of
  WorkloadSpec kind pod -> object {objectSpec = WorkloadSpec kind (mutation pod)}
  _ -> object

isWorkload object = case objectSpec object of WorkloadSpec {} -> True; _ -> False
isAcceleratorPod object = case objectSpec object of WorkloadSpec _ pod -> podAcceleratorClaim pod /= Nothing; _ -> False
isInternalService object = objectSpec object == ServiceSpec ClusterInternal
isPolicy object = case objectSpec object of NetworkPolicySpec {} -> True; _ -> False

mutateFirst predicate mutation objects = case objects of
  [] -> []
  first : remaining
    | predicate first -> mutation first : remaining
    | otherwise -> first : mutateFirst predicate mutation remaining
