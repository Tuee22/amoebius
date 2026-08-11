{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Storage.ScalingAction
  ( StorageScalingTransition (..)
  , StorageScalingAction
  , StorageScalingTokenState (..)
  , mintStorageScalingAction
  , consumeStorageScalingAction
  , storageScalingTransition
  ) where

import Control.DeepSeq (NFData)
import Control.Concurrent.Class.MonadSTM
  ( MonadSTM
  , TVar
  , atomically
  , newTVar
  , readTVar
  , writeTVar
  )
import Data.Text (Text)
import GHC.Generics (Generic)

data StorageScalingTransition
  = StorageNoChange
  | CreateRetainedCapacity
  | VerifyStorageMigration
  | CreateProviderCapacity
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data StorageScalingTokenState = Fresh | Consumed
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data StorageScalingAction m = StorageScalingAction
  { storageScalingTransition :: StorageScalingTransition
  , storageScalingFingerprint :: Text
  , storageScalingToken :: TVar m StorageScalingTokenState
  }

mintStorageScalingAction :: MonadSTM m => StorageScalingTransition -> Text -> m (StorageScalingAction m)
mintStorageScalingAction transition fingerprint =
  StorageScalingAction transition fingerprint <$> atomically (newTVar Fresh)

consumeStorageScalingAction :: MonadSTM m => Text -> StorageScalingAction m -> m Bool
consumeStorageScalingAction observed action
  | observed /= storageScalingFingerprint action = pure False
  | otherwise = atomically $ do
      state <- readTVar (storageScalingToken action)
      writeTVar (storageScalingToken action) Consumed
      pure $ case state of
        Fresh -> True
        Consumed -> False
