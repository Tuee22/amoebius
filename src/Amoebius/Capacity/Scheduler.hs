{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Aggregate scheduler reservation algebra used by the later live scheduler.
-- Unknown Binding outcomes remain charged and every guard is bound to one
-- complete root-ledger snapshot.
module Amoebius.Capacity.Scheduler
  ( ReservationState (..)
  , ContentExtent (..)
  , CompleteResourceReservation (..)
  , ReservationLedgerRow (..)
  , SchedulerSupply (..)
  , SchedulerSnapshot (..)
  , CandidateReservation (..)
  , ProvisionedExecutionSchedulingGuard (..)
  , SchedulerError (..)
  , mkCompleteReservation
  , reservationProjection
  , provisionSchedulingGuard
  , ledgerOnlyAbsentRecovery
  , beginBinding
  , confirmBound
  ) where

import Amoebius.Capacity.Types
  ( Axis (..)
  , ResourceEnvelope
  , ResourceVector (..)
  , addResources
  , envelopeHeadroom
  , envelopeRequests
  , zeroResources
  )
import Control.DeepSeq (NFData)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import GHC.Generics (Generic)
import Numeric.Natural (Natural)

data ReservationState
  = Reserved
  | BindingInFlight
  | Bound
  | Terminating
  | TerminalRetained
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data ContentExtent = ContentExtent
  { contentAllocationDomain :: Text
  , contentIdentity :: Text
  , contentBytes :: Natural
  }
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

data CompleteResourceReservation = CompleteResourceReservation
  { reservationOwner :: Text
  , reservationRequired :: ResourceVector
  , reservationPad :: ResourceVector
  , reservationReserved :: ResourceVector
  , reservationCsiVolumes :: Set (Text, Text)
  , reservationContent :: [ContentExtent]
  , reservationAcceleratorDevices :: Set Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ReservationLedgerRow = ReservationLedgerRow
  { ledgerReservation :: CompleteResourceReservation
  , ledgerReservationState :: ReservationState
  , ledgerPodPresent :: Bool
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data SchedulerSupply = SchedulerSupply
  { schedulerAllocatable :: ResourceVector
  , schedulerCsiCapacity :: Map Text Natural
  , schedulerAcceleratorDevices :: Set Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data SchedulerSnapshot = SchedulerSnapshot
  { schedulerSnapshotFingerprint :: Text
  , schedulerRootVersion :: Natural
  , schedulerSupply :: SchedulerSupply
  , schedulerStaticReservations :: [CompleteResourceReservation]
  , schedulerForeignReservations :: [CompleteResourceReservation]
  , schedulerResidentReservations :: [CompleteResourceReservation]
  , schedulerLedgerRows :: [ReservationLedgerRow]
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

newtype CandidateReservation = CandidateReservation
  { candidateReservation :: CompleteResourceReservation
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data ProvisionedExecutionSchedulingGuard = ProvisionedExecutionSchedulingGuard
  { schedulingGuardFingerprint :: Text
  , schedulingGuardRootVersion :: Natural
  , schedulingGuardCandidate :: Text
  , schedulingGuardAggregate :: ResourceVector
  , schedulingGuardContent :: Map (Text, Text) Natural
  , schedulingGuardCsiVolumes :: Set (Text, Text)
  , schedulingGuardDevices :: Set Text
  }
  deriving stock (Eq, Generic, Show)
  deriving anyclass (NFData)

data SchedulerError
  = ReservationProjectionMismatch Text
  | SchedulerSnapshotChanged Text Text
  | SchedulerCapacityExceeded Axis Natural Natural
  | SchedulerCsiExceeded Text Natural Natural
  | SchedulerContentConflict Text Natural Natural
  | SchedulerDeviceConflict Text
  | SchedulerDeviceMissing Text
  | SchedulerStateTransitionInvalid ReservationState ReservationState
  deriving stock (Eq, Generic, Ord, Show)
  deriving anyclass (NFData)

mkCompleteReservation
  :: Text
  -> ResourceEnvelope
  -> Set (Text, Text)
  -> [ContentExtent]
  -> Set Text
  -> Either SchedulerError CompleteResourceReservation
mkCompleteReservation owner envelope csi content devices =
  let required = envelopeRequests envelope
      padding = envelopeHeadroom envelope
      projection = addResources required padding
   in Right
        CompleteResourceReservation
          { reservationOwner = owner
          , reservationRequired = required
          , reservationPad = padding
          , reservationReserved = projection
          , reservationCsiVolumes = csi
          , reservationContent = content
          , reservationAcceleratorDevices = devices
          }

reservationProjection :: CompleteResourceReservation -> Either SchedulerError ResourceVector
reservationProjection reservation
  | reservationReserved reservation == addResources (reservationRequired reservation) (reservationPad reservation) =
      Right (reservationReserved reservation)
  | otherwise = Left (ReservationProjectionMismatch (reservationOwner reservation))

provisionSchedulingGuard
  :: Text
  -> SchedulerSnapshot
  -> CandidateReservation
  -> Either SchedulerError ProvisionedExecutionSchedulingGuard
provisionSchedulingGuard expectedFingerprint snapshot candidate
  | expectedFingerprint /= schedulerSnapshotFingerprint snapshot =
      Left (SchedulerSnapshotChanged expectedFingerprint (schedulerSnapshotFingerprint snapshot))
  | otherwise = do
      let activeLedger = fmap ledgerDebit (schedulerLedgerRows snapshot)
          reservations =
            schedulerStaticReservations snapshot
              <> schedulerForeignReservations snapshot
              <> schedulerResidentReservations snapshot
              <> activeLedger
              <> [candidateReservation candidate]
      projections <- mapM reservationProjection reservations
      let aggregate = foldl addResources zeroResources projections
          supply = schedulerSupply snapshot
      ensureResources aggregate (schedulerAllocatable supply)
      csi <- unionCsi (schedulerCsiCapacity supply) reservations
      content <- unionContent reservations
      devices <- unionDevices (schedulerAcceleratorDevices supply) reservations
      pure
        ProvisionedExecutionSchedulingGuard
          { schedulingGuardFingerprint = schedulerSnapshotFingerprint snapshot
          , schedulingGuardRootVersion = schedulerRootVersion snapshot
          , schedulingGuardCandidate = reservationOwner (candidateReservation candidate)
          , schedulingGuardAggregate = aggregate
          , schedulingGuardContent = content
          , schedulingGuardCsiVolumes = csi
          , schedulingGuardDevices = devices
          }

ledgerOnlyAbsentRecovery :: ReservationLedgerRow -> CompleteResourceReservation
ledgerOnlyAbsentRecovery row
  | ledgerPodPresent row = ledgerReservation row
  | otherwise = case ledgerReservationState row of
      Reserved -> ledgerReservation row
      BindingInFlight -> ledgerReservation row
      Bound -> ledgerReservation row
      Terminating -> ledgerReservation row
      TerminalRetained -> retainedOnly (ledgerReservation row)

beginBinding :: ProvisionedExecutionSchedulingGuard -> ReservationLedgerRow -> Either SchedulerError ReservationLedgerRow
beginBinding _ row = case ledgerReservationState row of
  Reserved -> Right row {ledgerReservationState = BindingInFlight}
  state -> Left (SchedulerStateTransitionInvalid state BindingInFlight)

confirmBound :: ProvisionedExecutionSchedulingGuard -> ReservationLedgerRow -> Either SchedulerError ReservationLedgerRow
confirmBound _ row = case ledgerReservationState row of
  BindingInFlight -> Right row {ledgerReservationState = Bound, ledgerPodPresent = True}
  state -> Left (SchedulerStateTransitionInvalid state Bound)

ledgerDebit :: ReservationLedgerRow -> CompleteResourceReservation
ledgerDebit = ledgerOnlyAbsentRecovery

retainedOnly :: CompleteResourceReservation -> CompleteResourceReservation
retainedOnly reservation =
  reservation
    { reservationRequired = zeroResources
    , reservationPad = zeroResources
    , reservationReserved = zeroResources
    , reservationCsiVolumes = Set.empty
    , reservationAcceleratorDevices = Set.empty
    }

ensureResources :: ResourceVector -> ResourceVector -> Either SchedulerError ()
ensureResources required available
  | resourceCpu required > resourceCpu available = exceeded CpuAxis resourceCpu
  | resourceMemory required > resourceMemory available = exceeded MemoryAxis resourceMemory
  | resourceEphemeralStorage required > resourceEphemeralStorage available = exceeded EphemeralStorageAxis resourceEphemeralStorage
  | resourcePodSlots required > resourcePodSlots available = exceeded PodSlotsAxis resourcePodSlots
  | otherwise = Right ()
 where
  exceeded axis project = Left (SchedulerCapacityExceeded axis (project required) (project available))

unionCsi :: Map Text Natural -> [CompleteResourceReservation] -> Either SchedulerError (Set (Text, Text))
unionCsi limits reservations = do
  let unioned = Set.unions (fmap reservationCsiVolumes reservations)
      byDriver = Map.fromListWith (+) [(driver, 1 :: Natural) | (driver, _) <- Set.toList unioned]
  mapM_ check (Map.toList byDriver)
  Right unioned
 where
  check (driver, required) =
    let available = Map.findWithDefault 0 driver limits
     in if required <= available
          then Right ()
          else Left (SchedulerCsiExceeded driver required available)

unionContent :: [CompleteResourceReservation] -> Either SchedulerError (Map (Text, Text) Natural)
unionContent reservations = go Map.empty (sortOn key (concatMap reservationContent reservations))
 where
  key extent = (contentAllocationDomain extent, contentIdentity extent)
  go result remaining = case remaining of
    [] -> Right result
    extent : rest -> case Map.lookup (key extent) result of
      Nothing -> go (Map.insert (key extent) (contentBytes extent) result) rest
      Just bytes
        | bytes == contentBytes extent -> go result rest
        | otherwise -> Left (SchedulerContentConflict (contentIdentity extent) bytes (contentBytes extent))

unionDevices :: Set Text -> [CompleteResourceReservation] -> Either SchedulerError (Set Text)
unionDevices available reservations = go Set.empty (concatMap (Set.toList . reservationAcceleratorDevices) reservations)
 where
  go result remaining = case remaining of
    [] -> Right result
    device : rest
      | device `Set.notMember` available -> Left (SchedulerDeviceMissing device)
      | device `Set.member` result -> Left (SchedulerDeviceConflict device)
      | otherwise -> go (Set.insert device result) rest
