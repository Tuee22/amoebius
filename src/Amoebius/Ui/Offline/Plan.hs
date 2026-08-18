{-# LANGUAGE CPP #-}

module Amoebius.Ui.Offline.Plan
  ( ClientPlan (..)
  , OfflinePlanError (..)
  , ReplayPlan (..)
  , compileOffline
  , generatedArtifactCommands
  , mechanismConstructors
  ) where

import Amoebius.Ui.Offline.Decode
import Amoebius.Ui.Offline.Types
import Data.List (find, sort, sortOn)

data ClientPlan = ClientPlan
  { clientKeys :: [PortId]
  , publicQueueContracts :: [(PortId, QueueContract)]
  , leakedPrivateFields :: [String]
  }
  deriving stock (Eq, Show)

data ReplayPlan = ReplayPlan
  { replayKeys :: [PortId]
  , privateQueueContracts :: [(PortId, QueueContract)]
  }
  deriving stock (Eq, Show)

data OfflinePlanError
  = QueueDecodeError DecodeError
  | DuplicatePort PortId
  | PlanKeyMismatch
  deriving stock (Eq, Show)

compileOffline :: OfflineSource -> Either OfflinePlanError (ClientPlan, ReplayPlan)
compileOffline source = do
  validated <- traverse validate (queuedPorts source)
  let entries = sortOn fst [(operationPort operation, contract) | QueuedPort operation contract <- validated]
      keys = map fst entries
  case duplicateKey keys of
    Just duplicate -> Left (DuplicatePort duplicate)
    Nothing -> do
      let client = ClientPlan keys entries privateLeak
          replay = ReplayPlan serverKeys entries
      if clientKeys client == replayKeys replay then Right (client, replay) else Left PlanKeyMismatch
  where
    validate = either (Left . QueueDecodeError) Right . decodeQueueContract
#ifdef OFFLINE_LANGUAGE_PLAN_OMIT_SERVER_HANDLER_MUTANT
    serverKeys = drop 1 (map (operationPort . operationOf) (queuedPorts source))
#else
    serverKeys = sort (map (operationPort . operationOf) (queuedPorts source))
#endif
#ifdef OFFLINE_LANGUAGE_PLAN_PERSIST_PRIVATE_FIELD_MUTANT
    privateLeak = ["authority-policy"]
#else
    privateLeak = []
#endif
    operationOf (QueuedPort operation _) = operation

duplicateKey :: [PortId] -> Maybe PortId
duplicateKey keys = find (\key -> length (filter (== key) keys) > 1) keys

generatedArtifactCommands :: [String]
generatedArtifactCommands = ["emit-client-offline-plan", "emit-server-replay-plan"]

mechanismConstructors :: [String]
#ifdef OFFLINE_LANGUAGE_PLAN_BROWSER_REDIS_CONSTRUCTOR_MUTANT
mechanismConstructors = ["IndexedDB", "Redis"]
#else
mechanismConstructors = []
#endif
