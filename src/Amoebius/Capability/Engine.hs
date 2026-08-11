{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Target-offering-selected engine lanes and identity-complete owner demands.
-- Engine identities are catalog names; there is intentionally no URL form.
module Amoebius.Capability.Engine
  ( EngineLane (..)
  , EngineFamily (..)
  , TargetOffering (..)
  , offeringLane
  , offeringAccelerators
  , familyForProfile
  , familyAvailable
  , EngineWorkloadClass (..)
  , EngineCoexistencePolicy (..)
  , CudaOwnerDemand (..)
  , MetalOwnerDemand (..)
  , EngineOwnerDemand (..)
  , ProvisionedEngineAccelerator
  , provisionedEngineLane
  , provisionedEngineFamily
  , provisionedEngineCapacity
  , EngineProvisionError (..)
  , engineProvisionErrorTag
  , provisionEngineOwner
  ) where

import Amoebius.Capacity.Accelerator
  ( AcceleratorCoexistenceEpoch (AcceleratorCoexistenceEpoch)
  , AcceleratorDemand (..)
  , AcceleratorDevice (..)
  , AcceleratorError (..)
  , AcceleratorFamily (..)
  , AcceleratorOffering (AcceleratorOffering)
  , AcceleratorResidencyDemand (..)
  , ProvisionedAccelerator
  , ResidencyPlacement (..)
  , VramShardAssignment (..)
  , provisionAccelerator
  )
import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data EngineLane = AppleMetalLane | CudaLane | LinuxCpuLane
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data EngineFamily = LlamaFamily | VllmFamily | DiffusionFamily | OnnxFamily
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data TargetOffering
  = AppleOffering Text (Map Text AcceleratorDevice)
  | LinuxCpuOffering Text
  | LinuxCudaOffering Text (Map Text AcceleratorDevice)
  | WindowsCudaOffering Text (Map Text AcceleratorDevice)
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

offeringLane :: TargetOffering -> EngineLane
offeringLane offering = case offering of
  AppleOffering {} -> AppleMetalLane
  LinuxCpuOffering {} -> LinuxCpuLane
  LinuxCudaOffering {} -> CudaLane
  WindowsCudaOffering {} -> CudaLane

offeringAccelerators :: TargetOffering -> AcceleratorOffering
offeringAccelerators offering = AcceleratorOffering $ case offering of
  AppleOffering _ devices -> devices
  LinuxCpuOffering _ -> Map.empty
  LinuxCudaOffering _ devices -> devices
  WindowsCudaOffering _ devices -> devices

familyForProfile :: Text -> EngineFamily
familyForProfile profile
  | "vllm" `Text.isPrefixOf` folded = VllmFamily
  | "diffusion" `Text.isPrefixOf` folded = DiffusionFamily
  | "onnx" `Text.isPrefixOf` folded = OnnxFamily
  | otherwise = LlamaFamily
 where
  folded = Text.toLower profile

familyAvailable :: EngineFamily -> EngineLane -> Bool
familyAvailable family lane = case family of
  LlamaFamily -> True
  VllmFamily -> lane == CudaLane
  DiffusionFamily -> lane == CudaLane || lane == AppleMetalLane
  OnnxFamily -> lane == CudaLane || lane == LinuxCpuLane

data EngineWorkloadClass = ServedModel | TrainingJob | JitCompilation | LibraryWork
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data EngineCoexistencePolicy = EngineCoexistencePolicy
  { engineMaxResidentByClass :: Map EngineWorkloadClass Natural
  , engineMaxRunningByClass :: Map EngineWorkloadClass Natural
  , engineAllowedEpochs :: Map Text (Set Text)
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data CudaOwnerDemand = CudaOwnerDemand
  { cudaOwnerIdentity :: Text
  , cudaOwnerDeviceProfile :: Text
  , cudaOwnerDeviceIds :: Set Text
  , cudaOwnerDeviceCount :: Natural
  , cudaOwnerSources :: Map Text EngineWorkloadClass
  , cudaOwnerWorkloads :: Map Text AcceleratorResidencyDemand
  , cudaOwnerPolicy :: EngineCoexistencePolicy
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data MetalOwnerDemand = MetalOwnerDemand
  { metalOwnerIdentity :: Text
  , metalOwnerDeviceProfile :: Text
  , metalOwnerDeviceIds :: Set Text
  , metalOwnerSources :: Map Text EngineWorkloadClass
  , metalOwnerWorkloads :: Map Text AcceleratorResidencyDemand
  , metalOwnerPolicy :: EngineCoexistencePolicy
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data EngineOwnerDemand
  = CudaEngineOwner CudaOwnerDemand
  | MetalEngineOwner MetalOwnerDemand
  | CpuEngineOwner Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedEngineAccelerator = ProvisionedEngineAccelerator
  { provisionedEngineLane :: EngineLane
  , provisionedEngineFamily :: EngineFamily
  , provisionedEngineCapacity :: ProvisionedAccelerator
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data EngineProvisionError
  = EngineLaneMismatch EngineLane EngineLane
  | EngineFamilyUnavailable EngineFamily EngineLane
  | EngineSourceWorkloadMismatch (Set Text) (Set Text)
  | EngineSourceIdentityMismatch Text Text
  | EngineWorkloadClassMismatch Text EngineWorkloadClass Text
  | EnginePolicyDomainMismatch (Set EngineWorkloadClass) (Set EngineWorkloadClass) (Set EngineWorkloadClass)
  | EngineEpochMemberMissing Text Text
  | EngineResidencyPlacementInvalid Text
  | EngineVramOvercommit Text Natural Natural
  | EngineAcceleratorFailure AcceleratorError
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

engineProvisionErrorTag :: EngineProvisionError -> Text
engineProvisionErrorTag problem = case problem of
  EngineLaneMismatch CudaLane _ -> "MissingCapability"
  EngineLaneMismatch {} -> "EngineLaneMismatch"
  EngineFamilyUnavailable {} -> "EngineFamilyUnavailable"
  EngineSourceWorkloadMismatch {} -> "EngineSourceWorkloadMismatch"
  EngineSourceIdentityMismatch {} -> "EngineSourceIdentityMismatch"
  EngineWorkloadClassMismatch {} -> "EngineWorkloadClassMismatch"
  EnginePolicyDomainMismatch {} -> "EnginePolicyDomainMismatch"
  EngineEpochMemberMissing {} -> "EngineEpochMemberMissing"
  EngineResidencyPlacementInvalid {} -> "EngineResidencyPlacementInvalid"
  EngineVramOvercommit {} -> "VramOvercommit"
  EngineAcceleratorFailure acceleratorProblem -> acceleratorFailureTag acceleratorProblem

acceleratorFailureTag :: AcceleratorError -> Text
acceleratorFailureTag problem = case problem of
  AcceleratorFamilyAbsent {} -> "MissingCapability"
  AcceleratorDeviceCountShortage {} -> "AcceleratorCountShortage"
  AcceleratorResidencyFit {} -> "AcceleratorCoexistenceOvercommit"
  AcceleratorNetAllocatableViolation {} -> "VramOvercommit"
  AcceleratorProfileMismatch {} -> "AcceleratorProfileMismatch"
  AcceleratorSharedDevice {} -> "AcceleratorSharedDevice"
  AcceleratorDomainMismatch {} -> "AcceleratorSourceWorkloadMismatch"
  AcceleratorShardInvalid {} -> "AcceleratorResidencyPlacement"
  AcceleratorInterconnectMissing {} -> "AcceleratorInterconnectMissing"
  AcceleratorDeviceMissing {} -> "AcceleratorCountShortage"

provisionEngineOwner
  :: TargetOffering
  -> EngineFamily
  -> EngineOwnerDemand
  -> Either EngineProvisionError ProvisionedEngineAccelerator
provisionEngineOwner offering family owner = do
  let selectedLane = offeringLane offering
      requiredLane = ownerLane owner
  if selectedLane /= requiredLane
    then Left (EngineLaneMismatch requiredLane selectedLane)
    else Right ()
  if familyAvailable family selectedLane
    then Right ()
    else Left (EngineFamilyUnavailable family selectedLane)
  validateIndividualResidencies offering owner
  demand <- ownerAcceleratorDemand owner
  capacity <- mapAccelerator (provisionAccelerator (offeringAccelerators offering) demand)
  Right (ProvisionedEngineAccelerator selectedLane family capacity)

ownerLane :: EngineOwnerDemand -> EngineLane
ownerLane owner = case owner of
  CudaEngineOwner {} -> CudaLane
  MetalEngineOwner {} -> AppleMetalLane
  CpuEngineOwner {} -> LinuxCpuLane

validateIndividualResidencies :: TargetOffering -> EngineOwnerDemand -> Either EngineProvisionError ()
validateIndividualResidencies offering owner = mapM_ validate (Map.elems workloads)
 where
  AcceleratorOffering devices = offeringAccelerators offering
  workloads = case owner of
    CudaEngineOwner demand -> cudaOwnerWorkloads demand
    MetalEngineOwner demand -> metalOwnerWorkloads demand
    CpuEngineOwner _ -> Map.empty
  maximumAllocatable = foldl max 0 (fmap acceleratorAllocatableVramBytes (Map.elems devices))
  minimumAllocatable = case Map.elems devices of
    [] -> 0
    first : remaining -> foldl (\current device -> min current (acceleratorAllocatableVramBytes device)) (acceleratorAllocatableVramBytes first) remaining
  validate residency = case acceleratorResidencyPlacement residency of
    Unsharded
      | acceleratorResidencyBytes residency > maximumAllocatable ->
          Left (EngineVramOvercommit (acceleratorResidencyId residency) (acceleratorResidencyBytes residency) maximumAllocatable)
    ReplicatedPerDevice
      | acceleratorResidencyBytes residency > minimumAllocatable ->
          Left (EngineVramOvercommit (acceleratorResidencyId residency) (acceleratorResidencyBytes residency) minimumAllocatable)
    _ -> Right ()

ownerAcceleratorDemand :: EngineOwnerDemand -> Either EngineProvisionError AcceleratorDemand
ownerAcceleratorDemand owner = case owner of
  CpuEngineOwner _ -> Right NoAcceleratorDemand
  CudaEngineOwner demand ->
    checkedDemand
      (cudaOwnerIdentity demand)
      CudaFamily
      (cudaOwnerDeviceProfile demand)
      (cudaOwnerDeviceIds demand)
      (cudaOwnerDeviceCount demand)
      (cudaOwnerSources demand)
      (cudaOwnerWorkloads demand)
      (cudaOwnerPolicy demand)
  MetalEngineOwner demand ->
    checkedDemand
      (metalOwnerIdentity demand)
      AppleMetalFamily
      (metalOwnerDeviceProfile demand)
      (metalOwnerDeviceIds demand)
      1
      (metalOwnerSources demand)
      (metalOwnerWorkloads demand)
      (metalOwnerPolicy demand)

checkedDemand
  :: Text
  -> AcceleratorFamily
  -> Text
  -> Set Text
  -> Natural
  -> Map Text EngineWorkloadClass
  -> Map Text AcceleratorResidencyDemand
  -> EngineCoexistencePolicy
  -> Either EngineProvisionError AcceleratorDemand
checkedDemand owner family profile devices deviceCount sources workloads policy = do
  let sourceKeys = Map.keysSet sources
      workloadKeys = Map.keysSet workloads
      classes = Set.fromList (Map.elems sources)
      residentDomain = Map.keysSet (engineMaxResidentByClass policy)
      runningDomain = Map.keysSet (engineMaxRunningByClass policy)
  if sourceKeys /= workloadKeys
    then Left (EngineSourceWorkloadMismatch sourceKeys workloadKeys)
    else Right ()
  mapM_ (validateWorkload sources deviceCount) (Map.toList workloads)
  if classes /= residentDomain || classes /= runningDomain
    then Left (EnginePolicyDomainMismatch classes residentDomain runningDomain)
    else Right ()
  epochs <- traverse (epochFor workloads) (Map.toList (engineAllowedEpochs policy))
  Right
    AcceleratorDemand
      { acceleratorDemandOwner = owner
      , acceleratorDemandFamily = family
      , acceleratorDemandProfile = profile
      , acceleratorDemandDeviceIds = devices
      , acceleratorDemandDeviceCount = deviceCount
      , acceleratorDemandSources = sourceKeys
      , acceleratorDemandWorkloadClasses = Set.map classText classes
      , acceleratorDemandEpochs = epochs
      }

validateWorkload
  :: Map Text EngineWorkloadClass
  -> Natural
  -> (Text, AcceleratorResidencyDemand)
  -> Either EngineProvisionError ()
validateWorkload sources deviceCount (identity, residency) = do
  if acceleratorResidencySource residency /= identity
    then Left (EngineSourceIdentityMismatch identity (acceleratorResidencySource residency))
    else Right ()
  expectedClass <- case Map.lookup identity sources of
    Nothing -> Left (EngineSourceWorkloadMismatch (Map.keysSet sources) Set.empty)
    Just value -> Right value
  if acceleratorResidencyWorkloadClass residency /= classText expectedClass
    then Left (EngineWorkloadClassMismatch identity expectedClass (acceleratorResidencyWorkloadClass residency))
    else Right ()
  case acceleratorResidencyPlacement residency of
    Sharded shards
      | fromIntegral (length shards) > deviceCount -> Left (EngineResidencyPlacementInvalid (identity <> ":shard-count"))
      | Set.size (Set.fromList (fmap vramShardId shards)) /= length shards -> Left (EngineResidencyPlacementInvalid (identity <> ":shard-id"))
      | sum (fmap vramShardBytes shards) /= acceleratorResidencyBytes residency -> Left (EngineResidencyPlacementInvalid (identity <> ":shard-sum"))
      | otherwise -> Right ()
    _ -> Right ()

epochFor
  :: Map Text AcceleratorResidencyDemand
  -> (Text, Set Text)
  -> Either EngineProvisionError AcceleratorCoexistenceEpoch
epochFor workloads (epochIdentity, members) = do
  rows <- traverse lookupMember (Set.toAscList members)
  Right (AcceleratorCoexistenceEpoch epochIdentity rows)
 where
  lookupMember identity = case Map.lookup identity workloads of
    Nothing -> Left (EngineEpochMemberMissing epochIdentity identity)
    Just row -> Right row

classText :: EngineWorkloadClass -> Text
classText workloadClass = case workloadClass of
  ServedModel -> "served-model"
  TrainingJob -> "training-job"
  JitCompilation -> "jit-compilation"
  LibraryWork -> "library-work"

mapAccelerator :: Either AcceleratorError value -> Either EngineProvisionError value
mapAccelerator outcome = case outcome of
  Left problem -> Left (EngineAcceleratorFailure problem)
  Right value -> Right value
