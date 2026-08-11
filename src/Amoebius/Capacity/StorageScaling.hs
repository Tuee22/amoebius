{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Observe-then-plan storage scaling.  No value in this module can enact a
-- provider or retained-storage mutation.
module Amoebius.Capacity.StorageScaling
  ( ProvisionedStorageScalingEnvelope
  , ObservedStorageScalingSnapshot (..)
  , StorageScalingWitness (..)
  , StorageScalingPlan (..)
  , mkProvisionedStorageScalingEnvelope
  , planStorageScaling
  ) where

import Amoebius.Capacity.Storage (BackingId, StorageError (..))
import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ProvisionedStorageScalingEnvelope = ProvisionedStorageScalingEnvelope
  { envelopeFingerprint :: Text
  , envelopeBacking :: BackingId
  , envelopeDesiredBytes :: Natural
  , envelopeRetainedCarveCeiling :: Natural
  , envelopeProviderCeiling :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ObservedStorageScalingSnapshot = ObservedStorageScalingSnapshot
  { snapshotFingerprint :: Text
  , snapshotCurrentBytes :: Natural
  , snapshotRetainedResidualBytes :: Natural
  , snapshotProviderResidualBytes :: Natural
  , snapshotMigrationHighWaterBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data StorageScalingWitness = StorageScalingWitness
  { scalingCurrentBytes :: Natural
  , scalingDesiredBytes :: Natural
  , scalingAvailableBytes :: Natural
  , scalingMigrationHighWaterBytes :: Natural
  , scalingObservedFingerprint :: Text
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data StorageScalingPlan
  = NoStorageChange StorageScalingWitness
  | AllocateWithinRetainedCarve StorageScalingWitness
  | CreateProviderCapacity StorageScalingWitness
  | ShrinkByVerifiedMigration StorageScalingWitness
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

mkProvisionedStorageScalingEnvelope
  :: Text
  -> BackingId
  -> Natural
  -> Natural
  -> Natural
  -> Either StorageError ProvisionedStorageScalingEnvelope
mkProvisionedStorageScalingEnvelope fingerprint owner desired retainedCeiling providerCeiling
  | fingerprint == "" = Left (ScalingEnvelopeViolation "empty scaling fingerprint")
  | desired > max retainedCeiling providerCeiling = Left (ScalingEnvelopeViolation "desired bytes exceed every finite policy ceiling")
  | otherwise = Right (ProvisionedStorageScalingEnvelope fingerprint owner desired retainedCeiling providerCeiling)

planStorageScaling
  :: ProvisionedStorageScalingEnvelope
  -> ObservedStorageScalingSnapshot
  -> Either StorageError StorageScalingPlan
planStorageScaling envelope snapshot
  | envelopeFingerprint envelope /= snapshotFingerprint snapshot =
      Left (ScalingSnapshotMismatch (envelopeFingerprint envelope) (snapshotFingerprint snapshot))
  | desired == current = Right (NoStorageChange (witness 0))
  | desired < current =
      let highWaterRequired = current + desired
       in if snapshotMigrationHighWaterBytes snapshot >= highWaterRequired
            then Right (ShrinkByVerifiedMigration (witness (snapshotMigrationHighWaterBytes snapshot)))
            else Left (ScalingEnvelopeViolation "shrink migration high-water is not witnessed")
  | growth <= snapshotRetainedResidualBytes snapshot && desired <= envelopeRetainedCarveCeiling envelope =
      Right (AllocateWithinRetainedCarve (witness (snapshotRetainedResidualBytes snapshot)))
  | growth <= snapshotProviderResidualBytes snapshot && desired <= envelopeProviderCeiling envelope =
      Right (CreateProviderCapacity (witness (snapshotProviderResidualBytes snapshot)))
  | otherwise = Left (ScalingEnvelopeViolation "observed residual and quota cannot satisfy desired bytes")
 where
  desired = envelopeDesiredBytes envelope
  current = snapshotCurrentBytes snapshot
  growth = desired - current
  witness available =
    StorageScalingWitness
      { scalingCurrentBytes = current
      , scalingDesiredBytes = desired
      , scalingAvailableBytes = available
      , scalingMigrationHighWaterBytes = snapshotMigrationHighWaterBytes snapshot
      , scalingObservedFingerprint = snapshotFingerprint snapshot
      }
