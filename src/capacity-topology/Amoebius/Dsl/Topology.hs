{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}

module Amoebius.Dsl.Topology
  ( Substrate (..)
  , SubstrateToken (..)
  , LinuxHost
  , bareLinuxHost
  , limaHost
  , wsl2Host
  , ServerCount (..)
  , OddQuorumToken (..)
  , ServerCountToken (..)
  , ServerQuorum (..)
  , mkServerQuorum
  , Site (..)
  , SiteToken (..)
  , HostAt
  , hostAt
  , SiteQuorum
  , mkThreeSiteQuorum
  , ReachKind (..)
  , ReachToken (..)
  , MissingReachToken (..)
  , AgentReach
  , HostWorkerReach
  , mkStretchedAgent
  , mkHostWorkerReach
  , ComputeEngine (..)
  , NodeSupply (..)
  , Topology
  , topologyEngine
  , topologySupply
  , TopologyError (..)
  , IncompatibleEntry (..)
  , mkTopology
  , mkRke2Topology
  , checkCompatibility
  , engineAcceptsEnvironment
  ) where

import Amoebius.Capacity.Types
  ( CandidateNodeClass (..)
  , GrowthQuota
  , HostEnvironment (..)
  , Node (..)
  )
import Control.DeepSeq (NFData)
import Data.List.NonEmpty (NonEmpty)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)

data Substrate = LinuxCpu | LinuxCuda | Apple | Windows

data SubstrateToken (substrate :: Substrate) where
  LinuxCpuToken :: SubstrateToken 'LinuxCpu
  LinuxCudaToken :: SubstrateToken 'LinuxCuda
  AppleToken :: SubstrateToken 'Apple
  WindowsToken :: SubstrateToken 'Windows

newtype LinuxHost (substrate :: Substrate) = LinuxHost Text

bareLinuxHost :: SubstrateToken 'LinuxCpu -> Text -> LinuxHost 'LinuxCpu
bareLinuxHost _ = LinuxHost

limaHost :: SubstrateToken 'Apple -> Text -> LinuxHost 'Apple
limaHost _ = LinuxHost

wsl2Host :: SubstrateToken 'Windows -> Text -> LinuxHost 'Windows
wsl2Host _ = LinuxHost

data ServerCount = OneServer | TwoServers | ThreeServers | FiveServers

data OddQuorumToken (count :: ServerCount) where
  OddOneToken :: OddQuorumToken 'OneServer
  OddThreeToken :: OddQuorumToken 'ThreeServers
  OddFiveToken :: OddQuorumToken 'FiveServers

data ServerCountToken (count :: ServerCount) where
  EvenTwoToken :: ServerCountToken 'TwoServers

data ServerQuorum = SingleServer | ThreeServerQuorum | FiveServerQuorum
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

mkServerQuorum :: OddQuorumToken count -> ServerQuorum
mkServerQuorum token = case token of
  OddOneToken -> SingleServer
  OddThreeToken -> ThreeServerQuorum
  OddFiveToken -> FiveServerQuorum

data Site = SiteA | SiteB

data SiteToken (site :: Site) where
  SiteAToken :: SiteToken 'SiteA
  SiteBToken :: SiteToken 'SiteB

newtype HostAt (site :: Site) = HostAt Text

hostAt :: SiteToken site -> Text -> HostAt site
hostAt _ = HostAt

newtype SiteQuorum (site :: Site) = SiteQuorum (Text, Text, Text)

mkThreeSiteQuorum :: HostAt site -> HostAt site -> HostAt site -> SiteQuorum site
mkThreeSiteQuorum (HostAt first) (HostAt second) (HostAt third) = SiteQuorum (first, second, third)

data ReachKind = FullAgent | HostWorker

data ReachToken (kind :: ReachKind) where
  ControlPlaneToken :: ReachToken 'FullAgent
  DataPlaneToken :: ReachToken 'HostWorker

data MissingReachToken = NoReachToken

newtype AgentReach (site :: Site) = AgentReach Text

newtype HostWorkerReach (site :: Site) = HostWorkerReach Text

mkStretchedAgent :: ReachToken 'FullAgent -> HostAt site -> AgentReach site
mkStretchedAgent _ (HostAt host) = AgentReach host

mkHostWorkerReach :: ReachToken 'HostWorker -> HostAt site -> HostWorkerReach site
mkHostWorkerReach _ (HostAt host) = HostWorkerReach host

data ComputeEngine = KindEngine | Rke2Engine | ManagedEksEngine
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data NodeSupply
  = FixedSupply (NonEmpty Node)
  | ElasticSupply [Node] (NonEmpty CandidateNodeClass) GrowthQuota
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data Topology = Topology
  { topologyEngine :: ComputeEngine
  , topologySupply :: NodeSupply
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data IncompatibleEntry = IncompatibleEntry
  { incompatibleName :: Text
  , incompatibleEnvironment :: HostEnvironment
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data TopologyError
  = EngineSubstrateMismatch [IncompatibleEntry]
  | DuplicateHostId Text
  | EmptyRke2Topology
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

mkTopology :: ComputeEngine -> NodeSupply -> Either TopologyError Topology
mkTopology engine supply = case checkCompatibility engine supply of
  [] -> Right (Topology engine supply)
  incompatible -> Left (EngineSubstrateMismatch incompatible)

mkRke2Topology :: ServerQuorum -> [Node] -> [Node] -> Either TopologyError Topology
mkRke2Topology _ servers agents =
#if defined(CAPACITY_RKE2_DUPLICATE_HOST_MUTANT)
  case NonEmpty.nonEmpty (servers <> agents) of
    Nothing -> Left EmptyRke2Topology
    Just nodes -> mkTopology Rke2Engine (FixedSupply nodes)
#else
  case duplicateHost (servers <> agents) of
    Just host -> Left (DuplicateHostId host)
    Nothing -> case NonEmpty.nonEmpty (servers <> agents) of
      Nothing -> Left EmptyRke2Topology
      Just nodes -> mkTopology Rke2Engine (FixedSupply nodes)
#endif

checkCompatibility :: ComputeEngine -> NodeSupply -> [IncompatibleEntry]
checkCompatibility engine supply =
  [ IncompatibleEntry name environment
  | (name, environment) <- entries supply
  , not (engineAcceptsEnvironment engine environment)
  ]
 where
  entries nodeSupply = case nodeSupply of
    FixedSupply nodes ->
      [ (nodeId node, nodeEnvironment node)
      | node <- NonEmpty.toList nodes
      ]
    ElasticSupply floorNodes candidates _ ->
      [ (nodeId node, nodeEnvironment node)
      | node <- floorNodes
      ]
        <> [ (candidateName candidate, candidateEnvironment candidate)
           | candidate <- NonEmpty.toList candidates
           ]

engineAcceptsEnvironment :: ComputeEngine -> HostEnvironment -> Bool
#if defined(CAPACITY_COMPATIBILITY_ADMIT_ALL_MUTANT)
engineAcceptsEnvironment _ _ = True
#else
engineAcceptsEnvironment engine environment = case (engine, environment) of
  (KindEngine, NativeLinux) -> True
  (KindEngine, VirtualizedLinux) -> True
  (Rke2Engine, NativeLinux) -> True
  (Rke2Engine, VirtualizedLinux) -> True
  (ManagedEksEngine, ManagedAws) -> True
  _ -> False
#endif

duplicateHost :: [Node] -> Maybe Text
duplicateHost = go Set.empty
 where
  go _ [] = Nothing
  go seen (node : remaining)
    | nodeHostId node `Set.member` seen = Just (nodeHostId node)
    | otherwise = go (Set.insert (nodeHostId node) seen) remaining
