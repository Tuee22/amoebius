{-# LANGUAGE OverloadedStrings #-}

-- | Stage lower. The decoded root becomes the topology, the bound deployment, and the
-- target supply the planner reads. This module alone assembles a bound deployment, so
-- every bound deployment the pipeline holds was lowered from a decoded specification.
module Amoebius.Dsl.Lower
  ( Lowered (loweredCluster, loweredTopology, loweredDeployment, loweredSupply, loweredApp)
  , LowerRefusal (..)
  , lowerRefusalTag
  , lowerTopology
  , lowerDeployment
  , dumpLowered
  ) where

import Amoebius.Capacity.Execution
  ( BoundExecutionUnit (..)
  , ControllerBody (DeploymentBody)
  , ExecutionTransitionSource (FirstDeployment)
  , recreateRollout
  )
import Amoebius.Capacity.Provision
  ( ClusterBudget (..)
  , InfrastructureState (InfrastructureAlreadyPresent)
  , ProvisionTargetSupply (..)
  , TargetSupply (..)
  )
import Amoebius.Capacity.Types (CpuOvercommitPolicy (NoCpuOvercommit), HostEnvironment (NativeLinux), Node (..), NodeCapacity (..), ResourceEnvelope, envelopeHeadroom, envelopeLimits, envelopeRequests, mkResourceEnvelope)
import Amoebius.Capacity.Vector (ResourceVector (..), addResources, zeroResources)
import Amoebius.Capability.Assemble (assembleWithApps)
import Amoebius.Capability.Binding (bind)
import Amoebius.Capability.Types
  ( BoundApp (..)
  , BoundDeployment
  , BoundExecutionSet (..)
  , BoundServiceSpec (..)
  , CapabilityBinding (CapabilityBinding)
  , CapabilityNeed (..)
  , ProviderObject (..)
  , boundDeploymentExecutions
  , boundDeploymentServices
  , capabilityArm
  , renderCapabilityNeedSurface
  )
import Amoebius.Dsl.Dump (commas, natural, row, rows, vector)
import Amoebius.Dsl.Policy (supplySnapshot)
import Amoebius.Dsl.Spec
import Amoebius.Dsl.Topology
  ( ComputeEngine (KindEngine)
  , NodeSupply (FixedSupply)
  , Topology
  , mkTopology
  , topologyEngine
  , topologySupply
  )
import Amoebius.Vocabulary (CapabilityArm (..))
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

data LowerRefusal
  = OutsideScope
  | UnknownDeployment Text
  | UnboundNeed Text
  | DanglingBinding Text
  | UnloweredArm
  | TopologyRefused Text
  | AssemblyRefused Text
  deriving stock (Eq, Show)

-- | The stable tag of a refusal: the name of its constructor.
lowerRefusalTag :: LowerRefusal -> Text
lowerRefusalTag refusal = case refusal of
  OutsideScope -> "OutsideScope"
  UnknownDeployment _ -> "UnknownDeployment"
  UnboundNeed _ -> "UnboundNeed"
  DanglingBinding _ -> "DanglingBinding"
  UnloweredArm -> "UnloweredArm"
  TopologyRefused _ -> "TopologyRefused"
  AssemblyRefused _ -> "AssemblyRefused"

-- | What the stage hands on. The constructor is private.
data Lowered = Lowered
  { loweredCluster :: Text
  , loweredTopology :: Topology
  , loweredDeployment :: BoundDeployment
  , loweredSupply :: ProvisionTargetSupply
  , loweredApp :: BoundApp
  }

-- | One node container per authored replica, each carrying the host's resources.
lowerTopology :: ClusterSpec -> Either LowerRefusal Topology
lowerTopology cluster = case map nodeAt [1 .. kindReplicasCount replicas] of
  [] -> Left (TopologyRefused "no nodes")
  first : rest -> either (Left . TopologyRefused . Text.pack . show) Right (mkTopology KindEngine (FixedSupply (first :| rest)))
 where
  KindTopology host replicas = clusterTopology cluster
  hostText = hostNameText (hostName host)
  resources = hostResources host
  allocatable = ResourceVector (hostCpu resources) (hostMemory resources) (hostEphemeral resources) (hostPods resources)
  nodeAt index =
    Node
      { nodeId = hostText <> "-" <> natural index
      , nodeHostId = hostText
      , nodeEnvironment = NativeLinux
      , nodeCapacity = NodeCapacity allocatable NoCpuOvercommit Map.empty
      , nodeTaints = Set.empty
      }

-- | The deployment's application, its bindings, and the cluster they run on, checked in
-- this order: the deployment names an application, every need is bound, and every
-- binding answers a need.
lowerDeployment :: RootInForceSpec -> Either LowerRefusal Lowered
lowerDeployment root = do
  cluster <- soleCluster (rootClusters root)
  deployment <- soleDeployment (rootDeployments root)
  named <- applicationNamed root deployment
  app <- soleApp (rootApps root) named
  checkCoverage app deployment
  topology <- lowerTopology cluster
  services <- mapM (serviceFor deployment) (NonEmpty.toList (appNeeds app))
  unit <- appUnit app (distributionReplicas (deploymentDistribution deployment))
  let bound =
        BoundApp
          { boundAppName = appNameText (appName app)
          , boundAppExecution = unit
          , boundAppNeeds = map (renderCapabilityNeedSurface . fst) services
          }
  assembled <- either (Left . AssemblyRefused . Text.pack . show) Right (assembleWithApps FirstDeployment Nothing Nothing (map snd services) [bound])
  let BoundExecutionSet units = boundDeploymentExecutions assembled
      supply = StandaloneRoot (TargetSupply InfrastructureAlreadyPresent (capacityOf topology) (Map.keysSet units) supplySnapshot)
  pure
    Lowered
      { loweredCluster = clusterNameText (clusterName cluster)
      , loweredTopology = topology
      , loweredDeployment = assembled
      , loweredSupply = supply
      , loweredApp = bound
      }

soleCluster :: NonEmpty ClusterSpec -> Either LowerRefusal ClusterSpec
soleCluster clusters = case clusters of
  cluster :| [] -> Right cluster
  _ -> Left OutsideScope

soleDeployment :: [DeploymentRules] -> Either LowerRefusal DeploymentRules
soleDeployment deployments = case deployments of
  [deployment] -> Right deployment
  _ -> Left OutsideScope

applicationNamed :: RootInForceSpec -> DeploymentRules -> Either LowerRefusal AppName
applicationNamed root deployment = case [name | app <- rootApps root, let name = appName app, name == deploymentOf deployment] of
  name : _ -> Right name
  [] -> Left (UnknownDeployment (appNameText (deploymentOf deployment)))

soleApp :: [AppSpec] -> AppName -> Either LowerRefusal AppSpec
soleApp apps name = case apps of
  [app] | appName app == name -> Right app
  _ -> Left OutsideScope

checkCoverage :: AppSpec -> DeploymentRules -> Either LowerRefusal ()
checkCoverage app deployment = do
  case [name | name <- needNames, name `notElem` bindingNames] of
    name : _ -> Left (UnboundNeed name)
    [] -> Right ()
  case [name | name <- bindingNames, name `notElem` needNames] of
    name : _ -> Left (DanglingBinding name)
    [] -> Right ()
 where
  needNames = map (needNameText . needName) (NonEmpty.toList (appNeeds app))
  bindingNames = map (needNameText . bindingNeed) (NonEmpty.toList (deploymentBindings deployment))

-- | The need and the provider service bound to it.
serviceFor :: DeploymentRules -> NeedSpec -> Either LowerRefusal (CapabilityNeed, BoundServiceSpec)
serviceFor deployment need = do
  capability <- capabilityNeed need
  case [binding | binding <- NonEmpty.toList (deploymentBindings deployment), bindingNeed binding == needName need] of
    binding : _ -> Right (capability, bind capability (CapabilityBinding (bindingProvider binding) (bindingShape binding)))
    [] -> Left (UnboundNeed (needNameText (needName need)))

capabilityNeed :: NeedSpec -> Either LowerRefusal CapabilityNeed
capabilityNeed need = case needCapability need of
  ObjectStore -> Right (ObjectStoreNeed name)
  SecretStore -> Right (SecretStoreNeed name)
  MessageBus -> Right (MessageBusNeed name)
  Sql -> Right (SqlNeed name)
  Identity -> Right (IdentityNeed name)
  Observability -> Right (ObservabilityNeed name)
  Registry -> Right (RegistryNeed name)
  Edge -> Right (EdgeNeed name)
  InferenceEngine -> Left UnloweredArm
 where
  name = needNameText (needName need)

-- | The application's unit: a deployment of the authored replica count whose envelope
-- holds the authored requests, limits, and headroom, each with the pod slot it occupies.
appUnit :: AppSpec -> Replicas -> Either LowerRefusal BoundExecutionUnit
appUnit app replicas = do
  envelope <- either (Left . AssemblyRefused . Text.pack . show) Right (mkResourceEnvelope (podVector (workloadRequests workload)) (podVector (workloadLimits workload)) (padVector (workloadHeadroom workload)))
  pure
    BoundExecutionUnit
      { executionUnitId = "app/" <> appNameText (appName app)
      , executionRevision = 1
      , executionResource = envelope
      , executionBody = DeploymentBody (replicasCount replicas) recreateRollout
      }
 where
  workload = appWorkload app

podVector :: PodResources -> ResourceVector
podVector pod = ResourceVector (podCpu pod) (podMemory pod) (podEphemeral pod) 1

padVector :: Maybe PodResources -> ResourceVector
padVector pad = case pad of
  Just pod -> ResourceVector (podCpu pod) (podMemory pod) (podEphemeral pod) 0
  Nothing -> zeroResources

-- | The capacity of the supply: every node's allocatable resources, summed.
capacityOf :: Topology -> ResourceVector
capacityOf topology = foldl addResources zeroResources (map (nodeAllocatable . nodeCapacity) (nodesOf topology))

nodesOf :: Topology -> [Node]
nodesOf topology = case topologySupply topology of
  FixedSupply nodes -> NonEmpty.toList nodes
  _ -> []

-- | The lowered dump: one tab-separated key and value per line, in a fixed order.
dumpLowered :: Lowered -> Text
dumpLowered lowered = rows (topologyRows lowered <> appRows lowered <> serviceRows lowered <> supplyRows lowered)

topologyRows :: Lowered -> [Text]
topologyRows lowered =
  [ row "topology.cluster" (loweredCluster lowered)
  , row "topology.engine" (Text.pack (show (topologyEngine (loweredTopology lowered))))
  , row "topology.nodes" (commas (map nodeId nodes))
  ]
    <> concatMap nodeRows nodes
 where
  nodes = nodesOf (loweredTopology lowered)

nodeRows :: Node -> [Text]
nodeRows node = [row (base <> ".host") (nodeHostId node), row (base <> ".allocatable") (vector (nodeAllocatable (nodeCapacity node))), row (base <> ".taints") (commas (Set.toAscList (nodeTaints node)))]
 where
  base = "topology.node." <> nodeId node

appRows :: Lowered -> [Text]
appRows lowered =
  [ row "bound.app" name
  , row (base <> ".unit") (executionUnitId unit)
  , row (base <> ".replicas") (replicasText unit)
  , row (base <> ".revision") (natural (executionRevision unit))
  , row (base <> ".envelope") (envelopeText (executionResource unit))
  , row (base <> ".needs") (commas (boundAppNeeds app))
  ]
 where
  app = loweredApp lowered
  name = boundAppName app
  unit = boundAppExecution app
  base = "bound.app." <> name

replicasText :: BoundExecutionUnit -> Text
replicasText unit = case executionBody unit of
  DeploymentBody count _ -> natural count
  _ -> "unbounded"

envelopeText :: ResourceEnvelope -> Text
envelopeText envelope = "requests=" <> vector (envelopeRequests envelope) <> ";limits=" <> vector (envelopeLimits envelope) <> ";headroom=" <> vector (envelopeHeadroom envelope)

serviceRows :: Lowered -> [Text]
serviceRows lowered = concatMap (uncurry serviceRowsFor) (Map.toList (boundDeploymentServices (loweredDeployment lowered)))

serviceRowsFor :: Text -> BoundServiceSpec -> [Text]
serviceRowsFor name service =
  [ row "bound.service" name
  , row (base <> ".arm") (Text.pack (show (capabilityArm (boundCapabilityNeed service))))
  , row (base <> ".provider") (Text.pack (show (boundProvider service)))
  , row (base <> ".product") (boundProviderProduct service)
  , row (base <> ".shape") (Text.pack (show (boundShape service)))
  , row (base <> ".objects") (commas (map objectText (boundProviderGraph service)))
  , row (base <> ".controllers") (commas [executionUnitId unit <> ":" <> Text.pack (show (executionBody unit)) | unit <- Map.elems units])
  , row (base <> ".intents") (commas (map (Text.pack . show) (boundProviderIntents service)))
  ]
 where
  base = "bound.service." <> name
  BoundExecutionSet units = boundServiceExecutions service

objectText :: ProviderObject -> Text
objectText object = providerObjectIdentity object <> ":" <> providerObjectKind object <> ":" <> providerObjectRole object

supplyRows :: Lowered -> [Text]
supplyRows lowered =
  [ row "bound.units" (commas (Set.toAscList (Map.keysSet units)))
  , row "supply.state" (Text.pack (show state))
  , row "supply.capacity" (vector capacity)
  , row "supply.snapshot" (natural snapshot)
  , row "supply.identities" (commas (Set.toAscList identities))
  ]
 where
  BoundExecutionSet units = boundDeploymentExecutions (loweredDeployment lowered)
  (state, capacity, identities, snapshot) = supplyParts (loweredSupply lowered)

supplyParts :: ProvisionTargetSupply -> (InfrastructureState, ResourceVector, Set.Set Text, Natural)
supplyParts supply = case supply of
  StandaloneRoot target -> (targetSupplyState target, targetSupplyCapacity target, targetSupplyIdentities target, targetSupplySnapshotVersion target)
  ForestMember budget -> (clusterBudgetState budget, clusterBudgetCapacity budget, clusterBudgetIdentities budget, clusterBudgetSnapshotVersion budget)
