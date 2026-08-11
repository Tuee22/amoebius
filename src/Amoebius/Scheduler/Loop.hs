{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Scheduler.Loop
  ( SchedulerProtocolStep (..)
  , schedulerProtocolOrder
  ) where

import Control.DeepSeq (NFData)
import GHC.Generics (Generic)

data SchedulerProtocolStep
  = ReservationCasSucceeded
  | BindingInFlightCasSucceeded
  | KubernetesBindingSubmitted
  | ExactNodeAndUidConfirmed
  | BoundCasSucceeded
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

schedulerProtocolOrder :: [SchedulerProtocolStep]
schedulerProtocolOrder =
  [ ReservationCasSucceeded
  , BindingInFlightCasSucceeded
  , KubernetesBindingSubmitted
  , ExactNodeAndUidConfirmed
  , BoundCasSucceeded
  ]
