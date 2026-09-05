module OfflineRuntimeCases
  ( actionNames
  , calculusRows
  , projectionPaths
  ) where

actionNames :: [String]
actionNames =
  [ "derive-partition", "unlock", "queue", "inspect-ciphertext", "restart", "recover"
  , "claim-tab-a", "refuse-tab-b", "release-tab-a", "claim-tab-b", "migrate"
  , "upgrade-assets", "switch-partition", "quota-refusal"
  ]

projectionPaths :: [FilePath]
projectionPaths =
  [ "indexed-db.js", "opfs.js", "service-worker.js", "web-locks.js"
  , "broadcast-channel.js", "web-crypto.js"
  ]

calculusRows :: [[String]]
calculusRows =
  [ ["calculus-kinds", "artifact,budget,lift,workflow,evidence"]
  , ["component-names", "production-offline-artifacts,closed-offline-budget,browser-offline-corpus,fenced-tab-workflow,mutant-evidence"]
  , ["projection-counts", "6,7,35,14,7"]
  , ["resource-vector", "5,69,0,0"]
  ]
