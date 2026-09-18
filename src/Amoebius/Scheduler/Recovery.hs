{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Scheduler.Recovery
  ( BindingRecoveryObservation (..)
  , RecoveryAction (..)
  , recoverReservation
  ) where

import Amoebius.Scheduler.Ledger
import Control.DeepSeq (NFData)
import Data.Text (Text)
import GHC.Generics (Generic)

data BindingRecoveryObservation
  = ConfirmedBound SchedulerPodUid Text
  | ConfirmedUnboundSameUidAndResourceVersion SchedulerPodUid Int
  | RecoveryPodAbsent
  | RecoveryUnknown
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data RecoveryAction = RepairReservationBound | ReleaseUnboundReservation | KeepReservationCharged
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

recoverReservation :: ReservationRecord -> BindingRecoveryObservation -> RecoveryAction
recoverReservation record observation = case reservationState record of
  BindingInFlight -> case observation of
    ConfirmedBound uid node
      | uid == reservationUid record && node == reservationNode record -> RepairReservationBound
    ConfirmedUnboundSameUidAndResourceVersion uid _
      | uid == reservationUid record -> ReleaseUnboundReservation
    RecoveryPodAbsent -> ReleaseUnboundReservation
    RecoveryUnknown -> KeepReservationCharged
    _ -> KeepReservationCharged
  Reserved -> case observation of
    RecoveryPodAbsent -> ReleaseUnboundReservation
    RecoveryUnknown -> KeepReservationCharged
    _ -> KeepReservationCharged
  Bound -> KeepReservationCharged
  Terminating -> KeepReservationCharged
  TerminalRetained -> KeepReservationCharged
