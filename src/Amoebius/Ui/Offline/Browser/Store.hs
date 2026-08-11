{-# LANGUAGE CPP #-}

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
#ifdef PHASE60_SILENT_DEPENDENCY_EVICTION_MUTANT
  | _dependedOn = EvictedDependency
#endif
  | otherwise = RejectedQuota

prohibitedPersistenceFields :: [String]
#ifdef PHASE60_RETAIN_CREDENTIALS_MUTANT
prohibitedPersistenceFields = ["credential", "refresh-token", "private-plan"]
#else
prohibitedPersistenceFields = []
#endif
