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
  , RawRke2 (..)
  , RawQuorum (..)
  , RawThree (..)
  , RawFive (..)
  , RawHost (..)
  , RawApp (..)
  , RawNeed (..)
  , RawArm (..)
  , RawWorkload (..)
  , RawPod (..)
  , RawDeployment (..)
  , RawBinding (..)
  , RawEngineRuntime (..)
  , RawInferenceFamily (..)
  , RawInferenceBinding (..)
  , RawCacheParameters (..)
  , RawExtensionParameters (..)
  , RawExtensionRequest (..)
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
  , hostOs :: Text
  , hostArch :: Text
  , hostGpu :: Bool
  , hostTaints :: [Text]
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
data RawThree = RawThree {server1 :: Text, server2 :: Text, server3 :: Text}
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawFive = RawFive {serverA :: Text, serverB :: Text, serverC :: Text, serverD :: Text, serverE :: Text}
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawQuorum = Single Text | Three RawThree | Five RawFive
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawRke2 = RawRke2 {rke2Servers :: RawQuorum, rke2Agents :: [Text]}
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawTopology = KindTopology RawKind | Rke2Topology RawRke2
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

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
  , bindingInference :: Maybe RawInferenceBinding
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawEngineRuntime = AppleMetal | Cuda | LinuxCpu
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawInferenceFamily = LlamaCpp | WhisperCpp | Onnx | Vllm | Pytorch | Diffusers | Transformers | Audiveris
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawInferenceBinding = RawInferenceBinding
  { engineRuntime :: RawEngineRuntime
  , engineFamily :: RawInferenceFamily
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawCacheParameters = RawCacheParameters
  { cacheBudgetBytes :: Natural
  , cacheTemporaryBytes :: Natural
  , cacheFirstMissConcurrency :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawExtensionParameters
  = BuildCacheParameters RawCacheParameters
  | CoordinationParameters Text
  | InferenceParameters Natural
  | TrainingParameters Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (FromDhall, ToDhall)

data RawExtensionRequest = RawExtensionRequest
  { extensionId :: Text
  , extensionParameters :: RawExtensionParameters
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
  , rootExtensions :: [RawExtensionRequest]
  }
  deriving stock (Eq, Show)

topologyDecoder :: Decoder RawTopology
topologyDecoder = Dhall.auto

topologyEncoder :: Encoder RawTopology
topologyEncoder = Dhall.inject

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
      <*> Dhall.field "rootExtensions" (Dhall.list Dhall.auto)
  )

rootEncoder :: Encoder RawRoot
rootEncoder = Dhall.recordEncoder
  ( fields
      >$< Dhall.encodeFieldWith "rootClusters" clusterListEncoder
      >*< Dhall.encodeFieldWith "rootApps" Dhall.inject
      >*< Dhall.encodeFieldWith "rootDeployments" Dhall.inject
      >*< Dhall.encodeFieldWith "rootExtensions" Dhall.inject
  )
 where
  fields root = (rootClusters root, (rootApps root, (rootDeployments root, rootExtensions root)))
