{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}

module ReconcileCoreMutants
  ( reemitAtFixedPoint
  , oscillatingApply
  , acceptTokenReuse
  , dropReservationOnCrash
  ) where

import Amoebius.Capacity.Scheduler (ReservationLedgerRow)
import Amoebius.Reconcile.Core
import Amoebius.Reconcile.Sim (TokenResult (TokenApplied))

reemitAtFixedPoint
  :: ObservedInventory
  -> Either Refusal ActionSet
  -> Either Refusal ActionSet
reemitAtFixedPoint inventory result = case result of
  Right [] -> case
      [SomeAction (DeleteObject identifier present)
      | (identifier, SomeObservation present@PresentObservation {}) <- inventoryEntries inventory]
    of
      action : _ -> Right [action]
      [] -> result
  _ -> result

oscillatingApply :: SomeAction -> ObservedInventory -> ObservedInventory
oscillatingApply action@(SomeAction planned) inventory = case planned of
  ApplyObject identifier _ (PresentObservation prior) ->
    applyActionToInventory
      (SomeAction (ApplyObject identifier (DesiredRevision prior) (PresentObservation "mutant-current")))
      (applyActionToInventory action inventory)
  _ -> applyActionToInventory action inventory

acceptTokenReuse :: TokenResult
acceptTokenReuse = TokenApplied

dropReservationOnCrash :: ReservationLedgerRow -> Maybe ReservationLedgerRow
dropReservationOnCrash _ = Nothing
