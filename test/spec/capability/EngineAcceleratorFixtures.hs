{-# LANGUAGE OverloadedStrings #-}

module EngineAcceleratorFixtures
  ( cudaOffering
  , windowsCudaOffering
  , appleOffering
  , cpuOffering
  , baseCudaOwner
  , classCompleteCudaOwner
  , sourceMismatchCudaOwner
  , policyMismatchCudaOwner
  , invalidShardCudaOwner
  , coexistenceOvercommitCudaOwner
  , EngineNegative (..)
  , engineNegatives
  ) where

import Amoebius.Capacity.Accelerator
  ( AcceleratorDevice (AcceleratorDevice)
  , AcceleratorFamily (..)
  , AcceleratorResidencyDemand (AcceleratorResidencyDemand)
  , InterconnectRequirement (NoPeerRequirement)
  , ResidencyPlacement (..)
  , VramShardAssignment (VramShardAssignment)
  )
import Amoebius.Capability.Engine
  ( CudaOwnerDemand (..)
  , EngineCoexistencePolicy (EngineCoexistencePolicy)
  , EngineFamily (..)
  , EngineOwnerDemand (..)
  , EngineProvisionError
  , EngineWorkloadClass (..)
  , ProvisionedEngineAccelerator
  , TargetOffering (..)
  , provisionEngineOwner
  )
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)

cudaDeviceA, cudaDeviceB, metalDevice :: AcceleratorDevice
cudaDeviceA = AcceleratorDevice "cuda-a" CudaFamily "a10" 24 4 20 (Set.singleton "cuda-b") (Set.singleton "cuda-b")
cudaDeviceB = AcceleratorDevice "cuda-b" CudaFamily "a10" 24 4 20 (Set.singleton "cuda-a") (Set.singleton "cuda-a")
metalDevice = AcceleratorDevice "metal-a" AppleMetalFamily "m3-max" 64 4 60 Set.empty Set.empty

cudaOffering, windowsCudaOffering, appleOffering, cpuOffering :: TargetOffering
cudaOffering = LinuxCudaOffering "linux-cuda-a10" (Map.fromList [("cuda-a", cudaDeviceA), ("cuda-b", cudaDeviceB)])
windowsCudaOffering = WindowsCudaOffering "windows-cuda-a10" (Map.singleton "cuda-a" cudaDeviceA)
appleOffering = AppleOffering "apple-m3-max" (Map.singleton "metal-a" metalDevice)
cpuOffering = LinuxCpuOffering "linux-cpu"

baseCudaOwner :: CudaOwnerDemand
baseCudaOwner = ownerWith (Map.singleton "model" ServedModel) (Map.singleton "model" (residency "model" ServedModel 20 Unsharded)) basePolicy

classCompleteCudaOwner :: CudaOwnerDemand
classCompleteCudaOwner =
  ownerWith
    ( Map.fromList
        [ ("serve", ServedModel)
        , ("train", TrainingJob)
        , ("jit", JitCompilation)
        , ("library", LibraryWork)
        ]
    )
    ( Map.fromList
        [ ("serve", residency "serve" ServedModel 8 Unsharded)
        , ("train", residency "train" TrainingJob 4 Unsharded)
        , ("jit", residency "jit" JitCompilation 2 Unsharded)
        , ("library", residency "library" LibraryWork 1 Unsharded)
        ]
    )
    ( EngineCoexistencePolicy
        (Map.fromList [(workloadClass, 1) | workloadClass <- [minBound .. maxBound]])
        (Map.fromList [(workloadClass, 1) | workloadClass <- [minBound .. maxBound]])
        (Map.singleton "all-classes" (Set.fromList ["serve", "train", "jit", "library"]))
    )

sourceMismatchCudaOwner :: CudaOwnerDemand
sourceMismatchCudaOwner = baseCudaOwner {cudaOwnerWorkloads = Map.empty}

policyMismatchCudaOwner :: CudaOwnerDemand
policyMismatchCudaOwner =
  baseCudaOwner
    { cudaOwnerPolicy =
        EngineCoexistencePolicy
          Map.empty
          (Map.singleton ServedModel 1)
          (Map.singleton "steady" (Set.singleton "model"))
    }

invalidShardCudaOwner :: CudaOwnerDemand
invalidShardCudaOwner =
  singleWorkload
    20
    ( Sharded
        [ VramShardAssignment "duplicate" "cuda-a" 10
        , VramShardAssignment "duplicate" "cuda-a" 10
        ]
    )

coexistenceOvercommitCudaOwner :: CudaOwnerDemand
coexistenceOvercommitCudaOwner = coexistenceOwner 12 9

data EngineNegative = EngineNegative
  { engineNegativeName :: Text
  , engineNegativeExpected :: Text
  , engineNegativeTwin :: Text
  , engineNegativeOutcome :: Either EngineProvisionError ProvisionedEngineAccelerator
  , engineNegativeTwinOutcome :: Either EngineProvisionError ProvisionedEngineAccelerator
  }

engineNegatives :: [EngineNegative]
engineNegatives =
  [ negative "illegal_engine_family_unavailable_on_lane" "EngineFamilyUnavailable" "legal_engine_family_available_on_lane" (provisionEngineOwner cpuOffering VllmFamily (CpuEngineOwner "cpu")) (provisionEngineOwner cpuOffering LlamaFamily (CpuEngineOwner "cpu"))
  , negative "illegal_cuda_on_cpu_target" "MissingCapability" "legal_cuda_on_cuda_target" (provisionEngineOwner cpuOffering LlamaFamily (CudaEngineOwner baseCudaOwner)) basePositive
  , negative "illegal_accelerator_count_shortage" "AcceleratorCountShortage" "legal_accelerator_count_exact" (cudaResult baseCudaOwner {cudaOwnerDeviceIds = Set.singleton "cuda-a", cudaOwnerDeviceCount = 2}) (cudaResult baseCudaOwner {cudaOwnerDeviceIds = Set.singleton "cuda-a", cudaOwnerDeviceCount = 1})
  , negative "illegal_accelerator_vram_shortage" "VramOvercommit" "legal_accelerator_vram_exact" (cudaResult (singleWorkload 21 Unsharded)) (cudaResult (singleWorkload 20 Unsharded))
  , negative "illegal_accelerator_source_workload_mismatch" "EngineSourceWorkloadMismatch" "legal_accelerator_source_workload_equal" (cudaResult sourceMismatchCudaOwner) basePositive
  , negative "illegal_accelerator_policy_domain_mismatch" "EnginePolicyDomainMismatch" "legal_accelerator_policy_domain_equal" (cudaResult policyMismatchCudaOwner) basePositive
  , negative "illegal_accelerator_residency_placement" "EngineResidencyPlacementInvalid" "legal_accelerator_residency_placement" (cudaResult invalidShardCudaOwner) (cudaResult (singleWorkload 20 (Sharded [VramShardAssignment "only" "cuda-a" 20])))
  , negative "illegal_accelerator_coexistence_overcommit" "AcceleratorCoexistenceOvercommit" "legal_accelerator_coexistence_exact" (cudaResult coexistenceOvercommitCudaOwner) (cudaResult (coexistenceOwner 12 8))
  ]
 where
  negative = EngineNegative
  basePositive = cudaResult baseCudaOwner

cudaResult :: CudaOwnerDemand -> Either EngineProvisionError ProvisionedEngineAccelerator
cudaResult = provisionEngineOwner cudaOffering LlamaFamily . CudaEngineOwner

ownerWith sources workloads policy =
  CudaOwnerDemand "engine-owner" "a10" (Set.singleton "cuda-a") 1 sources workloads policy

basePolicy :: EngineCoexistencePolicy
basePolicy = EngineCoexistencePolicy (Map.singleton ServedModel 1) (Map.singleton ServedModel 1) (Map.singleton "steady" (Set.singleton "model"))

singleWorkload bytes placement =
  ownerWith (Map.singleton "model" ServedModel) (Map.singleton "model" (residency "model" ServedModel bytes placement)) basePolicy

coexistenceOwner leftBytes rightBytes =
  ownerWith
    (Map.fromList [("left", ServedModel), ("right", ServedModel)])
    (Map.fromList [("left", residency "left" ServedModel leftBytes Unsharded), ("right", residency "right" ServedModel rightBytes Unsharded)])
    ( EngineCoexistencePolicy
        (Map.singleton ServedModel 2)
        (Map.singleton ServedModel 2)
        ( Map.fromList
            [ ("favorable", Set.singleton "left")
            , ("together", Set.fromList ["left", "right"])
            ]
        )
    )

residency identity workloadClass bytes placement =
  AcceleratorResidencyDemand (identity <> ":residency") identity (classText workloadClass) bytes placement NoPeerRequirement

classText workloadClass = case workloadClass of
  ServedModel -> "served-model"
  TrainingJob -> "training-job"
  JitCompilation -> "jit-compilation"
  LibraryWork -> "library-work"
