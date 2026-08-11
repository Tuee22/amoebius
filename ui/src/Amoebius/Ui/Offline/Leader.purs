module Amoebius.Ui.Offline.Leader where

import Amoebius.Ui.Offline.Partition (PartitionKey)

newtype FencingGeneration = FencingGeneration Int
newtype TabId = TabId String

type LeaderLease =
  { partition :: PartitionKey
  , tab :: TabId
  , generation :: FencingGeneration
  }

data LeadershipOutcome
  = Acquired LeaderLease
  | ConcurrentTabRefused
  | CoordinationUnsupported
