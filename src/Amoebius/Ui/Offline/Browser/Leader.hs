{-# LANGUAGE CPP #-}

module Amoebius.Ui.Offline.Browser.Leader
  ( Generation (..)
  , LeaderError (..)
  , LeaderState
  , TabId (..)
  , claimLeader
  , emptyLeaderState
  , leaderGeneration
  , leaderOwners
  , releaseLeader
  ) where

import Amoebius.Ui.Offline.Browser.Partition (PartitionKey)

newtype TabId = TabId String
  deriving stock (Eq, Ord, Show)

newtype Generation = Generation Int
  deriving stock (Eq, Ord, Show)

data LeaderState = LeaderState [(PartitionKey, TabId)] Generation
  deriving stock (Eq, Show)

data LeaderError = ConcurrentTabRefused
  deriving stock (Eq, Show)

emptyLeaderState :: LeaderState
emptyLeaderState = LeaderState [] (Generation 0)

claimLeader :: PartitionKey -> TabId -> LeaderState -> Either LeaderError LeaderState
claimLeader partition tab (LeaderState owners generation)
  | any ((== partition) . fst) owners =
#ifdef ENCRYPTED_BROWSER_RUNTIME_TWO_REPLAY_LEADERS_MUTANT
      Right (LeaderState ((partition, tab) : owners) (advance generation))
#else
      Left ConcurrentTabRefused
#endif
  | otherwise = Right (LeaderState ((partition, tab) : owners) (advance generation))
  where
#ifdef ENCRYPTED_BROWSER_RUNTIME_OMIT_FENCING_MUTANT
    advance value = value
#else
    advance (Generation value) = Generation (value + 1)
#endif

releaseLeader :: TabId -> LeaderState -> LeaderState
releaseLeader tab (LeaderState owners generation) =
  LeaderState (filter ((/= tab) . snd) owners) generation

leaderGeneration :: LeaderState -> Generation
leaderGeneration (LeaderState _ generation) = generation

leaderOwners :: LeaderState -> [TabId]
leaderOwners (LeaderState owners _) = map snd owners
