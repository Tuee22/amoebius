{-# LANGUAGE OverloadedStrings #-}

module ProvisionMutants
  ( provisionMutants
  , runProvisionMutant
  ) where

import Amoebius.Capacity.Execution
  ( BoundExecutionUnit (..)
  , ExecutionEpoch (..)
  , MaterializedExecutionInstance (..)
  , ProvisionedExecutionEpochs (..)
  )
import Amoebius.Capacity.Fold (effectiveReserved)
import Amoebius.Capacity.NodeLocalStorage (NodeStorageComponent (..))
import Amoebius.Capacity.Provision
  ( InfrastructureDemand (..)
  , ProvisionedSpec
  , deriveInfrastructureDemand
  , provisionErrorTag
  , provisionedExecution
  , provisionedMonitoring
  , provisionedRuntimeStorage
  )
import Amoebius.Capacity.RuntimeStorage
  ( KubeletRuntimeMetadataDemand (KubeletRuntimeMetadataDemand)
  , PodRuntimeMetadataSource (PodRuntimeMetadataSource)
  , ProvisionedKubeletRuntimeMetadataDemand (..)
  , ProvisionedNodeRuntimeStorageAccounting (..)
  , RuntimeAccountingId (PlannedExecutionSlotId)
  , RuntimeStorageError (RuntimeMetadataModelMissing)
  , provisionKubeletRuntimeMetadata
  )
import Amoebius.Capacity.Types (addResources, zeroResources)
import Amoebius.Capability.Types
  ( BoundDeployment (..)
  , BoundExecutionSet (BoundExecutionSet)
  , ServiceShape (SingleNode)
  )
import BindFixtures (CapabilityFixture (..), capabilityFixtures)
import Data.List (find)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import ProvisionFixtures
  ( ProvisionNegative (..)
  , fixtureDeployment
  , provisionFixture
  , provisionNegatives
  )
import RuntimeStorageBindingProps (expectedDesiredInstances)

provisionMutants :: [Text]
provisionMutants =
  [ "mutant_fixed_prometheus"
  , "mutant_provisioned_in_bound"
  , "mutant_unchecked_prior"
  , "mutant_drop_execution_replica"
  , "mutant_drop_surge"
  , "mutant_old_revision"
  , "mutant_wrong_revision_join"
  , "mutant_double_debit_controller_child"
  , "mutant_drop_largest_kubelet_metadata"
  , "mutant_missing_metadata_model"
  ]

runProvisionMutant :: Text -> IO Bool
runProvisionMutant mutant = case mutant of
  "mutant_fixed_prometheus" -> pure fixedPrometheusCaught
  "mutant_provisioned_in_bound" -> provisionedInBoundCaught
  "mutant_unchecked_prior" -> pure uncheckedPriorCaught
  "mutant_drop_execution_replica" -> pure dropExecutionReplicaCaught
  "mutant_drop_surge" -> pure dropSurgeCaught
  "mutant_old_revision" -> pure oldRevisionCaught
  "mutant_wrong_revision_join" -> pure wrongRevisionJoinCaught
  "mutant_double_debit_controller_child" -> pure doubleDebitCaught
  "mutant_drop_largest_kubelet_metadata" -> pure dropLargestMetadataCaught
  "mutant_missing_metadata_model" -> pure missingMetadataModelCaught
  _ -> pure False

fixedPrometheusCaught :: Bool
fixedPrometheusCaught = case (fixture "objectstore", fixture "observability") of
  (Just plain, Just monitored) -> case (provisionFixture plain SingleNode, provisionFixture monitored SingleNode) of
    (Right plainSpec, Right monitoredSpec) ->
      let originalPlain = provisionedMonitoring plainSpec
          originalMonitored = provisionedMonitoring monitoredSpec
          mutatedPlain = originalMonitored
       in originalPlain == Nothing && originalMonitored /= Nothing && mutatedPlain /= originalPlain
    _ -> False
  _ -> False

provisionedInBoundCaught :: IO Bool
provisionedInBoundCaught = do
  source <- TextIO.readFile "src/Amoebius/Capability/Types.hs"
  let afterStart = snd (Text.breakOn "data BoundDeployment" source)
      declaration = fst (Text.breakOn "data ExtensionName" afterStart)
      mutated = declaration <> "\n  , boundProvisionedSpec :: ProvisionedSpec"
      noProvisioned = not . Text.isInfixOf "Provisioned"
  pure (not (Text.null declaration) && noProvisioned declaration && not (noProvisioned mutated))

uncheckedPriorCaught :: Bool
uncheckedPriorCaught = case (fixture "observability", fixture "inferenceengine") of
  (Just observability, Just cuda) -> case find ((== "illegal_prior_provision_ref_missing") . negativeName) (provisionNegatives observability cuda) of
    Just negative ->
      hasTag "MissingPriorProvisionRef" (negativeOutcome negative)
        && isRight (negativeTwinOutcome negative)
        && not (hasTag "MissingPriorProvisionRef" (Right ()))
    Nothing -> False
  _ -> False

dropExecutionReplicaCaught :: Bool
dropExecutionReplicaCaught = all fixtureCountMatches capabilityFixtures && mutationDropsOneInstance

mutationDropsOneInstance :: Bool
mutationDropsOneInstance = case fixture "inferenceengine" of
  Nothing -> False
  Just capability -> case (fixtureDeployment capability SingleNode, provisionFixture capability SingleNode) of
    (Right deployment, Right sealed) ->
      let rows = provisionedDesiredSteady (provisionedExecution sealed)
          mutated = maybe rows (\(identity, _row) -> Map.delete identity rows) (Map.lookupMin rows)
       in Map.size rows == expectedDesiredInstances deployment
            && Map.size mutated /= expectedDesiredInstances deployment
    _ -> False

fixtureCountMatches :: CapabilityFixture -> Bool
fixtureCountMatches capability = case (fixtureDeployment capability SingleNode, provisionFixture capability SingleNode) of
  (Right deployment, Right sealed) -> Map.size (provisionedDesiredSteady (provisionedExecution sealed)) == expectedDesiredInstances deployment
  _ -> False

dropSurgeCaught :: Bool
dropSurgeCaught = any hasTransitionPeak capabilityFixtures
 where
  hasTransitionPeak capability = case provisionFixture capability SingleNode of
    Left _ -> False
    Right sealed ->
      let execution = provisionedExecution sealed
          desiredCount = Map.size (provisionedDesiredSteady execution)
          originalHasPeak = any ((> desiredCount) . Map.size . executionEpochInstances) (provisionedEpochs execution)
          mutatedEpochs = filter ((<= desiredCount) . Map.size . executionEpochInstances) (provisionedEpochs execution)
          mutatedHasPeak = any ((> desiredCount) . Map.size . executionEpochInstances) mutatedEpochs
       in originalHasPeak && not mutatedHasPeak

oldRevisionCaught :: Bool
oldRevisionCaught = withExecution $ \units rows -> case Map.lookupMin rows of
  Nothing -> False
  Just (identity, row) ->
    revisionRowsValid units rows
      && not (revisionRowsValid units (Map.insert identity row {executionInstanceRevision = executionInstanceRevision row + 1} rows))

wrongRevisionJoinCaught :: Bool
wrongRevisionJoinCaught = withExecution $ \units rows -> case Map.lookupMin rows of
  Nothing -> False
  Just (identity, row) ->
    revisionRowsValid units rows
      && not (revisionRowsValid units (Map.insert identity row {executionInstanceSource = "unknown-source"} rows))

withExecution predicate = case fixture "inferenceengine" of
  Nothing -> False
  Just capability -> case (fixtureDeployment capability SingleNode, provisionFixture capability SingleNode) of
    (Right deployment, Right sealed) ->
      let BoundExecutionSet units = boundDeploymentExecutions deployment
       in predicate units (provisionedDesiredSteady (provisionedExecution sealed))
    _ -> False

revisionRowsValid units = all rowValid . Map.elems
 where
  rowValid row = case Map.lookup (executionInstanceSource row) units of
    Nothing -> False
    Just unit -> executionInstanceRevision row == executionRevision unit

doubleDebitCaught :: Bool
doubleDebitCaught = case fixture "inferenceengine" of
  Nothing -> False
  Just capability -> case fixtureDeployment capability SingleNode of
    Left _ -> False
    Right deployment ->
      let BoundExecutionSet units = boundDeploymentExecutions deployment
          independent = foldl addResources zeroResources (fmap (effectiveReserved . executionResource) (Map.elems units))
          observed = infrastructureRequiredResources (deriveInfrastructureDemand deployment)
          mutated = addResources observed independent
       in observed == independent && mutated /= independent

dropLargestMetadataCaught :: Bool
dropLargestMetadataCaught = case fixture "inferenceengine" of
  Nothing -> False
  Just capability -> case provisionFixture capability SingleNode of
    Left _ -> False
    Right sealed ->
      let rows = concatMap (Map.elems . provisionedRuntimeRows) (provisionedRuntimeStorage sealed)
       in all hasAllMetadataComponents rows && any droppedComponentFails rows
 where
  hasAllMetadataComponents row =
    length (provisionedRuntimeComponents row) == 7
      && sum (fmap nodeStorageComponentBytes (provisionedRuntimeComponents row)) == 7
  droppedComponentFails row =
    let mutatedComponents = drop 1 (provisionedRuntimeComponents row)
     in length mutatedComponents /= 7 || sum (fmap nodeStorageComponentBytes mutatedComponents) /= 7

missingMetadataModelCaught :: Bool
missingMetadataModelCaught = case provisionKubeletRuntimeMetadata Map.empty demand of
  Left (RuntimeMetadataModelMissing "missing-model") -> True
  _ -> False
 where
  demand =
    KubeletRuntimeMetadataDemand
      (PlannedExecutionSlotId "slot")
      "missing-model"
      (PodRuntimeMetadataSource (Set.singleton "container") (Set.singleton "volume") (Set.singleton ("container", "volume")) (Set.singleton "cni"))

fixture :: Text -> Maybe CapabilityFixture
fixture slug = find ((== slug) . fixtureSlug) capabilityFixtures

hasTag expected outcome = case outcome of
  Left problem -> provisionErrorTag problem == expected
  Right _ -> False

isRight outcome = case outcome of
  Left _ -> False
  Right _ -> True
