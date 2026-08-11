{-# LANGUAGE CPP #-}

module Amoebius.Ui.Offline.Replay
  ( Outbox (..)
  , ReplayAdmission (..)
  , ReplayOwner
  , ReplaySession (..)
  , Tab (..)
  , admitReplay
  , claimReplay
  , disconnect
  , noReplayOwner
  ) where

import Amoebius.Ui.Offline.Outcome
import Amoebius.Ui.Offline.Receipt

data ReplaySession = ReplaySession
  { replayScope :: Scope
  , membershipCurrent :: Bool
  , programCompatible :: Bool
  }
  deriving stock (Eq, Show)

data ReplayAdmission = ReplayAdmitted Scope | ReplayRefused Denial
  deriving stock (Eq, Show)

newtype Tab = Tab String
  deriving stock (Eq, Show)

newtype ReplayOwner = ReplayOwner (Maybe Tab)
  deriving stock (Eq, Show)

newtype Outbox = Outbox [CommandId]
  deriving stock (Eq, Show)

noReplayOwner :: ReplayOwner
noReplayOwner = ReplayOwner Nothing

admitReplay :: ReplaySession -> ReplayAdmission
admitReplay session
#ifndef PHASE61_DROP_MEMBERSHIP_VALIDATION_MUTANT
  | not (membershipCurrent session) = ReplayRefused DeniedMembership
#endif
  | not (programCompatible session) = ReplayRefused ReloadRequired
  | otherwise = ReplayAdmitted (replayScope session)

claimReplay :: Tab -> ReplayOwner -> Either Denial ReplayOwner
claimReplay tab (ReplayOwner Nothing) = Right (ReplayOwner (Just tab))
claimReplay _tab (ReplayOwner (Just _)) =
#ifdef PHASE61_TWO_TAB_REPLAY_MUTANT
  Right (ReplayOwner (Just _tab))
#else
  Left DeniedNotReplayOwner
#endif

disconnect :: Outbox -> Outbox
#ifdef PHASE61_DISCARD_PENDING_DISCONNECT_MUTANT
disconnect _ = Outbox []
#else
disconnect outbox = outbox
#endif
