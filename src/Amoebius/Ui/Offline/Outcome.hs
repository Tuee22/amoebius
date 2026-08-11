module Amoebius.Ui.Offline.Outcome
  ( Denial (..)
  , ReplayOutcome (..)
  ) where

data Denial = DeniedMembership | ReloadRequired | DeniedNotReplayOwner
  deriving stock (Eq, Show)

data ReplayOutcome receipt
  = Accepted receipt
  | Denied Denial
  | Pending
  | Conflict
  deriving stock (Eq, Show)
