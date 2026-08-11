{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Ephemeral, node-scoped cache state.  Keys can only be obtained by hashing
-- bytes; the constructor is deliberately hidden.
module Amoebius.Jit.Cache
  ( CacheKey
  , cacheKeyForBytes
  , cacheKeyText
  , Resident (..)
  , CacheState
  , emptyCache
  , cacheResidents
  , lookupResident
  , storeResident
  , cacheBytes
  , pruneFor
  ) where

import Amoebius.Kernel.ContentAddress (BlobSha, blobShaText, contentAddress)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Numeric.Natural (Natural)

newtype CacheKey = CacheKey BlobSha
  deriving stock (Eq, Ord, Show)

data Resident = Resident
  { residentKey :: CacheKey
  , residentPayload :: ByteString
  , residentSizeBytes :: Natural
  , residentPinned :: Bool
  }
  deriving stock (Eq, Show)

newtype CacheState = CacheState (Map CacheKey Resident)
  deriving stock (Eq, Show)

cacheKeyForBytes :: ByteString -> CacheKey
cacheKeyForBytes = CacheKey . contentAddress

cacheKeyText :: CacheKey -> Text
cacheKeyText (CacheKey value) = blobShaText value

emptyCache :: CacheState
emptyCache = CacheState Map.empty

cacheResidents :: CacheState -> [Resident]
cacheResidents (CacheState residents) = Map.elems residents

lookupResident :: CacheKey -> CacheState -> Maybe Resident
lookupResident key (CacheState residents) = Map.lookup key residents

storeResident :: Bool -> ByteString -> CacheState -> CacheState
storeResident pinned payload (CacheState residents) =
  CacheState (Map.insertWith keepExisting key value residents)
 where
  key = cacheKeyForBytes payload
  value = Resident key payload (fromIntegral (ByteString.length payload)) pinned
  keepExisting _ existing = existing

cacheBytes :: CacheState -> Natural
cacheBytes = sum . map residentSizeBytes . cacheResidents

pruneFor :: Natural -> Natural -> CacheState -> Either Text ([CacheKey], CacheState)
pruneFor budget incoming state
  | incoming > budget = Left "CachePeakExceedsBudget"
#ifdef PHASE48_PRUNE_NOOP_MUTANT
  | otherwise = Right ([], state)
#else
  | cacheBytes state + incoming <= budget = Right ([], state)
  | otherwise = evict [] candidates state
 where
  candidates = map residentKey (filter (not . residentPinned) (cacheResidents state))
  evict removed [] current
    | cacheBytes current + incoming <= budget = Right (reverse removed, current)
    | otherwise = Left "PinnedResidentsExceedBudget"
  evict removed (key : rest) (CacheState current) =
    let next = CacheState (Map.delete key current)
     in if cacheBytes next + incoming <= budget
          then Right (reverse (key : removed), next)
          else evict (key : removed) rest next
#endif
