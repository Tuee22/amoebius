module Amoebius.Daemon.InClusterControlPlane
  ( ComputeEngineObservation (..)
  , DaemonTopologyObservation (..)
  , HostlessTopologyError (..)
  , HostlessProviderTopology
  , observeHostlessProviderTopology
  , requireHostSubstrate
  ) where

import Data.Text (Text)

data ComputeEngineObservation = ManagedEks | SelfManaged Text
  deriving stock (Eq, Show)

data DaemonTopologyObservation = DaemonTopologyObservation
  { observedControlPlaneDaemonRoles :: Int
  , observedCapacitySchedulerRoles :: Int
  , observedHostDaemonRoles :: Int
  , observedHostNodePortPeers :: Int
  , observedHostSubstrate :: Maybe Text
  }
  deriving stock (Eq, Show)

data HostlessTopologyError
  = NoHostSubstrateOnManagedEks
  | HostSubstrateRequiredOnSelfManaged
  | ControlPlaneRoleCardinality
  | CapacitySchedulerRoleCardinality
  | HostDaemonPresentOnManagedEks
  | HostNodePortPeerPresentOnManagedEks
  deriving stock (Eq, Show)

newtype HostlessProviderTopology = HostlessProviderTopology DaemonTopologyObservation
  deriving stock (Eq, Show)

observeHostlessProviderTopology
  :: ComputeEngineObservation
  -> DaemonTopologyObservation
  -> Either HostlessTopologyError HostlessProviderTopology
observeHostlessProviderTopology engine observed
  | observedControlPlaneDaemonRoles observed /= 1 = Left ControlPlaneRoleCardinality
  | observedCapacitySchedulerRoles observed /= 1 = Left CapacitySchedulerRoleCardinality
  | otherwise = case engine of
      ManagedEks
        | observedHostDaemonRoles observed /= 0 -> Left HostDaemonPresentOnManagedEks
        | observedHostNodePortPeers observed /= 0 -> Left HostNodePortPeerPresentOnManagedEks
        | observedHostSubstrate observed /= Nothing -> Left NoHostSubstrateOnManagedEks
        | otherwise -> Right (HostlessProviderTopology observed)
      SelfManaged _ -> Left HostSubstrateRequiredOnSelfManaged

requireHostSubstrate :: ComputeEngineObservation -> Either HostlessTopologyError Text
requireHostSubstrate ManagedEks = Left NoHostSubstrateOnManagedEks
requireHostSubstrate (SelfManaged substrate)
  | substrate == mempty = Left HostSubstrateRequiredOnSelfManaged
  | otherwise = Right substrate
