{-# LANGUAGE OverloadedStrings #-}

-- | The one place a 'BoundDeployment' is assembled.  The constructor lives in
-- "Amoebius.Capability.Types.Internal", which no other component can import, so
-- every bound deployment passes through these two functions.
module Amoebius.Capability.Assemble
  ( assembleBoundDeployment
  , assembleWithApps
  ) where

import Amoebius.Capacity.Execution
  ( BoundExecutionUnit (..)
  , ExecutionTransitionSource
  )
import Amoebius.Capability.Types.Internal
import Amoebius.Dsl.Error (DecodeError (..))
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)

-- | A deployment of provider services alone.
assembleBoundDeployment
  :: ExecutionTransitionSource
  -> Maybe PriorVolumeProvisionRef
  -> Maybe PriorRegistryProvisionRef
  -> [BoundServiceSpec]
  -> Either DecodeError BoundDeployment
assembleBoundDeployment transition volumeRef registryRef services =
  assembleWithApps transition volumeRef registryRef services []

-- | A deployment of provider services and applications.  Each application's
-- unit joins the execution set and is explained by its own controller child, so
-- provisioning treats it exactly as it treats a provider member.
assembleWithApps
  :: ExecutionTransitionSource
  -> Maybe PriorVolumeProvisionRef
  -> Maybe PriorRegistryProvisionRef
  -> [BoundServiceSpec]
  -> [BoundApp]
  -> Either DecodeError BoundDeployment
assembleWithApps transition volumeRef registryRef services apps = do
  serviceMap <- uniqueBy capabilityResourceNameFromSpec services
  executionMap <- mergeExecutionSets (fmap boundServiceExecutions services <> fmap appExecutionSet apps)
  let children = concatMap boundControllerChildren services <> fmap appChild apps
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
          , boundDeploymentApps = apps
          }

appExecutionSet :: BoundApp -> BoundExecutionSet
appExecutionSet app = BoundExecutionSet (Map.singleton (executionUnitId (boundAppExecution app)) (boundAppExecution app))

appChild :: BoundApp -> ControllerChildEnvelope
appChild app =
  ControllerChildEnvelope
    { childIdentity = executionUnitId (boundAppExecution app)
    , childSourceObject = executionUnitId (boundAppExecution app)
    , childExpanderVersion = "canonical-expander-v1:" <> boundAppName app
    , childExecutionUnit = boundAppExecution app
    }

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
