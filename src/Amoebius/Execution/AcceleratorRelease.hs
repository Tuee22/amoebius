{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Execution.AcceleratorRelease
  ( AcceleratorRelease (..)
  , ReleaseError (..)
  , validateAcceleratorRelease
  ) where

import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data AcceleratorRelease
  = OrdinaryRelease {releaseProcessAbsent :: Bool}
  | CudaRelease
      { releaseProcessAbsent :: Bool
      , releaseDeviceHoldAbsent :: Bool
      , releaseDeviceFreeVramBytes :: Natural
      , releaseRequiredVramBytes :: Natural
      }
  | MetalRelease
      { releaseProcessAbsent :: Bool
      , releaseDrainObserved :: Bool
      , releaseAllocationAbsent :: Bool
      , releaseCacheFingerprint :: Text
      , releaseExpectedCacheFingerprint :: Text
      }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ReleaseError = ProcessStillPresent | DeviceHoldStillPresent | DeviceVramNotReleased | MetalDrainMissing | MetalAllocationStillPresent | MetalCacheChanged
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

validateAcceleratorRelease :: AcceleratorRelease -> Either ReleaseError ()
validateAcceleratorRelease release = do
  if releaseProcessAbsent release then Right () else Left ProcessStillPresent
  case release of
    OrdinaryRelease {} -> Right ()
    CudaRelease _ holdAbsent free required ->
      if not holdAbsent then Left DeviceHoldStillPresent else if free < required then Left DeviceVramNotReleased else Right ()
    MetalRelease _ drained allocationAbsent cache expected ->
      if not drained then Left MetalDrainMissing
      else if not allocationAbsent then Left MetalAllocationStillPresent
      else if cache /= expected then Left MetalCacheChanged
      else Right ()
