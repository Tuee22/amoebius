{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Admission.ExecutionIdentity
import Amoebius.Manifest.Authority
import Amoebius.Scheduler.Readiness
import Data.Set qualified as Set
import Data.Text qualified as Text
import System.Exit (die)

main :: IO ()
main = do
  verifySystemAuthority
  bootstrap <- verifyBootstrapReadiness
  managed <- verifyManagedReadiness bootstrap
  verifyAdmission managed
  putStrLn "scheduler-readiness-spec: PASS (scheduler-system authority, two-stage readiness, and execution admission)"

verifySystemAuthority :: IO ()
verifySystemAuthority = do
  let demand = CapacitySchedulerSystemDemand "sha256:image" "amoebius-capacity-scheduler" 1 "node"
      lease = LeasePresent "Lease/ns/reconciler" "holder" "uid" "7"
  missing <- mintSchedulerSystemAction "holder" demand (LeaseAbsent "Lease/ns/reconciler")
  case missing of
    Left SchedulerSystemLeaseAbsent -> pure ()
    _ -> die "scheduler did not require exact Lease holder"
  wrong <- mintSchedulerSystemAction "holder" demand (LeasePresent "Lease/ns/reconciler" "foreign" "uid" "7")
  case wrong of
    Left (SchedulerSystemLeaseHolderMismatch "holder" "foreign") -> pure ()
    _ -> die "scheduler did not reject foreign Lease holder"
  token <- mintSchedulerSystemAction "holder" demand lease >>= requireRight
  assertEqual "scheduler-system token" (Right (ApplyBootstrapSchedulerSystem demand)) =<< consumeSchedulerSystemAction token
  assertEqual "scheduler-system token single use" (Left SchedulerSystemTokenAlreadyConsumed) =<< consumeSchedulerSystemAction token

verifyBootstrapReadiness :: IO BootstrapCapacitySchedulerReady
verifyBootstrapReadiness = do
  let exact = bootstrapObservation
  ready <- requireRight (observeBootstrapCapacitySchedulerReady exact)
  assertEqual "managed authority cannot install from bootstrap witness" False (authorizeBootstrapAction ready InstallManagedAuthority)
  assertEqual "general action cannot run from bootstrap witness" False (authorizeBootstrapAction ready ApplyGeneralGuardedController)
  assertEqual "enumerated cutover action allowed" True (authorizeBootstrapAction ready (CutoverEnumeratedController "addon"))
  assertEqual "config digest mismatch" (Left BootstrapConfigDigestMismatch) (observeBootstrapCapacitySchedulerReady (exact {bootstrapObservedConfigDigest = "wrong"}))
  assertEqual "managed taint must be absent" (Left BootstrapManagedAuthorityAlreadyPresent) (observeBootstrapCapacitySchedulerReady (exact {bootstrapManagedTaintAbsent = False}))
  pure ready

verifyManagedReadiness :: BootstrapCapacitySchedulerReady -> IO ManagedCapacityReady
verifyManagedReadiness bootstrap = do
  let expected = Set.fromList ["addon-a", "addon-b"]
      observations = [controller "addon-a", controller "addon-b"]
      readback = ManagedAuthorityReadback True True True True True
  assertEqual
    "complete bootstrap controller domain"
    (Left (BootstrapControllerDomainMismatch expected (Set.singleton "addon-a")))
    (observeManagedCapacityReady bootstrap expected [controller "addon-a"] readback)
  assertEqual
    "old UID release required"
    (Left (BootstrapControllerNotReleased "addon-a"))
    (observeManagedCapacityReady bootstrap expected [(controller "addon-a") {bootstrapOldUidAbsent = False}, controller "addon-b"] readback)
  assertEqual
    "independent authority readback required"
    (Left ManagedAuthorityReadbackMismatch)
    (observeManagedCapacityReady bootstrap expected observations (readback {managedExclusiveBindingRbacPresent = False}))
  requireRight (observeManagedCapacityReady bootstrap expected observations readback)

verifyAdmission :: ManagedCapacityReady -> IO ()
verifyAdmission managed = do
  let identity = guardedIdentity
  assertEqual "premature guarded workload" (Left ManagedCapacityNotReady) (admitExecutionCreate BeforeManagedCapacityReady identity)
  assertEqual "managed guarded workload" (Right ()) (admitExecutionCreate (AfterManagedCapacityReady managed) identity)
  let bypass = identity {executionSchedulerName = "default-scheduler"}
  assertEqual "default-scheduler managed-node bypass" (Left DefaultSchedulerManagedNodeBypass) (admitExecutionCreate (AfterManagedCapacityReady managed) bypass)
  let changed = identity {executionGeneration = "changed"}
  assertEqual "protected UPDATE identity" (Left ProtectedExecutionIdentityChanged) (admitExecutionUpdate (AfterManagedCapacityReady managed) identity changed)
  let bootstrap = identity {executionSchedulerName = "default-scheduler", executionToleratesManagedTaint = False, executionIsBootstrapScheduler = True}
  assertEqual "sole bootstrap exception" (Right ()) (admitExecutionCreate BeforeManagedCapacityReady bootstrap)

bootstrapObservation :: BootstrapSchedulerObservation
bootstrapObservation = BootstrapSchedulerObservation "generation" "generation" "sha256:config" "sha256:config" "17" "17" True True True True

controller :: Text.Text -> BootstrapControllerObservation
controller name = BootstrapControllerObservation name True True (name <> "-new") True True True

guardedIdentity :: ExecutionIdentity
guardedIdentity = ExecutionIdentity "deployment" "generation" "source" "revision" "sha256:template" "amoebius-capacity" True True False

requireRight :: Show problem => Either problem value -> IO value
requireRight = either (die . show) pure

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual
  | expected == actual = pure ()
  | otherwise = die (label <> ": expected " <> show expected <> ", got " <> show actual)
