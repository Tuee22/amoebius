{-# LANGUAGE CPP #-}

module Amoebius.Multicluster.PlannedHandover
  ( WatermarkSnapshot (..)
  , PlannedHandoverError (..)
  , verifyCaughtUp
  , plannedHandoverActions
  ) where

data WatermarkSnapshot = WatermarkSnapshot
  { sourceWatermark :: Int
  , targetWatermark :: Int
  }
  deriving stock (Eq, Show)

data PlannedHandoverError
  = TargetNotCaughtUp
  deriving stock (Eq, Show)

verifyCaughtUp :: WatermarkSnapshot -> Bool
#ifdef GATEWAY_MIGRATION_DRILLS_VERIFY_CAUGHT_UP_STUB_MUTANT
verifyCaughtUp _ = True
#else
verifyCaughtUp snapshot = targetWatermark snapshot == sourceWatermark snapshot
#endif

plannedHandoverActions :: WatermarkSnapshot -> Either PlannedHandoverError [String]
plannedHandoverActions snapshot
  | verifyCaughtUp snapshot = Right
      [ "StartPlanned", "StandUpReplica", "Quiesce", "VerifyCaughtUp"
      , "PromotePlanned", "RepointPlannedDns", "Unfreeze", "DrainMonitor"
      , "DecommissionSource"
      ]
  | otherwise = Left TargetNotCaughtUp
