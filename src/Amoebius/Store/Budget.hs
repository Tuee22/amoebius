{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Store.Budget
  ( StorageBudgetId (..)
  , MutationAdmission (..)
  , ObjectStoreDemand (..)
  , BudgetObservation (..)
  , BudgetDecision (..)
  , logicalPeakBytes
  , admitObjectStore
  ) where

import Data.Set (Set)
import Data.Text (Text)
import Numeric.Natural (Natural)

newtype StorageBudgetId = StorageBudgetId Text
  deriving stock (Eq, Ord, Show)

data MutationAdmission = ExclusiveContentWriter Text
  deriving stock (Eq, Show)

data ObjectStoreDemand = ObjectStoreDemand
  { demandStorageBudget :: StorageBudgetId
  , demandPhysicalObjectIdentities :: Set Text
  , demandCommittedBytes :: Natural
  , demandAdditionalRetainedBytes :: Natural
  , demandConcurrentWriteBytes :: Natural
  , demandFailedWriteSetBytes :: Natural
  , demandMaximumFailedWriteSets :: Natural
  , demandOrphanGcHorizonSeconds :: Natural
  , demandMutationAdmission :: MutationAdmission
  }
  deriving stock (Eq, Show)

data BudgetObservation = BudgetObservation
  { observedOrphanBytes :: Natural
  , observedOrphanAgeSeconds :: Natural
  , observedOrphanDeletion :: Bool
  }
  deriving stock (Eq, Show)

data BudgetDecision
  = ObjectStoreAdmitted Natural
  | ObjectStoreCapacityExceeded Natural Natural
  | ObjectStoreDemandInvalid Text
  deriving stock (Eq, Show)

logicalPeakBytes :: ObjectStoreDemand -> BudgetObservation -> Natural
logicalPeakBytes demand observation =
  demandCommittedBytes demand
    + demandAdditionalRetainedBytes demand
    + demandConcurrentWriteBytes demand
    + failedWindow
    + retainedObservedOrphan
  where
    failedWindow = demandFailedWriteSetBytes demand * demandMaximumFailedWriteSets demand
    retainedObservedOrphan
      | observedOrphanDeletion observation
          && observedOrphanAgeSeconds observation >= demandOrphanGcHorizonSeconds demand = 0
      | otherwise = observedOrphanBytes observation

admitObjectStore :: Natural -> ObjectStoreDemand -> BudgetObservation -> BudgetDecision
admitObjectStore supply demand observation
  | demandOrphanGcHorizonSeconds demand == 0 = ObjectStoreDemandInvalid "OrphanGcHorizonMustBePositive"
  | demandMaximumFailedWriteSets demand == 0 = ObjectStoreDemandInvalid "MaximumFailedWriteSetsMustBePositive"
  | null (demandPhysicalObjectIdentities demand) = ObjectStoreDemandInvalid "PhysicalObjectIdentitySetMustBeNonEmpty"
  | peak <= supply = ObjectStoreAdmitted peak
  | otherwise = ObjectStoreCapacityExceeded peak supply
  where
    peak = logicalPeakBytes demand observation
