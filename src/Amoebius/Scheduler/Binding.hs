{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Scheduler.Binding
  ( BindingRequest (..)
  , BindingError (..)
  , prepareBinding
  ) where

import Amoebius.Scheduler.Ledger
import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

data BindingRequest = BindingRequest
  { bindingPodUid :: SchedulerPodUid
  , bindingNode :: Text
  , bindingReservationRootVersion :: Int
  , bindingLeaseHolder :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BindingError = BindingReservationNotInFlight | BindingLeaseHolderMismatch
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

prepareBinding
  :: Text
  -> Text
  -> Int
  -> ReservationRecord
  -> Either BindingError BindingRequest
prepareBinding expectedHolder observedHolder rootVersion record
  | expectedHolder /= observedHolder = Left BindingLeaseHolderMismatch
#ifndef CAPACITY_SCHEDULER_BIND_BEFORE_RESERVATION_CAS_MUTANT
  | reservationState record /= BindingInFlight = Left BindingReservationNotInFlight
#endif
  | otherwise = Right (BindingRequest (reservationUid record) (reservationNode record) rootVersion observedHolder)
