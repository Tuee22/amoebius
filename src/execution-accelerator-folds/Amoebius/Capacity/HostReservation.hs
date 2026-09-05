{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Zero-capable release partitions for native host reservations.  Physical
-- cache/log/artifact residents are retained until their own observed cleanup.
module Amoebius.Capacity.HostReservation
  ( HostReservationPartition (..)
  , HostReservation (..)
  , HostReservationError (..)
  , mkHostReservation
  , releaseHostReservation
  ) where

import Amoebius.Capacity.Types (ResourceVector (..), addResources, zeroResources)
import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data HostReservationPartition = HostReservationPartition
  { partitionCompute :: ResourceVector
  , partitionCacheBytes :: Natural
  , partitionLogBytes :: Natural
  , partitionArtifactBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data HostReservation = HostReservation
  { hostReservationOwner :: Text
  , hostReservationRequired :: HostReservationPartition
  , hostReservationPad :: HostReservationPartition
  , hostReservationTotal :: HostReservationPartition
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

newtype HostReservationError = HostReservationProjectionMismatch Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

mkHostReservation :: Text -> HostReservationPartition -> HostReservationPartition -> HostReservation
mkHostReservation owner required padding =
  HostReservation owner required padding (addPartition required padding)

releaseHostReservation
  :: HostReservation
  -> HostReservationPartition
  -> Either HostReservationError HostReservation
releaseHostReservation reservation retained
  | retained `within` hostReservationTotal reservation =
      Right
        reservation
          { hostReservationRequired = retained
          , hostReservationPad = zeroPartition
          , hostReservationTotal = retained
          }
  | otherwise = Left (HostReservationProjectionMismatch (hostReservationOwner reservation))

addPartition :: HostReservationPartition -> HostReservationPartition -> HostReservationPartition
addPartition left right =
  HostReservationPartition
    { partitionCompute = addResources (partitionCompute left) (partitionCompute right)
    , partitionCacheBytes = partitionCacheBytes left + partitionCacheBytes right
    , partitionLogBytes = partitionLogBytes left + partitionLogBytes right
    , partitionArtifactBytes = partitionArtifactBytes left + partitionArtifactBytes right
    }

within :: HostReservationPartition -> HostReservationPartition -> Bool
within required available =
  resourceCpu (partitionCompute required) <= resourceCpu (partitionCompute available)
    && resourceMemory (partitionCompute required) <= resourceMemory (partitionCompute available)
    && resourceEphemeralStorage (partitionCompute required) <= resourceEphemeralStorage (partitionCompute available)
    && resourcePodSlots (partitionCompute required) <= resourcePodSlots (partitionCompute available)
    && partitionCacheBytes required <= partitionCacheBytes available
    && partitionLogBytes required <= partitionLogBytes available
    && partitionArtifactBytes required <= partitionArtifactBytes available

zeroPartition :: HostReservationPartition
zeroPartition = HostReservationPartition zeroResources 0 0 0
