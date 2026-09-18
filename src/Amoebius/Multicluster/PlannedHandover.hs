

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
verifyCaughtUp snapshot = targetWatermark snapshot == sourceWatermark snapshot

plannedHandoverActions :: WatermarkSnapshot -> Either PlannedHandoverError [String]
plannedHandoverActions snapshot
  | verifyCaughtUp snapshot = Right
      [ "StartPlanned", "StandUpReplica", "Quiesce", "VerifyCaughtUp"
      , "PromotePlanned", "RepointPlannedDns", "Unfreeze", "DrainMonitor"
      , "DecommissionSource"
      ]
  | otherwise = Left TargetNotCaughtUp
