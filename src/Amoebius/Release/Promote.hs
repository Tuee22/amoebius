{-# LANGUAGE CPP #-}

module Amoebius.Release.Promote
  ( ETag (..)
  , PointerHead (..)
  , PointerStore
  , emptyPointerStore
  , pointerStoreFromHeads
  , pointerHeads
  , pointerHistory
  , PointerResult (..)
  , promote
  ) where

import Amoebius.Release.Environment
import Amoebius.Release.ReleaseHash
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

newtype ETag = ETag Int
  deriving stock (Eq, Ord, Show)

data PointerHead = PointerHead
  { pointerRelease :: ReleaseHash
  , pointerETag :: ETag
  }
  deriving stock (Eq, Show)

data PointerStore = PointerStore
  { pointerHeads :: Map Environment PointerHead
  , pointerHistory :: Map Environment [PointerHead]
  }
  deriving stock (Eq, Show)

emptyPointerStore :: PointerStore
emptyPointerStore = PointerStore Map.empty Map.empty

pointerStoreFromHeads :: [(Environment, PointerHead)] -> PointerStore
pointerStoreFromHeads values = PointerStore heads (Map.map (: []) heads)
 where
  heads = Map.fromList values

data PointerResult
  = PointerWritten PointerHead
  | PointerConflict (Maybe PointerHead)
  deriving stock (Eq, Show)

promote :: Environment -> Maybe ETag -> ReleaseHash -> PointerStore -> (PointerStore, PointerResult)
promote environment expected target store
#ifndef RELEASE_LIFECYCLE_BLIND_PUT_MUTANT
  | expected /= (pointerETag <$> current) = (store, PointerConflict current)
#endif
  | otherwise =
      let next = PointerHead target (ETag (maybe 1 ((+ 1) . unETag . pointerETag) current))
          heads = Map.insert environment next (pointerHeads store)
          history = Map.insertWith (flip (<>)) environment [next] (pointerHistory store)
       in (PointerStore heads history, PointerWritten next)
 where
  current = Map.lookup environment (pointerHeads store)
  unETag (ETag value) = value
