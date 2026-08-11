{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Jit.CacheBudget
  ( Observation (..)
  , ObservedResident (..)
  , AssetMaterializationDemand (..)
  , CachePopulationDemand (..)
  , CacheProvisionError (..)
  , ProvisionedCacheDemand
  , provisionedResidentBytes
  , provisionedTemporaryBytes
  , provisionedPeakBytes
  , provisionCacheDemand
  ) where

import Amoebius.Jit.Cache (CacheKey)
import Data.List (groupBy, sortBy)
import Data.Ord (Down (..), comparing)
import Numeric.Natural (Natural)

data Observation = Present | Absent | Unreachable
  deriving stock (Eq, Ord, Show)

data ObservedResident = ObservedResident
  { observedKey :: CacheKey
  , observedBytes :: Natural
  , observedDeletionRequested :: Bool
  , observedState :: Observation
  }
  deriving stock (Eq, Ord, Show)

data AssetMaterializationDemand = AssetMaterializationDemand
  { assetKey :: CacheKey
  , assetResidentBytes :: Natural
  , assetTemporaryBytes :: Natural
  }
  deriving stock (Eq, Ord, Show)

data CachePopulationDemand = CachePopulationDemand
  { populationObserved :: [ObservedResident]
  , populationSelected :: [AssetMaterializationDemand]
  , populationFirstMissConcurrency :: Natural
  , populationCacheBudgetBytes :: Natural
  , populationEmptyDirSizeLimitBytes :: Natural
  , populationEphemeralRequestBytes :: Natural
  , populationWritableAndLogHeadroomBytes :: Natural
  }
  deriving stock (Eq, Show)

data CacheProvisionError
  = ResidentSizeConflict
  | DeletionNotObserved
  | UnreachableResident
  | FirstMissConcurrencyInvalid
  | CachePeakExceedsBudget Natural Natural
  | CacheBudgetExceedsEmptyDir Natural Natural
  | OwnerEphemeralUnderReserved Natural Natural
  deriving stock (Eq, Ord, Show)

data ProvisionedCacheDemand = ProvisionedCacheDemand Natural Natural Natural
  deriving stock (Eq, Ord, Show)

provisionedResidentBytes :: ProvisionedCacheDemand -> Natural
provisionedResidentBytes (ProvisionedCacheDemand resident _ _) = resident

provisionedTemporaryBytes :: ProvisionedCacheDemand -> Natural
provisionedTemporaryBytes (ProvisionedCacheDemand _ temporary _) = temporary

provisionedPeakBytes :: ProvisionedCacheDemand -> Natural
provisionedPeakBytes (ProvisionedCacheDemand _ _ peak) = peak

provisionCacheDemand :: CachePopulationDemand -> Either CacheProvisionError ProvisionedCacheDemand
provisionCacheDemand demand = do
  if populationFirstMissConcurrency demand == 0 then Left FirstMissConcurrencyInvalid else Right ()
  observed <- traverse admitObserved (populationObserved demand)
  selected <- uniqueAssets (populationSelected demand)
  ensureConsistent observed selected
  let observedPairs = [(observedKey item, observedBytes item) | item <- observed, observedState item == Present]
      residentPairs = mergePairs observedPairs [(assetKey item, assetResidentBytes item) | item <- selected]
      resident = sum (map snd residentPairs)
      observedKeys = map fst observedPairs
      missing = filter ((`notElem` observedKeys) . assetKey) selected
      temporary = sum (take (fromIntegral (populationFirstMissConcurrency demand)) (sortBy (comparing Down) (map assetTemporaryBytes missing)))
      peak = resident + temporary
      budget = populationCacheBudgetBytes demand
      volume = populationEmptyDirSizeLimitBytes demand
      requiredRequest = volume + populationWritableAndLogHeadroomBytes demand
  if peak > budget then Left (CachePeakExceedsBudget peak budget) else Right ()
  if budget > volume then Left (CacheBudgetExceedsEmptyDir budget volume) else Right ()
  if populationEphemeralRequestBytes demand < requiredRequest
    then Left (OwnerEphemeralUnderReserved requiredRequest (populationEphemeralRequestBytes demand))
    else Right ()
  Right (ProvisionedCacheDemand resident temporary peak)
 where
  admitObserved item = case observedState item of
    Unreachable -> Left UnreachableResident
    Present | observedDeletionRequested item -> Left DeletionNotObserved
    _ -> Right item

uniqueAssets :: [AssetMaterializationDemand] -> Either CacheProvisionError [AssetMaterializationDemand]
uniqueAssets assets = traverse collapse (groupBy sameKey (sortBy (comparing assetKey) assets))
 where
  sameKey left right = assetKey left == assetKey right
  collapse [] = error "groupBy returned empty group"
  collapse group@(first : _)
    | all ((== assetResidentBytes first) . assetResidentBytes) group = Right first
    | otherwise = Left ResidentSizeConflict

ensureConsistent :: [ObservedResident] -> [AssetMaterializationDemand] -> Either CacheProvisionError ()
ensureConsistent observed selected =
  if and [observedBytes resident == assetResidentBytes asset | resident <- observed, observedState resident == Present, asset <- selected, observedKey resident == assetKey asset]
    then Right ()
    else Left ResidentSizeConflict

mergePairs :: Eq key => [(key, Natural)] -> [(key, Natural)] -> [(key, Natural)]
mergePairs = foldl insert
 where
  insert rows pair@(key, _)
    | key `elem` map fst rows = rows
    | otherwise = pair : rows
