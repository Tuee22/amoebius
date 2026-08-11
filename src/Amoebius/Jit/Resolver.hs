{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Jit.Resolver
  ( EngineRuntime (..)
  , ResolveArm (..)
  , EngineHandle
  , engineHandleKey
  , engineHandleVersion
  , ResolveReceipt (..)
  , ResolverError (..)
  , catalogPayload
  , catalogVersion
  , resolveEngine
  ) where

import Amoebius.Jit.Cache
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)

data EngineRuntime = LlamaCppCpu
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data ResolveArm = Build | Download
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data EngineHandle = EngineHandle CacheKey Text
  deriving stock (Eq, Show)

data ResolveReceipt = ResolveReceipt
  { receiptCacheHit :: Bool
  , receiptArmExecuted :: Maybe ResolveArm
  , receiptResidentKey :: CacheKey
  , receiptResidentBytes :: Int
  }
  deriving stock (Eq, Show)

data ResolverError
  = ResolvedDigestMismatch
  | ResolvedSizeMismatch Int Int
  deriving stock (Eq, Ord, Show)

catalogPayload :: EngineRuntime -> ByteString
catalogPayload LlamaCppCpu = "#!/bin/sh\nprintf 'llama.cpp-cpu 0.1.0\\n'\n"

catalogVersion :: EngineRuntime -> Text
catalogVersion LlamaCppCpu = "llama.cpp-cpu 0.1.0"

engineHandleKey :: EngineHandle -> CacheKey
engineHandleKey (EngineHandle key _) = key

engineHandleVersion :: EngineHandle -> Text
engineHandleVersion (EngineHandle _ version) = version

resolveEngine :: ResolveArm -> EngineRuntime -> CacheState -> Either ResolverError (EngineHandle, CacheState, ResolveReceipt)
resolveEngine arm runtime state =
  case lookupResident expectedKey state of
    Just resident -> Right (handle, state, receipt True Nothing resident)
    Nothing -> do
      let materialized = materialize runtime
          actualKey = cacheKeyForBytes materialized
          actualSize = ByteString.length materialized
          expectedSize = ByteString.length expected
      if actualKey /= expectedKey then Left ResolvedDigestMismatch else Right ()
      if actualSize /= expectedSize then Left (ResolvedSizeMismatch expectedSize actualSize) else Right ()
      let next = storeResident True materialized state
          resident = Resident actualKey materialized (fromIntegral actualSize) True
      Right (handle, next, receipt False (Just arm) resident)
 where
  expected = catalogPayload runtime
  expectedKey = cacheKeyForBytes expected
  handle = EngineHandle expectedKey (catalogVersion runtime)
  receipt hit executed resident = ResolveReceipt hit executed (residentKey resident) (fromIntegral (residentSizeBytes resident))

materialize :: EngineRuntime -> ByteString
materialize runtime =
#ifdef PHASE48_FIXED_MARKER_MUTANT
  "fixed-16-marker!"
#elif defined(PHASE48_ONE_BYTE_SHORT_MUTANT)
  ByteString.init (catalogPayload runtime)
#else
  catalogPayload runtime
#endif
