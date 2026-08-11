{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Single-use refinement of a storage scaling decision into cloud actions.
module Amoebius.Storage.ProviderScaling
  ( StorageScalingTransition (..)
  , CloudAction (..)
  , ScalingError (..)
  , ValidatedCloudActionBatch
  , CloudEnactment (..)
  , mkValidatedCloudActionBatch
  , validatedBatchActions
  , enactCreateProviderCapacity
  ) where

import Data.Text (Text)

data StorageScalingTransition
  = NoChange
  | AllocateWithinRetainedCarve
  | CreateProviderCapacity
  | VerifyStorageMigration
  deriving stock (Eq, Show)

data CloudAction = CreateVolume | WriteDurableCheckpoint
  deriving stock (Eq, Show)

data ScalingError
  = ScalingFingerprintEmpty
  | ScalingBatchDomainMismatch
  | ScalingObservationStale
  | ScalingBatchAlreadyConsumed
  | NonProviderTransition
  deriving stock (Eq, Show)

data ValidatedCloudActionBatch = ValidatedCloudActionBatch
  { batchFingerprint :: Text
  , batchTransition :: StorageScalingTransition
  , batchActions :: [CloudAction]
  , batchConsumed :: Bool
  }
  deriving stock (Eq, Show)

data CloudEnactment = CloudEnactment
  { enactedActions :: [CloudAction]
  , enactedReceiptFingerprint :: Text
  , enactedBatch :: ValidatedCloudActionBatch
  }
  deriving stock (Eq, Show)

mkValidatedCloudActionBatch
  :: Text
  -> StorageScalingTransition
  -> [CloudAction]
  -> Either ScalingError ValidatedCloudActionBatch
mkValidatedCloudActionBatch fingerprint transition actions
  | fingerprint == "" = Left ScalingFingerprintEmpty
  | transition == CreateProviderCapacity && actions /= exactProviderActions = Left ScalingBatchDomainMismatch
  | transition /= CreateProviderCapacity && not (null actions) = Left ScalingBatchDomainMismatch
  | otherwise = Right (ValidatedCloudActionBatch fingerprint transition actions False)

validatedBatchActions :: ValidatedCloudActionBatch -> [CloudAction]
validatedBatchActions = batchActions

enactCreateProviderCapacity
  :: Text
  -> Text
  -> ValidatedCloudActionBatch
  -> Either ScalingError CloudEnactment
enactCreateProviderCapacity observed receipt batch
#ifdef PHASE46_BYPASS_VALIDATED_BATCH_MUTANT
  = observed `seq` Right (CloudEnactment exactProviderActions receipt batch)
#else
  | batchTransition batch /= CreateProviderCapacity = Left NonProviderTransition
  | batchActions batch /= exactProviderActions = Left ScalingBatchDomainMismatch
  | batchConsumed batch = Left ScalingBatchAlreadyConsumed
  | observed /= batchFingerprint batch = Left ScalingObservationStale
  | otherwise =
      Right
        CloudEnactment
          { enactedActions = batchActions batch
          , enactedReceiptFingerprint = receipt
          , enactedBatch = batch {batchConsumed = True}
          }
#endif

exactProviderActions :: [CloudAction]
exactProviderActions = [CreateVolume, WriteDurableCheckpoint]
