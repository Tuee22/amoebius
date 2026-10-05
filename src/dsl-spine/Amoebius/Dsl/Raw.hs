{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The authored shape of a specification: plain records and unions that mirror the
-- Dhall labels. A list here may be empty and a number may be zero; the typed
-- specification refuses each under its own tag. Nothing here is a decision.
module Amoebius.Dsl.Raw
  ( RawRoot (..)
  , RawCluster (..)
  , RawTopology (..)
  , RawKind (..)
  , RawHost (..)
  , RawApp (..)
  , RawNeed (..)
  , RawArm (..)
  , RawWorkload (..)
  , RawPod (..)
  , RawDeployment (..)
  , RawBinding (..)
  , RawShape (..)
  , RawDistribution (..)
  , rootDecoder
  , rootEncoder
  ) where

import Data.Sequence qualified as Seq
import Data.Text (Text)
import Dhall (Decoder, Encoder, FromDhall, ToDhall, (>$<), (>*<))
import Dhall qualified
import Dhall.Core qualified as Core
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data RawHost = RawHost
  { hostName :: Text
  , hostCpu :: Natural
  , hostMemory :: Natural
  , hostEphemeral :: Natural
  , hostPods :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawKind = RawKind
  { kindHost :: Text
  , kindReplicas :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

-- | The one topology this phase spells. A single alternative is still a union in the
-- authored text, so its codec is written by hand.
newtype RawTopology = KindTopology RawKind
  deriving stock (Eq, Show)

data RawCluster = RawCluster
  { clusterName :: Text
  , clusterTopology :: RawTopology
  , clusterHosts :: [RawHost]
  }
  deriving stock (Eq, Show)

data RawArm
  = ObjectStore
  | SecretStore
  | MessageBus
  | Sql
  | Identity
  | Observability
  | Registry
  | Edge
  | InferenceEngine
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawNeed = RawNeed
  { needCapability :: RawArm
  , needName :: Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawPod = RawPod
  { podCpu :: Natural
  , podMemory :: Natural
  , podEphemeral :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawWorkload = RawWorkload
  { workloadRequests :: RawPod
  , workloadLimits :: RawPod
  , workloadHeadroom :: Maybe RawPod
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawApp = RawApp
  { appName :: Text
  , needs :: [RawNeed]
  , workload :: RawWorkload
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawShape = SingleNode | Distributed Natural
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawBinding = RawBinding
  { bindingNeed :: Text
  , bindingProvider :: Text
  , bindingShape :: RawShape
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

newtype RawDistribution = RawDistribution
  { replicas :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawDeployment = RawDeployment
  { deploymentOf :: Text
  , bindings :: [RawBinding]
  , distribution :: RawDistribution
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawRoot = RawRoot
  { rootClusters :: [RawCluster]
  , rootApps :: [RawApp]
  , rootDeployments :: [RawDeployment]
  }
  deriving stock (Eq, Show)

topologyDecoder :: Decoder RawTopology
topologyDecoder = Dhall.union (KindTopology <$> Dhall.constructor "KindTopology" Dhall.auto)

topologyEncoder :: Encoder RawTopology
topologyEncoder = Dhall.unionEncoder (unwrap >$< Dhall.encodeConstructor "KindTopology")
 where
  unwrap (KindTopology kind) = kind

clusterDecoder :: Decoder RawCluster
clusterDecoder = Dhall.record
  ( RawCluster
      <$> Dhall.field "clusterName" Dhall.strictText
      <*> Dhall.field "clusterTopology" topologyDecoder
      <*> Dhall.field "clusterHosts" (Dhall.list Dhall.auto)
  )

clusterEncoder :: Encoder RawCluster
clusterEncoder = Dhall.recordEncoder
  ( fields
      >$< Dhall.encodeFieldWith "clusterName" Dhall.inject
      >*< Dhall.encodeFieldWith "clusterTopology" topologyEncoder
      >*< Dhall.encodeFieldWith "clusterHosts" Dhall.inject
  )
 where
  fields cluster = (clusterName cluster, (clusterTopology cluster, clusterHosts cluster))

-- | A list of clusters; an empty list carries its element type, as Dhall requires.
clusterListEncoder :: Encoder [RawCluster]
clusterListEncoder = Dhall.Encoder
  { Dhall.embed = \clusters -> case clusters of
      [] -> Core.ListLit (Just (Core.App Core.List (Dhall.declared clusterEncoder))) Seq.empty
      _ -> Core.ListLit Nothing (Seq.fromList (map (Dhall.embed clusterEncoder) clusters))
  , Dhall.declared = Core.App Core.List (Dhall.declared clusterEncoder)
  }

-- | The decoder of the whole authored record; its expected type is the schema.
rootDecoder :: Decoder RawRoot
rootDecoder = Dhall.record
  ( RawRoot
      <$> Dhall.field "rootClusters" (Dhall.list clusterDecoder)
      <*> Dhall.field "rootApps" (Dhall.list Dhall.auto)
      <*> Dhall.field "rootDeployments" (Dhall.list Dhall.auto)
  )

rootEncoder :: Encoder RawRoot
rootEncoder = Dhall.recordEncoder
  ( fields
      >$< Dhall.encodeFieldWith "rootClusters" clusterListEncoder
      >*< Dhall.encodeFieldWith "rootApps" Dhall.inject
      >*< Dhall.encodeFieldWith "rootDeployments" Dhall.inject
  )
 where
  fields root = (rootClusters root, (rootApps root, rootDeployments root))
