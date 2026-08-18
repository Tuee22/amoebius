{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Pulsar.Topology
  ( Topic
  , Lane (..)
  , RouteDirection (..)
  , RouteEntry (..)
  , StorageBudgetId (..)
  , PulsarOffloadObjectDemand (..)
  , TopicDescriptor (..)
  , TopologyViolation (..)
  , topicFor
  , renderTopic
  , logicalTopicFamily
  , validateTopology
  ) where

import Amoebius.Pulsar.Internal.Types (Topic (..))
import Data.List (group, sort)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Numeric.Natural (Natural)

data Lane = LinuxCpu | LinuxCuda | Apple | Windows
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data RouteDirection = Input | Report
  deriving stock (Eq, Ord, Show)

data RouteEntry = RouteEntry
  { routeWorkflow :: Text
  , routePhase :: Text
  , routeLanes :: Set Lane
  , routeDirection :: RouteDirection
  , routeEmitOnly :: Bool
  , routeMonitoringOwner :: Maybe Text
  , routeMonitoringFeasible :: Bool
  }
  deriving stock (Eq, Ord, Show)

newtype StorageBudgetId = StorageBudgetId Text
  deriving stock (Eq, Ord, Show)

data PulsarOffloadObjectDemand = PulsarOffloadObjectDemand
  { offloadTopicIdentity :: Text
  , offloadRetainedBytes :: Natural
  , offloadSegmentBytes :: Natural
  , offloadConcurrency :: Natural
  , offloadRateWindowBytes :: Natural
  , offloadDeletionLagBytes :: Natural
  , offloadFailureOrphanBytes :: Natural
  , offloadMutationAdmissionBytes :: Natural
  }
  deriving stock (Eq, Show)

data TopicDescriptor = TopicDescriptor
  { descriptorRoute :: RouteEntry
  , descriptorBudget :: StorageBudgetId
  , descriptorOffload :: PulsarOffloadObjectDemand
  }
  deriving stock (Eq, Show)

data TopologyViolation
  = DuplicateTopic Text
  | EmptyLaneSet Text
  | OneSidedLink Text Lane
  | MonitoringInfeasible Text
  | UnroutedMonitor Text
  deriving stock (Eq, Ord, Show)

laneText :: Lane -> Text
laneText LinuxCpu = "linux-cpu"
laneText LinuxCuda = "linux-cuda"
laneText Apple = "apple"
laneText Windows = "windows"

topicFor :: Text -> Text -> RouteEntry -> Lane -> Topic
#ifdef PULSAR_CLIENT_TOPIC_LITERAL_MUTANT
topicFor _ _ _ _ = Topic "persistent://literal/mutant/hard-coded"
#else
topicFor tenant namespace route lane =
  Topic
    ( "persistent://" <> tenant <> "/" <> namespace <> "/"
        <> routeWorkflow route <> "." <> routePhase route <> "." <> laneText lane
    )
#endif

renderTopic :: Topic -> Text
renderTopic (Topic value) = value

logicalTopicFamily :: RouteEntry -> Text
logicalTopicFamily route = routeWorkflow route <> "." <> routePhase route

validateTopology :: [RouteEntry] -> [TopologyViolation]
validateTopology routes = duplicates <> empties <> oneSided <> monitoring <> unrouted
  where
    renderedTopics =
      [ renderTopic (topicFor "oracle-tenant" "oracle-namespace" route lane)
      | route <- routes
      , lane <- Set.toList (routeLanes route)
      ]
    duplicates =
      [ DuplicateTopic first
      | first : _ : _ <- group (sort renderedTopics)
      ]
    empties = [EmptyLaneSet (routeWorkflow route) | route <- routes, Set.null (routeLanes route)]
    directions =
      Map.fromListWith (<> )
        [ ((routeWorkflow route, lane), Set.singleton (routeDirection route, routeEmitOnly route))
        | route <- routes
        , lane <- Set.toList (routeLanes route)
        ]
#ifdef PULSAR_CLIENT_DROP_ONE_SIDED_MUTANT
    oneSided = []
#else
    oneSided =
      [ OneSidedLink workflow lane
      | ((workflow, lane), values) <- Map.toList directions
      , let plainDirections = Set.map fst values
      , plainDirections /= Set.fromList [Input, Report]
      , not (plainDirections == Set.singleton Report && any snd values)
      ]
#endif
    monitoring =
      [ MonitoringInfeasible (routeWorkflow route)
      | route <- routes
      , not (routeMonitoringFeasible route)
      ]
    unrouted =
      [ UnroutedMonitor (routeWorkflow route)
      | route <- routes
      , routeMonitoringOwner route == Nothing
      ]
