{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Amoebius.Scheduler.Reservation
  ( ReservationRoot
  , ReservationRootSnapshot (..)
  , ReservationCandidate (..)
  , ReservationMutation (..)
  , ReservationError (..)
  , newReservationRoot
  , readReservationRoot
  , reserveCandidate
  , transitionReservation
  ) where

import Amoebius.Scheduler.Ledger
import Amoebius.Scheduler.Placement
import Control.Concurrent.Class.MonadSTM
  ( MonadSTM
  , TVar
  , atomically
  , newTVar
  , readTVar
  , readTVarIO
  , writeTVar
  )
import Control.DeepSeq (NFData)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import GHC.Generics (Generic)

data ReservationRoot m = ReservationRoot (TVar m ReservationRootSnapshot)

data ReservationRootSnapshot = ReservationRootSnapshot
  { reservationRootVersion :: Int
  , reservationRootRecords :: Map SchedulerPodUid ReservationRecord
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ReservationCandidate = ReservationCandidate
  { candidateUid :: SchedulerPodUid
  , candidateNode :: Text
  , candidateGeneration :: Text
  , candidateTemplateDigest :: Text
  , candidateFullDebit :: SchedulerResourceVector
  , candidateTerminalDebit :: SchedulerResourceVector
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ReservationMutation
  = ReservationCreated ReservationRecord Int
  | ReservationReused ReservationRecord Int
  | ReservationTransitioned ReservationRecord Int
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ReservationError
  = ReservationRootVersionConflict Int Int
  | ReservationCapacityError PlacementError
  | ReservationIdentityConflict SchedulerPodUid
  | ReservationTransitionStateMismatch SchedulerPodUid ReservationState ReservationState
  | ReservationMissing SchedulerPodUid
  | ReservationTransitionIllegal ReservationState ReservationState
  deriving stock (Eq, Show)

newReservationRoot :: MonadSTM m => m (ReservationRoot m)
newReservationRoot = ReservationRoot <$> atomically (newTVar (ReservationRootSnapshot 0 Map.empty))

readReservationRoot :: MonadSTM m => ReservationRoot m -> m ReservationRootSnapshot
readReservationRoot (ReservationRoot root) = readTVarIO root

reserveCandidate
  :: MonadSTM m
  => SchedulerResourceVector
  -> [SchedulerResourceVector]
  -> Int
  -> ReservationCandidate
  -> ReservationRoot m
  -> m (Either ReservationError ReservationMutation)
reserveCandidate capacity nonLedger expectedVersion candidate (ReservationRoot root) = atomically $ do
  snapshot <- readTVar root
  if reservationRootVersion snapshot /= expectedVersion
    then pure (Left (ReservationRootVersionConflict expectedVersion (reservationRootVersion snapshot)))
    else case Map.lookup (candidateUid candidate) (reservationRootRecords snapshot) of
      Just existing
        | existing == candidateRecord candidate -> do
#ifdef CAPACITY_SCHEDULER_SAME_UID_DOUBLE_DEBIT_MUTANT
            let changed = snapshot {reservationRootVersion = reservationRootVersion snapshot + 1}
            writeTVar root changed
            pure (Right (ReservationReused existing (reservationRootVersion changed)))
#else
            pure (Right (ReservationReused existing (reservationRootVersion snapshot)))
#endif
        | otherwise -> pure (Left (ReservationIdentityConflict (candidateUid candidate)))
      Nothing -> case refoldSchedulerPlacement capacity (nonLedger <> fmap reservationFullDebit (Map.elems (reservationRootRecords snapshot))) (candidateFullDebit candidate) of
        Left problem -> pure (Left (ReservationCapacityError problem))
        Right _ -> do
          let record = candidateRecord candidate
              nextVersion = reservationRootVersion snapshot + 1
              changed = ReservationRootSnapshot nextVersion (Map.insert (candidateUid candidate) record (reservationRootRecords snapshot))
          writeTVar root changed
          pure (Right (ReservationCreated record nextVersion))

transitionReservation
  :: MonadSTM m
  => Int
  -> SchedulerPodUid
  -> ReservationState
  -> ReservationState
  -> ReservationRoot m
  -> m (Either ReservationError ReservationMutation)
transitionReservation expectedVersion uid expectedState nextState (ReservationRoot root) = atomically $ do
  snapshot <- readTVar root
  if reservationRootVersion snapshot /= expectedVersion
    then pure (Left (ReservationRootVersionConflict expectedVersion (reservationRootVersion snapshot)))
    else case Map.lookup uid (reservationRootRecords snapshot) of
      Nothing -> pure (Left (ReservationMissing uid))
      Just record
        | reservationState record /= expectedState -> pure (Left (ReservationTransitionStateMismatch uid expectedState (reservationState record)))
        | not (legalTransition expectedState nextState) -> pure (Left (ReservationTransitionIllegal expectedState nextState))
        | otherwise -> do
            let changedRecord = record {reservationState = nextState}
                nextVersion = reservationRootVersion snapshot + 1
                changed = ReservationRootSnapshot nextVersion (Map.insert uid changedRecord (reservationRootRecords snapshot))
            writeTVar root changed
            pure (Right (ReservationTransitioned changedRecord nextVersion))

candidateRecord :: ReservationCandidate -> ReservationRecord
candidateRecord candidate =
  ReservationRecord
    (candidateUid candidate)
    Reserved
    (candidateNode candidate)
    (candidateGeneration candidate)
    (candidateTemplateDigest candidate)
    (candidateFullDebit candidate)
    (candidateTerminalDebit candidate)
    False

legalTransition :: ReservationState -> ReservationState -> Bool
legalTransition Reserved BindingInFlight = True
legalTransition BindingInFlight Bound = True
legalTransition Bound Terminating = True
legalTransition Terminating TerminalRetained = True
legalTransition _ _ = False
