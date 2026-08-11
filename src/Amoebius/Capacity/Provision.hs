{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Conditional infrastructure planning and the sole whole-deployment
-- provision seal.  Every function here is pure: action receipts and observed
-- readback are values supplied by a later live interpreter.
module Amoebius.Capacity.Provision
  ( InfrastructureState (..)
  , TargetSupply (..)
  , ClusterBudget (..)
  , ProvisionTargetSupply (..)
  , InfrastructureDemand (..)
  , PlanToken (..)
  , ActionToken (..)
  , InfrastructureAction (..)
  , ProvisionedProviderActionBatch (..)
  , InfrastructurePlan (..)
  , InfrastructurePlanningResult (..)
  , ValidatedInfrastructureActionBatch
  , InfrastructureActionLedger (..)
  , emptyInfrastructureActionLedger
  , ObservedReadback (..)
  , ObservedInfrastructureMaterialization
  , observedMaterializedIdentities
  , observedMaterializedCapacity
  , planInfrastructure
  , deriveInfrastructureDemand
  , validateInfrastructurePlan
  , enactInfrastructurePlan
  , observationFromPlanningResult
  , ProvisionPolicy (..)
  , PriorArtifactArm (..)
  , PriorArtifactWitness (..)
  , PriorProvisionCatalog (..)
  , emptyPriorProvisionCatalog
  , ProvisionContext
  , mkProvisionContext
  , ProvisionedServicePart (..)
  , ProvisionedCapacitySchedulerSystem (..)
  , ProvisionedSpec
  , provisionedPlacement
  , provisionedExecution
  , provisionedRuntimeStorage
  , provisionedMonitoring
  , provisionedServiceParts
  , provisionedSchedulerSystem
  , provisionedPulumiExecution
  , provisionedRenderSources
  , provisionedEngineAccelerators
  , ProvisionError (..)
  , provisionErrorTag
  , provision
  ) where

import Amoebius.Capacity.Execution
  ( BoundExecutionInventory (BoundExecutionInventory)
  , BoundExecutionUnit (..)
  , ExecutionError (..)
  , MaterializedExecutionInstance (..)
  , PriorExecutionProvision
  , ProvisionedExecutionEpochs (..)
  , provisionExecutionEpochs
  )
import Amoebius.Capacity.Accelerator
  ( AcceleratorDevice (..)
  , AcceleratorError (..)
  , AcceleratorOffering (AcceleratorOffering)
  , AcceleratorResidencyDemand (AcceleratorResidencyDemand)
  , InterconnectRequirement (NoPeerRequirement)
  , ResidencyPlacement (Unsharded)
  )
import Amoebius.Capacity.Fold (effectiveReserved, place)
import Amoebius.Capacity.NodeLocalStorage
  ( ImageMetadataCatalog (ImageMetadataCatalog)
  , KubeletFilesystemLayout (Unified)
  , LocalBacking (LocalBacking)
  , NodeImageStorageDemand (NodeImageStorageDemand)
  , provisionNodeImageStorage
  )
import Amoebius.Capacity.PulumiExecution
  ( HostComputeError
  , MonitoringWorkBudget (MonitoringWorkBudget)
  , ProvisionedMonitoringWork
  , ProvisionedPulumiExecutionDemand
  , PulumiExecutionDemand (PulumiExecutionDemand)
  , provisionMonitoringWork
  , provisionPulumiExecution
  )
import Amoebius.Capacity.RenderSource
  ( K8sObjectIdentity (K8sObjectIdentity)
  , ProvisionedDeploymentParts (ProvisionedDeploymentParts)
  , ProvisionedPartWitness (..)
  , ProvisionedRenderSourceSet
  , ReconcileMode (..)
  , RenderSourceCandidate (..)
  , RenderSourceError
  , activationForWitness
  , ownerForWitness
  , provisionRenderSources
  )
import Amoebius.Capacity.RuntimeStorage
  ( KubeletRuntimeMetadataDemand (KubeletRuntimeMetadataDemand)
  , KubeletRuntimeMetadataModel (KubeletRuntimeMetadataModel)
  , PodRuntimeMetadataSource (PodRuntimeMetadataSource)
  , ProvisionedNodeRuntimeStorageAccounting
  , RuntimeAccountingId (PlannedExecutionSlotId)
  , RuntimeAccountingScope (PlannedEpochScope)
  , RuntimeStorageError
  , provisionNodeRuntimeStorageAccounting
  )
import Amoebius.Capacity.Storage
  ( BackingAllocationPolicy (BackingAllocationPolicy)
  , BackingId (BackingId)
  , StorageBacking (StorageBacking)
  , StorageError
  , StorageWitness
  , fitBacking
  )
import Amoebius.Capacity.Types
  ( Placement
  , PlacementError
  , ResourceVector (..)
  , Workload (..)
  , addResources
  , emptyStorageDemand
  , zeroResources
  )
import Amoebius.Capability.Types
  ( BoundDeployment (..)
  , BoundExecutionSet (BoundExecutionSet)
  , BoundServiceSpec (..)
  , CapabilityArm (..)
  , CapabilityNeed (..)
  , ControllerChildEnvelope (..)
  , EngineRuntime (..)
  , InferenceEngineNeed (..)
  , PriorRegistryProvisionRef (PriorRegistryProvisionRef)
  , PriorVolumeProvisionRef (PriorVolumeProvisionRef)
  , ProviderIntent
  , ProviderObject (..)
  , capabilityArm
  , capabilityResourceName
  )
import Amoebius.Capability.Engine
  ( CudaOwnerDemand (CudaOwnerDemand)
  , EngineCoexistencePolicy (EngineCoexistencePolicy)
  , EngineFamily
  , EngineLane (..)
  , EngineOwnerDemand (..)
  , EngineProvisionError (..)
  , EngineWorkloadClass (ServedModel)
  , MetalOwnerDemand (MetalOwnerDemand)
  , ProvisionedEngineAccelerator
  , TargetOffering (..)
  , familyForProfile
  , offeringAccelerators
  , provisionEngineOwner
  )
import Amoebius.Dsl.Topology (NodeSupply (ElasticSupply), Topology, topologySupply)
import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data InfrastructureState = InfrastructureAlreadyPresent | InfrastructureCreationRequired
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data TargetSupply = TargetSupply
  { targetSupplyState :: InfrastructureState
  , targetSupplyCapacity :: ResourceVector
  , targetSupplyIdentities :: Set Text
  , targetSupplySnapshotVersion :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ClusterBudget = ClusterBudget
  { clusterBudgetState :: InfrastructureState
  , clusterBudgetCapacity :: ResourceVector
  , clusterBudgetIdentities :: Set Text
  , clusterBudgetSnapshotVersion :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionTargetSupply = StandaloneRoot TargetSupply | ForestMember ClusterBudget
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data InfrastructureDemand = InfrastructureDemand
  { infrastructureRequiredResources :: ResourceVector
  , infrastructureRequiredIdentities :: Set Text
  , infrastructureRequiredUnits :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype PlanToken = PlanToken Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

newtype ActionToken = ActionToken Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data InfrastructureAction = InfrastructureAction
  { infrastructureActionIdentity :: Text
  , infrastructureActionResources :: ResourceVector
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedProviderActionBatch = ProvisionedProviderActionBatch
  { providerActionToken :: ActionToken
  , providerActions :: Map Text InfrastructureAction
  , providerCheckpoint :: Text
  , providerDependencies :: Map Text (Set Text)
  , providerConcurrency :: Natural
  , providerQuotaPartition :: ResourceVector
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data InfrastructurePlan = InfrastructurePlan
  { infrastructurePlanToken :: PlanToken
  , infrastructurePlanSnapshotVersion :: Natural
  , infrastructurePlanDemand :: InfrastructureDemand
  , infrastructurePlanBatch :: ProvisionedProviderActionBatch
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data InfrastructurePlanningResult
  = NoInfrastructureRequired ObservedInfrastructureMaterialization
  | InfrastructureRequired InfrastructurePlan
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ValidatedInfrastructureActionBatch = ValidatedInfrastructureActionBatch
  { validatedInfrastructurePlan :: InfrastructurePlan
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data InfrastructureActionLedger = InfrastructureActionLedger
  { consumedPlanTokens :: Set PlanToken
  , consumedActionTokens :: Set ActionToken
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

emptyInfrastructureActionLedger :: InfrastructureActionLedger
emptyInfrastructureActionLedger = InfrastructureActionLedger Set.empty Set.empty

data ObservedReadback = ObservedReadback
  { readbackIdentities :: Set Text
  , readbackCapacity :: ResourceVector
  , readbackSnapshotVersion :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data MaterializationEvidence = AlreadyMaterializedEvidence | ReceiptBoundEvidence PlanToken ActionToken
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ObservedInfrastructureMaterialization = ObservedInfrastructureMaterialization
  { observedMaterializedIdentities :: Set Text
  , observedMaterializedCapacity :: ResourceVector
  , observedMaterializedSnapshotVersion :: Natural
  , observedMaterializationEvidence :: MaterializationEvidence
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionPolicy = ProvisionPolicy
  { policyRuntimeBackingBytes :: Natural
  , policyStorageBackingBytes :: Natural
  , policyMonitoringWorkflowLimit :: Natural
  , policyMonitoringRuleLimit :: Natural
  , policyMonitoringSeriesLimit :: Natural
  , policyMonitoringVolumeBytes :: Natural
  , policyCudaAvailable :: Bool
  , policyAllocatableVramBytes :: Natural
  , policyTargetOffering :: Maybe TargetOffering
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PriorArtifactArm = PriorVolumeArm | PriorRegistryArm
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data PriorArtifactWitness = PriorArtifactWitness
  { priorArtifactRef :: Text
  , priorArtifactDeployment :: Text
  , priorArtifactGeneration :: Natural
  , priorArtifactArm :: PriorArtifactArm
  , priorArtifactFresh :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PriorProvisionCatalog = PriorProvisionCatalog
  { priorExecutionCatalog :: Map Text PriorExecutionProvision
  , priorVolumeCatalog :: Map Text PriorArtifactWitness
  , priorRegistryCatalog :: Map Text PriorArtifactWitness
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

emptyPriorProvisionCatalog :: PriorProvisionCatalog
emptyPriorProvisionCatalog = PriorProvisionCatalog Map.empty Map.empty Map.empty

data ProvisionContext = ProvisionContext
  { contextDeployment :: Text
  , contextGeneration :: Natural
  , contextObservation :: ObservedInfrastructureMaterialization
  , contextPolicy :: ProvisionPolicy
  , contextPriorCatalog :: PriorProvisionCatalog
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedServicePart = ProvisionedServicePart
  { provisionedServiceName :: Text
  , provisionedServiceArm :: CapabilityArm
  , provisionedServiceObjects :: [ProviderObject]
  , provisionedServiceIntents :: [ProviderIntent]
  , provisionedServiceStorage :: StorageWitness
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedCapacitySchedulerSystem = ProvisionedCapacitySchedulerSystem
  { schedulerSystemOwner :: Text
  , schedulerBootstrapReservations :: Natural
  , schedulerManagedAdmissionRequired :: Bool
  , schedulerLeaseIdentity :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedSpec = ProvisionedSpec
  { provisionedPlacement :: Placement
  , provisionedExecution :: ProvisionedExecutionEpochs
  , provisionedRuntimeStorage :: [ProvisionedNodeRuntimeStorageAccounting]
  , provisionedMonitoring :: Maybe ProvisionedMonitoringWork
  , provisionedServiceParts :: Map Text ProvisionedServicePart
  , provisionedSchedulerSystem :: ProvisionedCapacitySchedulerSystem
  , provisionedPulumiExecution :: ProvisionedPulumiExecutionDemand
  , provisionedRenderSources :: ProvisionedRenderSourceSet
  , provisionedEngineAccelerators :: Map Text ProvisionedEngineAccelerator
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionError
  = InfrastructureDemandExceeded ResourceVector ResourceVector
  | InfrastructureSnapshotMismatch Natural Natural
  | InfrastructurePlanReplay PlanToken
  | InfrastructureActionReplay ActionToken
  | InfrastructureReadbackMissing (Set Text) (Set Text)
  | PromisedIdentityNotObserved Text
  | PostBindExpansionOvercommit Text
  | MonitoringBudgetExceeded Natural Natural
  | VramOvercommit Natural Natural
  | MissingCapability Text
  | UnknownCommitment Text
  | ElasticPerNodeExpansionOvercommit Text
  | MissingPriorProvisionRef Text
  | StalePriorProvisionRef Text
  | WrongGenerationPriorProvisionRef Text Natural Natural
  | WrongArmPriorProvisionRef Text PriorArtifactArm PriorArtifactArm
  | PlacementProvisionFailure PlacementError
  | ExecutionProvisionFailure ExecutionError
  | RuntimeStorageProvisionFailure RuntimeStorageError
  | StorageProvisionFailure StorageError
  | HostComputeProvisionFailure HostComputeError
  | RenderSourceProvisionFailure RenderSourceError
  | EngineFamilyUnavailableAtLane EngineFamily EngineLane
  | AcceleratorCountShortage Natural Natural
  | AcceleratorSourceWorkloadMismatch Text
  | AcceleratorPolicyDomainMismatch Text
  | AcceleratorResidencyPlacement Text
  | AcceleratorCoexistenceOvercommit Text Natural Natural
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

provisionErrorTag :: ProvisionError -> Text
provisionErrorTag problem = case problem of
  InfrastructureDemandExceeded {} -> "InfrastructureDemandExceeded"
  InfrastructureSnapshotMismatch {} -> "InfrastructureSnapshotMismatch"
  InfrastructurePlanReplay {} -> "InfrastructurePlanReplay"
  InfrastructureActionReplay {} -> "InfrastructureActionReplay"
  InfrastructureReadbackMissing {} -> "InfrastructureReadbackMissing"
  PromisedIdentityNotObserved {} -> "PromisedIdentityNotObserved"
  PostBindExpansionOvercommit {} -> "PostBindExpansionOvercommit"
  MonitoringBudgetExceeded {} -> "MonitoringBudgetExceeded"
  VramOvercommit {} -> "VramOvercommit"
  MissingCapability {} -> "MissingCapability"
  UnknownCommitment {} -> "UnknownCommitment"
  ElasticPerNodeExpansionOvercommit {} -> "ElasticPerNodeExpansionOvercommit"
  MissingPriorProvisionRef {} -> "MissingPriorProvisionRef"
  StalePriorProvisionRef {} -> "StalePriorProvisionRef"
  WrongGenerationPriorProvisionRef {} -> "WrongGenerationPriorProvisionRef"
  WrongArmPriorProvisionRef {} -> "WrongArmPriorProvisionRef"
  PlacementProvisionFailure {} -> "PlacementProvisionFailure"
  ExecutionProvisionFailure {} -> "ExecutionProvisionFailure"
  RuntimeStorageProvisionFailure {} -> "RuntimeStorageProvisionFailure"
  StorageProvisionFailure {} -> "StorageProvisionFailure"
  HostComputeProvisionFailure {} -> "HostComputeProvisionFailure"
  RenderSourceProvisionFailure {} -> "RenderSourceProvisionFailure"
  EngineFamilyUnavailableAtLane {} -> "EngineFamilyUnavailable"
  AcceleratorCountShortage {} -> "AcceleratorCountShortage"
  AcceleratorSourceWorkloadMismatch {} -> "AcceleratorSourceWorkloadMismatch"
  AcceleratorPolicyDomainMismatch {} -> "AcceleratorPolicyDomainMismatch"
  AcceleratorResidencyPlacement {} -> "AcceleratorResidencyPlacement"
  AcceleratorCoexistenceOvercommit {} -> "AcceleratorCoexistenceOvercommit"

deriveInfrastructureDemand :: BoundDeployment -> InfrastructureDemand
deriveInfrastructureDemand deployment =
  InfrastructureDemand
    { infrastructureRequiredResources = foldl addResources zeroResources (fmap (effectiveReserved . executionResource) units)
    , infrastructureRequiredIdentities = Set.fromList (fmap executionUnitId units)
    , infrastructureRequiredUnits = fromIntegral (length units)
    }
 where
  BoundExecutionSet unitMap = boundDeploymentExecutions deployment
  units = Map.elems unitMap

planInfrastructure :: ProvisionTargetSupply -> BoundDeployment -> Either ProvisionError InfrastructurePlanningResult
planInfrastructure supply deployment = do
  let demand = deriveInfrastructureDemand deployment
      (state, capacity, identities, snapshot) = supplyProjection supply
  ensureResources (infrastructureRequiredResources demand) capacity
  case state of
    InfrastructureAlreadyPresent -> do
      ensureExactIdentities (infrastructureRequiredIdentities demand) identities
      Right
        ( NoInfrastructureRequired
            ObservedInfrastructureMaterialization
              { observedMaterializedIdentities = identities
              , observedMaterializedCapacity = capacity
              , observedMaterializedSnapshotVersion = snapshot
              , observedMaterializationEvidence = AlreadyMaterializedEvidence
              }
        )
    InfrastructureCreationRequired -> Right (InfrastructureRequired (mkInfrastructurePlan snapshot capacity demand))

validateInfrastructurePlan
  :: InfrastructureActionLedger
  -> Natural
  -> InfrastructurePlan
  -> Either ProvisionError ValidatedInfrastructureActionBatch
validateInfrastructurePlan ledger observedSnapshot plan
  | infrastructurePlanToken plan `Set.member` consumedPlanTokens ledger = Left (InfrastructurePlanReplay (infrastructurePlanToken plan))
  | providerActionToken batch `Set.member` consumedActionTokens ledger = Left (InfrastructureActionReplay (providerActionToken batch))
  | observedSnapshot /= infrastructurePlanSnapshotVersion plan = Left (InfrastructureSnapshotMismatch (infrastructurePlanSnapshotVersion plan) observedSnapshot)
  | Map.keysSet (providerActions batch) /= infrastructureRequiredIdentities (infrastructurePlanDemand plan) =
      Left (InfrastructureReadbackMissing (infrastructureRequiredIdentities (infrastructurePlanDemand plan)) (Map.keysSet (providerActions batch)))
  | otherwise = Right (ValidatedInfrastructureActionBatch plan)
 where
  batch = infrastructurePlanBatch plan

enactInfrastructurePlan
  :: InfrastructureActionLedger
  -> ValidatedInfrastructureActionBatch
  -> ObservedReadback
  -> Either ProvisionError (InfrastructureActionLedger, ObservedInfrastructureMaterialization)
enactInfrastructurePlan ledger validated readback = do
  let plan = validatedInfrastructurePlan validated
      batch = infrastructurePlanBatch plan
      planToken = infrastructurePlanToken plan
      actionToken = providerActionToken batch
      expected = infrastructureRequiredIdentities (infrastructurePlanDemand plan)
  if planToken `Set.member` consumedPlanTokens ledger
    then Left (InfrastructurePlanReplay planToken)
    else Right ()
  if actionToken `Set.member` consumedActionTokens ledger
    then Left (InfrastructureActionReplay actionToken)
    else Right ()
  if readbackSnapshotVersion readback /= infrastructurePlanSnapshotVersion plan
    then Left (InfrastructureSnapshotMismatch (infrastructurePlanSnapshotVersion plan) (readbackSnapshotVersion readback))
    else Right ()
  ensureExactIdentities expected (readbackIdentities readback)
  ensureResources (infrastructureRequiredResources (infrastructurePlanDemand plan)) (readbackCapacity readback)
  let updated =
        InfrastructureActionLedger
          { consumedPlanTokens = Set.insert planToken (consumedPlanTokens ledger)
          , consumedActionTokens = Set.insert actionToken (consumedActionTokens ledger)
          }
      observation =
        ObservedInfrastructureMaterialization
          { observedMaterializedIdentities = readbackIdentities readback
          , observedMaterializedCapacity = readbackCapacity readback
          , observedMaterializedSnapshotVersion = readbackSnapshotVersion readback
          , observedMaterializationEvidence = ReceiptBoundEvidence planToken actionToken
          }
  Right (updated, observation)

observationFromPlanningResult :: InfrastructurePlanningResult -> Either ProvisionError ObservedInfrastructureMaterialization
observationFromPlanningResult result = case result of
  NoInfrastructureRequired observation -> Right observation
  InfrastructureRequired plan -> Left (PromisedIdentityNotObserved (planTokenText (infrastructurePlanToken plan)))

mkProvisionContext
  :: Text
  -> Natural
  -> ProvisionPolicy
  -> PriorProvisionCatalog
  -> ObservedInfrastructureMaterialization
  -> Either ProvisionError ProvisionContext
mkProvisionContext deployment generation policy catalog observation
  | Set.null (observedMaterializedIdentities observation) = Left (PromisedIdentityNotObserved "empty-readback")
  | otherwise =
      Right
        ProvisionContext
          { contextDeployment = deployment
          , contextGeneration = generation
          , contextObservation = observation
          , contextPolicy = policy
          , contextPriorCatalog = catalog
          }

provision :: ProvisionContext -> Topology -> BoundDeployment -> Either ProvisionError ProvisionedSpec
provision context topology deployment = do
  let demand = deriveInfrastructureDemand deployment
      available = observedMaterializedCapacity (contextObservation context)
      BoundExecutionSet unitMap = boundDeploymentExecutions deployment
      units = Map.elems unitMap
  ensureResources (infrastructureRequiredResources demand) available
  ensureExactIdentities (infrastructureRequiredIdentities demand) (observedMaterializedIdentities (contextObservation context))
  validateControllerChildren deployment unitMap
  resolveArtifactRefs context deployment
  placement <- mapPlacementFor topology (place topology (fmap unitWorkload units))
  execution <- mapExecution (provisionExecutionEpochs (priorExecutionCatalog (contextPriorCatalog context)) available (BoundExecutionInventory (boundDeploymentTransition deployment) units))
  runtime <- provisionRuntime context execution
  monitoring <- provisionMonitoring context deployment
  accelerators <- provisionAccelerators context deployment
  serviceParts <- provisionServices context deployment
  pulumi <- mapHostCompute (provisionPulumiExecution (pulumiDemand demand))
  let scheduler =
        ProvisionedCapacitySchedulerSystem
          { schedulerSystemOwner = "deployment-global"
          , schedulerBootstrapReservations = infrastructureRequiredUnits demand
          , schedulerManagedAdmissionRequired = True
          , schedulerLeaseIdentity = "amoebius-capacity/lease"
          }
      candidates = renderCandidates deployment
      parts = ProvisionedDeploymentParts (Set.fromList (fmap candidateMapKey candidates)) candidates
  renderSources <- mapRenderSource (provisionRenderSources parts)
  Right
    ProvisionedSpec
      { provisionedPlacement = placement
      , provisionedExecution = execution
      , provisionedRuntimeStorage = [runtime]
      , provisionedMonitoring = monitoring
      , provisionedServiceParts = serviceParts
      , provisionedSchedulerSystem = scheduler
      , provisionedPulumiExecution = pulumi
      , provisionedRenderSources = renderSources
      , provisionedEngineAccelerators = accelerators
      }

supplyProjection :: ProvisionTargetSupply -> (InfrastructureState, ResourceVector, Set Text, Natural)
supplyProjection supply = case supply of
  StandaloneRoot target -> (targetSupplyState target, targetSupplyCapacity target, targetSupplyIdentities target, targetSupplySnapshotVersion target)
  ForestMember budget -> (clusterBudgetState budget, clusterBudgetCapacity budget, clusterBudgetIdentities budget, clusterBudgetSnapshotVersion budget)

mkInfrastructurePlan :: Natural -> ResourceVector -> InfrastructureDemand -> InfrastructurePlan
mkInfrastructurePlan snapshot capacity demand =
  InfrastructurePlan
    { infrastructurePlanToken = planToken
    , infrastructurePlanSnapshotVersion = snapshot
    , infrastructurePlanDemand = demand
    , infrastructurePlanBatch =
        ProvisionedProviderActionBatch
          { providerActionToken = actionToken
          , providerActions = Map.fromSet (\identity -> InfrastructureAction identity (perActionResources demand)) (infrastructureRequiredIdentities demand)
          , providerCheckpoint = "pulumi-checkpoint:" <> tokenBody
          , providerDependencies = Map.fromSet (const Set.empty) (infrastructureRequiredIdentities demand)
          , providerConcurrency = max 1 (min 4 (infrastructureRequiredUnits demand))
          , providerQuotaPartition = capacity
          }
    }
 where
  tokenBody = Text.intercalate ":" (Set.toAscList (infrastructureRequiredIdentities demand))
  planToken = PlanToken ("plan:" <> tokenBody)
  actionToken = ActionToken ("action:" <> tokenBody)

perActionResources :: InfrastructureDemand -> ResourceVector
perActionResources demand
  | infrastructureRequiredUnits demand == 0 = zeroResources
  | otherwise = divideResources (infrastructureRequiredUnits demand) (infrastructureRequiredResources demand)

divideResources :: Natural -> ResourceVector -> ResourceVector
divideResources divisor resources =
  ResourceVector
    { resourceCpu = resourceCpu resources `div` divisor
    , resourceMemory = resourceMemory resources `div` divisor
    , resourceEphemeralStorage = resourceEphemeralStorage resources `div` divisor
    , resourcePodSlots = resourcePodSlots resources `div` divisor
    }

ensureResources :: ResourceVector -> ResourceVector -> Either ProvisionError ()
ensureResources required available
  | resourceCpu required > resourceCpu available = exceeded
  | resourceMemory required > resourceMemory available = exceeded
  | resourceEphemeralStorage required > resourceEphemeralStorage available = exceeded
  | resourcePodSlots required > resourcePodSlots available = exceeded
  | otherwise = Right ()
 where
  exceeded = Left (InfrastructureDemandExceeded required available)

ensureExactIdentities :: Set Text -> Set Text -> Either ProvisionError ()
ensureExactIdentities expected observed = case Set.lookupMin (expected Set.\\ observed) of
  Just missing -> Left (PromisedIdentityNotObserved missing)
  Nothing
    | expected == observed -> Right ()
    | otherwise -> Left (InfrastructureReadbackMissing expected observed)

validateControllerChildren :: BoundDeployment -> Map Text BoundExecutionUnit -> Either ProvisionError ()
validateControllerChildren deployment units = mapM_ validate (boundDeploymentControllerExplanations deployment)
 where
  validate child
    | Text.null (childExpanderVersion child) = Left (UnknownCommitment (childIdentity child))
    | childSourceObject child /= childIdentity child = Left (UnknownCommitment (childIdentity child <> ":source"))
    | Map.lookup (childIdentity child) units /= Just (childExecutionUnit child) = Left (UnknownCommitment (childIdentity child <> ":unit"))
    | otherwise = Right ()

resolveArtifactRefs :: ProvisionContext -> BoundDeployment -> Either ProvisionError ()
resolveArtifactRefs context deployment = do
  case boundPriorVolumeRef deployment of
    Nothing -> Right ()
    Just (PriorVolumeProvisionRef reference) -> validateArtifactRef context PriorVolumeArm reference (priorVolumeCatalog catalog)
  case boundPriorRegistryRef deployment of
    Nothing -> Right ()
    Just (PriorRegistryProvisionRef reference) -> validateArtifactRef context PriorRegistryArm reference (priorRegistryCatalog catalog)
 where
  catalog = contextPriorCatalog context

validateArtifactRef :: ProvisionContext -> PriorArtifactArm -> Text -> Map Text PriorArtifactWitness -> Either ProvisionError ()
validateArtifactRef context expectedArm reference catalog = case Map.lookup reference catalog of
  Nothing -> Left (MissingPriorProvisionRef reference)
  Just witness
    | not (priorArtifactFresh witness) -> Left (StalePriorProvisionRef reference)
    | priorArtifactArm witness /= expectedArm -> Left (WrongArmPriorProvisionRef reference expectedArm (priorArtifactArm witness))
    | priorArtifactDeployment witness /= contextDeployment context -> Left (WrongGenerationPriorProvisionRef reference (previousGeneration context) (priorArtifactGeneration witness))
    | priorArtifactGeneration witness /= previousGeneration context -> Left (WrongGenerationPriorProvisionRef reference (previousGeneration context) (priorArtifactGeneration witness))
    | otherwise -> Right ()

previousGeneration :: ProvisionContext -> Natural
previousGeneration context = contextGeneration context - min 1 (contextGeneration context)

unitWorkload :: BoundExecutionUnit -> Workload
unitWorkload unit =
  Workload
    { workloadId = executionUnitId unit
    , workloadEnvelope = executionResource unit
    , workloadStorage = emptyStorageDemand
    , workloadAttachments = []
    , workloadTolerations = Set.empty
    , workloadAntiAffinity = Nothing
    }

provisionRuntime :: ProvisionContext -> ProvisionedExecutionEpochs -> Either ProvisionError ProvisionedNodeRuntimeStorageAccounting
provisionRuntime context execution = do
  image <- mapStorageImage (provisionNodeImageStorage imageCatalog imageDemand)
  mapRuntime
    ( provisionNodeRuntimeStorageAccounting
        runtimeModels
        scope
        (Unified (LocalBacking "node-unified" (policyRuntimeBackingBytes policy)))
        demands
        image
    )
 where
  policy = contextPolicy context
  identities = Map.keysSet (provisionedDesiredSteady execution)
  scope = PlannedEpochScope "desired" (Set.map ("planned:" <>) identities)
  demands = fmap runtimeDemand (Map.elems (provisionedDesiredSteady execution))

runtimeDemand :: MaterializedExecutionInstance -> KubeletRuntimeMetadataDemand
runtimeDemand instanceRow =
  KubeletRuntimeMetadataDemand
    (PlannedExecutionSlotId identity)
    "kubelet-v1"
    (PodRuntimeMetadataSource (Set.singleton container) (Set.singleton volume) (Set.singleton (container, volume)) (Set.singleton "cni0"))
 where
  identity = executionInstanceId instanceRow
  container = identity <> ":container"
  volume = identity <> ":volume"

runtimeModels :: Map Text KubeletRuntimeMetadataModel
runtimeModels = Map.singleton "kubelet-v1" (KubeletRuntimeMetadataModel 1 1 1 1 1 1 1)

imageCatalog :: ImageMetadataCatalog
imageCatalog = ImageMetadataCatalog Map.empty Map.empty Map.empty Map.empty Map.empty (Set.singleton "oci-v1")

imageDemand :: NodeImageStorageDemand
imageDemand = NodeImageStorageDemand "oci-v1" [] Set.empty 1 Map.empty

provisionMonitoring :: ProvisionContext -> BoundDeployment -> Either ProvisionError (Maybe ProvisionedMonitoringWork)
provisionMonitoring context deployment
  | count == 0 = Right Nothing
  | count > policyMonitoringWorkflowLimit policy = Left (MonitoringBudgetExceeded count (policyMonitoringWorkflowLimit policy))
  | rules > policyMonitoringRuleLimit policy = Left (MonitoringBudgetExceeded rules (policyMonitoringRuleLimit policy))
  | series > policyMonitoringSeriesLimit policy = Left (MonitoringBudgetExceeded series (policyMonitoringSeriesLimit policy))
  | otherwise = Just <$> mapHostCompute (provisionMonitoringWork budget)
 where
  policy = contextPolicy context
  count = sum [fromIntegral (Map.size unitMap) | service <- Map.elems (boundDeploymentServices deployment), capabilityArm (boundCapabilityNeed service) == Observability, let BoundExecutionSet unitMap = boundServiceExecutions service]
  rules = count * 2
  series = count * 10
  budget = MonitoringWorkBudget count rules series (count * 20) 1 5 10 1 1 (count * 10) (count * 5) (policyMonitoringVolumeBytes policy)

provisionAccelerators
  :: ProvisionContext
  -> BoundDeployment
  -> Either ProvisionError (Map Text ProvisionedEngineAccelerator)
provisionAccelerators context deployment = fmap Map.fromList (mapM provisionOne inferenceServices)
 where
  policy = contextPolicy context
  inferenceServices =
    [ (capabilityResourceName (boundCapabilityNeed service), inference)
    | service <- Map.elems (boundDeploymentServices deployment)
    , InferenceEngineCapabilityNeed inference <- [boundCapabilityNeed service]
    ]
  provisionOne (name, inference) = do
    offering <- selectedOffering policy
    let family = familyForProfile (inferenceProfile inference)
        owner = ownerDemandFor name (inferenceRuntime inference) offering
    checked <- mapEngine (provisionEngineOwner offering family owner)
    Right (name, checked)

selectedOffering :: ProvisionPolicy -> Either ProvisionError TargetOffering
selectedOffering policy
  | not (policyCudaAvailable policy) = Right (LinuxCpuOffering "policy-cpu-only")
  | otherwise = case policyTargetOffering policy of
      Nothing -> Left (MissingCapability "target-offering")
      Just offering -> Right (limitOfferingVram (policyAllocatableVramBytes policy) offering)

limitOfferingVram :: Natural -> TargetOffering -> TargetOffering
limitOfferingVram limit offering = case offering of
  AppleOffering identity devices -> AppleOffering identity (Map.map clamp devices)
  LinuxCpuOffering {} -> offering
  LinuxCudaOffering identity devices -> LinuxCudaOffering identity (Map.map clamp devices)
  WindowsCudaOffering identity devices -> WindowsCudaOffering identity (Map.map clamp devices)
 where
  clamp device = device {acceleratorAllocatableVramBytes = min limit (acceleratorAllocatableVramBytes device)}

ownerDemandFor :: Text -> EngineRuntime -> TargetOffering -> EngineOwnerDemand
ownerDemandFor owner runtime offering = case runtime of
  Cuda _ -> CudaEngineOwner (CudaOwnerDemand owner profile deviceIds deviceCount sources workloads policy)
  AppleMetal _ -> MetalEngineOwner (MetalOwnerDemand owner profile deviceIds sources workloads policy)
  LinuxCpu _ -> CpuEngineOwner owner
 where
  devices = case offeringAccelerators offering of
    AcceleratorOffering rows -> rows
  deviceIds = Map.keysSet devices
  deviceCount = fromIntegral (Map.size devices)
  profile = case Map.lookupMin devices of
    Nothing -> "none"
    Just (_, device) -> acceleratorDeviceProfile device
  identity = owner <> ":served-model"
  sources = Map.singleton identity ServedModel
  workloads =
    Map.singleton
      identity
      (AcceleratorResidencyDemand (identity <> ":weights-kv-activation") identity "served-model" 8 Unsharded NoPeerRequirement)
  policy = EngineCoexistencePolicy (Map.singleton ServedModel 1) (Map.singleton ServedModel 1) (Map.singleton "steady" (Set.singleton identity))

mapEngine :: Either EngineProvisionError value -> Either ProvisionError value
mapEngine outcome = case outcome of
  Right value -> Right value
  Left problem -> case problem of
    EngineLaneMismatch required observed -> Left (laneMismatch required observed)
    EngineFamilyUnavailable family lane -> Left (EngineFamilyUnavailableAtLane family lane)
    EngineSourceWorkloadMismatch expected observed -> Left (AcceleratorSourceWorkloadMismatch (Text.pack (show (expected, observed))))
    EngineSourceIdentityMismatch expected observed -> Left (AcceleratorSourceWorkloadMismatch (expected <> ":" <> observed))
    EngineWorkloadClassMismatch identity _ observed -> Left (AcceleratorSourceWorkloadMismatch (identity <> ":" <> observed))
    EnginePolicyDomainMismatch expected resident running -> Left (AcceleratorPolicyDomainMismatch (Text.pack (show (expected, resident, running))))
    EngineEpochMemberMissing epoch member -> Left (AcceleratorPolicyDomainMismatch (epoch <> ":" <> member))
    EngineResidencyPlacementInvalid identity -> Left (AcceleratorResidencyPlacement identity)
    EngineVramOvercommit _ required available -> Left (VramOvercommit required available)
    EngineAcceleratorFailure acceleratorProblem -> mapAcceleratorProvision acceleratorProblem

laneMismatch :: EngineLane -> EngineLane -> ProvisionError
laneMismatch required observed = case required of
  CudaLane -> MissingCapability "Cuda"
  AppleMetalLane -> MissingCapability "AppleMetal"
  LinuxCpuLane -> MissingCapability ("LinuxCpu:" <> Text.pack (show observed))

mapAcceleratorProvision :: AcceleratorError -> Either ProvisionError value
mapAcceleratorProvision problem = case problem of
  AcceleratorFamilyAbsent family -> Left (MissingCapability (Text.pack (show family)))
  AcceleratorDeviceCountShortage required available -> Left (AcceleratorCountShortage required available)
  AcceleratorResidencyFit identity required available -> Left (VramOvercommit required available)
  AcceleratorNetAllocatableViolation identity raw reserve available -> Left (VramOvercommit (reserve + available) raw)
  AcceleratorProfileMismatch expected observed -> Left (MissingCapability ("accelerator-profile:" <> expected <> ":" <> observed))
  AcceleratorSharedDevice device leftOwner rightOwner -> Left (AcceleratorResidencyPlacement (device <> ":" <> leftOwner <> ":" <> rightOwner))
  AcceleratorDomainMismatch axis expected observed -> Left (AcceleratorSourceWorkloadMismatch (axis <> ":" <> Text.pack (show (expected, observed))))
  AcceleratorShardInvalid identity -> Left (AcceleratorResidencyPlacement identity)
  AcceleratorInterconnectMissing device peer -> Left (MissingCapability ("accelerator-interconnect:" <> device <> ":" <> peer))
  AcceleratorDeviceMissing identity -> Left (AcceleratorCountShortage 1 0)

provisionServices :: ProvisionContext -> BoundDeployment -> Either ProvisionError (Map Text ProvisionedServicePart)
provisionServices context deployment = traverse provisionOne (boundDeploymentServices deployment)
 where
  provisionOne service = do
    let name = capabilityResourceName (boundCapabilityNeed service)
        required = fromIntegral (length (boundProviderGraph service)) * 2
        backing = StorageBacking (BackingId ("service:" <> name)) (policyStorageBackingBytes (contextPolicy context)) (BackingAllocationPolicy 0 1)
    storage <- mapStorage (fitBacking backing required)
    Right
      ProvisionedServicePart
        { provisionedServiceName = name
        , provisionedServiceArm = capabilityArm (boundCapabilityNeed service)
        , provisionedServiceObjects = boundProviderGraph service
        , provisionedServiceIntents = boundProviderIntents service
        , provisionedServiceStorage = storage
        }

pulumiDemand :: InfrastructureDemand -> PulumiExecutionDemand
pulumiDemand demand = PulumiExecutionDemand (infrastructureRequiredResources demand) [] 1 1

renderCandidates :: BoundDeployment -> [RenderSourceCandidate]
renderCandidates deployment = globalCandidates <> concatMap serviceCandidates (Map.elems (boundDeploymentServices deployment))

globalCandidates :: [RenderSourceCandidate]
globalCandidates =
  [ candidate "global/namespace" NamespacePart Map.empty ServerSideApply
  , candidate "global/capacity-scheduler" CapacitySchedulerPart Map.empty ServerSideApply
  , candidate "global/bootstrap-addon-cutover" BootstrapAddonCutoverPart Map.empty CreateBeforeDelete
  , candidate "global/managed-capacity-admission" ManagedCapacityAdmissionPart Map.empty ServerSideApply
  ]

serviceCandidates :: BoundServiceSpec -> [RenderSourceCandidate]
serviceCandidates service = fmap fromObject (boundProviderGraph service)
 where
  name = capabilityResourceName (boundCapabilityNeed service)
  BoundExecutionSet executionUnits = boundServiceExecutions service
  fromObject object =
    candidate
      (providerObjectIdentity object)
      (witnessFor name object)
      ( Map.fromList [("kind", providerObjectKind object), ("role", providerObjectRole object)]
          <> executionFields (Map.lookup (providerObjectIdentity object) executionUnits)
      )
      (if providerObjectKind object == "Job" then ReplaceOnChange else ServerSideApply)

executionFields :: Maybe BoundExecutionUnit -> Map Text Text
executionFields maybeUnit = case maybeUnit of
  Nothing -> Map.empty
  Just unit ->
    let reservedResources = effectiveReserved (executionResource unit)
     in Map.fromList
          [ ("cpu", naturalText (resourceCpu reservedResources))
          , ("memory", naturalText (resourceMemory reservedResources))
          , ("ephemeral-storage", naturalText (resourceEphemeralStorage reservedResources))
          , ("pod-slots", naturalText (resourcePodSlots reservedResources))
          , ("revision", naturalText (executionRevision unit))
          ]

naturalText :: Natural -> Text
naturalText = Text.pack . show

witnessFor :: Text -> ProviderObject -> ProvisionedPartWitness
witnessFor service object = case providerObjectRole object of
  "provider-config" -> ServiceConfigurationPart service
  "stable-endpoint" -> ServiceEndpointPart service
  "member" -> ServiceWorkloadPart service
  "bootstrap" -> ServiceWorkloadPart service
  _ -> ServicePolicyPart service

candidate :: Text -> ProvisionedPartWitness -> Map Text Text -> ReconcileMode -> RenderSourceCandidate
candidate identityText witness fields mode =
  RenderSourceCandidate key key (ownerForWitness witness) fields mode (activationForWitness witness) witness
 where
  key = K8sObjectIdentity identityText

mapPlacementFor :: Topology -> Either PlacementError value -> Either ProvisionError value
mapPlacementFor topology outcome = case outcome of
  Left problem -> case topologySupply topology of
    ElasticSupply {} -> Left (ElasticPerNodeExpansionOvercommit (Text.pack (show problem)))
    _ -> Left (PostBindExpansionOvercommit (Text.pack (show problem)))
  Right value -> Right value

mapExecution :: Either ExecutionError value -> Either ProvisionError value
mapExecution outcome = case outcome of
  Left (PriorExecutionMissing reference) -> Left (MissingPriorProvisionRef reference)
  Left problem@PriorExecutionReferenceMismatch {} -> Left (ExecutionProvisionFailure problem)
  Left problem@ExecutionIdentityMismatch {} -> Left (ExecutionProvisionFailure problem)
  Left problem@DuplicateExecutionUnit {} -> Left (ExecutionProvisionFailure problem)
  Left problem@InvalidExecutionPolicy {} -> Left (ExecutionProvisionFailure problem)
  Left problem@ExecutionOvercommit {} -> Left (PostBindExpansionOvercommit (Text.pack (show problem)))
  Right value -> Right value

mapRuntime :: Either RuntimeStorageError value -> Either ProvisionError value
mapRuntime outcome = case outcome of
  Left problem -> Left (RuntimeStorageProvisionFailure problem)
  Right value -> Right value

mapStorage :: Either StorageError value -> Either ProvisionError value
mapStorage outcome = case outcome of
  Left problem -> Left (StorageProvisionFailure problem)
  Right value -> Right value

mapStorageImage :: Either problem value -> Either ProvisionError value
mapStorageImage outcome = case outcome of
  Left _ -> Left (PostBindExpansionOvercommit "image-storage")
  Right value -> Right value

mapHostCompute :: Either HostComputeError value -> Either ProvisionError value
mapHostCompute outcome = case outcome of
  Left _ -> Left (MonitoringBudgetExceeded 1 0)
  Right value -> Right value

mapRenderSource :: Either RenderSourceError value -> Either ProvisionError value
mapRenderSource outcome = case outcome of
  Left problem -> Left (RenderSourceProvisionFailure problem)
  Right value -> Right value

planTokenText :: PlanToken -> Text
planTokenText (PlanToken value) = value
