{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module ObjectReconcilerSimCommon
  ( FaultClass (..)
  , Phase26Schedule (..)
  , Phase26Run (..)
  , ActionEvent (..)
  , Mutant (..)
  , allMutants
  , mutantName
  , parseMutant
  , mutantOutcome
  , runPhase26Schedule
  , replaySchedule
  , validateRun
  ) where

import Amoebius.Execution.AcceleratorRelease
import Amoebius.Execution.HostTransition
import Amoebius.Execution.JobTerminal
import Amoebius.Execution.SerialOnDelete
import Amoebius.Capacity.RenderSource (K8sObjectIdentity (..))
import Amoebius.Manifest.Actions
import Amoebius.Manifest.Apply
import Amoebius.Manifest.Authority
import Amoebius.Manifest.Delete
import Amoebius.Manifest.Wait
import Amoebius.Sim.Env
import Amoebius.Sim.Interp.Sim
import Control.Monad.Class.MonadAsync (async, wait)
import Control.Monad.Class.MonadTest (exploreRaces)
import Control.Monad.IOSim (IOSim, runSimOrThrow)
import Data.Aeson (ToJSON, encode)
import qualified Data.ByteString.Lazy as LazyByteString
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import GHC.Generics (Generic)

data FaultClass
  = LeaseAcquireFault
  | LeaseRenewAmbiguity
  | ScopedSsaConflict
  | SerialStageChange
  | HostDeviceRelease
  | CompletionWriteFailure
  | AuthenticatedDeleteConflict
  | ReadinessInterruption
  deriving stock (Bounded, Enum, Eq, Ord, Show, Generic)
  deriving anyclass (ToJSON)

data Phase26Schedule = Phase26Schedule
  { phase26Seed :: Int
  , phase26FaultClass :: FaultClass
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data ActionEvent
  = FaultEntered FaultClass Int
  | LeaseConsumptionWriters Int
  | LeaseStaleResourceVersionRejected
  | LeaseFreshRetryApplied
  | ScopedSsaPrepared
  | ScopedSsaConflictRejected
  | ScopedSsaFreshRetryApplied
  | SerialPredecessorAbsentObserved
  | SerialPrematureAdvanceRejected
  | SerialReplacementBoundReadyObserved
  | HostPrematureStartRejected
  | HostReleaseObserved
  | CompletionRetryRetained
  | CompletionPersistedBeforeCleanup
  | DeleteStaleAuthorityRejected
  | DeleteExactAuthorityAccepted
  | NeverReadyRejected
  | ReadinessObserved
  | ChildOverboundRejected
  | ScheduleConvergedToTypedNoOp
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (ToJSON)

data Phase26Run = Phase26Run
  { phase26RunSchedule :: Phase26Schedule
  , phase26ActionTrace :: [ActionEvent]
  , phase26SubstrateTrace :: [TraceEvent]
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data Mutant
  = LostLeaseResourceVersionRetry
  | MutationWithoutHolder
  | SleepGatedReadiness
  | SerialStageCollapse
  | CompletionCleanupBeforePersist
  | LabelOnlyDelete
  | CachedObservation
  deriving stock (Bounded, Enum, Eq, Ord, Show)

allMutants :: [Mutant]
allMutants = [minBound .. maxBound]

mutantName :: Mutant -> String
mutantName mutant = case mutant of
  LostLeaseResourceVersionRetry -> "lost-lease-resourceversion-retry"
  MutationWithoutHolder -> "mutation-without-holder"
  SleepGatedReadiness -> "sleep-gated-readiness"
  SerialStageCollapse -> "serial-stage-collapse"
  CompletionCleanupBeforePersist -> "completion-cleanup-before-persist"
  LabelOnlyDelete -> "label-only-delete"
  CachedObservation -> "cached-observation"

parseMutant :: String -> Maybe Mutant
parseMutant raw = case filter ((== raw) . mutantName) allMutants of
  [mutant] -> Just mutant
  _ -> Nothing

mutantOutcome :: Mutant -> InvariantOutcome
mutantOutcome mutant = Violated $ case mutant of
  LostLeaseResourceVersionRetry -> "NoStaleTokenReuse"
  MutationWithoutHolder -> "NoWriteWithoutExactLeaseHolder"
  SleepGatedReadiness -> "ReadinessRequiresObservation"
  SerialStageCollapse -> "SerialReplacementBoundReadyBeforeAdvance"
  CompletionCleanupBeforePersist -> "CompletionDurableBeforeCleanup"
  LabelOnlyDelete -> "DeleteRequiresExactAuthority"
  CachedObservation -> "FreshSnapshotBeforeMutation"

runPhase26Schedule :: Phase26Schedule -> IOSim s Phase26Run
runPhase26Schedule schedule = do
  exploreRaces
  handle <- newIOSimEnv (substrateSchedule schedule)
  watcher <- async (envWatchObjects (simEnv handle) (ResourceVersion 2))
  action <- async (runFault schedule (simEnv handle))
  _ <- wait watcher
  events <- wait action
  trace <- simReadTrace handle
  pure (Phase26Run schedule (FaultEntered (phase26FaultClass schedule) (phase26Seed schedule) : events <> [ScheduleConvergedToTypedNoOp]) trace)

replaySchedule :: Phase26Schedule -> (Phase26Run, LazyByteString.ByteString)
replaySchedule schedule =
  let result = runSimOrThrow (runPhase26Schedule schedule)
   in (result, encode result)

validateRun :: Phase26Run -> Either Text ()
validateRun result
  | FaultEntered fault seed `notElem` events = Left "FaultDidNotEnterCriticalSection"
  | ScheduleConvergedToTypedNoOp `notElem` events = Left "DidNotConvergeToTypedNoOp"
  | otherwise = validateFault fault events
 where
  schedule = phase26RunSchedule result
  fault = phase26FaultClass schedule
  seed = phase26Seed schedule
  events = phase26ActionTrace result

validateFault :: FaultClass -> [ActionEvent] -> Either Text ()
validateFault fault events = case fault of
  LeaseAcquireFault -> require [LeaseConsumptionWriters 1]
  LeaseRenewAmbiguity -> require [LeaseStaleResourceVersionRejected, LeaseFreshRetryApplied]
  ScopedSsaConflict -> require [ScopedSsaPrepared, ScopedSsaConflictRejected, ScopedSsaFreshRetryApplied]
  SerialStageChange -> require [SerialPredecessorAbsentObserved, SerialPrematureAdvanceRejected, SerialReplacementBoundReadyObserved]
  HostDeviceRelease -> require [HostPrematureStartRejected, HostReleaseObserved]
  CompletionWriteFailure -> require [CompletionRetryRetained, CompletionPersistedBeforeCleanup]
  AuthenticatedDeleteConflict -> require [DeleteStaleAuthorityRejected, DeleteExactAuthorityAccepted]
  ReadinessInterruption -> require [NeverReadyRejected, ReadinessObserved, ChildOverboundRejected]
 where
  require expected
    | all (`elem` events) expected = Right ()
    | otherwise = Left "RequiredSafetyEventAbsent"

substrateSchedule :: Phase26Schedule -> FaultSchedule
substrateSchedule schedule =
  FaultSchedule
    { scheduleName = "phase26"
    , scheduleSeed = phase26Seed schedule
    , schedulePartition = False
    , scheduleRedelivery = False
    , scheduleReorder = odd (phase26Seed schedule)
    , scheduleDuplicate = False
    , scheduleCrash = False
    , scheduleDnsDelay = 0
    }

runFault :: Phase26Schedule -> Env (IOSim s) -> IOSim s [ActionEvent]
runFault schedule environment = do
  envDelay environment (1 + phase26Seed schedule `mod` 7)
  case phase26FaultClass schedule of
    LeaseAcquireFault -> leaseAcquire
    LeaseRenewAmbiguity -> leaseRenew environment
    ScopedSsaConflict -> scopedSsa environment
    SerialStageChange -> pure serialTransition
    HostDeviceRelease -> pure hostTransition
    CompletionWriteFailure -> pure completionTransition
    AuthenticatedDeleteConflict -> pure deleteTransition
    ReadinessInterruption -> pure readinessTransition

leaseAcquire :: IOSim s [ActionEvent]
leaseAcquire = do
  planned <- planLeaseAction "Lease/ns/reconciler" "holder" (LeaseAbsent "Lease/ns/reconciler")
  case planned of
    Left _ -> pure []
    Right token -> do
      first <- async (consumeLeaseActionToken token)
      second <- async (consumeLeaseActionToken token)
      results <- sequence [wait first, wait second]
      let writers = length [() | Right (BootstrapAcquire _ _) <- results]
      pure [LeaseConsumptionWriters writers]

leaseRenew :: Env (IOSim s) -> IOSim s [ActionEvent]
leaseRenew environment = do
  initial <- envApplyObject environment (ObjectName "lease") (ResourceVersion 0) "holder"
  case initial of
    ObjectApplied firstVersion -> do
      planned <- planLeaseAction "Lease/ns/reconciler" "holder" (LeasePresent "Lease/ns/reconciler" "holder" "uid" (versionText firstVersion))
      external <- envApplyObject environment (ObjectName "lease") firstVersion "holder-external-renew"
      case (planned, external) of
        (Right token, ObjectApplied currentVersion) -> do
          consumed <- consumeLeaseActionToken token
          stale <- case consumed of
            Right (HolderRenew _ _ _) -> envApplyObject environment (ObjectName "lease") firstVersion "holder-renew"
            _ -> pure ApplyCrashed
          fresh <- envApplyObject environment (ObjectName "lease") currentVersion "holder-renew"
          pure
            ( [LeaseStaleResourceVersionRejected | isConflict stale]
                <> [LeaseFreshRetryApplied | isApplied fresh]
            )
        _ -> pure []
    _ -> pure []

scopedSsa :: Env (IOSim s) -> IOSim s [ActionEvent]
scopedSsa environment = do
  let identity = K8sObjectIdentity "ConfigMap/ns/config"
      action = validatedAction ApplyDesiredObject identity
      prepared = prepareScopedSsa action (Map.singleton "data.owned" "v1")
  initial <- envApplyObject environment (ObjectName "config") (ResourceVersion 0) "v0"
  case (prepared, initial) of
    (Right _, ObjectApplied firstVersion) -> do
      external <- envApplyObject environment (ObjectName "config") firstVersion "foreign-v1"
      case external of
        ObjectApplied currentVersion -> do
          stale <- envApplyObject environment (ObjectName "config") firstVersion "owned-v1"
          fresh <- envApplyObject environment (ObjectName "config") currentVersion "owned-v1"
          pure
            ([ScopedSsaPrepared]
              <> [ScopedSsaConflictRejected | isConflict stale]
              <> [ScopedSsaFreshRetryApplied | isApplied fresh])
        _ -> pure []
    _ -> pure []

serialTransition :: [ActionEvent]
serialTransition =
  let base = SerialObservation "fresh" "fresh" "slot-1" (Just "old") True (Just "new") True False
      release = planSerialAction ObserveRelease base
      early = planSerialAction ObserveReplacement base
      ready = planSerialAction ObserveReplacement (base {serialReplacementReady = True})
   in [SerialPredecessorAbsentObserved | release == Right (ResumeController "slot-1")]
        <> [SerialPrematureAdvanceRejected | early == Left SerialReplacementNotBoundReady]
        <> [SerialReplacementBoundReadyObserved | ready == Right (AdvanceAfterReplacement "slot-1" "new")]

hostTransition :: [ActionEvent]
hostTransition =
  let held = CudaAfterDeviceRelease "old" (CudaRelease True False 4096 4096)
      released = CudaAfterDeviceRelease "old" (CudaRelease True True 4096 4096)
   in [HostPrematureStartRejected | either (const True) (const False) (authorizeHostStart "fresh" "fresh" held)]
        <> [HostReleaseObserved | authorizeHostStart "fresh" "fresh" released == Right ()]

completionTransition :: [ActionEvent]
completionTransition =
  let terminal = TerminalJobObservation "pod" JobSucceeded "digest" "revision" True Nothing False False
      retry = planJobTerminal terminal
      persisted = terminal {terminalCompletionReadback = Just (JobSucceeded, "digest", "revision")}
      beforeDeadline = planJobTerminal persisted
      cleanup = planJobTerminal (persisted {terminalCleanupDeadlineReached = True, terminalReleaseComplete = True})
   in [CompletionRetryRetained | retry == Right (PersistJobCompletion JobSucceeded "digest" "revision")]
        <> [ CompletionPersistedBeforeCleanup
           | beforeDeadline == Right (CompletedTerminalNoOp "pod")
              && cleanup == Right (CleanupPersistedTerminal "pod")
           ]

deleteTransition :: [ActionEvent]
deleteTransition =
  let candidate = DeleteCandidate "ConfigMap/ns/old" "owner" "generation" "8" False True
      stale = DeleteAuthority "ConfigMap/ns/old" "owner" "generation" "7"
      exact = stale {deleteAuthorityResourceVersion = "8"}
   in [DeleteStaleAuthorityRejected | authorizeDelete stale candidate == Left DeleteAuthorityMismatch]
        <> [DeleteExactAuthorityAccepted | authorizeDelete exact candidate == Right candidate]

readinessTransition :: [ActionEvent]
readinessTransition =
  let never = ReadinessObservation False 1000 5000 3
      ready = never {readinessAvailable = True}
      envelope = ChildEnvelope 100 65536 65536 16384 1 1
      over = envelope {childCpuMillis = 101}
   in [NeverReadyRejected | observeReady never == Left ConvergenceTimeout]
        <> [ReadinessObserved | observeReady ready == Right ()]
        <> [ChildOverboundRejected | validateChildEnvelope envelope over == Left (ChildEnvelopeExceeded envelope over)]

isConflict :: ApplyResult -> Bool
isConflict ResourceVersionConflict {} = True
isConflict _ = False

isApplied :: ApplyResult -> Bool
isApplied ObjectApplied {} = True
isApplied _ = False

versionText :: ResourceVersion -> Text
versionText (ResourceVersion version) = case version of
  1 -> "1"
  2 -> "2"
  _ -> "other"
