{-# LANGUAGE OverloadedStrings #-}

-- | What a workflow did: the arms it took, what it provisioned, and how each obligation
-- left the outstanding set.
--
-- 'workflow_calculus_doctrine.md' section 3 says teardown is /derived, never authored/ —
-- the obligations a workflow accumulated are the teardown plan. The ledger is that
-- derivation made readable: nothing writes to it except the arms themselves, so it cannot
-- drift from what the workflow actually did, and an independently authored table can be
-- replayed against it.
--
-- The two questions the ledger is asked are deliberately different, because they fail
-- differently. Whether the provisioned and released /sets/ are equal catches an obligation
-- that was dropped. Whether any resource appears twice among the released catches one
-- discharged twice — which leaves the sets equal and is invisible to the first question.
module Amoebius.Calculus.Workflow.Ledger
  ( Ledger
  , emptyLedger
  , ledgerArms
  , ledgerProvisioned
  , ledgerReleased
  , recordArm
  , recordProvision
  , recordRelease
  , balances
  , dischargedOnce
  ) where

import Amoebius.Calculus.Workflow.Arm (Arm, Discharge, Resource)
import Data.List (nub, sort)

-- | The record. Entries are appended in the order the arms ran, so the list is a trace
-- rather than a summary and a reader can see what happened rather than what totals it
-- came to.
data Ledger = Ledger
  { ledgerArms :: [Arm]
  , ledgerProvisioned :: [Resource]
  , ledgerReleased :: [(Resource, Discharge)]
  }
  deriving stock (Eq, Show)

emptyLedger :: Ledger
emptyLedger = Ledger {ledgerArms = [], ledgerProvisioned = [], ledgerReleased = []}

recordArm :: Arm -> Ledger -> Ledger
recordArm arm ledger = ledger {ledgerArms = ledgerArms ledger <> [arm]}

recordProvision :: Resource -> Ledger -> Ledger
recordProvision resource ledger =
  ledger {ledgerProvisioned = ledgerProvisioned ledger <> [resource]}

-- | Record that an obligation left the outstanding set, and how.
--
-- This module carries no seeded defect on purpose. The two questions below are the
-- instrument, and an instrument that is also the thing under test measures itself: the
-- mutations live in the arms that call this, where a dropped or doubled discharge is the
-- defect a workflow could actually have.
recordRelease :: Resource -> Discharge -> Ledger -> Ledger
recordRelease resource discharge ledger =
  ledger {ledgerReleased = ledgerReleased ledger <> [(resource, discharge)]}

-- | Every resource provisioned was released, and every resource released was provisioned.
--
-- Stated over sets on purpose: this is the question a dropped obligation fails and a
-- double discharge passes, and keeping the two questions apart is what makes each mutant
-- attributable to one of them.
balances :: Ledger -> Bool
balances ledger =
  sort (nub (ledgerProvisioned ledger)) == sort (nub (fmap fst (ledgerReleased ledger)))

-- | No resource left the outstanding set more than once.
dischargedOnce :: Ledger -> Bool
dischargedOnce ledger = length released == length (nub released)
  where
    released = fmap fst (ledgerReleased ledger)
