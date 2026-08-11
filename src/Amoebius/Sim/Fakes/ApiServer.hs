module Amoebius.Sim.Fakes.ApiServer
  ( ApiFaults (..)
  , ApiServerState
  , emptyApiServer
  , applyObject
  , watchObjects
  ) where

import Amoebius.Sim.Env
  ( ApplyResult (..)
  , ObjectName
  , ResourceVersion (..)
  , WatchResult (..)
  )
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)

data ApiFaults = ApiFaults
  { apiCrashOnce :: Bool
  , apiWatchFloor :: ResourceVersion
  }
  deriving stock (Eq, Show)

data ApiServerState = ApiServerState
  { objects :: Map ObjectName (ResourceVersion, Text)
  , nextVersion :: ResourceVersion
  , faults :: ApiFaults
  }
  deriving stock (Eq, Show)

emptyApiServer :: ApiFaults -> ApiServerState
emptyApiServer apiFaults = ApiServerState Map.empty (ResourceVersion 1) apiFaults

applyObject
  :: ObjectName
  -> ResourceVersion
  -> Text
  -> ApiServerState
  -> (ApplyResult, ApiServerState)
applyObject name expected body state
  | apiCrashOnce (faults state) =
      (ApplyCrashed, state {faults = (faults state) {apiCrashOnce = False}})
  | expected /= currentVersion = (ResourceVersionConflict currentVersion, state)
  | otherwise =
      let assigned = nextVersion state
          ResourceVersion version = assigned
          state' =
            state
              { objects = Map.insert name (assigned, body) (objects state)
              , nextVersion = ResourceVersion (version + 1)
              }
       in (ObjectApplied assigned, state')
  where
    currentVersion = maybe (ResourceVersion 0) fst (Map.lookup name (objects state))

watchObjects :: ResourceVersion -> ApiServerState -> WatchResult
watchObjects requested state
  | requested < apiWatchFloor (faults state) = WatchGap (apiWatchFloor (faults state))
  | otherwise = WatchObjects [(name, version, body) | (name, (version, body)) <- Map.toAscList (objects state)]
