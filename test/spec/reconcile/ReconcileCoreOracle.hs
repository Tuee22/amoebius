{-# LANGUAGE OverloadedStrings #-}

module ReconcileCoreOracle
  ( CoreCase (..)
  , ScheduleContract (..)
  , FormalCorrespondence (..)
  , coreCases
  , scheduleContracts
  , formalCorrespondence
  , expectedFinalInventory
  , productionMutants
  ) where

import Data.Text (Text)
import Numeric.Natural (Natural)

-- This module is an independently authored semantic reading of the Phase-19
-- contract. It deliberately imports neither production reconcile module.
data CoreCase = CoreCase
  { coreCaseName :: String
  , coreDesiredSource :: Text
  , coreObservedSource :: Text
  , coreExpected :: Text
  }
  deriving (Eq, Show)

data ScheduleContract = ScheduleContract
  { oracleScheduleName :: Text
  , oracleScheduleSeed :: Int
  , oracleScheduleBound :: Natural
  , oracleDuplicateDelivery :: Bool
  , oracleCrashBeforeApply :: Bool
  , oracleStaleSnapshot :: Bool
  , oracleDelayMicros :: Int
  , oracleAcceptedWrites :: Natural
  , oracleReuseRejections :: Natural
  , oracleStaleRejections :: Natural
  , oracleRequiredEvent :: Text
  }
  deriving (Eq, Show)

data FormalCorrespondence = FormalCorrespondence
  { correspondenceProperty :: Text
  , correspondenceModel :: Text
  , correspondenceInvariant :: Text
  , correspondenceEvidence :: Text
  }
  deriving (Eq, Show)

coreCases :: [CoreCase]
coreCases =
  [ CoreCase "converged-single" "a=v1" "a=present:v1" "actions:-"
  , CoreCase "create-absent" "a=v1" "a=absent" "actions:create:a@v1"
  , CoreCase "apply-drift" "a=v2" "a=present:v1" "actions:apply:a:v1->v2"
  , CoreCase "delete-extra" "-" "a=present:v1" "actions:delete:a@v1"
  , CoreCase "mixed-three" "a=v2;b=v1" "a=present:v1;b=absent;c=present:v7" "actions:apply:a:v1->v2;create:b@v1;delete:c@v7"
  , CoreCase "empty-stable" "-" "a=absent" "actions:-"
  , CoreCase "unreachable-desired" "a=v1" "a=unreachable:timeout" "refusal:unreachable:a"
  , CoreCase "unreachable-extra" "-" "a=unreachable:partition" "refusal:unreachable:a"
  , CoreCase "missing-observation" "a=v1" "-" "refusal:missing:a"
  ]

scheduleContracts :: [ScheduleContract]
scheduleContracts =
  [ ScheduleContract "baseline" 11 8 False False False 0 3 0 0 "action-applied"
  , ScheduleContract "duplicate-delivery" 13 8 True False False 0 3 3 0 "token-rejected:reuse"
  , ScheduleContract "crash-before-apply" 17 9 False True False 1 3 0 0 "crash-before-apply"
  , ScheduleContract "stale-snapshot" 19 9 False False True 1 3 0 1 "token-rejected:stale"
  ]

formalCorrespondence :: [FormalCorrespondence]
formalCorrespondence =
  [ FormalCorrespondence "token-no-reuse" "SnapshotToken" "NoTokenReuse" "concurrent-snapshot-token-race"
  , FormalCorrespondence "reservation-one-debit" "ReservationProtocol" "OneDebitPerReservation" "concurrent-reservation-cas"
  , FormalCorrespondence "unreachable-refusal" "ReconcileProtocol" "RefuseOnUnreachable" "core-corpus-adjacent-refusal"
  , FormalCorrespondence "fixed-point-stability" "ReconcileProtocol" "ConvergedIsStable" "converged-corpus-and-simulation"
  ]

expectedFinalInventory :: [Text]
expectedFinalInventory = ["a=present:v2", "b=present:v1", "c=absent"]

productionMutants :: [(Text, Text)]
productionMutants =
  [ ("fixed-point-reemit", "FixedPoint")
  , ("oscillating-apply", "Convergence")
  , ("token-guard-removed", "NoTokenReuse")
  , ("reservation-crash-drop", "BoundRetainedAfterCrash")
  , ("delete-unreachable-witness", "DeleteRequiresPresentWitness")
  ]
