module Amoebius.Ui.Offline.Replay where

newtype CommandId = CommandId String
newtype FencingGeneration = FencingGeneration Int

data ReplayOutcome
  = Pending
  | Accepted String
  | DeniedMembership
  | ReloadRequired
  | Conflict

type ReplayEnvelope =
  { commandId :: CommandId
  , fencingGeneration :: FencingGeneration
  , opaquePartition :: String
  }
