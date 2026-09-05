{-# LANGUAGE CPP #-}

module Amoebius.Ui.Offline.Browser.Runtime
  ( Facility (..)
  , MigrationError (..)
  , OfflineState (..)
  , ReplayError (..)
  , initialOfflineState
  , migrateState
  , recoverReplay
  , renderRuntimeProjection
  , supportedFacilities
  ) where

import Amoebius.Ui.Offline.Browser.Leader (Generation)
import Amoebius.Ui.Offline.Browser.Partition (PartitionKey)
import Data.List (sort)

data Facility
  = IndexedDb
  | Opfs
  | ServiceWorker
  | WebLocks
  | BroadcastChannel
  | WebCrypto
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data OfflineState = OfflineState
  { offlinePartition :: PartitionKey
  , offlineSchemaEpoch :: Int
  , offlineCommittedSequence :: Int
  , offlineFence :: Generation
  }
  deriving stock (Eq, Show)

data MigrationError = MigrationSkippedEpoch | MigrationRegressed
  deriving stock (Eq, Show)

data ReplayError = ReplayPartitionMismatch | ReplayFenceMismatch | ReplaySequenceGap
  deriving stock (Eq, Show)

initialOfflineState :: PartitionKey -> Generation -> OfflineState
initialOfflineState partition generation = OfflineState partition 1 0 generation

migrateState :: Int -> OfflineState -> Either MigrationError OfflineState
migrateState target state
  | target <= offlineSchemaEpoch state = Left MigrationRegressed
  | target /= offlineSchemaEpoch state + 1 = Left MigrationSkippedEpoch
  | otherwise = Right state{offlineSchemaEpoch = target}

recoverReplay :: PartitionKey -> Generation -> [Int] -> OfflineState -> Either ReplayError OfflineState
recoverReplay partition generation pending state
  | partition /= offlinePartition state = Left ReplayPartitionMismatch
  | generation /= offlineFence state = Left ReplayFenceMismatch
  | ordered /= expected = Left ReplaySequenceGap
  | otherwise = Right state{offlineCommittedSequence = lastOr (offlineCommittedSequence state) ordered}
  where
    ordered = sort pending
    expected = [offlineCommittedSequence state + 1 .. offlineCommittedSequence state + length pending]
    lastOr fallback [] = fallback
    lastOr _ values = last values

supportedFacilities :: [Facility]
supportedFacilities = [minBound .. maxBound]

renderRuntimeProjection :: [(FilePath, String)]
renderRuntimeProjection =
  [ ("indexed-db.js", "partitionKey; encryptedEnvelope; quotaOutcome")
  , ("opfs.js", "partitionKey; encryptedBlob; dependencyRefusal")
  , ("service-worker.js", "immutablePublicAssets; digestCheck")
#ifdef ENCRYPTED_BROWSER_RUNTIME_DROP_FENCE_HOOK_MUTANT
  , ("web-locks.js", "singleOwner")
#else
  , ("web-locks.js", "partitionKey; fenceGeneration; singleOwner")
#endif
  , ("broadcast-channel.js", "partitionKey; fenceGeneration; ownerNotice")
  , ("web-crypto.js", "localUnlock; nonExtractableKey; encryptedEnvelope")
  ]
