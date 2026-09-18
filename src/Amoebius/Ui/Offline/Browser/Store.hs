

module Amoebius.Ui.Offline.Browser.Store
  ( QuotaOutcome (..)
  , RecordKind (..)
  , admitBytes
  , prohibitedPersistenceFields
  ) where

data RecordKind = CachedProjection | QueuedCommand | LocalBlob | OfflineAuthMetadata
  deriving stock (Eq, Show, Enum, Bounded)

data QuotaOutcome = Stored | RejectedQuota | EvictedDependency
  deriving stock (Eq, Show)

admitBytes :: Int -> Int -> Int -> Bool -> QuotaOutcome
admitBytes budget used requested _dependedOn
  | used + requested <= budget = Stored
  | otherwise = RejectedQuota

prohibitedPersistenceFields :: [String]
prohibitedPersistenceFields = []
