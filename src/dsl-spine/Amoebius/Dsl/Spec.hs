{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The typed root specification: the first product specification, spelled once.
-- Every record is built through a smart constructor, so an illegal value has no
-- spelling; a refusal carries a stable tag and is reported at the decode stage.
module Amoebius.Dsl.Spec
  ( SpecError (..)
  , specErrorTag
  , ClusterName
  , AppName
  , NeedName
  , HostName
  , mkClusterName
  , mkAppName
  , mkNeedName
  , mkHostName
  , clusterNameText
  , appNameText
  , needNameText
  , hostNameText
  , PodResources (..)
  , HostResources (..)
  , HostSpec (..)
  , KindReplicas
  , mkKindReplicas
  , kindReplicasCount
  , TopologySpec (..)
  , ClusterSpec (clusterName, clusterTopology, clusterHosts)
  , mkClusterSpec
  , NeedSpec (needCapability, needName)
  , mkNeedSpec
  , WorkloadSpec (workloadRequests, workloadLimits, workloadHeadroom)
  , mkWorkloadSpec
  , AppSpec (appName, appNeeds, appWorkload)
  , mkAppSpec
  , Replicas
  , mkReplicas
  , replicasCount
  , DistributionRule (..)
  , BindingSpec (..)
  , DeploymentRules (deploymentOf, deploymentBindings, deploymentDistribution)
  , mkDeploymentRules
  , RootInForceSpec (rootClusters, rootApps, rootDeployments)
  , mkRootInForceSpec
  ) where

import Amoebius.Capability.Types (CapabilityProvider, ServiceShape)
import Amoebius.Vocabulary (CapabilityArm (..), Quantity, Unit (..), isLabel)
import Data.List (nub)
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Text (Text)
import Numeric.Natural (Natural)

data SpecError
  = InvalidName Text
  | TopologyHostUndeclared Text
  | UnreferencedHost Text
  | DuplicateHost Text
  | KindReplicasZero
  | UnsupportedArm
  | RequestsAboveLimits
  | HeadroomAllZero
  | EmptyNeeds
  | DuplicateNeed Text
  | ZeroReplicas
  | EmptyBindings
  | DuplicateBinding Text
  | EmptyClusters
  | UnbuiltProviderArm Text
  | DistributedShape Natural
  deriving stock (Eq, Ord, Show)

-- | The stable tag of a refusal: the name of its constructor.
specErrorTag :: SpecError -> Text
specErrorTag refusal = case refusal of
  InvalidName _ -> "InvalidName"
  TopologyHostUndeclared _ -> "TopologyHostUndeclared"
  UnreferencedHost _ -> "UnreferencedHost"
  DuplicateHost _ -> "DuplicateHost"
  KindReplicasZero -> "KindReplicasZero"
  UnsupportedArm -> "UnsupportedArm"
  RequestsAboveLimits -> "RequestsAboveLimits"
  HeadroomAllZero -> "HeadroomAllZero"
  EmptyNeeds -> "EmptyNeeds"
  DuplicateNeed _ -> "DuplicateNeed"
  ZeroReplicas -> "ZeroReplicas"
  EmptyBindings -> "EmptyBindings"
  DuplicateBinding _ -> "DuplicateBinding"
  EmptyClusters -> "EmptyClusters"
  UnbuiltProviderArm _ -> "UnbuiltProviderArm"
  DistributedShape _ -> "DistributedShape"

newtype ClusterName = ClusterName Text
  deriving stock (Eq, Ord, Show)

newtype AppName = AppName Text
  deriving stock (Eq, Ord, Show)

newtype NeedName = NeedName Text
  deriving stock (Eq, Ord, Show)

newtype HostName = HostName Text
  deriving stock (Eq, Ord, Show)

label :: (Text -> name) -> Text -> Either SpecError name
label wrap text = if isLabel text then Right (wrap text) else Left (InvalidName text)

mkClusterName :: Text -> Either SpecError ClusterName
mkClusterName = label ClusterName

mkAppName :: Text -> Either SpecError AppName
mkAppName = label AppName

mkNeedName :: Text -> Either SpecError NeedName
mkNeedName = label NeedName

mkHostName :: Text -> Either SpecError HostName
mkHostName = label HostName

clusterNameText :: ClusterName -> Text
clusterNameText (ClusterName text) = text

appNameText :: AppName -> Text
appNameText (AppName text) = text

needNameText :: NeedName -> Text
needNameText (NeedName text) = text

hostNameText :: HostName -> Text
hostNameText (HostName text) = text

-- | The three axes of a pod: processor, memory, and ephemeral storage. The pod slot
-- every instance occupies is implicit.
data PodResources = PodResources
  { podCpu :: Quantity 'CpuUnit
  , podMemory :: Quantity 'MemoryUnit
  , podEphemeral :: Quantity 'EphemeralUnit
  }
  deriving stock (Eq, Ord, Show)

-- | The four axes of a host.
data HostResources = HostResources
  { hostCpu :: Quantity 'CpuUnit
  , hostMemory :: Quantity 'MemoryUnit
  , hostEphemeral :: Quantity 'EphemeralUnit
  , hostPods :: Quantity 'SlotUnit
  }
  deriving stock (Eq, Ord, Show)

data HostSpec = HostSpec
  { hostName :: HostName
  , hostResources :: HostResources
  }
  deriving stock (Eq, Ord, Show)

newtype KindReplicas = KindReplicas Natural
  deriving stock (Eq, Ord, Show)

mkKindReplicas :: Natural -> Either SpecError KindReplicas
mkKindReplicas count = if count == 0 then Left KindReplicasZero else Right (KindReplicas count)

kindReplicasCount :: KindReplicas -> Natural
kindReplicasCount (KindReplicas count) = count

-- | The one topology this phase spells: kind node containers on one declared host.
data TopologySpec = KindTopology HostSpec KindReplicas
  deriving stock (Eq, Ord, Show)

data ClusterSpec = ClusterSpec
  { clusterName :: ClusterName
  , clusterTopology :: TopologySpec
  , clusterHosts :: NonEmpty HostSpec
  }
  deriving stock (Eq, Ord, Show)

-- | A cluster names its topology's host, which must be one of its declared hosts, and
-- declares no host that nothing references.
mkClusterSpec :: ClusterName -> Text -> KindReplicas -> NonEmpty HostSpec -> Either SpecError ClusterSpec
mkClusterSpec name kindHost replicas hosts = do
  let declared = map (hostNameText . hostName) (NonEmpty.toList hosts)
  case [host | host <- NonEmpty.toList hosts, hostNameText (hostName host) == kindHost] of
    [] -> Left (TopologyHostUndeclared kindHost)
    host : _ -> do
      case [duplicate | duplicate <- nub declared, length (filter (== duplicate) declared) > 1] of
        duplicate : _ -> Left (DuplicateHost duplicate)
        [] -> Right ()
      case [unreferenced | unreferenced <- declared, unreferenced /= kindHost] of
        unreferenced : _ -> Left (UnreferencedHost unreferenced)
        [] -> Right (ClusterSpec name (KindTopology host replicas) hosts)

data NeedSpec = NeedSpec
  { needCapability :: CapabilityArm
  , needName :: NeedName
  }
  deriving stock (Eq, Ord, Show)

-- | An inference engine needs a profile and a runtime that a bare need cannot carry.
mkNeedSpec :: CapabilityArm -> NeedName -> Either SpecError NeedSpec
mkNeedSpec arm name = case arm of
  InferenceEngine -> Left UnsupportedArm
  _ -> Right (NeedSpec arm name)

data WorkloadSpec = WorkloadSpec
  { workloadRequests :: PodResources
  , workloadLimits :: PodResources
  , workloadHeadroom :: Maybe PodResources
  }
  deriving stock (Eq, Ord, Show)

-- | Requests plus headroom may not exceed limits on any axis, and a headroom that is
-- present is not all zero.
mkWorkloadSpec :: PodResources -> PodResources -> Maybe PodResources -> Either SpecError WorkloadSpec
mkWorkloadSpec requests limits headroom = do
  case headroom of
    Just pad | podCpu pad == 0 && podMemory pad == 0 && podEphemeral pad == 0 -> Left HeadroomAllZero
    _ -> Right ()
  let pad = maybe (PodResources 0 0 0) id headroom
  if podCpu requests + podCpu pad > podCpu limits
    || podMemory requests + podMemory pad > podMemory limits
    || podEphemeral requests + podEphemeral pad > podEphemeral limits
    then Left RequestsAboveLimits
    else Right (WorkloadSpec requests limits headroom)

data AppSpec = AppSpec
  { appName :: AppName
  , appNeeds :: NonEmpty NeedSpec
  , appWorkload :: WorkloadSpec
  }
  deriving stock (Eq, Ord, Show)

-- | An application names at least one need, each once, and carries no shape,
-- provider, replica count, or image of its own.
mkAppSpec :: AppName -> [NeedSpec] -> WorkloadSpec -> Either SpecError AppSpec
mkAppSpec name needs workload = case needs of
  [] -> Left EmptyNeeds
  first : rest -> do
    let names = map (needNameText . needName) needs
    case [duplicate | duplicate <- nub names, length (filter (== duplicate) names) > 1] of
      duplicate : _ -> Left (DuplicateNeed duplicate)
      [] -> Right (AppSpec name (first :| rest) workload)

newtype Replicas = Replicas Natural
  deriving stock (Eq, Ord, Show)

mkReplicas :: Natural -> Either SpecError Replicas
mkReplicas count = if count == 0 then Left ZeroReplicas else Right (Replicas count)

replicasCount :: Replicas -> Natural
replicasCount (Replicas count) = count

newtype DistributionRule = DistributionRule
  { distributionReplicas :: Replicas
  }
  deriving stock (Eq, Ord, Show)

data BindingSpec = BindingSpec
  { bindingNeed :: NeedName
  , bindingProvider :: CapabilityProvider
  , bindingShape :: ServiceShape
  }
  deriving stock (Eq, Ord, Show)

data DeploymentRules = DeploymentRules
  { deploymentOf :: AppName
  , deploymentBindings :: NonEmpty BindingSpec
  , deploymentDistribution :: DistributionRule
  }
  deriving stock (Eq, Ord, Show)

mkDeploymentRules :: AppName -> [BindingSpec] -> DistributionRule -> Either SpecError DeploymentRules
mkDeploymentRules app bindings distribution = case bindings of
  [] -> Left EmptyBindings
  first : rest -> do
    let needs = map (needNameText . bindingNeed) bindings
    case [duplicate | duplicate <- nub needs, length (filter (== duplicate) needs) > 1] of
      duplicate : _ -> Left (DuplicateBinding duplicate)
      [] -> Right (DeploymentRules app (first :| rest) distribution)

data RootInForceSpec = RootInForceSpec
  { rootClusters :: NonEmpty ClusterSpec
  , rootApps :: [AppSpec]
  , rootDeployments :: [DeploymentRules]
  }
  deriving stock (Eq, Ord, Show)

mkRootInForceSpec :: [ClusterSpec] -> [AppSpec] -> [DeploymentRules] -> Either SpecError RootInForceSpec
mkRootInForceSpec clusters apps deployments = case clusters of
  [] -> Left EmptyClusters
  first : rest -> Right (RootInForceSpec (first :| rest) apps deployments)
