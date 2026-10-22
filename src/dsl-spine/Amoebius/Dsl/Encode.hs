{-# LANGUAGE OverloadedStrings #-}

-- | The inverse of decoding: a typed specification, or a deliberately illegal authored
-- value, rendered as Dhall text. The corpus is built through this module, never written
-- by hand, so an example cannot disagree with the schema.
module Amoebius.Dsl.Encode
  ( rawOf
  , encodeRaw
  , encodeRoot
  ) where

import Amoebius.Extension.Config qualified as Extension
import Amoebius.Vocabulary qualified as Vocabulary
import Amoebius.Capability.Types (CapabilityProvider (CanonicalProvider), ServiceShape (..))
import Amoebius.Dsl.Raw qualified as Raw
import Amoebius.Dsl.Spec
import Amoebius.Topology.Rke2 (Rke2Quorum (..))
import Amoebius.Vocabulary (CapabilityArm (..), Substrate (..), detectedArchitecture, detectedSubstrate, architectureName, quantityValue)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Dhall qualified
import Dhall.Core qualified as Core

-- | The authored shape of a typed specification.
rawOf :: RootInForceSpec -> Raw.RawRoot
rawOf root = Raw.RawRoot
  { Raw.rootClusters = map rawCluster (NonEmpty.toList (rootClusters root))
  , Raw.rootApps = map rawApp (rootApps root)
  , Raw.rootDeployments = map rawDeployment (rootDeployments root)
  , Raw.rootExtensions = map rawExtension (rootExtensions root)
  }

rawCluster :: ClusterSpec -> Raw.RawCluster
rawCluster cluster =
  Raw.RawCluster
       { Raw.clusterName = clusterNameText (clusterName cluster)
       , Raw.clusterTopology = case clusterTopology cluster of
           KindTopology host replicas -> Raw.KindTopology (Raw.RawKind (hostNameText (hostName host)) (kindReplicasCount replicas))
           Rke2Topology quorum agents -> Raw.Rke2Topology (Raw.RawRke2 (rawQuorum quorum) (map (hostNameText . hostName) agents))
       , Raw.clusterHosts = map rawHost (NonEmpty.toList (clusterHosts cluster))
       }

rawQuorum :: Rke2Quorum HostSpec -> Raw.RawQuorum
rawQuorum quorum = case quorum of
  Single one -> Raw.Single (name one)
  Three one two three -> Raw.Three (Raw.RawThree (name one) (name two) (name three))
  Five one two three four five -> Raw.Five (Raw.RawFive (name one) (name two) (name three) (name four) (name five))
 where
  name = hostNameText . hostName

rawHost :: HostSpec -> Raw.RawHost
rawHost host =
  let resources = hostResources host
      detected = hostDetected host
      operatingSystem = case detectedSubstrate detected of
        LinuxCpu -> "linux"
        LinuxCuda -> "linux"
        Apple -> "darwin"
        Windows -> "windows"
  in Raw.RawHost (hostNameText (hostName host)) (quantityValue (hostCpu resources)) (quantityValue (hostMemory resources)) (quantityValue (hostEphemeral resources)) (quantityValue (hostPods resources)) operatingSystem (Text.pack (architectureName (detectedArchitecture detected))) (detectedSubstrate detected == LinuxCuda) (Set.toAscList (hostTaints host))

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
  , Raw.bindingInference = fmap (\inference -> Raw.RawInferenceBinding
      (rawEngineRuntime (inferenceBindingRuntime inference)) (rawInferenceFamily (inferenceBindingFamily inference))) (bindingInference binding)
  }

rawEngineRuntime :: Vocabulary.EngineRuntime -> Raw.RawEngineRuntime
rawEngineRuntime runtime = case runtime of
  Vocabulary.AppleMetal -> Raw.AppleMetal
  Vocabulary.Cuda -> Raw.Cuda
  Vocabulary.CpuRuntime -> Raw.LinuxCpu

rawInferenceFamily :: Vocabulary.InferenceFamily -> Raw.RawInferenceFamily
rawInferenceFamily family = case family of
  Vocabulary.LlamaCpp -> Raw.LlamaCpp
  Vocabulary.WhisperCpp -> Raw.WhisperCpp
  Vocabulary.Onnx -> Raw.Onnx
  Vocabulary.Vllm -> Raw.Vllm
  Vocabulary.Pytorch -> Raw.Pytorch
  Vocabulary.Diffusers -> Raw.Diffusers
  Vocabulary.Transformers -> Raw.Transformers
  Vocabulary.Audiveris -> Raw.Audiveris

rawExtension :: Extension.ExtensionRequest -> Raw.RawExtensionRequest
rawExtension request = Raw.RawExtensionRequest
  (Vocabulary.extensionIdText (Extension.requestedExtension request)) parameters
 where
  configured = Extension.requestedParameters request
  parameters = case Extension.parameterSchema configured of
    Extension.BuildCacheConfig -> Raw.BuildCacheParameters (Raw.RawCacheParameters
      (maybe 0 id (Extension.cacheBudget configured)) (maybe 0 id (Extension.cacheTemporary configured))
      (maybe 0 id (Extension.cacheConcurrency configured)))
    Extension.CoordinationConfig -> Raw.CoordinationParameters (maybe "" id (Extension.configurationReference configured))
    Extension.InferenceConfig -> Raw.InferenceParameters (maybe 0 id (Extension.cacheBudget configured))
    Extension.TrainingConfig -> Raw.TrainingParameters (maybe "" id (Extension.configurationReference configured))

-- | Render an authored value, legal or not, as Dhall text.
encodeRaw :: Raw.RawRoot -> Text
encodeRaw = Core.pretty . Dhall.embed Raw.rootEncoder

encodeRoot :: RootInForceSpec -> Text
encodeRoot = encodeRaw . rawOf
