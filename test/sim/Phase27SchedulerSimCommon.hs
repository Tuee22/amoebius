{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Phase27SchedulerSimCommon
  ( SchedulerFaultClass (..)
  , SchedulerSchedule (..)
  , SchedulerRun (..)
  , SchedulerEvent (..)
  , SchedulerMutant (..)
  , schedulerMutants
  , schedulerMutantName
  , parseSchedulerMutant
  , schedulerMutantOutcome
  , runSchedulerSchedule
  , replaySchedulerSchedule
  , validateSchedulerRun
  ) where

import Amoebius.Admission.ExecutionIdentity
import Amoebius.Scheduler.Binding
import Amoebius.Scheduler.Ledger
import Amoebius.Scheduler.Readiness
import Amoebius.Scheduler.Recovery
import Amoebius.Scheduler.Reservation
import Amoebius.Sim.Env
import Amoebius.Sim.Interp.Sim
import Control.Monad.Class.MonadAsync (async, wait)
import Control.Monad.Class.MonadTest (exploreRaces)
import Control.Monad.IOSim (IOSim, runSimOrThrow)
import Data.Aeson (ToJSON, encode)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.List (elemIndex)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)

data SchedulerFaultClass
  = LeaseHolderAmbiguity
  | BootstrapReadinessInterruption
  | ManagedCutoverInterruption
  | ReservationCasRace
  | BindingFailure
  | CrashAfterBinding
  | CachedObservationWatchGap
  deriving stock (Bounded, Enum, Eq, Ord, Show, Generic)
  deriving anyclass (ToJSON)

data SchedulerSchedule = SchedulerSchedule
  { schedulerSeed :: Int
  , schedulerFaultClass :: SchedulerFaultClass
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data SchedulerEvent
  = SchedulerFaultEntered SchedulerFaultClass Int
  | ForeignLeaseHolderRejected
  | ExactLeaseHolderAccepted
  | BootstrapDigestMismatchRejected
  | BootstrapWitnessObserved
  | GeneralGuardedBeforeManagedRejected
  | PrematureManagedAuthorityRejected
  | IncompleteCutoverRejected
  | ManagedWitnessObserved
  | GeneralGuardedAfterManagedAdmitted
  | ReservationRaceWriters Int
  | AggregateCasConflictRejected
  | SameUidRetryVersionStable
  | BindingBeforeCasRejected
  | BindingForeignHolderRejected
  | BindingAfterCasPrepared
  | UnknownBindingOutcomeRetained
  | CrashAfterBindingRepaired
  | BoundRestartRetained
  | SchedulerWatchGapObserved
  | StaleSchedulerSnapshotRejected
  | FreshSchedulerSnapshotApplied
  | SchedulerConvergedToTypedNoOp
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (ToJSON)

data SchedulerRun = SchedulerRun
  { schedulerRunSchedule :: SchedulerSchedule
  , schedulerActionTrace :: [SchedulerEvent]
  , schedulerSubstrateTrace :: [TraceEvent]
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data SchedulerMutant
  = LostLeaseResourceVersionRetry
  | CollapsedSchedulerReadiness
  | PrematureManagedAuthority
  | BindBeforeCas
  | SameUidDoubleDebit
  | BoundDroppedOnRestart
  | CachedSchedulerObservation
  deriving stock (Bounded, Enum, Eq, Ord, Show)

schedulerMutants :: [SchedulerMutant]
schedulerMutants = [minBound .. maxBound]

schedulerMutantName :: SchedulerMutant -> String
schedulerMutantName mutant = case mutant of
  LostLeaseResourceVersionRetry -> "lost-lease-resourceversion-retry"
  CollapsedSchedulerReadiness -> "collapsed-scheduler-readiness"
  PrematureManagedAuthority -> "premature-managed-authority"
  BindBeforeCas -> "bind-before-cas"
  SameUidDoubleDebit -> "same-uid-double-debit"
  BoundDroppedOnRestart -> "bound-dropped-on-restart"
  CachedSchedulerObservation -> "cached-observation"

parseSchedulerMutant :: String -> Maybe SchedulerMutant
parseSchedulerMutant raw = case filter ((== raw) . schedulerMutantName) schedulerMutants of
  [mutant] -> Just mutant
  _ -> Nothing

schedulerMutantOutcome :: SchedulerMutant -> InvariantOutcome
schedulerMutantOutcome mutant = Violated $ case mutant of
  LostLeaseResourceVersionRetry -> "NoWriteWithoutExactLeaseHolder"
  CollapsedSchedulerReadiness -> "DistinctSchedulerReadinessStages"
  PrematureManagedAuthority -> "NoGeneralActionBeforeManagedCapacityReady"
  BindBeforeCas -> "NoBindingBeforeSuccessfulReservationCAS"
  SameUidDoubleDebit -> "OneReservationDebitPerPodUid"
  BoundDroppedOnRestart -> "BoundReservationSurvivesRestart"
  CachedSchedulerObservation -> "FreshSnapshotBeforeSchedulerMutation"

runSchedulerSchedule :: SchedulerSchedule -> IOSim s SchedulerRun
runSchedulerSchedule schedule = do
  exploreRaces
  handle <- newIOSimEnv (faultSchedule schedule)
  action <- async (runFault schedule (simEnv handle))
  events <- wait action
  trace <- simReadTrace handle
  pure SchedulerRun
    { schedulerRunSchedule = schedule
    , schedulerActionTrace = SchedulerFaultEntered (schedulerFaultClass schedule) (schedulerSeed schedule) : events <> [SchedulerConvergedToTypedNoOp]
    , schedulerSubstrateTrace = trace
    }

replaySchedulerSchedule :: SchedulerSchedule -> (SchedulerRun, LazyByteString.ByteString)
replaySchedulerSchedule schedule =
  let result = runSimOrThrow (runSchedulerSchedule schedule)
   in (result, encode result)

validateSchedulerRun :: SchedulerRun -> Either Text ()
validateSchedulerRun result
  | SchedulerFaultEntered fault seed `notElem` events = Left "FaultDidNotEnterSchedulerCriticalSection"
  | SchedulerConvergedToTypedNoOp `notElem` events = Left "SchedulerDidNotConvergeToTypedNoOp"
  | otherwise = validateFault fault events
 where
  schedule = schedulerRunSchedule result
  fault = schedulerFaultClass schedule
  seed = schedulerSeed schedule
  events = schedulerActionTrace result

validateFault :: SchedulerFaultClass -> [SchedulerEvent] -> Either Text ()
validateFault fault events = case fault of
  LeaseHolderAmbiguity -> require [ForeignLeaseHolderRejected, ExactLeaseHolderAccepted]
  BootstrapReadinessInterruption -> require [BootstrapDigestMismatchRejected, BootstrapWitnessObserved]
  ManagedCutoverInterruption -> do
    require [GeneralGuardedBeforeManagedRejected, PrematureManagedAuthorityRejected, IncompleteCutoverRejected, ManagedWitnessObserved, GeneralGuardedAfterManagedAdmitted]
    if ordered GeneralGuardedBeforeManagedRejected ManagedWitnessObserved events
        && ordered ManagedWitnessObserved GeneralGuardedAfterManagedAdmitted events
      then Right ()
      else Left "ManagedReadinessActionOrder"
  ReservationCasRace -> require [ReservationRaceWriters 1, AggregateCasConflictRejected, SameUidRetryVersionStable]
  BindingFailure -> require [BindingBeforeCasRejected, BindingForeignHolderRejected, BindingAfterCasPrepared, UnknownBindingOutcomeRetained]
  CrashAfterBinding -> require [BindingAfterCasPrepared, CrashAfterBindingRepaired, BoundRestartRetained]
  CachedObservationWatchGap -> require [SchedulerWatchGapObserved, StaleSchedulerSnapshotRejected, FreshSchedulerSnapshotApplied]
 where
  require expected
    | all (`elem` events) expected = Right ()
    | otherwise = Left "RequiredSchedulerSafetyEventAbsent"

ordered :: Eq event => event -> event -> [event] -> Bool
ordered first second events = case (elemIndex first events, elemIndex second events) of
  (Just left, Just right) -> left < right
  _ -> False

faultSchedule :: SchedulerSchedule -> FaultSchedule
faultSchedule schedule = FaultSchedule
  { scheduleName = "phase27-scheduler"
  , scheduleSeed = schedulerSeed schedule
  , schedulePartition = False
  , scheduleRedelivery = False
  , scheduleReorder = odd (schedulerSeed schedule)
  , scheduleDuplicate = False
  , scheduleCrash = schedulerFaultClass schedule == CrashAfterBinding
  , scheduleDnsDelay = 0
  }

runFault :: SchedulerSchedule -> Env (IOSim s) -> IOSim s [SchedulerEvent]
runFault schedule environment = do
  envDelay environment (1 + schedulerSeed schedule `mod` 7)
  case schedulerFaultClass schedule of
    LeaseHolderAmbiguity -> pure leaseHolderFault
    BootstrapReadinessInterruption -> pure bootstrapReadinessFault
    ManagedCutoverInterruption -> pure managedCutoverFault
    ReservationCasRace -> reservationRaceFault
    BindingFailure -> bindingFailureFault
    CrashAfterBinding -> crashAfterBindingFault
    CachedObservationWatchGap -> cachedObservationFault environment

leaseHolderFault :: [SchedulerEvent]
leaseHolderFault =
  [ForeignLeaseHolderRejected | prepareBinding holder "foreign" 2 inFlightRecord == Left BindingLeaseHolderMismatch]
    <> [ExactLeaseHolderAccepted | isBindingRight (prepareBinding holder holder 2 inFlightRecord)]

bootstrapReadinessFault :: [SchedulerEvent]
bootstrapReadinessFault =
  [BootstrapDigestMismatchRejected | observeBootstrapCapacitySchedulerReady (bootstrapObservation {bootstrapObservedConfigDigest = "wrong"}) == Left BootstrapConfigDigestMismatch]
    <> [BootstrapWitnessObserved | isBootstrapRight (observeBootstrapCapacitySchedulerReady bootstrapObservation)]

managedCutoverFault :: [SchedulerEvent]
managedCutoverFault = case observeBootstrapCapacitySchedulerReady bootstrapObservation of
  Left _ -> []
  Right bootstrap ->
    let expected = Set.singleton "addon"
        controller = BootstrapControllerObservation "addon" True True "new-uid" True True True
        readback = ManagedAuthorityReadback True True True True True
        premature = admitExecutionCreate BeforeManagedCapacityReady guardedIdentity
        unauthorized = authorizeBootstrapAction bootstrap InstallManagedAuthority
        incomplete = observeManagedCapacityReady bootstrap expected [] readback
        completed = observeManagedCapacityReady bootstrap expected [controller] readback
     in [GeneralGuardedBeforeManagedRejected | premature == Left ManagedCapacityNotReady]
          <> [PrematureManagedAuthorityRejected | not unauthorized]
          <> [IncompleteCutoverRejected | isManagedLeft incomplete]
          <> case completed of
            Left _ -> []
            Right managed ->
              [ManagedWitnessObserved]
                <> [GeneralGuardedAfterManagedAdmitted | admitExecutionCreate (AfterManagedCapacityReady managed) guardedIdentity == Right ()]

reservationRaceFault :: IOSim s [SchedulerEvent]
reservationRaceFault = do
  root <- newReservationRoot
  left <- async (reserveCandidate capacity [] 0 candidateA root)
  right <- async (reserveCandidate capacity [] 0 candidateB root)
  outcomes <- sequence [wait left, wait right]
  snapshot <- readReservationRoot root
  let writers = length [() | Right (ReservationCreated _ _) <- outcomes]
      conflicts = length [() | Left ReservationRootVersionConflict {} <- outcomes]
      winner = if Map.member uidA (reservationRootRecords snapshot) then candidateA else candidateB
  same <- reserveCandidate capacity [] (reservationRootVersion snapshot) winner root
  after <- readReservationRoot root
  pure
    ([ReservationRaceWriters writers]
      <> [AggregateCasConflictRejected | conflicts == 1 && Map.size (reservationRootRecords snapshot) == 1]
      <> [SameUidRetryVersionStable | isReusedAt (reservationRootVersion snapshot) same && after == snapshot])

bindingFailureFault :: IOSim s [SchedulerEvent]
bindingFailureFault = do
  root <- newReservationRoot
  created <- reserveCandidate capacity [] 0 candidateA root
  case created of
    Right mutation -> do
      let reserved = mutationRecord mutation
          before = prepareBinding holder holder 1 reserved
      transitioned <- transitionReservation 1 uidA Reserved BindingInFlight root
      case transitioned of
        Right inFlight -> do
          let record = mutationRecord inFlight
          pure
            ([BindingBeforeCasRejected | before == Left BindingReservationNotInFlight]
              <> [BindingForeignHolderRejected | prepareBinding holder "foreign" 2 record == Left BindingLeaseHolderMismatch]
              <> [BindingAfterCasPrepared | isBindingRight (prepareBinding holder holder 2 record)]
              <> [UnknownBindingOutcomeRetained | recoverReservation record RecoveryUnknown == KeepReservationCharged])
        Left _ -> pure []
    Left _ -> pure []

crashAfterBindingFault :: IOSim s [SchedulerEvent]
crashAfterBindingFault = do
  root <- newReservationRoot
  created <- reserveCandidate capacity [] 0 candidateA root
  case created of
    Left _ -> pure []
    Right reservedMutation -> do
      inFlightResult <- transitionReservation 1 uidA Reserved BindingInFlight root
      case inFlightResult of
        Left _ -> pure []
        Right inFlightMutation -> do
          let record = mutationRecord inFlightMutation
              prepared = prepareBinding holder holder 2 record
              recovery = recoverReservation record (ConfirmedBound uidA "node")
          boundResult <- transitionReservation 2 uidA BindingInFlight Bound root
          let retained = case boundResult of
                Right boundMutation -> recoverReservation (mutationRecord boundMutation) RecoveryPodAbsent == KeepReservationCharged
                Left _ -> False
          pure
            ([BindingAfterCasPrepared | isBindingRight prepared]
              <> [CrashAfterBindingRepaired | recovery == RepairReservationBound]
              <> [BoundRestartRetained | retained]
              <> [UnknownBindingOutcomeRetained | recoverReservation (mutationRecord reservedMutation) RecoveryUnknown == KeepReservationCharged])

cachedObservationFault :: Env (IOSim s) -> IOSim s [SchedulerEvent]
cachedObservationFault environment = do
  initial <- envApplyObject environment (ObjectName "scheduler-root") (ResourceVersion 0) "version-1"
  case initial of
    ObjectApplied firstVersion -> do
      gap <- envWatchObjects environment firstVersion
      external <- envApplyObject environment (ObjectName "scheduler-root") firstVersion "version-2"
      case external of
        ObjectApplied currentVersion -> do
          stale <- envApplyObject environment (ObjectName "scheduler-root") firstVersion "stale-scheduler-write"
          fresh <- envApplyObject environment (ObjectName "scheduler-root") currentVersion "fresh-scheduler-write"
          pure
            ([SchedulerWatchGapObserved | isWatchGap gap]
              <> [StaleSchedulerSnapshotRejected | isConflict stale]
              <> [FreshSchedulerSnapshotApplied | isApplied fresh])
        _ -> pure []
    _ -> pure []

bootstrapObservation :: BootstrapSchedulerObservation
bootstrapObservation = BootstrapSchedulerObservation generation generation config config "17" "17" True True True True
 where
  generation = "generation"
  config = "sha256:config"

guardedIdentity :: ExecutionIdentity
guardedIdentity = ExecutionIdentity "deployment" "generation" "source" "revision" "sha256:template" "amoebius-capacity" True True False

capacity :: SchedulerResourceVector
capacity = SchedulerResourceVector 100 100 100 100 1 100

debit :: SchedulerResourceVector
debit = SchedulerResourceVector 60 60 60 60 1 60

terminal :: SchedulerResourceVector
terminal = SchedulerResourceVector 0 0 10 10 1 10

uidA, uidB :: SchedulerPodUid
uidA = SchedulerPodUid "uid-a"
uidB = SchedulerPodUid "uid-b"

candidateA, candidateB :: ReservationCandidate
candidateA = ReservationCandidate uidA "node" "generation" "digest" debit terminal
candidateB = ReservationCandidate uidB "node" "generation" "digest" debit terminal

holder :: Text
holder = "phase26-bootstrap-host"

inFlightRecord :: ReservationRecord
inFlightRecord = ReservationRecord uidA BindingInFlight "node" "generation" "digest" debit terminal False

mutationRecord :: ReservationMutation -> ReservationRecord
mutationRecord mutation = case mutation of
  ReservationCreated record _ -> record
  ReservationReused record _ -> record
  ReservationTransitioned record _ -> record

isReusedAt :: Int -> Either ReservationError ReservationMutation -> Bool
isReusedAt expected result = case result of
  Right (ReservationReused _ version) -> version == expected
  _ -> False

isBindingRight :: Either BindingError BindingRequest -> Bool
isBindingRight value = case value of
  Right _ -> True
  Left _ -> False

isBootstrapRight :: Either BootstrapReadinessError BootstrapCapacitySchedulerReady -> Bool
isBootstrapRight value = case value of
  Right _ -> True
  Left _ -> False

isManagedLeft :: Either ManagedReadinessError ManagedCapacityReady -> Bool
isManagedLeft value = case value of
  Left _ -> True
  Right _ -> False

isWatchGap :: WatchResult -> Bool
isWatchGap value = case value of
  WatchGap _ -> True
  WatchObjects _ -> False

isConflict :: ApplyResult -> Bool
isConflict value = case value of
  ResourceVersionConflict _ -> True
  _ -> False

isApplied :: ApplyResult -> Bool
isApplied value = case value of
  ObjectApplied _ -> True
  _ -> False
