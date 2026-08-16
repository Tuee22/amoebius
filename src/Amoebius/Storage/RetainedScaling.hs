{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Storage.RetainedScaling
  ( MigrationEnvelope (..)
  , ProvisionedStorageMigration (..)
  , MigrationError (..)
  , MigrationStep (..)
  , RetainedScalingEffect (..)
  , provisionStorageMigration
  , completeStorageMigration
  , enactRetainedScaling
  ) where

import Amoebius.Storage.ScalingAction
import Control.DeepSeq (NFData)
import Control.Concurrent.Class.MonadSTM (MonadSTM)
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data MigrationEnvelope = MigrationEnvelope
  { migrationOldBytes :: Natural
  , migrationNewBytes :: Natural
  , migrationWorkspaceBytes :: Natural
  , migrationBackingBytes :: Natural
  , migrationCopyEnvelopeFits :: Bool
  , migrationExpectedDigest :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedStorageMigration = ProvisionedStorageMigration
  { provisionedMigrationHighWater :: Natural
  , provisionedMigrationDigest :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data MigrationError
  = OldNewWorkspaceExceedsBacking Natural Natural
  | CopyJobEnvelopeExceedsHeadroom
  | ByteVerificationMismatch Text Text
  | OldExtentDeletionNotObserved
  | ProviderCapacityUnavailable
  | StaleOrConsumedStorageScalingAction
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data MigrationStep
  = CopyJobRan
  | IndependentByteVerifyPassed
  | ClaimCutOver
  | ReclaimEligible
  | NewVolumeNonceReadBack
  | OldExtentDeletionObserved
  | OldExtentRetired
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RetainedScalingEffect = NoRetainedEffect | AllocateRetainedExtent | RunVerifiedMigration
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

provisionStorageMigration :: MigrationEnvelope -> Either MigrationError ProvisionedStorageMigration
provisionStorageMigration envelope
  | highWater > migrationBackingBytes envelope = Left (OldNewWorkspaceExceedsBacking highWater (migrationBackingBytes envelope))
  | not (migrationCopyEnvelopeFits envelope) = Left CopyJobEnvelopeExceedsHeadroom
  | otherwise = Right (ProvisionedStorageMigration highWater (migrationExpectedDigest envelope))
 where
  highWater = migrationOldBytes envelope + migrationNewBytes envelope + migrationWorkspaceBytes envelope

completeStorageMigration
  :: ProvisionedStorageMigration
  -> Text
  -> Bool
  -> Either MigrationError [MigrationStep]
completeStorageMigration provisioned observedDigest deletionObserved
#ifndef RETAINED_STORAGE_FAKE_VERIFY_MUTANT
  | observedDigest /= provisionedMigrationDigest provisioned = Left (ByteVerificationMismatch (provisionedMigrationDigest provisioned) observedDigest)
#endif
#ifndef RETAINED_STORAGE_CREDIT_BEFORE_CLEANUP_MUTANT
  | not deletionObserved = Left OldExtentDeletionNotObserved
#endif
  | otherwise = Right sequenceSteps
 where
  sequenceSteps =
#ifdef RETAINED_STORAGE_CUTOVER_BEFORE_VERIFY_MUTANT
    [CopyJobRan, ClaimCutOver, ReclaimEligible, IndependentByteVerifyPassed, NewVolumeNonceReadBack, OldExtentDeletionObserved, OldExtentRetired]
#elif defined(RETAINED_STORAGE_CREDIT_BEFORE_CLEANUP_MUTANT)
    [CopyJobRan, IndependentByteVerifyPassed, ClaimCutOver, ReclaimEligible, NewVolumeNonceReadBack, OldExtentRetired, OldExtentDeletionObserved]
#else
    [CopyJobRan, IndependentByteVerifyPassed, ClaimCutOver, ReclaimEligible, NewVolumeNonceReadBack, OldExtentDeletionObserved, OldExtentRetired]
#endif

enactRetainedScaling
  :: MonadSTM m
  => Text
  -> StorageScalingAction m
  -> m (Either MigrationError RetainedScalingEffect)
enactRetainedScaling fingerprint action = case storageScalingTransition action of
  CreateProviderCapacity -> pure (Left ProviderCapacityUnavailable)
  transition -> do
    accepted <- consumeStorageScalingAction fingerprint action
    pure $ if not accepted
      then Left StaleOrConsumedStorageScalingAction
      else Right $ case transition of
        StorageNoChange -> NoRetainedEffect
        CreateRetainedCapacity -> AllocateRetainedExtent
        VerifyStorageMigration -> RunVerifiedMigration
        CreateProviderCapacity -> NoRetainedEffect
