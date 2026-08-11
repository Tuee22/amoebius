module Amoebius.Multicluster.Pushback
  ( SurvivorResources (..)
  , PushbackReason (..)
  , TeardownOverride (..)
  , TeardownDecision (..)
  , admitTeardown
  ) where

data SurvivorResources = SurvivorResources
  { survivorCpuMilli :: Int
  , survivorMemoryBytes :: Integer
  , survivorEphemeralBytes :: Integer
  , survivorDurableBytes :: Integer
  , survivorCacheBytes :: Integer
  , survivorDeviceCount :: Int
  }
  deriving stock (Eq, Show)

data PushbackReason
  = SurvivorCpuShort
  | SurvivorMemoryShort
  | SurvivorEphemeralShort
  | SurvivorDurableShort
  | SurvivorCacheShort
  | SurvivorDeviceCountShort
  | SurvivorUnreachable
  deriving stock (Eq, Show)

data TeardownOverride = NoOverride | ExplicitFailback String
  deriving stock (Eq, Show)

data TeardownDecision
  = TeardownAdmitted
  | TeardownRefused PushbackReason
  | TeardownOverridden PushbackReason String
  deriving stock (Eq, Show)

admitTeardown :: Bool -> SurvivorResources -> SurvivorResources -> TeardownOverride -> TeardownDecision
admitTeardown reachable supply demand override =
  case reason of
    Nothing -> TeardownAdmitted
    Just problem -> case override of
      NoOverride -> TeardownRefused problem
      ExplicitFailback failback -> TeardownOverridden problem failback
 where
  reason
    | not reachable = Just SurvivorUnreachable
    | survivorCpuMilli supply < survivorCpuMilli demand = Just SurvivorCpuShort
    | survivorMemoryBytes supply < survivorMemoryBytes demand = Just SurvivorMemoryShort
    | survivorEphemeralBytes supply < survivorEphemeralBytes demand = Just SurvivorEphemeralShort
    | survivorDurableBytes supply < survivorDurableBytes demand = Just SurvivorDurableShort
    | survivorCacheBytes supply < survivorCacheBytes demand = Just SurvivorCacheShort
    | survivorDeviceCount supply < survivorDeviceCount demand = Just SurvivorDeviceCountShort
    | otherwise = Nothing
