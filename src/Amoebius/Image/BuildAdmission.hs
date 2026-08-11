{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Image.BuildAdmission
  ( Parallelism (..)
  , BuildStageDemand (..)
  , BuildExecutionEnvelope (..)
  , ObservedBuildHost (..)
  , BuildTransition (..)
  , BuildAdmissionError (..)
  , ValidatedBuildTarget
  , deriveBuildTransition
  , validateBuildTarget
  , admitBuildTarget
  , consumeValidatedBuildTarget
  , renderBuildAdmissionError
  ) where

import Control.DeepSeq (NFData)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Ord (Down (..))
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data Parallelism = Serial | BoundedParallel Natural
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data BuildStageDemand = BuildStageDemand
  { buildStageName :: Text
  , buildStageDependencies :: Set Text
  , buildStageCpuReservationMillis :: Natural
  , buildStageCpuCeilingMillis :: Natural
  , buildStageMemoryReservationBytes :: Natural
  , buildStageMemoryCeilingBytes :: Natural
  , buildStageIntermediateBytes :: Natural
  , buildStageCacheWriteBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BuildExecutionEnvelope = BuildExecutionEnvelope
  { buildStages :: [BuildStageDemand]
  , buildArchitectureConcurrency :: Parallelism
  , buildStageConcurrency :: Parallelism
  , buildScratchBacking :: Text
  , buildScratchCapacityBytes :: Natural
  , buildCacheBacking :: Text
  , buildCacheCapacityBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ObservedBuildHost = ObservedBuildHost
  { observedBuildFingerprint :: Text
  , observedResidualCpuMillis :: Natural
  , observedResidualMemoryBytes :: Natural
  , observedBackingCapacities :: Map Text Natural
  , observedCacheResidents :: Map Text Natural
  , observedArchitectureConcurrency :: Natural
  , observedStageConcurrency :: Natural
  , observedUnknownCommitments :: Set Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BuildTransition = BuildTransition
  { transitionCpuPeakMillis :: Natural
  , transitionMemoryPeakBytes :: Natural
  , transitionScratchPeakBytes :: Natural
  , transitionCacheWritePeakBytes :: Natural
  , transitionCacheResidentBytes :: Natural
  , transitionCachePeakBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data BuildAdmissionError
  = BuildStageSetEmpty
  | BuildStageNameDuplicate Text
  | BuildStageDependencyMissing Text Text
  | BuildStageGraphCyclic (Set Text)
  | BuildStageEnvelopeInvalid Text
  | BuildArchitectureConcurrencyInvalid
  | BuildStageConcurrencyInvalid
  | BuildUnknownCommitment (Set Text)
  | BuildCpuExceeded Natural Natural
  | BuildMemoryExceeded Natural Natural
  | BuildScratchBackingMissing Text
  | BuildScratchExceeded Natural Natural
  | BuildCacheBackingMissing Text
  | BuildCacheExceeded Natural Natural
  | BuildArchitectureConcurrencyExceeded Natural Natural
  | BuildStageConcurrencyExceeded Natural Natural
  | BuildSnapshotChanged Text Text
  | BuildTargetAlreadyConsumed
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ValidatedBuildTarget = ValidatedBuildTarget
  { validatedBuildFingerprint :: Text
  , validatedBuildTransition :: BuildTransition
  , validatedBuildConsumed :: IORef Bool
  }

deriveBuildTransition
  :: BuildExecutionEnvelope
  -> Natural
  -> Either BuildAdmissionError BuildTransition
deriveBuildTransition envelope residentBytes = do
  validateEnvelope envelope
  let architectures = parallelWidth (buildArchitectureConcurrency envelope)
      stages = parallelWidth (buildStageConcurrency envelope)
      peak projection = architectures * sumLargest stages (fmap projection (buildStages envelope))
      cpuPeak = peak buildStageCpuCeilingMillis
      memoryPeak = peak buildStageMemoryCeilingBytes
      scratchPeak = peak buildStageIntermediateBytes
      cacheWritePeak = peak buildStageCacheWriteBytes
  pure
    BuildTransition
      { transitionCpuPeakMillis = cpuPeak
      , transitionMemoryPeakBytes = memoryPeak
      , transitionScratchPeakBytes = scratchPeak
      , transitionCacheWritePeakBytes = cacheWritePeak
      , transitionCacheResidentBytes = residentBytes
      , transitionCachePeakBytes = residentBytes + cacheWritePeak
      }

validateBuildTarget
  :: BuildExecutionEnvelope
  -> ObservedBuildHost
  -> Either BuildAdmissionError BuildTransition
validateBuildTarget envelope observed = do
  if Set.null (observedUnknownCommitments observed)
    then Right ()
    else Left (BuildUnknownCommitment (observedUnknownCommitments observed))
  let archWidth = parallelWidth (buildArchitectureConcurrency envelope)
      stageWidth = parallelWidth (buildStageConcurrency envelope)
  if archWidth <= observedArchitectureConcurrency observed
    then Right ()
    else Left (BuildArchitectureConcurrencyExceeded archWidth (observedArchitectureConcurrency observed))
  if stageWidth <= observedStageConcurrency observed
    then Right ()
    else Left (BuildStageConcurrencyExceeded stageWidth (observedStageConcurrency observed))
  scratchCapacity <- backingCapacity BuildScratchBackingMissing (buildScratchBacking envelope) observed
  cacheCapacity <- backingCapacity BuildCacheBackingMissing (buildCacheBacking envelope) observed
  let scratchLimit = min scratchCapacity (buildScratchCapacityBytes envelope)
      cacheLimit = min cacheCapacity (buildCacheCapacityBytes envelope)
      residents = Map.findWithDefault 0 (buildCacheBacking envelope) (observedCacheResidents observed)
  transition <- deriveBuildTransition envelope residents
  requireWithin BuildCpuExceeded (transitionCpuPeakMillis transition) (observedResidualCpuMillis observed)
  requireWithin BuildMemoryExceeded (transitionMemoryPeakBytes transition) (observedResidualMemoryBytes observed)
  requireWithin BuildScratchExceeded (transitionScratchPeakBytes transition) scratchLimit
  requireWithin BuildCacheExceeded (transitionCachePeakBytes transition) cacheLimit
  pure transition

admitBuildTarget
  :: BuildExecutionEnvelope
  -> ObservedBuildHost
  -> IO (Either BuildAdmissionError ValidatedBuildTarget)
admitBuildTarget envelope observed = case validateBuildTarget envelope observed of
  Left problem -> pure (Left problem)
  Right transition -> do
    consumed <- newIORef False
    pure
      ( Right
          ValidatedBuildTarget
            { validatedBuildFingerprint = observedBuildFingerprint observed
            , validatedBuildTransition = transition
            , validatedBuildConsumed = consumed
            }
      )

consumeValidatedBuildTarget
  :: ValidatedBuildTarget
  -> ObservedBuildHost
  -> IO (Either BuildAdmissionError BuildTransition)
consumeValidatedBuildTarget target observed
  | validatedBuildFingerprint target /= observedBuildFingerprint observed =
      pure
        ( Left
            ( BuildSnapshotChanged
                (validatedBuildFingerprint target)
                (observedBuildFingerprint observed)
            )
        )
  | otherwise = do
      alreadyConsumed <- readIORef (validatedBuildConsumed target)
      if alreadyConsumed
        then pure (Left BuildTargetAlreadyConsumed)
        else do
          won <- atomicModifyIORef' (validatedBuildConsumed target) (\consumed -> (True, not consumed))
          pure
            ( if won
                then Right (validatedBuildTransition target)
                else Left BuildTargetAlreadyConsumed
            )

renderBuildAdmissionError :: BuildAdmissionError -> Text
renderBuildAdmissionError problem = case problem of
  BuildStageSetEmpty -> "BuildStageSetEmpty"
  BuildStageNameDuplicate _ -> "BuildStageNameDuplicate"
  BuildStageDependencyMissing _ _ -> "BuildStageDependencyMissing"
  BuildStageGraphCyclic _ -> "BuildStageGraphCyclic"
  BuildStageEnvelopeInvalid _ -> "BuildStageEnvelopeInvalid"
  BuildArchitectureConcurrencyInvalid -> "BuildArchitectureConcurrencyInvalid"
  BuildStageConcurrencyInvalid -> "BuildStageConcurrencyInvalid"
  BuildUnknownCommitment _ -> "BuildUnknownCommitment"
  BuildCpuExceeded _ _ -> "BuildCpuExceeded"
  BuildMemoryExceeded _ _ -> "BuildMemoryExceeded"
  BuildScratchBackingMissing _ -> "BuildScratchBackingMissing"
  BuildScratchExceeded _ _ -> "BuildScratchExceeded"
  BuildCacheBackingMissing _ -> "BuildCacheBackingMissing"
  BuildCacheExceeded _ _ -> "BuildCacheExceeded"
  BuildArchitectureConcurrencyExceeded _ _ -> "BuildArchitectureConcurrencyExceeded"
  BuildStageConcurrencyExceeded _ _ -> "BuildStageConcurrencyExceeded"
  BuildSnapshotChanged _ _ -> "BuildSnapshotChanged"
  BuildTargetAlreadyConsumed -> "BuildTargetAlreadyConsumed"

validateEnvelope :: BuildExecutionEnvelope -> Either BuildAdmissionError ()
validateEnvelope envelope = do
  let stages = buildStages envelope
      names = fmap buildStageName stages
      nameSet = Set.fromList names
  if null stages then Left BuildStageSetEmpty else Right ()
  case firstDuplicate names of
    Nothing -> Right ()
    Just duplicate -> Left (BuildStageNameDuplicate duplicate)
  mapM_ (validateStage nameSet) stages
  validateAcyclic stages
  if parallelWidth (buildArchitectureConcurrency envelope) > 0
    then Right ()
    else Left BuildArchitectureConcurrencyInvalid
  if parallelWidth (buildStageConcurrency envelope) > 0
    then Right ()
    else Left BuildStageConcurrencyInvalid
  if buildScratchBacking envelope == buildCacheBacking envelope
    then Left (BuildStageEnvelopeInvalid "scratch and cache backings must be distinct")
    else Right ()

validateStage :: Set Text -> BuildStageDemand -> Either BuildAdmissionError ()
validateStage names stage = do
  mapM_
    (\dependency -> if dependency `Set.member` names then Right () else Left (BuildStageDependencyMissing (buildStageName stage) dependency))
    (Set.toList (buildStageDependencies stage))
  if buildStageName stage `Set.member` buildStageDependencies stage
    then Left (BuildStageGraphCyclic (Set.singleton (buildStageName stage)))
    else Right ()
  if buildStageCpuReservationMillis stage == 0
      || buildStageCpuReservationMillis stage > buildStageCpuCeilingMillis stage
      || buildStageMemoryReservationBytes stage == 0
      || buildStageMemoryReservationBytes stage > buildStageMemoryCeilingBytes stage
      || buildStageIntermediateBytes stage == 0
      || buildStageCacheWriteBytes stage == 0
    then Left (BuildStageEnvelopeInvalid (buildStageName stage))
    else Right ()

validateAcyclic :: [BuildStageDemand] -> Either BuildAdmissionError ()
validateAcyclic stages = go Set.empty (Map.fromList [(buildStageName row, buildStageDependencies row) | row <- stages])
 where
  go resolved remaining
    | Map.null remaining = Right ()
    | null ready = Left (BuildStageGraphCyclic (Map.keysSet remaining))
    | otherwise =
        let resolved' = resolved <> Set.fromList ready
            remaining' = foldr Map.delete remaining ready
         in go resolved' remaining'
   where
    ready = [name | (name, dependencies) <- Map.toList remaining, dependencies `Set.isSubsetOf` resolved]

parallelWidth :: Parallelism -> Natural
parallelWidth parallelism = case parallelism of
  Serial -> 1
  BoundedParallel width -> width

sumLargest :: Natural -> [Natural] -> Natural
sumLargest count = sum . take (fromIntegral count) . sortOn Down

backingCapacity
  :: (Text -> BuildAdmissionError)
  -> Text
  -> ObservedBuildHost
  -> Either BuildAdmissionError Natural
backingCapacity missing name observed = case Map.lookup name (observedBackingCapacities observed) of
  Nothing -> Left (missing name)
  Just capacity -> Right capacity

requireWithin
  :: (Natural -> Natural -> BuildAdmissionError)
  -> Natural
  -> Natural
  -> Either BuildAdmissionError ()
requireWithin constructor demand supply =
  if demand <= supply then Right () else Left (constructor demand supply)

firstDuplicate :: Ord value => [value] -> Maybe value
firstDuplicate = go Set.empty
 where
  go _ [] = Nothing
  go seen (value : rest)
    | value `Set.member` seen = Just value
    | otherwise = go (Set.insert value seen) rest
