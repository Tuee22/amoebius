module OfflineRuntimeReference
  ( accessRows
  , assetRows
  , facilityRows
  , migrationRows
  , quotaRows
  , replayRows
  , storageRows
  ) where

storageRows :: [(String, String, Bool)]
storageRows =
  [ ("protected-record", "ciphertext", True)
  , ("offline-auth-metadata", "partition-only", True)
  , ("credentials", "absent", True)
  ]

assetRows :: [(String, String)]
assetRows = [("app.js", "admitted"), ("app.css", "admitted")]

quotaRows :: [(String, String)]
quotaRows =
  [ ("within-budget", "Stored")
  , ("over-budget-independent", "RejectedQuota")
  , ("over-budget-depended", "RejectedQuota")
  ]

accessRows :: [(String, String)]
accessRows = [("own", "allow"), ("foreign-subject", "deny"), ("foreign-tenant", "deny")]

migrationRows :: [(String, String)]
migrationRows = [("next-epoch", "allow"), ("skip-epoch", "deny"), ("regress", "deny")]

replayRows :: [(String, String)]
replayRows =
  [ ("ordered", "allow")
  , ("sequence-gap", "deny")
  , ("foreign-partition", "deny")
  , ("stale-fence", "deny")
  ]

facilityRows :: [String]
facilityRows = ["IndexedDb", "Opfs", "ServiceWorker", "WebLocks", "BroadcastChannel", "WebCrypto"]
