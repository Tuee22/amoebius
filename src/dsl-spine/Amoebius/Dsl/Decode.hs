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

import Amoebius.Capability.Binding (decodeCapabilityProvider)
import Amoebius.Capability.Types (CapabilityProvider (CanonicalProvider), ServiceShape (..), mkDistributedShape)
import Amoebius.Dsl.Import (Frozen, ImportRefusal, freezeFile, frozenExpression)
import Amoebius.Dsl.Raw qualified as Raw
import Amoebius.Dsl.Spec
import Amoebius.Vocabulary (CapabilityArm (..), Quantity (..), quantityText)
import Data.Bifunctor (first)
import Data.Foldable qualified as Foldable
import Data.List.NonEmpty (NonEmpty (..))
import Data.List.NonEmpty qualified as NonEmpty
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
  mkRootInForceSpec clusters apps deployments

checkCluster :: Raw.RawCluster -> Either SpecError ClusterSpec
checkCluster raw = do
  name <- mkClusterName (Raw.clusterName raw)
  hosts <- traverse checkHost (Raw.clusterHosts raw)
  let Raw.KindTopology kind = Raw.clusterTopology raw
  case hosts of
    [] -> Left (TopologyHostUndeclared (Raw.kindHost kind))
    first' : rest -> do
      replicas <- mkKindReplicas (Raw.kindReplicas kind)
      mkClusterSpec name (Raw.kindHost kind) replicas (first' :| rest)

checkHost :: Raw.RawHost -> Either SpecError HostSpec
checkHost raw = do
  name <- mkHostName (Raw.hostName raw)
  pure (HostSpec name (HostResources (Quantity (Raw.hostCpu raw)) (Quantity (Raw.hostMemory raw)) (Quantity (Raw.hostEphemeral raw)) (Quantity (Raw.hostPods raw))))

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
  pure (BindingSpec need provider shape)

-- | The decoded dump: one tab-separated key and value per line, in a fixed order.
dumpRoot :: RootInForceSpec -> Text
dumpRoot root = Text.unlines (map row (clusterRows <> appRows <> deploymentRows))
 where
  row (key, value) = key <> "\t" <> value
  clusterRows = concat
    [ clusterRowsAt index cluster | (index, cluster) <- zip [0 :: Int ..] (NonEmpty.toList (rootClusters root)) ]
  appRows = concat [appRowsAt index app | (index, app) <- zip [0 :: Int ..] (rootApps root)]
  deploymentRows = concat
    [deploymentRowsAt index deployment | (index, deployment) <- zip [0 :: Int ..] (rootDeployments root)]

indexed :: Text -> Int -> Text
indexed prefix index = prefix <> "." <> Text.pack (show index)

natText :: Natural -> Text
natText = Text.pack . show

clusterRowsAt :: Int -> ClusterSpec -> [(Text, Text)]
clusterRowsAt index cluster =
  [ (base <> ".name", clusterNameText (clusterName cluster))
  , (base <> ".topology", "KindTopology")
  , (base <> ".topology.host", hostNameText (hostName host))
  , (base <> ".topology.replicas", natText (kindReplicasCount replicas))
  ]
    <> concat
      [ [ (hostBase <> ".name", hostNameText (hostName declared))
        , (hostBase <> ".cpu", quantityText (hostCpu resources))
        , (hostBase <> ".memory", quantityText (hostMemory resources))
        , (hostBase <> ".ephemeral", quantityText (hostEphemeral resources))
        , (hostBase <> ".pods", quantityText (hostPods resources))
        ]
      | (hostIndex, declared) <- zip [0 :: Int ..] (NonEmpty.toList (clusterHosts cluster))
      , let hostBase = base <> ".host." <> Text.pack (show hostIndex)
      , let resources = hostResources declared
      ]
 where
  base = indexed "cluster" index
  KindTopology host replicas = clusterTopology cluster

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
