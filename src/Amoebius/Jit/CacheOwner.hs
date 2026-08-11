{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Jit.CacheOwner
  ( OwnerRoundTrip (..)
  , serveTwoClients
  , convergeSameDigestMisses
  ) where

import Amoebius.Jit.Cache (CacheState, cacheResidents, emptyCache)
import Amoebius.Jit.Resolver
import Data.Text (Text)

data OwnerRoundTrip = OwnerRoundTrip
  { ownerFirstReceipt :: ResolveReceipt
  , ownerSecondReceipt :: ResolveReceipt
  , ownerResidentCount :: Int
  , ownerHandleVersion :: Text
  }
  deriving stock (Eq, Show)

serveTwoClients :: ResolveArm -> EngineRuntime -> Either ResolverError OwnerRoundTrip
serveTwoClients arm runtime = do
  (firstHandle, afterFirst, firstReceipt) <- resolveEngine arm runtime emptyCache
  (secondHandle, afterSecond, secondReceipt) <- resolveEngine arm runtime afterFirst
  Right
    OwnerRoundTrip
      { ownerFirstReceipt = firstReceipt
      , ownerSecondReceipt = secondReceipt
      , ownerResidentCount = length (cacheResidents afterSecond)
      , ownerHandleVersion =
          if engineHandleVersion firstHandle == engineHandleVersion secondHandle
            then engineHandleVersion firstHandle
            else "version-mismatch"
      }

convergeSameDigestMisses :: ResolveArm -> EngineRuntime -> Either ResolverError CacheState
convergeSameDigestMisses arm runtime = do
  (_, afterFirst, _) <- resolveEngine arm runtime emptyCache
  (_, afterSecond, _) <- resolveEngine arm runtime afterFirst
  Right afterSecond
