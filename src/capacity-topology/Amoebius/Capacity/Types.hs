{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Capacity.Types
  ( Axis (..)
  , Demand (..)
  , AvailableCapacity (..)
  , Headroom (..)
  , Overcommit (..)
  , CpuOvercommitPolicy (..)
  , ResourceEnvelope
  , envelopeRequests
  , envelopeLimits
  , envelopeHeadroom
  , mkResourceEnvelope
  , exactResourceEnvelope
  , StorageDemand (..)
  , emptyStorageDemand
  , VolumeAttachment (..)
  , Workload (..)
  , HostEnvironment (..)
  , NodeCapacity (..)
  , Node (..)
  , NodeRole (..)
  , CandidateNodeClass (..)
  , GrowthQuota (..)
  , PlacementError (..)
  , Assignment (..)
  , MaterializedNode (..)
  , PlacementKind (..)
  , Placement (..)
  , firstExceeded
  , scaleQuantity
  , scaleResources
  , divideResources
  , maxResources
  , storageReservation
  ) where

import Amoebius.Capacity.Vector (ResourceVector (..), addResources, zeroResources)
import Amoebius.Vocabulary (Detected, Quantity (..), Unit (..), quantityValue)
import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Set (Set)
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data Axis
  = CpuAxis
  | MemoryAxis
  | EphemeralStorageAxis
  | PodSlotsAxis
  | CsiAttachmentsAxis Text
  | InstanceCountAxis
  | VcpuQuotaAxis
  | ClassMaximumAxis Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

newtype Demand = Demand {demandResources :: ResourceVector}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

newtype AvailableCapacity = AvailableCapacity {availableResources :: ResourceVector}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

newtype Headroom = Headroom {headroomResources :: ResourceVector}
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data Overcommit = Overcommit
  { overcommitAxis :: Axis
  , overcommitRequired :: Natural
  , overcommitAvailable :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data CpuOvercommitPolicy
  = NoCpuOvercommit
  | BoundedCpuOvercommit Natural
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ResourceEnvelope = ResourceEnvelope
  { envelopeRequests :: ResourceVector
  , envelopeLimits :: ResourceVector
  , envelopeHeadroom :: ResourceVector
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

mkResourceEnvelope :: ResourceVector -> ResourceVector -> ResourceVector -> Either PlacementError ResourceEnvelope
mkResourceEnvelope requests limits padding =
  case firstExceeded (addResources requests padding) limits of
    Just excess -> Left (InvalidResourceEnvelope excess)
    Nothing -> Right (ResourceEnvelope requests limits padding)

-- | A closed, construction-safe envelope for an exact reservation.  Binding
-- code can use this constructor without manufacturing an impossible failure
-- branch; later provisioning may still reject the reservation against supply.
exactResourceEnvelope :: ResourceVector -> ResourceEnvelope
exactResourceEnvelope resources = ResourceEnvelope resources resources zeroResources

data StorageDemand = StorageDemand
  { storageDiskBackedBytes :: Quantity 'EphemeralUnit
  , storagePrivateEphemeralBytes :: Quantity 'EphemeralUnit
  , storageTmpfsInitBytes :: Quantity 'MemoryUnit
  , storageTmpfsAppBytes :: Quantity 'MemoryUnit
  , storageTmpfsPersistsIntoApp :: Bool
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

emptyStorageDemand :: StorageDemand
emptyStorageDemand = StorageDemand 0 0 0 0 False

data VolumeAttachment = VolumeAttachment
  { attachmentDriver :: Text
  , attachmentClaim :: Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data Workload = Workload
  { workloadId :: Text
  , workloadEnvelope :: ResourceEnvelope
  , workloadStorage :: StorageDemand
  , workloadAttachments :: [VolumeAttachment]
  , workloadTolerations :: Set Text
  , workloadAntiAffinity :: Maybe Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data HostEnvironment = NativeLinux | VirtualizedLinux | ManagedAws
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data NodeCapacity = NodeCapacity
  { nodeAllocatable :: ResourceVector
  , nodeCpuOvercommit :: CpuOvercommitPolicy
  , nodeCsiAttachCapacity :: Map Text Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data NodeRole = KindWorker | Rke2Server | Rke2Agent | ManagedWorker
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data Node = Node
  { nodeId :: Text
  , nodeHostId :: Text
  , nodeEnvironment :: HostEnvironment
  , nodeCapacity :: NodeCapacity
  , nodeTaints :: Set Text
  , nodeDetected :: Detected
  , nodeRole :: NodeRole
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data CandidateNodeClass = CandidateNodeClass
  { candidateName :: Text
  , candidateEnvironment :: HostEnvironment
  , candidateDetected :: Detected
  , candidateCapacity :: NodeCapacity
  , candidatePerNodeDemand :: ResourceVector
  , candidateTaints :: Set Text
  , candidateBaseCount :: Natural
  , candidateMaxCount :: Natural
  , candidateQuotaVcpu :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data GrowthQuota = GrowthQuota
  { growthMaxInstances :: Natural
  , growthMaxVcpu :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data PlacementError
  = TaintedOnlyHost Text
  | CapacityOvercommit Overcommit
  | Unschedulable Text
  | CpuLimitPolicyExceeded Text Natural Natural
  | InvalidResourceEnvelope Overcommit
  | PodStorageUnderreserved Text Axis Natural Natural
  | GrowthQuotaExceeded Axis Natural Natural
  | CandidateClassMaximumExceeded Text Natural Natural
  | IneligibleNode Text Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data Assignment = Assignment
  { assignmentWorkload :: Text
  , assignmentNode :: Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data MaterializedNode = MaterializedNode
  { materializedNode :: Node
  , materializedClass :: Maybe Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PlacementKind = FixedPlacement | ElasticPlacement
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data Placement = Placement
  { placementKind :: PlacementKind
  , placementNodes :: [MaterializedNode]
  , placementAssignments :: [Assignment]
  , placementInstances :: Natural
  , placementVcpu :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

firstExceeded :: ResourceVector -> ResourceVector -> Maybe Overcommit
firstExceeded required available
  | resourceCpu required > resourceCpu available =
      Just (Overcommit CpuAxis (quantityValue (resourceCpu required)) (quantityValue (resourceCpu available)))
  | resourceMemory required > resourceMemory available =
      Just (Overcommit MemoryAxis (quantityValue (resourceMemory required)) (quantityValue (resourceMemory available)))
  | resourceEphemeralStorage required > resourceEphemeralStorage available =
      Just (Overcommit EphemeralStorageAxis (quantityValue (resourceEphemeralStorage required)) (quantityValue (resourceEphemeralStorage available)))
  | resourcePodSlots required > resourcePodSlots available =
      Just (Overcommit PodSlotsAxis (quantityValue (resourcePodSlots required)) (quantityValue (resourcePodSlots available)))
  | otherwise = Nothing

-- | One quantity repeated a whole number of times.
scaleQuantity :: Natural -> Quantity unit -> Quantity unit
scaleQuantity count (Quantity magnitude) = Quantity (count * magnitude)

-- | The vector repeated a whole number of times.
scaleResources :: Natural -> ResourceVector -> ResourceVector
scaleResources count resources =
  ResourceVector
    { resourceCpu = scaleQuantity count (resourceCpu resources)
    , resourceMemory = scaleQuantity count (resourceMemory resources)
    , resourceEphemeralStorage = scaleQuantity count (resourceEphemeralStorage resources)
    , resourcePodSlots = scaleQuantity count (resourcePodSlots resources)
    }

-- | The vector with every axis divided by a whole number, rounded down.
divideResources :: Natural -> ResourceVector -> ResourceVector
divideResources divisor resources =
  ResourceVector
    { resourceCpu = divideQuantity (resourceCpu resources)
    , resourceMemory = divideQuantity (resourceMemory resources)
    , resourceEphemeralStorage = divideQuantity (resourceEphemeralStorage resources)
    , resourcePodSlots = divideQuantity (resourcePodSlots resources)
    }
 where
  divideQuantity :: Quantity unit -> Quantity unit
  divideQuantity (Quantity magnitude) = Quantity (magnitude `div` divisor)

-- | The larger of two vectors on each axis.
maxResources :: ResourceVector -> ResourceVector -> ResourceVector
maxResources left right =
  ResourceVector
    { resourceCpu = max (resourceCpu left) (resourceCpu right)
    , resourceMemory = max (resourceMemory left) (resourceMemory right)
    , resourceEphemeralStorage = max (resourceEphemeralStorage left) (resourceEphemeralStorage right)
    , resourcePodSlots = max (resourcePodSlots left) (resourcePodSlots right)
    }

-- | The ephemeral storage and the memory a pod's volumes force it to request: disk-backed
-- and private ephemeral bytes against ephemeral storage, and the larger of the two tmpfs
-- volumes (their sum when the init volume persists into the app) against memory.
storageReservation :: StorageDemand -> (Quantity 'EphemeralUnit, Quantity 'MemoryUnit)
storageReservation storage =
  ( storageDiskBackedBytes storage + storagePrivateEphemeralBytes storage
  , if storageTmpfsPersistsIntoApp storage
      then storageTmpfsInitBytes storage + storageTmpfsAppBytes storage
      else max (storageTmpfsInitBytes storage) (storageTmpfsAppBytes storage)
  )
