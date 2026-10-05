{-# LANGUAGE OverloadedStrings #-}

-- | The inverse of decoding: a typed specification, or a deliberately illegal authored
-- value, rendered as Dhall text. The corpus is built through this module, never written
-- by hand, so an example cannot disagree with the schema.
module Amoebius.Dsl.Encode
  ( rawOf
  , encodeRaw
  , encodeRoot
  ) where

import Amoebius.Capability.Types (CapabilityProvider (CanonicalProvider), ServiceShape (..))
import Amoebius.Dsl.Raw qualified as Raw
import Amoebius.Dsl.Spec
import Amoebius.Vocabulary (CapabilityArm (..), quantityValue)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)
import Dhall qualified
import Dhall.Core qualified as Core

-- | The authored shape of a typed specification.
rawOf :: RootInForceSpec -> Raw.RawRoot
rawOf root = Raw.RawRoot
  { Raw.rootClusters = map rawCluster (NonEmpty.toList (rootClusters root))
  , Raw.rootApps = map rawApp (rootApps root)
  , Raw.rootDeployments = map rawDeployment (rootDeployments root)
  }

rawCluster :: ClusterSpec -> Raw.RawCluster
rawCluster cluster =
  let KindTopology host replicas = clusterTopology cluster
  in Raw.RawCluster
       { Raw.clusterName = clusterNameText (clusterName cluster)
       , Raw.clusterTopology = Raw.KindTopology (Raw.RawKind (hostNameText (hostName host)) (kindReplicasCount replicas))
       , Raw.clusterHosts = map rawHost (NonEmpty.toList (clusterHosts cluster))
       }

rawHost :: HostSpec -> Raw.RawHost
rawHost host =
  let resources = hostResources host
  in Raw.RawHost (hostNameText (hostName host)) (quantityValue (hostCpu resources)) (quantityValue (hostMemory resources)) (quantityValue (hostEphemeral resources)) (quantityValue (hostPods resources))

rawApp :: AppSpec -> Raw.RawApp
rawApp app = Raw.RawApp
  { Raw.appName = appNameText (appName app)
  , Raw.needs = map rawNeed (NonEmpty.toList (appNeeds app))
  , Raw.workload = rawWorkload (appWorkload app)
  }

rawNeed :: NeedSpec -> Raw.RawNeed
rawNeed need = Raw.RawNeed (rawArm (needCapability need)) (needNameText (needName need))

rawArm :: CapabilityArm -> Raw.RawArm
rawArm arm = case arm of
  ObjectStore -> Raw.ObjectStore
  SecretStore -> Raw.SecretStore
  MessageBus -> Raw.MessageBus
  Sql -> Raw.Sql
  Identity -> Raw.Identity
  Observability -> Raw.Observability
  Registry -> Raw.Registry
  Edge -> Raw.Edge
  InferenceEngine -> Raw.InferenceEngine

rawWorkload :: WorkloadSpec -> Raw.RawWorkload
rawWorkload workload = Raw.RawWorkload
  { Raw.workloadRequests = rawPod (workloadRequests workload)
  , Raw.workloadLimits = rawPod (workloadLimits workload)
  , Raw.workloadHeadroom = rawPod <$> workloadHeadroom workload
  }

rawPod :: PodResources -> Raw.RawPod
rawPod pod = Raw.RawPod (quantityValue (podCpu pod)) (quantityValue (podMemory pod)) (quantityValue (podEphemeral pod))

rawDeployment :: DeploymentRules -> Raw.RawDeployment
rawDeployment deployment = Raw.RawDeployment
  { Raw.deploymentOf = appNameText (deploymentOf deployment)
  , Raw.bindings = map rawBinding (NonEmpty.toList (deploymentBindings deployment))
  , Raw.distribution = Raw.RawDistribution (replicasCount (distributionReplicas (deploymentDistribution deployment)))
  }

rawBinding :: BindingSpec -> Raw.RawBinding
rawBinding binding = Raw.RawBinding
  { Raw.bindingNeed = needNameText (bindingNeed binding)
  , Raw.bindingProvider = case bindingProvider binding of CanonicalProvider -> "Canonical"
  , Raw.bindingShape = case bindingShape binding of
      SingleNode -> Raw.SingleNode
      Distributed nodes -> Raw.Distributed nodes
  }

-- | Render an authored value, legal or not, as Dhall text.
encodeRaw :: Raw.RawRoot -> Text
encodeRaw = Core.pretty . Dhall.embed Raw.rootEncoder

encodeRoot :: RootInForceSpec -> Text
encodeRoot = encodeRaw . rawOf
