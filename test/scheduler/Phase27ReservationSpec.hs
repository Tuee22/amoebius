{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Scheduler.Binding
import Amoebius.Scheduler.Ledger
import Amoebius.Scheduler.Loop
import Amoebius.Scheduler.Recovery
import Amoebius.Scheduler.Reservation
import Data.Map.Strict qualified as Map
import System.Exit (die)

main :: IO ()
main = do
  verifyProtocolOrder
  verifyAggregateCasAndIdempotence
  verifyBindingAuthority
  verifyRecovery
  putStrLn "scheduler-reservation-spec: PASS (whole-ledger aggregate CAS, reserve-before-Binding, and state-sensitive recovery)"

verifyProtocolOrder :: IO ()
verifyProtocolOrder = assertEqual "CAS/Binding protocol order"
  [ReservationCasSucceeded, BindingInFlightCasSucceeded, KubernetesBindingSubmitted, ExactNodeAndUidConfirmed, BoundCasSucceeded]
  schedulerProtocolOrder

verifyAggregateCasAndIdempotence :: IO ()
verifyAggregateCasAndIdempotence = do
  root <- newReservationRoot
  first <- reserveCandidate capacity [] 0 candidateA root >>= requireRight
  assertEqual "first reservation CAS version" 1 (mutationVersion first)
  stale <- reserveCandidate capacity [] 0 candidateB root
  assertEqual "two-candidate stale aggregate CAS" (Left (ReservationRootVersionConflict 0 1)) stale
  over <- reserveCandidate capacity [] 1 candidateB root
  case over of
    Left ReservationCapacityError {} -> pure ()
    verdict -> die ("whole-ledger refold did not reject overspend: " <> show verdict)
  reused <- reserveCandidate capacity [] 1 candidateA root >>= requireRight
  assertEqual "same UID retry does not debit or bump CAS" 1 (mutationVersion reused)
  snapshot <- readReservationRoot root
  assertEqual "one debit per UID" 1 (Map.size (reservationRootRecords snapshot))

verifyBindingAuthority :: IO ()
verifyBindingAuthority = do
  root <- newReservationRoot
  created <- reserveCandidate capacity [] 0 candidateA root >>= requireRight
  let reserved = mutationRecord created
  assertEqual "Binding requires BindingInFlight CAS" (Left BindingReservationNotInFlight) (prepareBinding "holder" "holder" 1 reserved)
  inFlight <- transitionReservation 1 uidA Reserved BindingInFlight root >>= requireRight
  let inFlightRecord = mutationRecord inFlight
  request <- requireRight (prepareBinding "holder" "holder" 2 inFlightRecord)
  assertEqual "Binding exact UID" uidA (bindingPodUid request)
  assertEqual "Binding exact node" "node" (bindingNode request)
  bound <- transitionReservation 2 uidA BindingInFlight Bound root >>= requireRight
  assertEqual "Bound CAS" Bound (reservationState (mutationRecord bound))

verifyRecovery :: IO ()
verifyRecovery = do
  let inFlight = (candidateRecordForTest candidateA) {reservationState = BindingInFlight}
      bound = inFlight {reservationState = Bound}
      terminating = inFlight {reservationState = Terminating}
  assertEqual "confirmed Binding repairs Bound" RepairReservationBound (recoverReservation inFlight (ConfirmedBound uidA "node"))
  assertEqual "unknown remains charged" KeepReservationCharged (recoverReservation inFlight RecoveryUnknown)
  assertEqual "unbound exact may release" ReleaseUnboundReservation (recoverReservation inFlight (ConfirmedUnboundSameUidAndResourceVersion uidA 7))
  assertEqual "Bound survives restart" KeepReservationCharged (recoverReservation bound RecoveryPodAbsent)
  assertEqual "Terminating survives restart" KeepReservationCharged (recoverReservation terminating RecoveryPodAbsent)

capacity :: SchedulerResourceVector
capacity = SchedulerResourceVector 100 100 100 100 2 100

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

candidateRecordForTest :: ReservationCandidate -> ReservationRecord
candidateRecordForTest candidate = ReservationRecord (candidateUid candidate) Reserved (candidateNode candidate) (candidateGeneration candidate) (candidateTemplateDigest candidate) (candidateFullDebit candidate) (candidateTerminalDebit candidate) False

mutationVersion :: ReservationMutation -> Int
mutationVersion mutation = case mutation of
  ReservationCreated _ version -> version
  ReservationReused _ version -> version
  ReservationTransitioned _ version -> version

mutationRecord :: ReservationMutation -> ReservationRecord
mutationRecord mutation = case mutation of
  ReservationCreated record _ -> record
  ReservationReused record _ -> record
  ReservationTransitioned record _ -> record

requireRight :: Show problem => Either problem value -> IO value
requireRight = either (die . show) pure

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual
  | expected == actual = pure ()
  | otherwise = die (label <> ": expected " <> show expected <> ", got " <> show actual)
