{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Total representational binding.  This module expands provider graphs but
-- deliberately imports no provision, capacity fold, or renderer.
module Amoebius.Capability.Binding
  ( bind
  , assembleBoundDeployment
  , decodeCapabilityProvider
  , validateBindingCoverage
  , validateExtensionGraph
  , boundDeploymentIsUnprovisioned
  ) where

import Amoebius.Capacity.Execution
  ( BoundExecutionUnit (..)
  , ControllerBody (..)
  , DaemonSetRollout (DaemonSetOnDelete)
  , ExecutionTransitionSource
  , StatefulSetRollout (StatefulSetNativeSerial)
  , recreateRollout
  )
import Amoebius.Capacity.Types
  ( ResourceVector (ResourceVector)
  , exactResourceEnvelope
  )
import Amoebius.Capability.Types
import Amoebius.Dsl.Error (DecodeError (..))
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

bind :: CapabilityNeed -> CapabilityBinding -> BoundServiceSpec
bind need binding =
  BoundServiceSpec
    { boundCapabilityNeed = need
    , boundProvider = bindingProvider binding
    , boundShape = bindingShape binding
    , boundProviderProduct = canonicalProduct arm
    , boundProviderGraph = graph
    , boundServiceExecutions = BoundExecutionSet executionMap
    , boundControllerChildren = children
    , boundProviderIntents = intentsFor need
    }
 where
  arm = capabilityArm need
  name = capabilityResourceName need
  graph = providerGraph arm name (bindingShape binding)
  runnable = filter isRunnable graph
  units = fmap (executionFor need) runnable
  executionMap = Map.fromList [(executionUnitId unit, unit) | unit <- units]
  children = zipWith (childFor name) runnable units

assembleBoundDeployment
  :: ExecutionTransitionSource
  -> Maybe PriorVolumeProvisionRef
  -> Maybe PriorRegistryProvisionRef
  -> [BoundServiceSpec]
  -> Either DecodeError BoundDeployment
assembleBoundDeployment transition volumeRef registryRef services = do
  serviceMap <- uniqueBy capabilityResourceNameFromSpec services
  executionMap <- mergeExecutionSets (fmap boundServiceExecutions services)
  let children = concatMap boundControllerChildren services
      childKeys = Set.fromList (fmap childIdentity children)
  if childKeys /= Map.keysSet executionMap || length children /= Map.size executionMap
    then Left (SchemaMismatch "bound-execution-set/controller-child inventory mismatch")
    else
      Right
        BoundDeployment
          { boundDeploymentTransition = transition
          , boundDeploymentServices = serviceMap
          , boundDeploymentExecutions = BoundExecutionSet executionMap
          , boundDeploymentControllerExplanations = children
          , boundPriorVolumeRef = volumeRef
          , boundPriorRegistryRef = registryRef
          }

-- | The representational bind boundary must not contain a provision result.
-- Phase 31 is the sole owner of the transition out of this state.
boundDeploymentIsUnprovisioned :: BoundDeployment -> Bool
boundDeploymentIsUnprovisioned _ =
#ifdef CAPABILITY_BIND_PROVISIONED_VALUE_MUTANT
  False
#else
  True
#endif

decodeCapabilityProvider :: Text -> Either DecodeError CapabilityProvider
decodeCapabilityProvider provider = case provider of
  "Canonical" -> Right CanonicalProvider
  unbuilt -> Left (UnbuiltProviderArm unbuilt)

validateBindingCoverage :: Set CapabilityArm -> Map CapabilityArm CapabilityBinding -> Either DecodeError ()
validateBindingCoverage declared bindings = case Set.lookupMin (declared Set.\\ Map.keysSet bindings) of
  Just missing -> Left (UnboundCapability (armName missing))
  Nothing -> Right ()

-- | Validate the closed extension provide/require graph.  Duplicate
-- providers are anti-shadowing violations; requirements are total; and a
-- DFS over provider edges rejects cycles, including self-loops.
validateExtensionGraph :: [ExtensionDescriptor] -> Either DecodeError ()
validateExtensionGraph extensions = do
  providerIndex <- buildProviderIndex extensions
  mapM_ (ensureRequirements providerIndex) extensions
  mapM_ (visit providerIndex Set.empty Set.empty) (fmap extensionName extensions)
 where
  buildProviderIndex :: [ExtensionDescriptor] -> Either DecodeError (Map CapabilityArm ExtensionName)
  buildProviderIndex = foldl insertExtension (Right Map.empty)

  insertExtension outcome extension = do
    index <- outcome
    foldl (insertCapability (extensionName extension)) (Right index) (Set.toList (extensionProvides extension))

  insertCapability owner outcome capability = do
    index <- outcome
    case Map.lookup capability index of
      Just existing -> Left (ShadowingExtension (extensionText owner <> " shadows " <> extensionText existing <> " for " <> armName capability))
      Nothing -> Right (Map.insert capability owner index)

  ensureRequirements index extension = case Set.lookupMin (extensionRequires extension Set.\\ Map.keysSet index) of
    Just missing -> Left (UnboundCapability (armName missing))
    Nothing -> Right ()

  visit index visiting visited name
    | name `Set.member` visiting = Left (CyclicExtension (extensionText name))
    | name `Set.member` visited = Right ()
    | otherwise = case findExtension name extensions of
        Nothing -> Right ()
        Just extension ->
          mapM_
            (visit index (Set.insert name visiting) (Set.insert name visited))
            [ provider
            | requirement <- Set.toList (extensionRequires extension)
            , Just provider <- [Map.lookup requirement index]
            ]

canonicalProduct :: CapabilityArm -> Text
canonicalProduct arm = case arm of
  ObjectStore -> "MinIO"
  SecretStore -> "Vault"
  MessageBus -> "Pulsar"
  Sql -> "Patroni"
  Identity -> "Keycloak"
  Observability -> "Prometheus"
  Registry -> "Distribution"
  Edge -> "Envoy"
  InferenceEngine -> "Infernix"

providerGraph :: CapabilityArm -> Text -> ServiceShape -> [ProviderObject]
providerGraph arm resource shape = serviceObject : configObject : members <> distributedObjects
 where
  prefix = armSlug arm <> "/" <> resource
  serviceObject = ProviderObject (prefix <> "/service") "Service" "stable-endpoint" Nothing
  configObject = ProviderObject (prefix <> "/config") "ConfigMap" "provider-config" Nothing
  members = fmap member (ordinals selectedNodeCount) <> bootstrapObjects
  selectedNodeCount =
#ifdef CAPABILITY_BIND_COPY_SHAPE_TAG_MUTANT
    1
#else
    shapeNodes shape
#endif
  member ordinal =
    ProviderObject
      (prefix <> "/member-" <> naturalText ordinal)
      (workloadKind arm)
      "member"
      (Just (prefix <> "/controller-" <> naturalText ordinal))
  distributedObjects = case shape of
    SingleNode -> []
#ifdef CAPABILITY_BIND_COPY_SHAPE_TAG_MUTANT
    Distributed nodes ->
      [ ProviderObject (prefix <> "/shape-" <> naturalText nodes) "ScalarTag" "shape-tag" Nothing
      ]
#else
    Distributed _ ->
      [ ProviderObject (prefix <> "/discovery") "Service" "member-discovery" Nothing
      , ProviderObject (prefix <> "/quorum-policy") "PodDisruptionBudget" "quorum-policy" Nothing
      ]
#endif
  bootstrapObjects = case arm of
    Sql -> [ProviderObject (prefix <> "/schema-bootstrap") "Job" "bootstrap" (Just (prefix <> "/schema-controller"))]
    _ -> []

executionFor :: CapabilityNeed -> ProviderObject -> BoundExecutionUnit
executionFor need object =
  BoundExecutionUnit
    { executionUnitId = providerObjectIdentity object
    , executionRevision = 1
    , executionResource = exactResourceEnvelope (resourcesFor (capabilityArm need))
    , executionBody = controllerFor need object
    }

controllerFor :: CapabilityNeed -> ProviderObject -> ControllerBody
controllerFor need object
  | providerObjectRole object == "bootstrap" = JobBody 1 1 3 600
  | otherwise = case need of
      EdgeNeed _ -> DeploymentBody 1 recreateRollout
      InferenceEngineCapabilityNeed inference -> case inferenceRuntime inference of
        AppleMetal _ -> HostProcessBody ["eligible-metal-host"] "release-drain-replace"
        Cuda _ -> DaemonSetBody ["eligible-cuda-node"] DaemonSetOnDelete
        LinuxCpu _ -> DeploymentBody 1 recreateRollout
      ObjectStoreNeed _ -> StatefulSetBody 1 StatefulSetNativeSerial
      SecretStoreNeed _ -> StatefulSetBody 1 StatefulSetNativeSerial
      MessageBusNeed _ -> StatefulSetBody 1 StatefulSetNativeSerial
      SqlNeed _ -> StatefulSetBody 1 StatefulSetNativeSerial
      IdentityNeed _ -> StatefulSetBody 1 StatefulSetNativeSerial
      ObservabilityNeed _ -> StatefulSetBody 1 StatefulSetNativeSerial
      RegistryNeed _ -> StatefulSetBody 1 StatefulSetNativeSerial

resourcesFor :: CapabilityArm -> ResourceVector
resourcesFor arm = case arm of
  ObjectStore -> ResourceVector 2 4 8 1
  SecretStore -> ResourceVector 1 2 2 1
  MessageBus -> ResourceVector 2 4 4 1
  Sql -> ResourceVector 2 4 8 1
  Identity -> ResourceVector 1 2 2 1
  Observability -> ResourceVector 2 4 8 1
  Registry -> ResourceVector 1 2 4 1
  Edge -> ResourceVector 1 1 1 1
  InferenceEngine -> ResourceVector 4 8 16 1

intentsFor :: CapabilityNeed -> [ProviderIntent]
intentsFor need = case need of
  ObjectStoreNeed name -> [ObjectStoreProducerIntent ApplicationBuckets name, ObjectStoreGatewayIntent name]
  RegistryNeed name -> [RegistryStorageProducerIntent RegistryProducer (RegistryStorageIntent name)]
  SqlNeed name -> [PatroniSqlIntent name, SchemaMigrationIntent name]
  ObservabilityNeed name -> [ObservabilityIntent name]
  other -> [GenericCapabilityIntent (capabilityArm other) (capabilityResourceName other)]

childFor :: Text -> ProviderObject -> BoundExecutionUnit -> ControllerChildEnvelope
childFor resource object unit =
  ControllerChildEnvelope
    { childIdentity = executionUnitId unit
    , childSourceObject = providerObjectIdentity object
    , childExpanderVersion = "canonical-expander-v1:" <> resource
    , childExecutionUnit = unit
    }

isRunnable :: ProviderObject -> Bool
isRunnable object = providerObjectRole object `elem` ["member", "bootstrap"]

mergeExecutionSets :: [BoundExecutionSet] -> Either DecodeError (Map Text BoundExecutionUnit)
mergeExecutionSets = foldl merge (Right Map.empty)
 where
  merge outcome (BoundExecutionSet incoming) = do
    accumulated <- outcome
    case Set.lookupMin (Map.keysSet accumulated `Set.intersection` Map.keysSet incoming) of
      Just duplicate -> Left (SchemaMismatch ("duplicate bound execution identity: " <> duplicate))
      Nothing -> Right (Map.union accumulated incoming)

uniqueBy :: Ord key => (value -> key) -> [value] -> Either DecodeError (Map key value)
uniqueBy project = foldl insertOne (Right Map.empty)
 where
  insertOne outcome value = do
    accumulated <- outcome
    let key = project value
    if Map.member key accumulated
      then Left (SchemaMismatch "duplicate bound service identity")
      else Right (Map.insert key value accumulated)

capabilityResourceNameFromSpec :: BoundServiceSpec -> Text
capabilityResourceNameFromSpec = capabilityResourceName . boundCapabilityNeed

shapeNodes :: ServiceShape -> Natural
shapeNodes shape = case shape of
  SingleNode -> 1
  Distributed nodes -> nodes

workloadKind :: CapabilityArm -> Text
workloadKind arm = case arm of
  Edge -> "Deployment"
  InferenceEngine -> "EngineWorkload"
  _ -> "StatefulSet"

armName :: CapabilityArm -> Text
armName arm = Text.pack (show arm)

armSlug :: CapabilityArm -> Text
armSlug = Text.toLower . armName

extensionText :: ExtensionName -> Text
extensionText extension = case extension of
  InfernixExtension -> "infernix"
  JitMLExtension -> "jitML"

findExtension :: ExtensionName -> [ExtensionDescriptor] -> Maybe ExtensionDescriptor
findExtension name extensions = case extensions of
  [] -> Nothing
  extension : rest
    | extensionName extension == name -> Just extension
    | otherwise -> findExtension name rest

naturalText :: Natural -> Text
naturalText = Text.pack . show

ordinals :: Natural -> [Natural]
ordinals count
  | count == 0 = []
  | otherwise = [0 .. count - 1]
