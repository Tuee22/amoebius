{-# LANGUAGE OverloadedStrings #-}

-- | Stage lower. The decoded root becomes the topology, the bound deployment, and the
-- target supply the planner reads. This module alone assembles a bound deployment, so
-- every bound deployment the pipeline holds was lowered from a decoded specification.
module Amoebius.Dsl.Lower
  ( Lowered (loweredCluster, loweredTopology, loweredDeployment, loweredSupply, loweredApp, loweredProofs, loweredExtensions)
  , LowerRefusal (..)
  , lowerRefusalTag
  , lowerTopology
  , lowerDeployment
  , dumpLowered
  ) where

import Amoebius.Capacity.Execution
  ( BoundExecutionUnit (..)
  , ControllerBody (..)
  , ExecutionTransitionSource (FirstDeployment)
  , recreateRollout
  )
import Amoebius.Capacity.Provision
  ( ClusterBudget (..)
  , InfrastructureState (InfrastructureAlreadyPresent)
  , ProvisionTargetSupply (..)
  , TargetSupply (..)
  )
import Amoebius.Capacity.Types (CpuOvercommitPolicy (NoCpuOvercommit), HostEnvironment (NativeLinux, VirtualizedLinux), Node (..), NodeRole (..), NodeCapacity (..), ResourceEnvelope, envelopeHeadroom, envelopeLimits, envelopeRequests, mkResourceEnvelope)
import Amoebius.Capacity.Vector (ResourceVector (..), addResources, zeroResources)
import Amoebius.Capability.Assemble (assembleWithApps)
import Amoebius.Capability.Binding (bind)
import Amoebius.Capability.Engine (EngineLane (..), familyAvailable)
import Amoebius.Capability.Types
  ( BoundApp (..)
  , BoundDeployment
  , BoundExecutionSet (..)
  , BoundServiceSpec (..)
  , CapabilityBinding (CapabilityBinding)
  , ControllerChildEnvelope (..)
  , CapabilityNeed (..)
  , InferenceEngineNeed (..)
  , ProviderObject (..)
  , boundDeploymentExecutions
  , boundDeploymentServices
  , capabilityArm
  , renderCapabilityNeedSurface
  )
import Amoebius.Dsl.Dump (commas, natural, row, rows, vector)
import Amoebius.Dsl.Policy (supplySnapshot)
import Amoebius.Dsl.Spec
import Amoebius.Extension.AstCheck (CheckedExtensionSource)
import Amoebius.Extension.Capability (DeclaredCapability (ServiceCapability))
import Amoebius.Extension.Config
import Amoebius.Extension.Linked qualified as Linked
import Amoebius.Extension.Spec (extId, extConfig, extRequires, extProvides, extRequiresLane)
import Amoebius.Extension.Surface qualified as Surface
import Amoebius.Scope.Attested (attest, bindingAttestation)
import Amoebius.Dsl.Topology
  ( ComputeEngine (KindEngine)
  , NodeSupply (FixedSupply)
  , Topology
  , mkTopology
  , mkRke2Topology
  , topologyEngine
  , topologySupply
  )
import Amoebius.Dsl.Topology qualified as Topology
import Amoebius.Vocabulary (CapabilityArm (..), EngineRuntime (..), Lane (..), lanesOf, extensionIdText, detectedSubstrate, detectedArchitecture, architectureName, substrateName, profileFrame, substrateProfile)
import Amoebius.Vocabulary.Frame qualified as Frame
import Amoebius.Topology.Lanes (laneLabels)
import Amoebius.Topology.Rke2 (Rke2Quorum (..))
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
  | DuplicateHostId Text
  | LinkRefused Linked.LinkRefusal
  | InferenceBindingRequired Text Text
  | LaneUnavailable Text Text
  | EngineFamilyUnavailable Text Text
  | ExtensionConfigurationMissing Text
  | ExtensionConfigurationMismatch Text
  | ExtensionDependencyBindingRequired Text Text
  | ExtensionLaneRefused Text Text
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
  DuplicateHostId _ -> "DuplicateHostId"
  LinkRefused problem -> Linked.linkRefusalTag problem
  InferenceBindingRequired {} -> "InferenceBindingRequired"
  LaneUnavailable {} -> "LaneUnavailable"
  EngineFamilyUnavailable {} -> "EngineFamilyUnavailable"
  ExtensionConfigurationMissing _ -> "ExtensionConfigurationMissing"
  ExtensionConfigurationMismatch _ -> "ExtensionConfigurationMismatch"
  ExtensionDependencyBindingRequired {} -> "ExtensionDependencyBindingRequired"
  ExtensionLaneRefused {} -> "ExtensionLaneRefused"

-- | What the stage hands on. The constructor is private.
data Lowered = Lowered
  { loweredCluster :: Text
  , loweredTopology :: Topology
  , loweredDeployment :: BoundDeployment
  , loweredSupply :: ProvisionTargetSupply
  , loweredApp :: BoundApp
  , loweredProofs :: Map.Map Text (Linked.BindingProof CheckedExtensionSource)
  , loweredExtensions :: [(Linked.ConcreteSpec, ExtensionParameters)]
  }

-- | One node container per authored replica, each carrying the host's resources.
lowerTopology :: ClusterSpec -> Either LowerRefusal Topology
lowerTopology cluster = case clusterTopology cluster of
  KindTopology host replicas -> case [nodeAt KindWorker (hostNameText (hostName host) <> "-" <> natural index) host | index <- [1 .. kindReplicasCount replicas]] of
    [] -> Left (TopologyRefused "no nodes")
    first : rest -> topologyResult (mkTopology KindEngine (FixedSupply (first :| rest)))
  Rke2Topology quorum agents -> topologyResult (mkRke2Topology (nodesQuorum quorum) (map (namedNode Rke2Agent) agents))
 where
  nodesQuorum quorum = case quorum of
    Single one -> Single (namedNode Rke2Server one)
    Three one two three -> Three (namedNode Rke2Server one) (namedNode Rke2Server two) (namedNode Rke2Server three)
    Five one two three four five -> Five (namedNode Rke2Server one) (namedNode Rke2Server two) (namedNode Rke2Server three) (namedNode Rke2Server four) (namedNode Rke2Server five)
  namedNode role host = nodeAt role (hostNameText (hostName host)) host
  topologyResult outcome = case outcome of
    Left (Topology.DuplicateHostId host) -> Left (DuplicateHostId host)
    Left problem -> Left (TopologyRefused (Text.pack (show problem)))
    Right topology -> Right topology
  nodeAt role name host =
    let hostText = hostNameText (hostName host)
        resources = hostResources host
        allocatable = ResourceVector (hostCpu resources) (hostMemory resources) (hostEphemeral resources) (hostPods resources)
        environment = case profileFrame (substrateProfile (detectedSubstrate (hostDetected host))) of
          Frame.NativeLinux -> NativeLinux
          Frame.LimaGuest -> VirtualizedLinux
          Frame.Wsl2Guest -> VirtualizedLinux
    in Node
      { nodeId = name
      , nodeHostId = hostText
      , nodeEnvironment = environment
      , nodeCapacity = NodeCapacity allocatable NoCpuOvercommit Map.empty
      , nodeTaints = hostTaints host
      , nodeDetected = hostDetected host
      , nodeRole = role
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
  links <- either (Left . LinkRefused) Right Linked.linkedExtensionSet
  proofs <- mapM (proofFor links app) (NonEmpty.toList (appNeeds app))
  let proofMap = Map.fromList [(Linked.bindingNeed proof, proof) | proof <- proofs]
  topology <- lowerTopology cluster
  extensions <- configureExtensions root app links proofs
  services <- mapM (serviceFor topology app deployment extensions proofMap) (NonEmpty.toList (appNeeds app))
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
      , loweredProofs = proofMap
      , loweredExtensions = extensions
      }

proofFor :: Linked.ConcreteLinkSet -> AppSpec -> NeedSpec -> Either LowerRefusal (Linked.BindingProof CheckedExtensionSource)
proofFor links app need = do
  subject <- maybe (Left (UnboundNeed name)) Right (applicationNeed app (needName need))
  either (Left . LinkRefused) Right (Linked.proveBinding subject links)
 where name = needNameText (needName need)

-- Configuration is data for the actual linked dependency closure. Binding is
-- resolved first, so a source-changed empty catalog refuses the exact app/need.
configureExtensions :: RootInForceSpec -> AppSpec -> Linked.ConcreteLinkSet
  -> [Linked.BindingProof CheckedExtensionSource]
  -> Either LowerRefusal [(Linked.ConcreteSpec, ExtensionParameters)]
configureExtensions root app links proofs = do
  let specifications = Linked.extensionsIn links
      requests = rootExtensions root
      requested = map requestedExtension requests
      issuers = [extId specification | specification <- specifications,
        any ((== "extension/" <> extensionIdText (extId specification)) . Linked.bindingIssuer) proofs]
      close identifiers =
        let next = Set.toList (Set.fromList (identifiers <>
              [owner | specification <- specifications, extId specification `elem` identifiers,
               requirement <- extRequires specification,
               Just (Linked.ExtensionProvider owner) <- [Linked.providerFor requirement links]]))
         in if Set.fromList next == Set.fromList identifiers then next else close next
      active = close (requested <> issuers)
  mapM_ (\identifier -> if any ((== identifier) . extId) specifications then Right ()
    else Left (LinkRefused (Linked.ProviderDeclarationAbsent identifier))) requested
  mapM configured [specification | identifier <- Linked.extensionOrder links, identifier `elem` active,
    specification <- specifications, extId specification == identifier]
 where
  configured specification = do
    parameters <- case [requestedParameters request | request <- rootExtensions root,
                        requestedExtension request == extId specification] of
      [value] -> Right value
      _ -> Left (ExtensionConfigurationMissing (extensionIdText (extId specification)))
    if parameterSchema parameters == extConfig specification then Right ()
      else Left (ExtensionConfigurationMismatch (extensionIdText (extId specification)))
    case (parameterSchema parameters, configurationReference parameters) of
      (CoordinationConfig, Just name) -> requireReference MessageBus name
      (TrainingConfig, Just name) -> requireReference ObjectStore name
      _ -> Right ()
    pure (specification, parameters)
  requireReference capability name = if any (\need -> needCapability need == capability && needNameText (needName need) == name) (NonEmpty.toList (appNeeds app))
    then Right () else Left (ExtensionDependencyBindingRequired (appNameText (appName app)) name)

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
serviceFor :: Topology -> AppSpec -> DeploymentRules
  -> [(Linked.ConcreteSpec, ExtensionParameters)] -> Map.Map Text (Linked.BindingProof CheckedExtensionSource)
  -> NeedSpec -> Either LowerRefusal (CapabilityNeed, BoundServiceSpec)
serviceFor topology app deployment extensions proofs need = do
  case [binding | binding <- NonEmpty.toList (deploymentBindings deployment), bindingNeed binding == needName need] of
    binding : _ -> do
      capability <- capabilityNeed application binding need
      case capability of
        InferenceEngineCapabilityNeed inference -> do
          let runtime = inferenceRuntime inference
              lane = case runtime of CpuRuntime -> LinuxCpuLane; Cuda -> CudaLane; AppleMetal -> AppleMetalLane
          (specification, parameters) <- case [(value, config) | (value, config) <- extensions,
              ServiceCapability InferenceEngine `elem` extProvides value] of
            [provider] -> Right provider
            _ -> Left (ExtensionLaneRefused application name)
          proof <- maybe (Left (ExtensionLaneRefused application name)) Right (Map.lookup name proofs)
          demanded <- mapM (demandedLane proof specification parameters runtime) (nodesOf topology)
          let eligible = [nodeId node | (node, required) <- zip (nodesOf topology) demanded,
                Set.null (nodeTaints node), required `elem` lanesOf (nodeDetected node)]
          if null eligible then Left (LaneUnavailable application name) else Right ()
          if familyAvailable (inferenceFamily inference) lane then Right ()
            else Left (EngineFamilyUnavailable application name)
          let service = bind capability (CapabilityBinding (bindingProvider binding) (bindingShape binding))
              BoundExecutionSet units = boundServiceExecutions service
              target unit = unit {executionBody = case executionBody unit of
                DaemonSetBody _ rollout -> DaemonSetBody eligible rollout
                HostProcessBody _ rollout -> HostProcessBody eligible rollout
                body -> body}
          Right (capability, service {boundServiceExecutions = BoundExecutionSet (Map.map target units),
            boundControllerChildren = [child {childExecutionUnit = target (childExecutionUnit child)} | child <- boundControllerChildren service]})
        _ -> Right (capability, bind capability (CapabilityBinding (bindingProvider binding) (bindingShape binding)))
    [] -> Left (UnboundNeed (needNameText (needName need)))
 where
  application = appNameText (appName app)
  name = needNameText (needName need)
  runtimeLane runtime node = case runtime of
    CpuRuntime -> LinuxCpuAt (detectedArchitecture (nodeDetected node))
    Cuda -> LinuxCudaAt (detectedArchitecture (nodeDetected node))
    AppleMetal -> AppleMetalOnHost
  demandedLane proof specification parameters runtime node = do
    nested <- either (const (Left (ExtensionLaneRefused application name))) Right $ attest (bindingAttestation proof) $ \scope -> do
      input <- either (const (Left (ExtensionLaneRefused application name))) Right
        (Surface.prepareExtensionInput scope specification parameters runtime [])
      Right (extRequiresLane specification input (detectedArchitecture (nodeDetected node)))
    required <- nested
    if required == runtimeLane runtime node then Right required else Left (ExtensionLaneRefused application name)

capabilityNeed :: Text -> BindingSpec -> NeedSpec -> Either LowerRefusal CapabilityNeed
capabilityNeed application binding need = case needCapability need of
  ObjectStore -> Right (ObjectStoreNeed name)
  SecretStore -> Right (SecretStoreNeed name)
  MessageBus -> Right (MessageBusNeed name)
  Sql -> Right (SqlNeed name)
  Identity -> Right (IdentityNeed name)
  Observability -> Right (ObservabilityNeed name)
  Registry -> Right (RegistryNeed name)
  Edge -> Right (EdgeNeed name)
  InferenceEngine -> case bindingInference binding of
    Nothing -> Left (InferenceBindingRequired application name)
    Just inference -> Right (InferenceEngineCapabilityNeed
      (InferenceEngineNeed name "extension-model" (inferenceBindingRuntime inference) (inferenceBindingFamily inference)))
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
nodeRows node = [row (base <> ".host") (nodeHostId node), row (base <> ".allocatable") (vector (nodeAllocatable (nodeCapacity node))), row (base <> ".taints") (commas (Set.toAscList (nodeTaints node))), row (base <> ".substrate") (Text.pack (substrateName (detectedSubstrate detected))), row (base <> ".architecture") (Text.pack (architectureName (detectedArchitecture detected))), row (base <> ".lanes") (commas (laneLabels detected)), row (base <> ".role") (Text.pack (show (nodeRole node)))]
 where
  base = "topology.node." <> nodeId node
  detected = nodeDetected node

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
