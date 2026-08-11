{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Manifest.Authority
  ( LeaseObservation (..)
  , LeaseAction (..)
  , LeaseAuthorityError (..)
  , LeaseActionToken
  , planLeaseAction
  , consumeLeaseActionToken
  , renewalAttemptsWithinWindow
  , CapacitySchedulerSystemDemand (..)
  , SchedulerSystemAction (..)
  , SchedulerSystemAuthorityError (..)
  , SchedulerSystemActionToken
  , mintSchedulerSystemAction
  , consumeSchedulerSystemAction
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

data LeaseObservation
  = LeaseAbsent Text
  | LeasePresent
      { leaseObservedIdentity :: Text
      , leaseObservedHolder :: Text
      , leaseObservedObjectUid :: Text
      , leaseObservedResourceVersion :: Text
      }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data LeaseAction = BootstrapAcquire Text Text | HolderRenew Text Text Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data LeaseAuthorityError
  = LeaseIdentityMismatch Text Text
  | LeaseHolderMismatch Text Text
  | LeaseTokenAlreadyConsumed
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data LeaseActionToken m = LeaseActionToken LeaseAction (TVar m Bool)

planLeaseAction :: MonadSTM m => Text -> Text -> LeaseObservation -> m (Either LeaseAuthorityError (LeaseActionToken m))
planLeaseAction expectedIdentity expectedHolder observed = case observed of
  LeaseAbsent identity
    | identity == expectedIdentity -> mint (BootstrapAcquire expectedIdentity expectedHolder)
    | otherwise -> pure (Left (LeaseIdentityMismatch expectedIdentity identity))
  LeasePresent identity holder _ resourceVersion
    | identity /= expectedIdentity -> pure (Left (LeaseIdentityMismatch expectedIdentity identity))
    | holder /= expectedHolder -> pure (Left (LeaseHolderMismatch expectedHolder holder))
    | otherwise -> mint (HolderRenew expectedIdentity expectedHolder resourceVersion)
 where
  mint action = Right . LeaseActionToken action <$> atomically (newTVar False)

consumeLeaseActionToken :: MonadSTM m => LeaseActionToken m -> m (Either LeaseAuthorityError LeaseAction)
consumeLeaseActionToken (LeaseActionToken action consumed) = atomically $ do
  used <- readTVar consumed
  writeTVar consumed True
  pure $
    if used
      then Left LeaseTokenAlreadyConsumed
      else Right action

renewalAttemptsWithinWindow :: Integral count => count -> count -> count
renewalAttemptsWithinWindow window retryPeriod
  | retryPeriod <= 0 = 0
  | otherwise = (window + retryPeriod - 1) `div` retryPeriod

data CapacitySchedulerSystemDemand = CapacitySchedulerSystemDemand
  { schedulerSystemImageDigest :: Text
  , schedulerSystemNamespace :: Text
  , schedulerSystemPodLimit :: Int
  , schedulerSystemNode :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data SchedulerSystemAction = ApplyBootstrapSchedulerSystem CapacitySchedulerSystemDemand
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data SchedulerSystemAuthorityError
  = SchedulerSystemLeaseAbsent
  | SchedulerSystemLeaseHolderMismatch Text Text
  | SchedulerSystemDemandInvalid
  | SchedulerSystemTokenAlreadyConsumed
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data SchedulerSystemActionToken m = SchedulerSystemActionToken SchedulerSystemAction (TVar m Bool)

mintSchedulerSystemAction
  :: MonadSTM m
  => Text
  -> CapacitySchedulerSystemDemand
  -> LeaseObservation
  -> m (Either SchedulerSystemAuthorityError (SchedulerSystemActionToken m))
mintSchedulerSystemAction expectedHolder demand observed
  | nullText (schedulerSystemImageDigest demand)
      || nullText (schedulerSystemNamespace demand)
      || schedulerSystemPodLimit demand /= 1
      || nullText (schedulerSystemNode demand) = pure (Left SchedulerSystemDemandInvalid)
  | otherwise = case observed of
      LeaseAbsent _ -> pure (Left SchedulerSystemLeaseAbsent)
      LeasePresent _ holder _ _
        | holder /= expectedHolder -> pure (Left (SchedulerSystemLeaseHolderMismatch expectedHolder holder))
        | otherwise -> Right . SchedulerSystemActionToken (ApplyBootstrapSchedulerSystem demand) <$> atomically (newTVar False)

consumeSchedulerSystemAction
  :: MonadSTM m
  => SchedulerSystemActionToken m
  -> m (Either SchedulerSystemAuthorityError SchedulerSystemAction)
consumeSchedulerSystemAction (SchedulerSystemActionToken action consumed) = atomically $ do
  used <- readTVar consumed
  writeTVar consumed True
  pure (if used then Left SchedulerSystemTokenAlreadyConsumed else Right action)

nullText :: Text -> Bool
nullText value = value == mempty
