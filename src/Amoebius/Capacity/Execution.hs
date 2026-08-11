{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Pure execution-controller expansion.  The result retains every steady and
-- transition epoch; callers cannot replace it with a scalar multiplier.
module Amoebius.Capacity.Execution
  ( ExecutionTransitionSource (..)
  , PriorExecutionProvision (..)
  , DeploymentRollout
  , recreateRollout
  , mkRollingUpdate
  , StatefulSetRollout (..)
  , DaemonSetRollout (..)
  , ControllerBody (..)
  , BoundExecutionUnit (..)
  , BoundExecutionInventory (..)
  , MaterializedExecutionInstance (..)
  , ExecutionEpoch (..)
  , ProvisionedExecutionEpochs (..)
  , ExecutionError (..)
  , provisionExecutionEpochs
  , resourcePeak
  ) where

import Amoebius.Capacity.Types
  ( Axis (..)
  , ResourceEnvelope
  , ResourceVector (..)
  , addResources
  , envelopeHeadroom
  , envelopeRequests
  , zeroResources
  )
import Control.DeepSeq (NFData)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ExecutionTransitionSource
  = FirstDeployment
  | UpdateFrom Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data PriorExecutionProvision = PriorExecutionProvision
  { priorProvisionRef :: Text
  , priorSteadyInstances :: Map Text MaterializedExecutionInstance
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data DeploymentRollout
  = RecreateRollout
  | RollingUpdate Natural Natural
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

recreateRollout :: DeploymentRollout
recreateRollout = RecreateRollout

mkRollingUpdate :: Natural -> Natural -> Either ExecutionError DeploymentRollout
mkRollingUpdate surge unavailable
  | surge == 0 && unavailable == 0 = Left (InvalidExecutionPolicy "Deployment rolling policy cannot make zero progress")
  | otherwise = Right (RollingUpdate surge unavailable)

data StatefulSetRollout = StatefulSetOnDelete | StatefulSetNativeSerial
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data DaemonSetRollout
  = DaemonSetOnDelete
  | DaemonSetSurge Natural
  | DaemonSetUnavailable Natural
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ControllerBody
  = DeploymentBody Natural DeploymentRollout
  | StatefulSetBody Natural StatefulSetRollout
  | DaemonSetBody [Text] DaemonSetRollout
  | JobBody Natural Natural Natural Natural
  | HostProcessBody [Text] Text
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BoundExecutionUnit = BoundExecutionUnit
  { executionUnitId :: Text
  , executionRevision :: Natural
  , executionResource :: ResourceEnvelope
  , executionBody :: ControllerBody
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BoundExecutionInventory = BoundExecutionInventory
  { executionTransition :: ExecutionTransitionSource
  , desiredExecutionUnits :: [BoundExecutionUnit]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data MaterializedExecutionInstance = MaterializedExecutionInstance
  { executionInstanceId :: Text
  , executionInstanceSource :: Text
  , executionInstanceRevision :: Natural
  , executionInstanceOrdinal :: Natural
  , executionInstanceSlot :: Text
  , executionInstanceResource :: ResourceVector
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ExecutionEpoch = ExecutionEpoch
  { executionEpochName :: Text
  , executionEpochInstances :: Map Text MaterializedExecutionInstance
  , executionEpochResources :: ResourceVector
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedExecutionEpochs = ProvisionedExecutionEpochs
  { provisionedTransitionSource :: ExecutionTransitionSource
  , provisionedPriorSteady :: Map Text MaterializedExecutionInstance
  , provisionedDesiredSteady :: Map Text MaterializedExecutionInstance
  , provisionedEpochs :: [ExecutionEpoch]
  , provisionedExecutionPeak :: ResourceVector
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ExecutionError
  = InvalidExecutionPolicy Text
  | DuplicateExecutionUnit Text
  | PriorExecutionMissing Text
  | PriorExecutionReferenceMismatch Text Text
  | ExecutionIdentityMismatch Text
  | ExecutionOvercommit Text Axis Natural Natural
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

provisionExecutionEpochs
  :: Map Text PriorExecutionProvision
  -> ResourceVector
  -> BoundExecutionInventory
  -> Either ExecutionError ProvisionedExecutionEpochs
provisionExecutionEpochs priorCatalog available inventory = do
  ensureUniqueUnits (desiredExecutionUnits inventory)
  prior <- resolvePrior priorCatalog (executionTransition inventory)
  mapM_ validatePriorRow (Map.toList prior)
  desiredRows <- fmap concat (mapM expandSteady (desiredExecutionUnits inventory))
  desired <- uniqueInstances desiredRows
  transitionMaps <- transitionEpochs prior desired (desiredExecutionUnits inventory)
  let maps = priorEpoch prior <> transitionMaps <> [desired]
      epochs = zipWith mkEpoch (ordinals (fromIntegral (length maps))) maps
  mapM_ (ensureEpochFits available) epochs
  pure
    ProvisionedExecutionEpochs
      { provisionedTransitionSource = executionTransition inventory
      , provisionedPriorSteady = prior
      , provisionedDesiredSteady = desired
      , provisionedEpochs = epochs
      , provisionedExecutionPeak = resourcePeak (fmap executionEpochResources epochs)
      }

resolvePrior
  :: Map Text PriorExecutionProvision
  -> ExecutionTransitionSource
  -> Either ExecutionError (Map Text MaterializedExecutionInstance)
resolvePrior catalog transition = case transition of
  FirstDeployment -> Right Map.empty
  UpdateFrom reference -> case Map.lookup reference catalog of
    Nothing -> Left (PriorExecutionMissing reference)
    Just provision
      | priorProvisionRef provision /= reference ->
          Left (PriorExecutionReferenceMismatch reference (priorProvisionRef provision))
      | otherwise -> Right (priorSteadyInstances provision)

ensureUniqueUnits :: [BoundExecutionUnit] -> Either ExecutionError ()
ensureUniqueUnits units = go Set.empty (sortOn executionUnitId units)
 where
  go seen remaining = case remaining of
    [] -> Right ()
    unit : rest
      | executionUnitId unit `Set.member` seen -> Left (DuplicateExecutionUnit (executionUnitId unit))
      | otherwise -> go (Set.insert (executionUnitId unit) seen) rest

validatePriorRow :: (Text, MaterializedExecutionInstance) -> Either ExecutionError ()
validatePriorRow (key, instanceRow)
  | key /= executionInstanceId instanceRow = Left (ExecutionIdentityMismatch key)
  | otherwise = Right ()

expandSteady :: BoundExecutionUnit -> Either ExecutionError [MaterializedExecutionInstance]
expandSteady unit = case executionBody unit of
  DeploymentBody replicas policy -> validateDeployment policy >> indexed unit "deployment" replicas
  StatefulSetBody replicas _ -> indexed unit "statefulset" replicas
  DaemonSetBody slots rollout -> validateDaemon rollout >> slotted unit "daemonset" slots
  JobBody completions parallelism _ terminalRetention
    | completions == 0 -> Right []
    | parallelism == 0 -> Left (InvalidExecutionPolicy "Job parallelism must be non-zero")
    | terminalRetention == 0 -> Left (InvalidExecutionPolicy "Job terminal retention must be finite and non-zero")
    | otherwise -> indexed unit "job" (min completions parallelism)
  HostProcessBody slots replacement
    | Text.null replacement -> Left (InvalidExecutionPolicy "Host process replacement policy is empty")
    | otherwise -> slotted unit "host" slots

transitionEpochs
  :: Map Text MaterializedExecutionInstance
  -> Map Text MaterializedExecutionInstance
  -> [BoundExecutionUnit]
  -> Either ExecutionError [Map Text MaterializedExecutionInstance]
transitionEpochs prior desired units = do
  extras <- fmap concat (mapM transitionFor units)
  let combinedEpoch = unionExact prior desired
  pure (combinedEpoch : extras)
 where
  transitionFor unit = case executionBody unit of
    DeploymentBody replicas policy -> case policy of
      RecreateRollout -> Right [Map.empty]
      RollingUpdate surge _ -> do
        surgeRows <- indexedFrom unit "deployment-surge" replicas surge
        surgeMap <- uniqueInstances surgeRows
        Right [unionExact combined surgeMap]
    StatefulSetBody replicas StatefulSetNativeSerial -> do
      one <- indexedFrom unit "statefulset-next" replicas (min 1 replicas)
      oneMap <- uniqueInstances one
      Right [unionExact combined oneMap]
    StatefulSetBody _ StatefulSetOnDelete -> Right []
    DaemonSetBody slots rollout -> case rollout of
      DaemonSetOnDelete -> Right []
      DaemonSetSurge amount -> do
        rows <- indexedFrom unit "daemonset-surge" (fromIntegral (length slots)) amount
        rowsMap <- uniqueInstances rows
        Right [unionExact combined rowsMap]
      DaemonSetUnavailable _ -> Right []
    JobBody {} -> Right []
    HostProcessBody {} -> Right []
  combined = unionExact prior desired

validateDeployment :: DeploymentRollout -> Either ExecutionError ()
validateDeployment rollout = case rollout of
  RecreateRollout -> Right ()
  RollingUpdate surge unavailable
    | surge == 0 && unavailable == 0 -> Left (InvalidExecutionPolicy "Deployment rolling policy cannot make zero progress")
    | otherwise -> Right ()

validateDaemon :: DaemonSetRollout -> Either ExecutionError ()
validateDaemon rollout = case rollout of
  DaemonSetOnDelete -> Right ()
  DaemonSetSurge amount
    | amount == 0 -> Left (InvalidExecutionPolicy "DaemonSet surge must be positive")
    | otherwise -> Right ()
  DaemonSetUnavailable amount
    | amount == 0 -> Left (InvalidExecutionPolicy "DaemonSet unavailable must be positive")
    | otherwise -> Right ()

indexed :: BoundExecutionUnit -> Text -> Natural -> Either ExecutionError [MaterializedExecutionInstance]
indexed unit kind count = indexedFrom unit kind 0 count

indexedFrom :: BoundExecutionUnit -> Text -> Natural -> Natural -> Either ExecutionError [MaterializedExecutionInstance]
indexedFrom unit kind start count = Right (fmap (instanceFor unit kind) (fmap (+ start) (ordinals count)))

slotted :: BoundExecutionUnit -> Text -> [Text] -> Either ExecutionError [MaterializedExecutionInstance]
slotted unit kind slots
  | length slots /= Set.size (Set.fromList slots) = Left (ExecutionIdentityMismatch (executionUnitId unit <> ":duplicate-slot"))
  | otherwise = Right (zipWith (instanceForSlot unit kind) (ordinals (fromIntegral (length slots))) slots)

instanceFor :: BoundExecutionUnit -> Text -> Natural -> MaterializedExecutionInstance
instanceFor unit kind ordinal = instanceForSlot unit kind ordinal (Text.pack (show ordinal))

instanceForSlot :: BoundExecutionUnit -> Text -> Natural -> Text -> MaterializedExecutionInstance
instanceForSlot unit kind ordinal slot =
  MaterializedExecutionInstance
    { executionInstanceId = identity
    , executionInstanceSource = executionUnitId unit
    , executionInstanceRevision = executionRevision unit
    , executionInstanceOrdinal = ordinal
    , executionInstanceSlot = slot
    , executionInstanceResource = reserved (executionResource unit)
    }
 where
  identity =
    Text.intercalate
      ":"
      [executionUnitId unit, Text.pack (show (executionRevision unit)), kind, slot]

uniqueInstances :: [MaterializedExecutionInstance] -> Either ExecutionError (Map Text MaterializedExecutionInstance)
uniqueInstances rows = go Map.empty (sortOn executionInstanceId rows)
 where
  go result remaining = case remaining of
    [] -> Right result
    row : rest
      | Map.member (executionInstanceId row) result -> Left (ExecutionIdentityMismatch (executionInstanceId row))
      | otherwise -> go (Map.insert (executionInstanceId row) row result) rest

unionExact
  :: Map Text MaterializedExecutionInstance
  -> Map Text MaterializedExecutionInstance
  -> Map Text MaterializedExecutionInstance
unionExact = Map.union

priorEpoch :: Map Text MaterializedExecutionInstance -> [Map Text MaterializedExecutionInstance]
priorEpoch prior = if Map.null prior then [] else [prior]

mkEpoch :: Natural -> Map Text MaterializedExecutionInstance -> ExecutionEpoch
mkEpoch ordinal rows =
  ExecutionEpoch
    { executionEpochName = "epoch-" <> Text.pack (show ordinal)
    , executionEpochInstances = rows
    , executionEpochResources = foldMapResources (fmap executionInstanceResource (Map.elems rows))
    }

ensureEpochFits :: ResourceVector -> ExecutionEpoch -> Either ExecutionError ()
ensureEpochFits available epoch = case firstExceeded (executionEpochResources epoch) available of
  Nothing -> Right ()
  Just (axis, required, capacity) -> Left (ExecutionOvercommit (executionEpochName epoch) axis required capacity)

resourcePeak :: [ResourceVector] -> ResourceVector
resourcePeak rows = case rows of
  [] -> zeroResources
  first : rest -> foldl maxResources first rest

reserved :: ResourceEnvelope -> ResourceVector
reserved envelope = addResources (envelopeRequests envelope) (envelopeHeadroom envelope)

foldMapResources :: [ResourceVector] -> ResourceVector
foldMapResources = foldl addResources zeroResources

maxResources :: ResourceVector -> ResourceVector -> ResourceVector
maxResources left right =
  ResourceVector
    { resourceCpu = max (resourceCpu left) (resourceCpu right)
    , resourceMemory = max (resourceMemory left) (resourceMemory right)
    , resourceEphemeralStorage = max (resourceEphemeralStorage left) (resourceEphemeralStorage right)
    , resourcePodSlots = max (resourcePodSlots left) (resourcePodSlots right)
    }

firstExceeded :: ResourceVector -> ResourceVector -> Maybe (Axis, Natural, Natural)
firstExceeded required available
  | resourceCpu required > resourceCpu available = Just (CpuAxis, resourceCpu required, resourceCpu available)
  | resourceMemory required > resourceMemory available = Just (MemoryAxis, resourceMemory required, resourceMemory available)
  | resourceEphemeralStorage required > resourceEphemeralStorage available =
      Just (EphemeralStorageAxis, resourceEphemeralStorage required, resourceEphemeralStorage available)
  | resourcePodSlots required > resourcePodSlots available = Just (PodSlotsAxis, resourcePodSlots required, resourcePodSlots available)
  | otherwise = Nothing

ordinals :: Natural -> [Natural]
ordinals count = go 0 count
 where
  go next remaining
    | remaining == 0 = []
    | otherwise = next : go (next + 1) (remaining - 1)
