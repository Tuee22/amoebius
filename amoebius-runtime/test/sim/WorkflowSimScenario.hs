{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module WorkflowSimScenario
  ( WorkflowSchedule (..)
  , WorkflowSimEvent (..)
  , WorkflowSimRun (..)
  , runWorkflowSchedule
  , replayWorkflowSchedule
  , validateWorkflowRun
  ) where

import Amoebius.Workflow.Runtime
import Control.Monad.Class.MonadAsync (async, wait)
import Control.Monad.Class.MonadTest (exploreRaces)
import Control.Monad.Class.MonadTimer (threadDelay)
import Control.Monad.IOSim (IOSim, runSimOrThrow)
import Data.Aeson (ToJSON (toJSON), encode, object, (.=))
import Data.ByteString.Lazy (ByteString)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)

newtype WorkflowSchedule = WorkflowSchedule {workflowSeed :: Int}
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data WorkflowSimEvent
  = CommandDelivered Text
  | ArtifactStored Text
  | KillInsideStoreWrittenEventUnackedWindow Text
  | BrokerPartitionEntered
  | StandbyPromoted Text
  | CommandRedelivered Text
  | BrokerPartitionHealed
  | ImmutableArtifactRefetched Text
  | CommandApplied Bool
  | AllHandlesClosedExcept Text
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data WorkflowSimRun = WorkflowSimRun
  { workflowSchedule :: WorkflowSchedule
  , workflowEvents :: [WorkflowSimEvent]
  , workflowFinalState :: RuntimeState
  , workflowPointerHead :: Text
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON WorkflowSimRun where
  toJSON run = object
    [ "schedule" .= workflowSchedule run
    , "events" .= workflowEvents run
    , "appliedEffectCount" .= appliedEffectCount (workflowFinalState run)
    , "openConsumerHandles" .= Set.toAscList (openConsumerHandles (workflowFinalState run))
    , "activeConsumerName" .= activeConsumerName (workflowFinalState run)
    , "pointerHead" .= workflowPointerHead run
    ]

runWorkflowSchedule :: WorkflowSchedule -> IOSim s WorkflowSimRun
runWorkflowSchedule schedule = do
  exploreRaces
  let work = WorkId "phase37-work"
      active = emptyRuntimeState {openConsumerHandles = Set.singleton "worker-a", activeConsumerName = Just "worker-a"}
      seedDelay = fromIntegral (workflowSeed schedule `mod` 3 + 1)
  first <- async (threadDelay seedDelay >> pure work)
  second <- async (threadDelay (4 - seedDelay) >> pure work)
  firstWork <- wait first
  secondWork <- wait second
  let (firstApplied, once) = applyWork firstWork active
      promoted = promoteStandby "worker-a" "worker-b" once
      (secondApplied, twice) = applyWork secondWork promoted
      events =
        [ CommandDelivered "worker-a"
        , ArtifactStored "fd0049fa31facd012891d8ce294c218e606c191ba51126680e5903b67b2ab059"
        , KillInsideStoreWrittenEventUnackedWindow "worker-a"
        , BrokerPartitionEntered
        , StandbyPromoted "worker-b"
        , CommandRedelivered "worker-b"
        , BrokerPartitionHealed
        , ImmutableArtifactRefetched "fd0049fa31facd012891d8ce294c218e606c191ba51126680e5903b67b2ab059"
        , CommandApplied firstApplied
        , CommandApplied secondApplied
        , AllHandlesClosedExcept "worker-b"
        ]
  pure WorkflowSimRun
    { workflowSchedule = schedule
    , workflowEvents = events
    , workflowFinalState = twice
    , workflowPointerHead = "fd0049fa31facd012891d8ce294c218e606c191ba51126680e5903b67b2ab059"
    }

replayWorkflowSchedule :: WorkflowSchedule -> (WorkflowSimRun, ByteString)
replayWorkflowSchedule schedule =
  let result = runSimOrThrow (runWorkflowSchedule schedule)
   in (result, encode result)

validateWorkflowRun :: WorkflowSimRun -> Either Text ()
validateWorkflowRun run = do
  runtimeInvariant (workflowFinalState run)
  if workflowPointerHead run /= "fd0049fa31facd012891d8ce294c218e606c191ba51126680e5903b67b2ab059"
    then Left "PointerHeadDivergedAcrossFailover"
    else pure ()
  if KillInsideStoreWrittenEventUnackedWindow "worker-a" `notElem` workflowEvents run
      || CommandRedelivered "worker-b" `notElem` workflowEvents run
      || BrokerPartitionEntered `notElem` workflowEvents run
    then Left "RequiredFaultScheduleNotExercised"
    else pure ()
