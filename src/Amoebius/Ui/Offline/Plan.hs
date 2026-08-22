{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

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
import Data.Text (Text)

data ClientPlan = ClientPlan
  { clientKeys :: [PortId]
  , clientProjectionKeys :: [Text]
  , clientBlobKeys :: [Text]
  , clientOfflineView :: Text
  , publicQueueContracts :: [(PortId, QueueContract)]
  , leakedPrivateFields :: [Text]
  }
  deriving stock (Eq, Show)

data ReplayPlan = ReplayPlan
  { replayKeys :: [PortId]
  , replayProjectionKeys :: [Text]
  , replayBlobKeys :: [Text]
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
  let entries = sortOn fst [(operationPort selected, queueContract) | QueuedPort selected queueContract <- validated]
      keys = map fst entries
      projectionKeys = sort (map projectionId (projections source))
      blobKeys = sort (map blobClassId (localBlobs source))
  case duplicateKey keys of
    Just duplicate -> Left (DuplicatePort duplicate)
    Nothing -> do
      let client = ClientPlan keys projectionKeys blobKeys (offlineView source) entries privateLeak
          replay = ReplayPlan serverKeys projectionKeys blobKeys entries
      if clientKeys client == replayKeys replay
        && clientProjectionKeys client == replayProjectionKeys replay
        && clientBlobKeys client == replayBlobKeys replay
        then Right (client, replay)
        else Left PlanKeyMismatch
  where
    validate = either (Left . QueueDecodeError) Right . decodeQueueContract
#ifdef OFFLINE_LANGUAGE_PLAN_OMIT_SERVER_HANDLER_MUTANT
    serverKeys = drop 1 (map (operationPort . operation) (queuedPorts source))
#else
    serverKeys = sort (map (operationPort . operation) (queuedPorts source))
#endif
#ifdef OFFLINE_LANGUAGE_PLAN_PERSIST_PRIVATE_FIELD_MUTANT
    privateLeak = ["authority-policy"]
#else
    privateLeak = []
#endif

duplicateKey :: [PortId] -> Maybe PortId
duplicateKey keys = find (\key -> length (filter (== key) keys) > 1) keys

generatedArtifactCommands :: [Text]
generatedArtifactCommands = ["emit-client-offline-plan", "emit-server-replay-plan"]

mechanismConstructors :: [Text]
#ifdef OFFLINE_LANGUAGE_PLAN_BROWSER_REDIS_CONSTRUCTOR_MUTANT
mechanismConstructors = ["IndexedDB", "Redis"]
#else
mechanismConstructors = []
#endif
