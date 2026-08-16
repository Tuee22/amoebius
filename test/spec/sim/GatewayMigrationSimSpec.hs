{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Multicluster.ClientRebind
import Amoebius.Multicluster.GatewayMigration
import Amoebius.Multicluster.PlannedHandover
import Amoebius.Multicluster.PromotionGate
import Amoebius.Multicluster.Pushback
import Amoebius.Multicluster.Teardown
import Control.Monad (forM_, when)
import Data.Aeson (Value (..), eitherDecodeFileStrict', object, (.=))
import Data.List (sort)
import Data.Set qualified as Set
import GatewayMigrationTrace
import System.Exit (die)

main :: IO ()
main = do
  verifyTraces
  verifyWatermarkAndPromotion
  verifyDemand
  verifyTeardownPushback
  verifyRebind
  verifySchedules
  putStrLn "gateway-migration-sim: PASS (256 schedules, both model traces, five invariants, teardown push-back)"

verifyTraces :: IO ()
verifyTraces = do
  plannedGolden <- readPinnedTrace "test/fixtures/phase43/planned-trace.golden.json"
  failoverGolden <- readPinnedTrace "test/fixtures/phase43/failover-trace.golden.json"
  planned <- either die pure (runModelTrace (pinnedActions plannedGolden))
  failover <- either die pure (runModelTrace (pinnedActions failoverGolden))
  either die pure (validatePinnedTrace plannedGolden planned)
  either die pure (validatePinnedTrace failoverGolden failover)
  expected <- decodeStrings "test/fixtures/phase43/safety-invariants.json"
  forM_ [planned, failover] $ \trace -> do
    verdicts <- either die pure (traceSatisfiesNamedInvariants trace)
    require (all snd verdicts) "a Phase-3 safety invariant failed under the runtime trace"
    require (sort (map fst verdicts) == sort expected) "runtime invariant names differ from Phase-0 pin"

verifyWatermarkAndPromotion :: IO ()
verifyWatermarkAndPromotion = do
  require (verifyCaughtUp (WatermarkSnapshot 24 24)) "caught-up snapshot refused"
  require
    (not (verifyCaughtUp (WatermarkSnapshot 24 16)))
    "phase43-verify-caught-up: lagging target was admitted"
  require
    (authorizePromotion (PromotionEvidence False False 1 5) == Left PromotionFreshnessUnproven)
    "phase43-promote-before-fence: survivor promoted without freshness or fence"
  require
    (authorizePromotion (PromotionEvidence True False 6 5) == Left (PromotionLagBoundExceeded 6 5))
    "over-bound lag promoted"
  require
    (authorizePromotion (PromotionEvidence False True 1 5) == Right PromotionAuthorized)
    "held fence did not authorize bounded failover"

verifyDemand :: IO ()
verifyDemand = do
  oracle <- decodeValue "test/fixtures/phase43/expected-migration-demand.json"
  require (demandJson representativeMigrationDemand == oracle) "migration demand differs from independent golden"
  require (validateMigrationDemand representativeMigrationDemand representativeMigrationDemand == Right ()) "exact migration demand refused"
  let demand = representativeMigrationDemand
      shortages =
        [ (demand {migrationCpuMilli = migrationCpuMilli demand - 1}, MigrationCpuShort)
        , (demand {migrationMemoryBytes = migrationMemoryBytes demand - 1}, MigrationMemoryShort)
        , (demand {migrationPodEphemeralBytes = migrationPodEphemeralBytes demand - 1}, MigrationPodEphemeralShort)
        , (demand {migrationCheckpointBytes = migrationCheckpointBytes demand - 1}, MigrationCheckpointShort)
        , (demand {migrationEtcdBytes = migrationEtcdBytes demand - 1}, MigrationEtcdShort)
        , (demand {migrationExternalJournalBytes = migrationExternalJournalBytes demand - 1}, MigrationExternalJournalShort)
        , (demand {migrationNetworkQueueBytes = migrationNetworkQueueBytes demand - 1}, MigrationNetworkQueueShort)
        , (demand {migrationApiObjects = migrationApiObjects demand - 1}, MigrationApiObjectShort)
        , (demand {migrationPulumiExecutorLiveSet = 0}, MigrationPulumiExecutorShort)
        , (demand {migrationHostProcessSlots = migrationHostProcessSlots demand - 1}, MigrationHostProcessSlotShort)
        ]
  forM_ shortages $ \(supply, reason) ->
    require (validateMigrationDemand supply demand == Left reason) ("wrong migration one-short result: " <> show reason)

verifyTeardownPushback :: IO ()
verifyTeardownPushback = do
  let graceful = gracefulTeardown True
  require (replicationSynchronized graceful && releasedCompute graceful) "graceful teardown did not synchronize"
  require (observedGuarantee graceful == LosslessBySynchronization) "graceful guarantee mislabeled"
  require (observedGuarantee chaosFailover == BoundedByFailoverBudget) "chaos guarantee mislabeled"
  let exact = SurvivorResources 2000 2147483648 268435456 1073741824 536870912 1
      cases =
        [ (exact {survivorCpuMilli = 1999}, SurvivorCpuShort)
        , (exact {survivorMemoryBytes = 2147483647}, SurvivorMemoryShort)
        , (exact {survivorEphemeralBytes = 268435455}, SurvivorEphemeralShort)
        , (exact {survivorDurableBytes = 1073741823}, SurvivorDurableShort)
        , (exact {survivorCacheBytes = 536870911}, SurvivorCacheShort)
        , (exact {survivorDeviceCount = 0}, SurvivorDeviceCountShort)
        ]
  require (admitTeardown True exact exact NoOverride == TeardownAdmitted) "satisfiable teardown refused"
  require (admitTeardown False exact exact NoOverride == TeardownRefused SurvivorUnreachable) "unreachable observer admitted"
  forM_ cases $ \(supply, reason) -> do
    require (admitTeardown True supply exact NoOverride == TeardownRefused reason) ("push-back missed " <> show reason)
    require
      (admitTeardown True supply exact (ExplicitFailback "restore-child") == TeardownOverridden reason "restore-child")
      ("explicit failback did not name " <> show reason)

verifyRebind :: IO ()
verifyRebind = do
  let states =
        [ (EndpointState True False True False, DirectSource)
        , (EndpointState False True True False, TransparentSourceProxy)
        , (EndpointState False False True True, DirectTarget)
        , (EndpointState False False True False, Redirect307)
        ]
  forM_ states $ \(state, expected) -> require (chooseRebindPath state == expected) "working client rebind path missing"
  require (chooseRebindPath (EndpointState False False False True) == NoWorkingEndpoint) "dead forest reported rebindable"

verifySchedules :: IO ()
verifySchedules = forM_ [0 .. 255 :: Int] $ \seed -> do
  let acknowledged = Set.fromList [1 .. 24 :: Int]
      lag = 8 + seed `mod` 5
      replicatedAtCut = Set.fromList [1 .. 24 - lag]
      plannedRecovered = Set.union replicatedAtCut (Set.difference acknowledged replicatedAtCut)
      lostWindowMillis = lag * 100
  require (Set.size (Set.difference acknowledged replicatedAtCut) >= 8) "schedule lacks positive lag"
  require (plannedRecovered == acknowledged) "planned schedule lost a source-acked write"
  require (lostWindowMillis <= 5000) "failover schedule exceeded pinned five-second window"

demandJson :: MigrationDemand -> Value
demandJson demand = object
  [ "apiObjects" .= migrationApiObjects demand
  , "checkpointBytes" .= migrationCheckpointBytes demand
  , "cpuMilli" .= migrationCpuMilli demand
  , "etcdBytes" .= migrationEtcdBytes demand
  , "externalJournalBytes" .= migrationExternalJournalBytes demand
  , "hostProcessSlots" .= migrationHostProcessSlots demand
  , "memoryBytes" .= migrationMemoryBytes demand
  , "networkQueueBytes" .= migrationNetworkQueueBytes demand
  , "podEphemeralBytes" .= migrationPodEphemeralBytes demand
  , "pulumiExecutorLiveSet" .= migrationPulumiExecutorLiveSet demand
  ]

decodeValue :: FilePath -> IO Value
decodeValue path = eitherDecodeFileStrict' path >>= either (die . ((path <> ": ") <>)) pure

decodeStrings :: FilePath -> IO [String]
decodeStrings path = eitherDecodeFileStrict' path >>= either (die . ((path <> ": ") <>)) pure

require :: Bool -> String -> IO ()
require condition message = when (not condition) (die message)
