{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Scheduler.Ledger
import Data.Aeson (FromJSON, eitherDecodeFileStrict')
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import GHC.Generics (Generic)
import System.Exit (die)

newtype ExpectedActions = ExpectedActions {schedulerActions :: [Text]}
  deriving stock (Generic, Show)
  deriving anyclass (FromJSON)

main :: IO ()
main = do
  verifyPinnedOracle
  verifyAbsentRecovery
  verifyObservedJoins
  verifyNegatives
  putStrLn "scheduler-ledger-spec: PASS (state-indexed exact-once normalization and closed absent-Pod recovery)"

verifyPinnedOracle :: IO ()
verifyPinnedOracle = do
  decoded <- eitherDecodeFileStrict' "test/live/fixtures/reconcile-corpus/expected-actions.json"
  expected <- either die pure decoded
  case schedulerActions expected of
    actions@[first, _, _, _, _, _, _, _, final] -> do
      assertEqual "scheduler action oracle size" 9 (length actions)
      assertEqual "scheduler first action" "ApplyBootstrapSchedulerSystem:Deployment/amoebius-capacity-scheduler/amoebius-capacity" first
      assertEqual "scheduler final action" "ConfirmBound:CapacityReservation/amoebius-phase27-gate/guarded-pod" final
    actions -> die ("scheduler action oracle domain: " <> show actions)

verifyAbsentRecovery :: IO ()
verifyAbsentRecovery = mapM_ verify [Reserved .. TerminalRetained]
 where
  verify state = do
    normalized <- requireRight (normalizeReservationLedger generation template "17" [] [record state True])
    let row = normalizedReservations normalized Map.! uid
        expected = if state == TerminalRetained then retained else full
    assertEqual ("absent recovery debit " <> show state) expected (normalizedReservationDebit row)
    assertEqual ("absent recovery source " <> show state) (LedgerOnlyAbsentRecovery state) (normalizedReservationSource row)

verifyObservedJoins :: IO ()
verifyObservedJoins = do
  let pending = observation PendingUnscheduled Nothing full
  planned <- requireRight (normalizeReservationLedger generation template "17" [pending] [record Reserved False])
  assertEqual "reserved pending debited once" full (normalizedLedgerDebit planned)
  let confirmed = observation ObservedBound (Just node) full
  joined <- requireRight (normalizeReservationLedger generation template "18" [confirmed] [record BindingInFlight False])
  assertEqual "confirmed Bound still in-flight debited once" full (normalizedLedgerDebit joined)
  assertEqual "confirmed Bound recovery source" ConfirmedBoundRecovery (normalizedReservationSource (normalizedReservations joined Map.! uid))
  let apiOnly = observation PendingUnscheduled Nothing full
  noReservation <- requireRight (normalizeReservationLedger generation template "19" [apiOnly] [])
  assertEqual "PendingUnscheduled API-only" zeroSchedulerVector (normalizedLedgerDebit noReservation)

verifyNegatives :: IO ()
verifyNegatives = do
  assertEqual "unclassified orphan" (Left (UnclassifiedOrphan uid Reserved)) (normalizeReservationLedger generation template "17" [] [record Reserved False])
  let bound = observation ObservedBound (Just node) full
  assertEqual "missing reservation" (Left (MissingReservation uid)) (normalizeReservationLedger generation template "17" [bound] [])
  assertEqual "duplicate reservation" (Left (DuplicateReservation uid)) (normalizeReservationLedger generation template "17" [] [record Reserved True, record Reserved True])
  let wrongNode = bound {podLedgerNode = Just "wrong-node"}
  assertEqual "wrong node" (Left (ReservationNodeMismatch uid)) (normalizeReservationLedger generation template "17" [wrongNode] [record Bound False])
  let wrongGeneration = bound {podLedgerGeneration = "wrong"}
  assertEqual "wrong generation" (Left (ReservationGenerationMismatch uid)) (normalizeReservationLedger generation template "17" [wrongGeneration] [record Bound False])
  let wrongTemplate = bound {podLedgerTemplateDigest = "wrong"}
  assertEqual "wrong template" (Left (ReservationTemplateMismatch uid)) (normalizeReservationLedger generation template "17" [wrongTemplate] [record Bound False])
  let unequal = bound {podLedgerDebit = full {schedulerCpuMillis = 109}}
  assertEqual "unequal axes including pad" (Left (ReservationAxesMismatch uid)) (normalizeReservationLedger generation template "17" [unequal] [record Bound False])
  let wrongState = bound
  assertEqual "wrong state" (Left (ReservationStateObservationMismatch uid Reserved ObservedBound)) (normalizeReservationLedger generation template "17" [wrongState] [record Reserved False])

uid :: SchedulerPodUid
uid = SchedulerPodUid "pod-uid"

node, generation, template :: Text
node = "amoebius-phase24-control-plane"
generation = "phase27-generation-1"
template = "sha256:phase27-guarded-template"

full, retained :: SchedulerResourceVector
full = SchedulerResourceVector 110 67108864 67108864 16777216 1 4096
retained = SchedulerResourceVector 0 0 16777216 16777216 1 2048

record :: ReservationState -> Bool -> ReservationRecord
record state recovery = ReservationRecord uid state node generation template full retained recovery

observation :: PodLedgerPhase -> Maybe Text -> SchedulerResourceVector -> PodLedgerObservation
observation phase observedNode debit = PodLedgerObservation uid phase observedNode generation template debit

requireRight :: Show problem => Either problem value -> IO value
requireRight = either (die . show) pure

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual
  | expected == actual = pure ()
  | otherwise = die (label <> ": expected " <> show expected <> ", got " <> show actual)
