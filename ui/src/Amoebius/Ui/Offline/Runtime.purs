module Amoebius.Ui.Offline.Runtime
  ( installOfflineRuntime
  , offlineCapabilities
  ) where

import Prelude

import Amoebius.Ui.Offline.Crypto (Ciphertext)
import Amoebius.Ui.Offline.Leader (LeadershipOutcome)
import Amoebius.Ui.Offline.Partition (PartitionKey)
import Amoebius.Ui.Offline.ServiceWorker (ImmutableAsset)
import Amoebius.Ui.Offline.Store (StoredRecord)
import Effect (Effect)

offlineCapabilities :: Array String
offlineCapabilities =
  [ "webcrypto-aes-gcm"
  , "indexeddb-ciphertext"
  , "opaque-scope-partition"
  , "web-lock-fencing"
  , "broadcast-handoff"
  , "immutable-service-worker-assets"
  , "explicit-quota-refusal"
  ]

-- The imported types keep the trusted browser facilities in this production component's
-- compile graph. The JavaScript FFI owns the browser APIs; authored programs see none of it.
type RuntimeBoundary =
  { ciphertext :: Ciphertext
  , partition :: PartitionKey
  , leadership :: LeadershipOutcome
  , record :: StoredRecord
  , assets :: Array ImmutableAsset
  }

foreign import installOfflineRuntime :: Array String -> Effect Unit
