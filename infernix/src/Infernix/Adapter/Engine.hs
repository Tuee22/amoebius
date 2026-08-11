{-# LANGUAGE OverloadedStrings #-}

module Infernix.Adapter.Engine
  ( CatalogIdentity
  , tinyLlamaCpuCatalog
  , catalogIdentityText
  , pinnedCpuModelBytes
  , EngineResolution (..)
  , resolveNamedEngine
  ) where

import Amoebius.Jit.CacheOwner
import Amoebius.Jit.Resolver
import Amoebius.Kernel.ContentAddress (blobShaText, contentAddress)
import Data.ByteString (ByteString)
import Data.Text (Text)

data CatalogIdentity = TinyLlamaCpuCatalog Text
  deriving stock (Eq, Ord, Show)

pinnedCpuModelBytes :: ByteString
pinnedCpuModelBytes =
  "phase49-tiny-decoder-v1|vocab=amoebius,deterministic,artifact,ready|weights=3,1,4,1,5,9"

tinyLlamaCpuCatalog :: CatalogIdentity
tinyLlamaCpuCatalog =
  TinyLlamaCpuCatalog ("catalog/tinyllama-1.1b-cpu@" <> blobShaText (contentAddress pinnedCpuModelBytes))

catalogIdentityText :: CatalogIdentity -> Text
catalogIdentityText (TinyLlamaCpuCatalog value) = value

data EngineResolution = EngineResolution
  { engineFirstMiss :: Bool
  , engineSecondHit :: Bool
  , engineResidentCount :: Int
  , engineVersion :: Text
  }
  deriving stock (Eq, Show)

resolveNamedEngine :: Either ResolverError EngineResolution
resolveNamedEngine = do
  roundTrip <- serveTwoClients Build LlamaCppCpu
  pure
    EngineResolution
      { engineFirstMiss = not (receiptCacheHit (ownerFirstReceipt roundTrip))
      , engineSecondHit = receiptCacheHit (ownerSecondReceipt roundTrip)
      , engineResidentCount = ownerResidentCount roundTrip
      , engineVersion = ownerHandleVersion roundTrip
      }
