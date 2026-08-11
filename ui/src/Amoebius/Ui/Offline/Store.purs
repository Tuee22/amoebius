module Amoebius.Ui.Offline.Store where

import Amoebius.Ui.Offline.Crypto (Ciphertext)
import Amoebius.Ui.Offline.Partition (PartitionKey)

data RecordKind
  = CachedProjection
  | QueuedCommand
  | LocalBlob
  | OfflineAuthMetadata

type StoredRecord =
  { partition :: PartitionKey
  , kind :: RecordKind
  , ciphertext :: Ciphertext
  }

data QuotaOutcome
  = Stored
  | RejectedQuota
