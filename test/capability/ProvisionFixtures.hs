{-# LANGUAGE OverloadedStrings #-}

module ProvisionFixtures
  ( baselineCapacity
  , baselinePolicy
  , fixtureDeployment
  , fixedTopology
  , elasticFailingTopology
  , preexistingObservation
  , contextFor
  , provisionFixture
  , provisionFixtureWithPolicy
  , ProvisionNegative (..)
  , provisionNegatives
  ) where

import Amoebius.Capacity.Execution (ExecutionTransitionSource (FirstDeployment))
import Amoebius.Capacity.Accelerator
  ( AcceleratorDevice (AcceleratorDevice)
  , AcceleratorFamily (CudaFamily)
  )
import Amoebius.Capacity.Provision
  ( InfrastructureState (..)
  , ObservedInfrastructureMaterialization
  , PriorArtifactArm (..)
  , PriorArtifactWitness (..)
  , PriorProvisionCatalog (..)
  , ProvisionContext
  , ProvisionError (..)
  , ProvisionPolicy (..)
  , ProvisionTargetSupply (..)
  , ProvisionedSpec
  , TargetSupply (TargetSupply)
  , emptyPriorProvisionCatalog
  , mkProvisionContext
  , observationFromPlanningResult
  , planInfrastructure
  , provision
  , deriveInfrastructureDemand
  , infrastructureRequiredResources
  )
import Amoebius.Capacity.Types
  ( CandidateNodeClass (CandidateNodeClass)
  , CpuOvercommitPolicy (NoCpuOvercommit)
  , GrowthQuota (GrowthQuota)
  , HostEnvironment (NativeLinux)
  , Node (Node)
  , NodeCapacity (NodeCapacity)
  , ResourceVector (..)
  )
import Amoebius.Capability.Binding (assembleBoundDeployment, bind)
import Amoebius.Capability.Engine (TargetOffering (LinuxCudaOffering))
import Amoebius.Capability.Types
  ( BoundDeployment (..)
  , BoundExecutionSet (BoundExecutionSet)
  , ControllerChildEnvelope (..)
  , PriorVolumeProvisionRef (PriorVolumeProvisionRef)
  , ServiceShape (..)
  )
import Amoebius.Dsl.Topology
  ( ComputeEngine (KindEngine)
  , NodeSupply (..)
  , Topology
  , mkTopology
  )
import BindFixtures
  ( CapabilityFixture (..)
  , distributedBinding
  , singleBinding
  )
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

baselineCapacity :: ResourceVector
baselineCapacity = ResourceVector 100000 100000 100000 100000

baselinePolicy :: ProvisionPolicy
baselinePolicy =
  ProvisionPolicy
    { policyRuntimeBackingBytes = 100000
    , policyStorageBackingBytes = 100000
    , policyMonitoringWorkflowLimit = 1000
    , policyMonitoringRuleLimit = 2000
    , policyMonitoringSeriesLimit = 10000
    , policyMonitoringVolumeBytes = 100000
    , policyCudaAvailable = True
    , policyAllocatableVramBytes = 100000
    , policyTargetOffering =
        Just
          ( LinuxCudaOffering
              "phase11-cuda"
              (Map.singleton "cuda-default" (AcceleratorDevice "cuda-default" CudaFamily "cuda-default" 100004 4 100000 Set.empty Set.empty))
          )
    }

fixtureDeployment :: CapabilityFixture -> ServiceShape -> Either ProvisionError BoundDeployment
fixtureDeployment fixture shape =
  mapDecode
    ( assembleBoundDeployment
        FirstDeployment
        Nothing
        Nothing
        [bind (fixtureNeed fixture) binding]
    )
 where
  binding = case shape of
    SingleNode -> singleBinding
    Distributed _ -> distributedBinding

fixedTopology :: ResourceVector -> Either ProvisionError Topology
fixedTopology capacity = mapTopology (mkTopology KindEngine (FixedSupply (node capacity :| [])))

elasticFailingTopology :: Either ProvisionError Topology
elasticFailingTopology =
  mapTopology
    ( mkTopology
        KindEngine
        ( ElasticSupply
            []
            ( candidate :| [] )
            (GrowthQuota 4 400)
        )
    )
 where
  candidate =
    CandidateNodeClass
      "elastic"
      NativeLinux
      (NodeCapacity (ResourceVector 100 100 100 10) NoCpuOvercommit Map.empty)
      (ResourceVector 100 0 0 0)
      Set.empty
      0
      4
      100

preexistingObservation :: BoundDeployment -> Either ProvisionError ObservedInfrastructureMaterialization
preexistingObservation deployment = do
  let BoundExecutionSet units = boundDeploymentExecutions deployment
      supply =
        StandaloneRoot
          (TargetSupply InfrastructureAlreadyPresent baselineCapacity (Map.keysSet units) 7)
  planned <- planInfrastructure supply deployment
  observationFromPlanningResult planned

contextFor
  :: ProvisionPolicy
  -> PriorProvisionCatalog
  -> BoundDeployment
  -> Either ProvisionError ProvisionContext
contextFor policy catalog deployment = do
  observation <- preexistingObservation deployment
  mkProvisionContext "phase11" 2 policy catalog observation

provisionFixture :: CapabilityFixture -> ServiceShape -> Either ProvisionError ProvisionedSpec
provisionFixture = provisionFixtureWithPolicy baselinePolicy

provisionFixtureWithPolicy :: ProvisionPolicy -> CapabilityFixture -> ServiceShape -> Either ProvisionError ProvisionedSpec
provisionFixtureWithPolicy policy fixture shape = do
  deployment <- fixtureDeployment fixture shape
  context <- contextFor policy emptyPriorProvisionCatalog deployment
  topology <- fixedTopology baselineCapacity
  provision context topology deployment

data ProvisionNegative = ProvisionNegative
  { negativeName :: Text
  , negativeExpected :: Text
  , negativeTwin :: Text
  , negativeOutcome :: Either ProvisionError ProvisionedSpec
  , negativeTwinOutcome :: Either ProvisionError ProvisionedSpec
  }

provisionNegatives :: CapabilityFixture -> CapabilityFixture -> [ProvisionNegative]
provisionNegatives observabilityFixture cudaFixture =
  [ negativeWithTwin "illegal_post_bind_expansion_overcommit" "PostBindExpansionOvercommit" "legal_post_bind_expansion_exact" postBindOutcome postBindTwin
  , negativeWithTwin "illegal_monitoring_work_over_budget" "MonitoringBudgetExceeded" "legal_monitoring_work_exact" (policyOutcome observabilityFixture monitoringShort) (policyOutcome observabilityFixture monitoringExact)
  , negativeWithTwin "illegal_accelerator_vram_shortage" "VramOvercommit" "legal_accelerator_vram_exact" (policyOutcome cudaFixture vramShort) (policyOutcome cudaFixture vramExact)
  , negative "illegal_cuda_on_cpu_target" "MissingCapability" "legal_cuda_on_cuda_target" (policyOutcome cudaFixture cpuOnly)
  , negative "illegal_controller_child_unbounded" "UnknownCommitment" "legal_controller_child_bounded" controllerOutcome
  , negativeWithTwin "illegal_elastic_per_node_expansion_overcommit" "ElasticPerNodeExpansionOvercommit" "legal_elastic_per_node_expansion_exact" elasticOutcome elasticTwin
  , negativeWithTwin "illegal_prior_provision_ref_missing" "MissingPriorProvisionRef" "legal_prior_provision_ref_present" (priorOutcome Map.empty) priorTwin
  , negativeWithTwin "illegal_prior_provision_ref_stale" "StalePriorProvisionRef" "legal_prior_provision_ref_fresh" (priorOutcome (Map.singleton priorRef staleWitness)) priorTwin
  , negativeWithTwin "illegal_prior_provision_ref_wrong_generation" "WrongGenerationPriorProvisionRef" "legal_prior_provision_ref_generation" (priorOutcome (Map.singleton priorRef wrongGenerationWitness)) priorTwin
  , negativeWithTwin "illegal_prior_provision_ref_wrong_arm" "WrongArmPriorProvisionRef" "legal_prior_provision_ref_arm" (priorOutcome (Map.singleton priorRef wrongArmWitness)) priorTwin
 ]
 where
  baseline = provisionFixture cudaFixture SingleNode
  negative name expected twin outcome = ProvisionNegative name expected twin outcome baseline
  negativeWithTwin = ProvisionNegative
  deploymentResult = fixtureDeployment cudaFixture SingleNode

  policyOutcome fixture policy = do
    deployment <- fixtureDeployment fixture SingleNode
    context <- contextFor policy emptyPriorProvisionCatalog deployment
    topology <- fixedTopology baselineCapacity
    provision context topology deployment

  postBindOutcome = do
    deployment <- deploymentResult
    context <- contextFor baselinePolicy emptyPriorProvisionCatalog deployment
    topology <- fixedTopology (ResourceVector 1 100000 100000 100000)
    provision context topology deployment

  postBindTwin = do
    deployment <- deploymentResult
    context <- contextFor baselinePolicy emptyPriorProvisionCatalog deployment
    topology <- fixedTopology (infrastructureRequiredResources (deriveInfrastructureDemand deployment))
    provision context topology deployment

  monitoringShort = baselinePolicy {policyMonitoringWorkflowLimit = 0}
  monitoringExact = baselinePolicy {policyMonitoringWorkflowLimit = 1}
  vramShort = baselinePolicy {policyAllocatableVramBytes = 7}
  vramExact = baselinePolicy {policyAllocatableVramBytes = 8}
  cpuOnly = baselinePolicy {policyCudaAvailable = False}

  controllerOutcome = do
    deployment <- deploymentResult
    mutated <- mutateFirstChild deployment
    context <- contextFor baselinePolicy emptyPriorProvisionCatalog mutated
    topology <- fixedTopology baselineCapacity
    provision context topology mutated

  elasticOutcome = do
    deployment <- deploymentResult
    context <- contextFor baselinePolicy emptyPriorProvisionCatalog deployment
    topology <- elasticFailingTopology
    provision context topology deployment

  elasticTwin = do
    deployment <- deploymentResult
    context <- contextFor baselinePolicy emptyPriorProvisionCatalog deployment
    topology <- elasticPassingTopology
    provision context topology deployment

  priorRef = "prior-volume"
  freshWitness = PriorArtifactWitness priorRef "phase11" 1 PriorVolumeArm True
  staleWitness = freshWitness {priorArtifactFresh = False}
  wrongGenerationWitness = freshWitness {priorArtifactGeneration = 0}
  wrongArmWitness = freshWitness {priorArtifactArm = PriorRegistryArm}
  priorTwin = priorOutcome (Map.singleton priorRef freshWitness)
  priorOutcome volumeCatalog = do
    deployment <- deploymentResult
    let withRef = deployment {boundPriorVolumeRef = Just (PriorVolumeProvisionRef priorRef)}
        catalog = emptyPriorProvisionCatalog {priorVolumeCatalog = volumeCatalog}
    context <- contextFor baselinePolicy catalog withRef
    topology <- fixedTopology baselineCapacity
    provision context topology withRef

  elasticPassingTopology =
    mapTopology
      ( mkTopology
          KindEngine
          ( ElasticSupply
              []
              ( CandidateNodeClass
                  "elastic-exact"
                  NativeLinux
                  (NodeCapacity baselineCapacity NoCpuOvercommit Map.empty)
                  (ResourceVector 0 0 0 0)
                  Set.empty
                  0
                  4
                  100
                  :| []
              )
              (GrowthQuota 4 400)
          )
      )

node :: ResourceVector -> Node
node capacity =
  Node
    "phase11-node"
    "phase11-host"
    NativeLinux
    (NodeCapacity capacity NoCpuOvercommit Map.empty)
    Set.empty

mutateFirstChild :: BoundDeployment -> Either ProvisionError BoundDeployment
mutateFirstChild deployment = case boundDeploymentControllerExplanations deployment of
  [] -> Left (UnknownCommitment "no-controller-child")
  child : remaining ->
    Right
      deployment
        { boundDeploymentControllerExplanations =
            child {childExpanderVersion = ""} : remaining
        }

mapDecode :: Either problem value -> Either ProvisionError value
mapDecode outcome = case outcome of
  Left problem -> Left (UnknownCommitment (Text.pack (showProblem problem)))
  Right value -> Right value

mapTopology :: Either problem value -> Either ProvisionError value
mapTopology outcome = case outcome of
  Left problem -> Left (UnknownCommitment (Text.pack (showProblem problem)))
  Right value -> Right value

showProblem :: problem -> String
showProblem _ = "fixture-construction"
