module GatewayMigrationForest
  ( expectedModeledActions
  , expectedSafetyInvariants
  ) where

expectedModeledActions :: [String]
expectedModeledActions =
  [ "StartPlanned", "StandUpReplica", "Quiesce", "VerifyCaughtUp", "PromotePlanned"
  , "RepointPlannedDns", "Unfreeze", "DrainMonitor", "DecommissionSource", "ActiveCrash"
  , "ColdSeed", "PromoteSurvivor", "RepointFailoverDns", "BoundedRebind", "Heal", "MergeConverge"
  ]

expectedSafetyInvariants :: [String]
expectedSafetyInvariants =
  [ "UniqueGatewayOwner", "SessionAlwaysRebindable", "PlannedIsLossless"
  , "NoWriteAfterStaleFailover", "NoTakeWithoutProvenFreshness"
  ]
