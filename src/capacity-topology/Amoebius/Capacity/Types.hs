{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Capacity.Types
  ( Axis (..)
  , ResourceVector (..)
  , zeroResources
  , addResources
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
  , CandidateNodeClass (..)
  , GrowthQuota (..)
  , PlacementError (..)
  , Assignment (..)
  , MaterializedNode (..)
  , PlacementKind (..)
  , Placement (..)
  ) where

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

data ResourceVector = ResourceVector
  { resourceCpu :: Natural
  , resourceMemory :: Natural
  , resourceEphemeralStorage :: Natural
  , resourcePodSlots :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

zeroResources :: ResourceVector
zeroResources = ResourceVector 0 0 0 0

addResources :: ResourceVector -> ResourceVector -> ResourceVector
addResources left right =
  ResourceVector
    { resourceCpu = resourceCpu left + resourceCpu right
    , resourceMemory = resourceMemory left + resourceMemory right
    , resourceEphemeralStorage = resourceEphemeralStorage left + resourceEphemeralStorage right
    , resourcePodSlots = resourcePodSlots left + resourcePodSlots right
    }

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
  { storageDiskBackedBytes :: Natural
  , storagePrivateEphemeralBytes :: Natural
  , storageTmpfsInitBytes :: Natural
  , storageTmpfsAppBytes :: Natural
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

data Node = Node
  { nodeId :: Text
  , nodeHostId :: Text
  , nodeEnvironment :: HostEnvironment
  , nodeCapacity :: NodeCapacity
  , nodeTaints :: Set Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data CandidateNodeClass = CandidateNodeClass
  { candidateName :: Text
  , candidateEnvironment :: HostEnvironment
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
  = CapacityOvercommit Overcommit
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
      Just (Overcommit CpuAxis (resourceCpu required) (resourceCpu available))
  | resourceMemory required > resourceMemory available =
      Just (Overcommit MemoryAxis (resourceMemory required) (resourceMemory available))
  | resourceEphemeralStorage required > resourceEphemeralStorage available =
      Just (Overcommit EphemeralStorageAxis (resourceEphemeralStorage required) (resourceEphemeralStorage available))
  | resourcePodSlots required > resourcePodSlots available =
      Just (Overcommit PodSlotsAxis (resourcePodSlots required) (resourcePodSlots available))
  | otherwise = Nothing
