{-# LANGUAGE CPP #-}

module Amoebius.Scheduler.Placement
  ( PlacementError (..)
  , schedulerVectorWithin
  , refoldSchedulerPlacement
  ) where

import Amoebius.Scheduler.Ledger

data PlacementError = SchedulerCapacityExceeded SchedulerResourceVector SchedulerResourceVector
  deriving stock (Eq, Show)

schedulerVectorWithin :: SchedulerResourceVector -> SchedulerResourceVector -> Bool
schedulerVectorWithin used capacity =
  schedulerCpuMillis used <= schedulerCpuMillis capacity
    && schedulerMemoryBytes used <= schedulerMemoryBytes capacity
    && schedulerEphemeralBytes used <= schedulerEphemeralBytes capacity
    && schedulerStorageBytes used <= schedulerStorageBytes capacity
    && schedulerPodSlots used <= schedulerPodSlots capacity
    && schedulerEtcdChurnBytes used <= schedulerEtcdChurnBytes capacity

refoldSchedulerPlacement
  :: SchedulerResourceVector
  -> [SchedulerResourceVector]
  -> SchedulerResourceVector
  -> Either PlacementError SchedulerResourceVector
refoldSchedulerPlacement capacity existing candidate =
#ifdef PHASE27_NUMERIC_ADD_MUTANT
  let total = candidate
#else
  let total = foldl addSchedulerVector candidate existing
#endif
   in if schedulerVectorWithin total capacity
        then Right total
        else Left (SchedulerCapacityExceeded total capacity)
