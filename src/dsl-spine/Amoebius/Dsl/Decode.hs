{-# LANGUAGE OverloadedStrings #-}

-- | Stage decode. A frozen specification is checked against the schema derived from the
-- decoder, decoded into the authored shape, and refined into the typed root specification
-- through its smart constructors. The schema is the decoder's own expected type; no second
-- description exists to drift from it.
module Amoebius.Dsl.Decode
  ( DecodeRefusal (..)
  , decodeRefusalTag
  , rootSchema
  , decodeRoot
  , decodeFrozen
  , dumpRoot
  ) where

import Amoebius.Extension.Config qualified as Extension
import Amoebius.Vocabulary qualified as Vocabulary
import Amoebius.Capability.Binding (decodeCapabilityProvider)
import Amoebius.Capability.Types (CapabilityProvider (CanonicalProvider), ServiceShape (..), mkDistributedShape)
import Amoebius.Dsl.Import (Frozen, ImportRefusal, freezeFile, frozenExpression)
import Amoebius.Dsl.Raw qualified as Raw
import Amoebius.Dsl.Spec
import Amoebius.Vocabulary (CapabilityArm (..), Gpu (..), OsName (..), RawArch (..), Quantity (..), quantityText, detectedArchitecture, detectedSubstrate, architectureName, substrateName)
import Amoebius.Substrate.Classify (Reads (..), classify)
import Amoebius.Topology.Lanes (laneLabels)
import Amoebius.Topology.Rke2 (Rke2Quorum (..), rke2Servers)
import Data.Bifunctor (first)
import Data.Foldable qualified as Foldable
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Void (Void)
import Dhall qualified
import Dhall.Core qualified as Core
import Dhall.Src (Src)
import Dhall.TypeCheck qualified as TypeCheck
import Numeric.Natural (Natural)

data DecodeRefusal
  = DhallFailure
  | SpecRefused SpecError
  deriving stock (Eq, Show)

decodeRefusalTag :: DecodeRefusal -> Text
decodeRefusalTag refusal = case refusal of
  DhallFailure -> "DhallFailure"
  SpecRefused problem -> specErrorTag problem

-- | The Dhall type every authored specification must have: the decoder's expected type.
rootSchema :: Text
rootSchema = maybe "" Core.pretty schemaExpression

schemaExpression :: Maybe (Core.Expr Src Void)
schemaExpression = case Foldable.toList (Dhall.expected Raw.rootDecoder) of
  [expression] -> Just expression
  _ -> Nothing

-- | Typecheck against the schema, decode, and refine.
decodeRoot :: Frozen -> Either DecodeRefusal RootInForceSpec
decodeRoot frozen = do
  schema <- maybe (Left DhallFailure) Right schemaExpression
  _ <- first (const DhallFailure) (TypeCheck.typeOf (Core.Annot (frozenExpression frozen) schema))
  raw <- maybe (Left DhallFailure) Right (Dhall.rawInput Raw.rootDecoder (frozenExpression frozen))
  first SpecRefused (checkRoot raw)

-- | The one front door: a file, frozen and then decoded.
decodeFrozen :: FilePath -> IO (Either (Either ImportRefusal DecodeRefusal) RootInForceSpec)
decodeFrozen path = do
  frozen <- freezeFile path
  pure $ case frozen of
    Left refusal -> Left (Left refusal)
    Right value -> first Right (decodeRoot value)

checkRoot :: Raw.RawRoot -> Either SpecError RootInForceSpec
checkRoot raw = do
  clusters <- traverse checkCluster (Raw.rootClusters raw)
  apps <- traverse checkApp (Raw.rootApps raw)
  deployments <- traverse checkDeployment (Raw.rootDeployments raw)
  extensions <- traverse checkExtension (Raw.rootExtensions raw)
  mkRootWithExtensions clusters apps deployments extensions

checkCluster :: Raw.RawCluster -> Either SpecError ClusterSpec
checkCluster raw = do
  name <- mkClusterName (Raw.clusterName raw)
  hosts <- traverse checkHost (Raw.clusterHosts raw)
  case Raw.clusterTopology raw of
    Raw.KindTopology kind -> case hosts of
      [] -> Left (TopologyHostUndeclared (Raw.kindHost kind))
      first' : rest -> do
        replicas <- mkKindReplicas (Raw.kindReplicas kind)
        mkClusterSpec name (Raw.kindHost kind) replicas (first' :| rest)
    Raw.Rke2Topology rke2 -> do
      quorum <- case Raw.rke2Servers rke2 of
        Raw.Single one -> Single <$> named hosts one
        Raw.Three (Raw.RawThree one two three) -> Three <$> named hosts one <*> named hosts two <*> named hosts three
        Raw.Five (Raw.RawFive one two three four five) -> Five <$> named hosts one <*> named hosts two <*> named hosts three <*> named hosts four <*> named hosts five
      agents <- traverse (named hosts) (Raw.rke2Agents rke2)
      let used = map hostName (rke2Servers quorum <> agents)
          declared = map hostName hosts
      case [duplicate | duplicate <- declared, length (filter (== duplicate) declared) > 1] of
        duplicate : _ -> Left (DuplicateHost (hostNameText duplicate))
        [] -> Right ()
      case [host | host <- declared, host `notElem` used] of
        unused : _ -> Left (UnreferencedHost (hostNameText unused))
        [] -> Right (mkRke2ClusterSpec name quorum agents)
 where
  named hosts label = case [host | host <- hosts, hostNameText (hostName host) == label] of
    host : _ -> Right host
    [] -> Left (TopologyHostUndeclared label)

checkHost :: Raw.RawHost -> Either SpecError HostSpec
checkHost raw = do
  name <- mkHostName (Raw.hostName raw)
  detected <- first InvalidDetection (classify (Reads (OsName (Text.unpack (Raw.hostOs raw))) (RawArch (Text.unpack (Raw.hostArch raw))) (if Raw.hostGpu raw then GpuPresent else GpuAbsent)))
  pure (HostSpec name (HostResources (Quantity (Raw.hostCpu raw)) (Quantity (Raw.hostMemory raw)) (Quantity (Raw.hostEphemeral raw)) (Quantity (Raw.hostPods raw))) detected (Set.fromList (Raw.hostTaints raw)))

checkApp :: Raw.RawApp -> Either SpecError AppSpec
checkApp raw = do
  name <- mkAppName (Raw.appName raw)
  needs <- traverse checkNeed (Raw.needs raw)
  workload <- checkWorkload (Raw.workload raw)
  mkAppSpec name needs workload

checkNeed :: Raw.RawNeed -> Either SpecError NeedSpec
checkNeed raw = do
  name <- mkNeedName (Raw.needName raw)
  mkNeedSpec (armOf (Raw.needCapability raw)) name

armOf :: Raw.RawArm -> CapabilityArm
armOf arm = case arm of
  Raw.ObjectStore -> ObjectStore
  Raw.SecretStore -> SecretStore
  Raw.MessageBus -> MessageBus
  Raw.Sql -> Sql
  Raw.Identity -> Identity
  Raw.Observability -> Observability
  Raw.Registry -> Registry
  Raw.Edge -> Edge
  Raw.InferenceEngine -> InferenceEngine

checkWorkload :: Raw.RawWorkload -> Either SpecError WorkloadSpec
checkWorkload raw =
  mkWorkloadSpec (podOf (Raw.workloadRequests raw)) (podOf (Raw.workloadLimits raw)) (podOf <$> Raw.workloadHeadroom raw)

podOf :: Raw.RawPod -> PodResources
podOf raw = PodResources (Quantity (Raw.podCpu raw)) (Quantity (Raw.podMemory raw)) (Quantity (Raw.podEphemeral raw))

checkDeployment :: Raw.RawDeployment -> Either SpecError DeploymentRules
checkDeployment raw = do
  app <- mkAppName (Raw.deploymentOf raw)
  bindings <- traverse checkBinding (Raw.bindings raw)
  replicas <- mkReplicas (Raw.replicas (Raw.distribution raw))
  mkDeploymentRules app bindings (DistributionRule replicas)

checkBinding :: Raw.RawBinding -> Either SpecError BindingSpec
checkBinding raw = do
  need <- mkNeedName (Raw.bindingNeed raw)
  provider <- first (const (UnbuiltProviderArm (Raw.bindingProvider raw))) (decodeCapabilityProvider (Raw.bindingProvider raw))
  shape <- case Raw.bindingShape raw of
    Raw.SingleNode -> Right SingleNode
    Raw.Distributed nodes -> first (const (DistributedShape nodes)) (mkDistributedShape nodes)
  pure $ case Raw.bindingInference raw of
    Nothing -> BindingSpec need provider shape
    Just inference -> mkInferenceBindingSpec need provider shape
      (checkEngineRuntime (Raw.engineRuntime inference)) (checkInferenceFamily (Raw.engineFamily inference))

checkEngineRuntime :: Raw.RawEngineRuntime -> Vocabulary.EngineRuntime
checkEngineRuntime runtime = case runtime of
  Raw.AppleMetal -> Vocabulary.AppleMetal
  Raw.Cuda -> Vocabulary.Cuda
  Raw.LinuxCpu -> Vocabulary.CpuRuntime

checkInferenceFamily :: Raw.RawInferenceFamily -> Vocabulary.InferenceFamily
checkInferenceFamily family = case family of
  Raw.LlamaCpp -> Vocabulary.LlamaCpp
  Raw.WhisperCpp -> Vocabulary.WhisperCpp
  Raw.Onnx -> Vocabulary.Onnx
  Raw.Vllm -> Vocabulary.Vllm
  Raw.Pytorch -> Vocabulary.Pytorch
  Raw.Diffusers -> Vocabulary.Diffusers
  Raw.Transformers -> Vocabulary.Transformers
  Raw.Audiveris -> Vocabulary.Audiveris

checkExtension :: Raw.RawExtensionRequest -> Either SpecError Extension.ExtensionRequest
checkExtension raw = do
  identifier <- maybe (Left (InvalidExtensionIdentity (Raw.extensionId raw))) Right
    (Vocabulary.mkExtensionId (Raw.extensionId raw))
  parameters <- first InvalidExtensionConfiguration $ case Raw.extensionParameters raw of
    Raw.BuildCacheParameters cache -> Extension.cacheParameters
      (Raw.cacheBudgetBytes cache) (Raw.cacheTemporaryBytes cache) (Raw.cacheFirstMissConcurrency cache)
    Raw.CoordinationParameters reference -> Extension.coordinationParameters reference
    Raw.InferenceParameters budget -> Extension.inferenceParameters budget
    Raw.TrainingParameters reference -> Extension.trainingParameters reference
  Right (Extension.extensionRequest identifier parameters)

-- | The decoded dump: one tab-separated key and value per line, in a fixed order.
dumpRoot :: RootInForceSpec -> Text
dumpRoot root = Text.unlines (map row (clusterRows <> appRows <> deploymentRows <> extensionRows))
 where
  row (key, value) = key <> "\t" <> value
  clusterRows = concat
    [ clusterRowsAt index cluster | (index, cluster) <- zip [0 :: Int ..] (NonEmpty.toList (rootClusters root)) ]
  appRows = concat [appRowsAt index app | (index, app) <- zip [0 :: Int ..] (rootApps root)]
  deploymentRows = concat
    [deploymentRowsAt index deployment | (index, deployment) <- zip [0 :: Int ..] (rootDeployments root)]

  extensionRows = concat
    [ let base = indexed "extension" index
       in [(base <> ".id", Vocabulary.extensionIdText (Extension.requestedExtension request)),
           (base <> ".schema", Text.pack (show (Extension.parameterSchema parameters)))]
            <> [(base <> ".cache-budget", natText value) | Just value <- [Extension.cacheBudget parameters]]
            <> [(base <> ".cache-temporary", natText value) | Just value <- [Extension.cacheTemporary parameters]]
            <> [(base <> ".cache-concurrency", natText value) | Just value <- [Extension.cacheConcurrency parameters]]
            <> [(base <> ".reference", value) | Just value <- [Extension.configurationReference parameters]]
    | (index, request) <- zip [0 :: Int ..] (rootExtensions root)
    , let parameters = Extension.requestedParameters request
    ]


indexed :: Text -> Int -> Text
indexed prefix index = prefix <> "." <> Text.pack (show index)

natText :: Natural -> Text
natText = Text.pack . show

clusterRowsAt :: Int -> ClusterSpec -> [(Text, Text)]
clusterRowsAt index cluster =
  [ (base <> ".name", clusterNameText (clusterName cluster))
  ]
    <> topologyRows
    <> concat
      [ [ (hostBase <> ".name", hostNameText (hostName declared))
        , (hostBase <> ".cpu", quantityText (hostCpu resources))
        , (hostBase <> ".memory", quantityText (hostMemory resources))
        , (hostBase <> ".ephemeral", quantityText (hostEphemeral resources))
        , (hostBase <> ".pods", quantityText (hostPods resources))
        , (hostBase <> ".substrate", Text.pack (substrateName (detectedSubstrate (hostDetected declared))))
        , (hostBase <> ".architecture", Text.pack (architectureName (detectedArchitecture (hostDetected declared))))
        , (hostBase <> ".lanes", Text.intercalate "," (laneLabels (hostDetected declared)))
        , (hostBase <> ".taints", Text.intercalate "," (Set.toAscList (hostTaints declared)))
        ]
      | (hostIndex, declared) <- zip [0 :: Int ..] (NonEmpty.toList (clusterHosts cluster))
      , let hostBase = base <> ".host." <> Text.pack (show hostIndex)
      , let resources = hostResources declared
      ]
 where
  base = indexed "cluster" index
  topologyRows = case clusterTopology cluster of
    KindTopology host replicas -> [(base <> ".topology", "KindTopology"), (base <> ".topology.host", hostNameText (hostName host)), (base <> ".topology.replicas", natText (kindReplicasCount replicas))]
    Rke2Topology quorum agents -> [(base <> ".topology", "Rke2Topology"), (base <> ".topology.servers", Text.intercalate "," (map (hostNameText . hostName) (rke2Servers quorum))), (base <> ".topology.agents", Text.intercalate "," (map (hostNameText . hostName) agents))]

appRowsAt :: Int -> AppSpec -> [(Text, Text)]
appRowsAt index app =
  [(base <> ".name", appNameText (appName app))]
    <> concat
      [ [ (needBase <> ".capability", Text.pack (show (needCapability need)))
        , (needBase <> ".name", needNameText (needName need))
        ]
      | (needIndex, need) <- zip [0 :: Int ..] (NonEmpty.toList (appNeeds app))
      , let needBase = base <> ".need." <> Text.pack (show needIndex)
      ]
    <> [ (base <> ".workload.requests", podText (workloadRequests workload))
       , (base <> ".workload.limits", podText (workloadLimits workload))
       , (base <> ".workload.headroom", maybe "none" podText (workloadHeadroom workload))
       ]
 where
  base = indexed "app" index
  workload = appWorkload app

podText :: PodResources -> Text
podText pod = Text.intercalate "," [quantityText (podCpu pod), quantityText (podMemory pod), quantityText (podEphemeral pod)]

deploymentRowsAt :: Int -> DeploymentRules -> [(Text, Text)]
deploymentRowsAt index deployment =
  [(base <> ".app", appNameText (deploymentOf deployment))]
    <> concat
      [ [ (bindingBase <> ".need", needNameText (bindingNeed binding))
        , (bindingBase <> ".provider", providerText (bindingProvider binding))
        , (bindingBase <> ".shape", shapeText (bindingShape binding))
        ]
          <> maybe [] (\inference ->
            [(bindingBase <> ".engine-runtime", Vocabulary.engineRuntimeName (inferenceBindingRuntime inference)),
             (bindingBase <> ".engine-family", Vocabulary.inferenceFamilyName (inferenceBindingFamily inference))]) (bindingInference binding)
      | (bindingIndex, binding) <- zip [0 :: Int ..] (NonEmpty.toList (deploymentBindings deployment))
      , let bindingBase = base <> ".binding." <> Text.pack (show bindingIndex)
      ]
    <> [(base <> ".distribution.replicas", natText (replicasCount (distributionReplicas (deploymentDistribution deployment))))]
 where
  base = indexed "deployment" index

providerText :: CapabilityProvider -> Text
providerText provider = case provider of
  CanonicalProvider -> "Canonical"

shapeText :: ServiceShape -> Text
shapeText shape = case shape of
  SingleNode -> "SingleNode"
  Distributed nodes -> "Distributed " <> natText nodes
