{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Scheduler.Ledger
  ( SchedulerPodUid (..)
  , SchedulerResourceVector (..)
  , ReservationState (..)
  , PodLedgerPhase (..)
  , PodLedgerObservation (..)
  , ReservationRecord (..)
  , DebitSource (..)
  , NormalizedReservation (..)
  , NormalizedLedger (..)
  , LedgerError (..)
  , zeroSchedulerVector
  , addSchedulerVector
  , normalizeReservationLedger
  ) where

import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

newtype SchedulerPodUid = SchedulerPodUid Text
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data SchedulerResourceVector = SchedulerResourceVector
  { schedulerCpuMillis :: Natural
  , schedulerMemoryBytes :: Natural
  , schedulerEphemeralBytes :: Natural
  , schedulerStorageBytes :: Natural
  , schedulerPodSlots :: Natural
  , schedulerEtcdChurnBytes :: Natural
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ReservationState = Reserved | BindingInFlight | Bound | Terminating | TerminalRetained
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data PodLedgerPhase = PendingUnscheduled | ObservedBound | ObservedTerminating | ObservedTerminal
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data PodLedgerObservation = PodLedgerObservation
  { podLedgerUid :: SchedulerPodUid
  , podLedgerPhase :: PodLedgerPhase
  , podLedgerNode :: Maybe Text
  , podLedgerGeneration :: Text
  , podLedgerTemplateDigest :: Text
  , podLedgerDebit :: SchedulerResourceVector
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ReservationRecord = ReservationRecord
  { reservationUid :: SchedulerPodUid
  , reservationState :: ReservationState
  , reservationNode :: Text
  , reservationGeneration :: Text
  , reservationTemplateDigest :: Text
  , reservationFullDebit :: SchedulerResourceVector
  , reservationTerminalDebit :: SchedulerResourceVector
  , reservationAbsentRecoveryWitness :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data DebitSource
  = PlannedReservation ReservationState
  | JoinedObservedReservation ReservationState
  | ConfirmedBoundRecovery
  | LedgerOnlyAbsentRecovery ReservationState
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data NormalizedReservation = NormalizedReservation
  { normalizedReservationUid :: SchedulerPodUid
  , normalizedReservationDebit :: SchedulerResourceVector
  , normalizedReservationSource :: DebitSource
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data NormalizedLedger = NormalizedLedger
  { normalizedLedgerResourceVersion :: Text
  , normalizedReservations :: Map SchedulerPodUid NormalizedReservation
  , normalizedPendingApiOnly :: Set.Set SchedulerPodUid
  , normalizedLedgerDebit :: SchedulerResourceVector
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data LedgerError
  = DuplicateReservation SchedulerPodUid
  | DuplicatePodObservation SchedulerPodUid
  | MissingReservation SchedulerPodUid
  | UnclassifiedOrphan SchedulerPodUid ReservationState
  | ReservationGenerationMismatch SchedulerPodUid
  | ReservationTemplateMismatch SchedulerPodUid
  | ReservationNodeMismatch SchedulerPodUid
  | ReservationAxesMismatch SchedulerPodUid
  | ReservationStateObservationMismatch SchedulerPodUid ReservationState PodLedgerPhase
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

zeroSchedulerVector :: SchedulerResourceVector
zeroSchedulerVector = SchedulerResourceVector 0 0 0 0 0 0

addSchedulerVector :: SchedulerResourceVector -> SchedulerResourceVector -> SchedulerResourceVector
addSchedulerVector left right =
  SchedulerResourceVector
    (schedulerCpuMillis left + schedulerCpuMillis right)
    (schedulerMemoryBytes left + schedulerMemoryBytes right)
    (schedulerEphemeralBytes left + schedulerEphemeralBytes right)
    (schedulerStorageBytes left + schedulerStorageBytes right)
    (schedulerPodSlots left + schedulerPodSlots right)
    (schedulerEtcdChurnBytes left + schedulerEtcdChurnBytes right)

normalizeReservationLedger
  :: Text
  -> Text
  -> Text
  -> [PodLedgerObservation]
  -> [ReservationRecord]
  -> Either LedgerError NormalizedLedger
normalizeReservationLedger expectedGeneration expectedTemplate rootVersion podRows reservationRows = do
  pods <- uniqueBy podLedgerUid DuplicatePodObservation podRows
  reservations <- uniqueBy reservationUid DuplicateReservation reservationRows
  let missing =
        [ uid
        | (uid, observed) <- Map.toAscList pods
        , podLedgerPhase observed /= PendingUnscheduled
        , Map.notMember uid reservations
        ]
  case missing of
    uid : _ -> Left (MissingReservation uid)
    [] -> pure ()
  normalized <- traverse (normalizeOne pods) reservations
  let pending =
        Set.fromList
          [ uid
          | (uid, observed) <- Map.toAscList pods
          , podLedgerPhase observed == PendingUnscheduled
          , Map.notMember uid reservations
          ]
      total = foldl (\accumulated row -> addSchedulerVector accumulated (normalizedReservationDebit row)) zeroSchedulerVector normalized
  pure
    NormalizedLedger
      { normalizedLedgerResourceVersion = rootVersion
      , normalizedReservations = normalized
      , normalizedPendingApiOnly = pending
      , normalizedLedgerDebit = total
      }
 where
  normalizeOne pods record = do
    let uid = reservationUid record
        state = reservationState record
        debit = if state == TerminalRetained then reservationTerminalDebit record else reservationFullDebit record
    if reservationGeneration record == expectedGeneration then pure () else Left (ReservationGenerationMismatch uid)
    if reservationTemplateDigest record == expectedTemplate then pure () else Left (ReservationTemplateMismatch uid)
    case Map.lookup uid pods of
      Nothing
        | reservationAbsentRecoveryWitness record ->
            pure (NormalizedReservation uid debit (LedgerOnlyAbsentRecovery state))
        | otherwise -> Left (UnclassifiedOrphan uid state)
      Just observed -> do
        if podLedgerGeneration observed == expectedGeneration then pure () else Left (ReservationGenerationMismatch uid)
        if podLedgerTemplateDigest observed == expectedTemplate then pure () else Left (ReservationTemplateMismatch uid)
        if podLedgerDebit observed == reservationFullDebit record || state == TerminalRetained && podLedgerDebit observed == reservationTerminalDebit record
          then pure ()
          else Left (ReservationAxesMismatch uid)
        validateState record observed
        let source = case (state, podLedgerPhase observed) of
              (BindingInFlight, ObservedBound) -> ConfirmedBoundRecovery
              (Reserved, PendingUnscheduled) -> PlannedReservation Reserved
              (BindingInFlight, PendingUnscheduled) -> PlannedReservation BindingInFlight
              _ -> JoinedObservedReservation state
        pure (NormalizedReservation uid debit source)

  validateState record observed =
    let uid = reservationUid record
        state = reservationState record
        phase = podLedgerPhase observed
        nodeMatches = podLedgerNode observed == Just (reservationNode record)
        reject = Left (ReservationStateObservationMismatch uid state phase)
     in case (state, phase) of
          (Reserved, PendingUnscheduled) -> pure ()
          (BindingInFlight, PendingUnscheduled) -> pure ()
          (BindingInFlight, ObservedBound) | nodeMatches -> pure ()
          (Bound, ObservedBound) | nodeMatches -> pure ()
          (Terminating, ObservedTerminating) | nodeMatches -> pure ()
          (TerminalRetained, ObservedTerminal) | nodeMatches -> pure ()
          (_, ObservedBound) | not nodeMatches -> Left (ReservationNodeMismatch uid)
          (_, ObservedTerminating) | not nodeMatches -> Left (ReservationNodeMismatch uid)
          (_, ObservedTerminal) | not nodeMatches -> Left (ReservationNodeMismatch uid)
          _ -> reject

uniqueBy :: Ord key => (value -> key) -> (key -> LedgerError) -> [value] -> Either LedgerError (Map key value)
uniqueBy identity duplicate = foldl insert (Right Map.empty)
 where
  insert result value = do
    indexed <- result
    let key = identity value
    if Map.member key indexed
      then Left (duplicate key)
      else Right (Map.insert key value indexed)
