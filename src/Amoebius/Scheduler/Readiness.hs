{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Scheduler.Readiness
  ( BootstrapSchedulerObservation (..)
  , BootstrapCapacitySchedulerReady
  , BootstrapReadinessError (..)
  , observeBootstrapCapacitySchedulerReady
  , BootstrapControllerObservation (..)
  , ManagedAuthorityReadback (..)
  , ManagedCapacityReady
  , ManagedReadinessError (..)
  , observeManagedCapacityReady
  , BootstrapAction (..)
  , authorizeBootstrapAction
  ) where

import Control.DeepSeq (NFData)
import Data.Foldable (traverse_)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Text (Text)
import GHC.Generics (Generic)

data BootstrapSchedulerObservation = BootstrapSchedulerObservation
  { bootstrapExpectedGeneration :: Text
  , bootstrapObservedGeneration :: Text
  , bootstrapExpectedConfigDigest :: Text
  , bootstrapObservedConfigDigest :: Text
  , bootstrapExpectedRootResourceVersion :: Text
  , bootstrapObservedRootResourceVersion :: Text
  , bootstrapSchedulerAvailable :: Bool
  , bootstrapManagedTaintAbsent :: Bool
  , bootstrapGeneralAdmissionAbsent :: Bool
  , bootstrapFullBindingAuthorityAbsent :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BootstrapCapacitySchedulerReady = BootstrapCapacitySchedulerReady Text Text Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BootstrapReadinessError
  = BootstrapGenerationMismatch
  | BootstrapConfigDigestMismatch
  | BootstrapRootMismatch
  | BootstrapSchedulerUnavailable
  | BootstrapManagedAuthorityAlreadyPresent
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

observeBootstrapCapacitySchedulerReady
  :: BootstrapSchedulerObservation
  -> Either BootstrapReadinessError BootstrapCapacitySchedulerReady
observeBootstrapCapacitySchedulerReady observed
  | bootstrapExpectedGeneration observed /= bootstrapObservedGeneration observed = Left BootstrapGenerationMismatch
#ifndef CAPACITY_SCHEDULER_COLLAPSED_READINESS_MUTANT
  | bootstrapExpectedConfigDigest observed /= bootstrapObservedConfigDigest observed = Left BootstrapConfigDigestMismatch
#endif
  | bootstrapExpectedRootResourceVersion observed /= bootstrapObservedRootResourceVersion observed = Left BootstrapRootMismatch
  | not (bootstrapSchedulerAvailable observed) = Left BootstrapSchedulerUnavailable
  | not (bootstrapManagedTaintAbsent observed && bootstrapGeneralAdmissionAbsent observed && bootstrapFullBindingAuthorityAbsent observed) = Left BootstrapManagedAuthorityAlreadyPresent
  | otherwise = Right (BootstrapCapacitySchedulerReady (bootstrapObservedGeneration observed) (bootstrapObservedConfigDigest observed) (bootstrapObservedRootResourceVersion observed))

data BootstrapControllerObservation = BootstrapControllerObservation
  { bootstrapControllerName :: Text
  , bootstrapOldUidAbsent :: Bool
  , bootstrapOldResourcesReleased :: Bool
  , bootstrapReplacementUid :: Text
  , bootstrapReplacementReservationJoined :: Bool
  , bootstrapReplacementBound :: Bool
  , bootstrapReplacementReady :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ManagedAuthorityReadback = ManagedAuthorityReadback
  { managedTaintPresent :: Bool
  , managedIdentityAdmissionPresent :: Bool
  , managedExclusiveBindingRbacPresent :: Bool
  , managedCutoverAuthorityRevoked :: Bool
  , managedWriterDomainExact :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ManagedCapacityReady = ManagedCapacityReady (Set Text)
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ManagedReadinessError
  = BootstrapControllerDomainMismatch (Set Text) (Set Text)
  | BootstrapControllerNotReleased Text
  | BootstrapReplacementNotJoinedReady Text
  | ManagedAuthorityReadbackMismatch
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

observeManagedCapacityReady
  :: BootstrapCapacitySchedulerReady
  -> Set Text
  -> [BootstrapControllerObservation]
  -> ManagedAuthorityReadback
  -> Either ManagedReadinessError ManagedCapacityReady
observeManagedCapacityReady _ expected observations readback = do
  let indexed = Map.fromList [(bootstrapControllerName row, row) | row <- observations]
      observed = Map.keysSet indexed
  if expected == observed then pure () else Left (BootstrapControllerDomainMismatch expected observed)
  traverse_ validateController (Map.elems indexed)
  if managedTaintPresent readback
      && managedIdentityAdmissionPresent readback
      && managedExclusiveBindingRbacPresent readback
      && managedCutoverAuthorityRevoked readback
      && managedWriterDomainExact readback
    then Right (ManagedCapacityReady expected)
    else Left ManagedAuthorityReadbackMismatch
 where
  validateController row
    | not (bootstrapOldUidAbsent row && bootstrapOldResourcesReleased row) = Left (BootstrapControllerNotReleased (bootstrapControllerName row))
    | nullText (bootstrapReplacementUid row)
        || not (bootstrapReplacementReservationJoined row && bootstrapReplacementBound row && bootstrapReplacementReady row) =
        Left (BootstrapReplacementNotJoinedReady (bootstrapControllerName row))
    | otherwise = Right ()

data BootstrapAction = CutoverEnumeratedController Text | InstallManagedAuthority | ApplyGeneralGuardedController
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

authorizeBootstrapAction :: BootstrapCapacitySchedulerReady -> BootstrapAction -> Bool
#ifdef CAPACITY_SCHEDULER_STAGE_DROP_MUTANT
authorizeBootstrapAction _ _ = True
#else
authorizeBootstrapAction _ CutoverEnumeratedController {} = True
authorizeBootstrapAction _ InstallManagedAuthority = False
authorizeBootstrapAction _ ApplyGeneralGuardedController = False
#endif

nullText :: Text -> Bool
nullText value = value == mempty
