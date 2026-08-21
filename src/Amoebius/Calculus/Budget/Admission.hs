{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Admission: the only place a declared demand may fail.
--
-- 'jit_budget_doctrine.md' section 4 makes admission a decision taken /before/ any work,
-- so a refusal costs nothing and leaves nothing behind. Both halves are visible in the
-- type: 'admit' is a pure function from a budget and a demand to a reservation or a
-- refusal, and the budget it returns on the refusal path is the budget it was given.
--
-- The refusal is a value with a reason rather than a boolean, because a caller that knows
-- /why/ it was refused can choose a smaller variant, and 'admitFirst' exists precisely to
-- express that choice in one step instead of as a caller that tries and cleans up.
--
-- What this module deliberately does not decide is whether the bytes then fit on the
-- disk. Section 7 keeps that a live observation: a grant remains valid while the space it
-- names is taken by something outside amoebius, and the calculus's claim is only that
-- amoebius wrote nothing unauthorised.
module Amoebius.Calculus.Budget.Admission
  ( -- * The demand
    Demand (..)
    -- * The verdict
  , Refusal (..)
  , RefusalTag (..)
  , refusalTag
  , admissionRefusalTags
  , refusalTagText
    -- * The reservation
  , Reservation
  , reservationBytes
  , reservationLocation
  , reservationPurpose
    -- * The budget a grant is spent through
  , Budget
  , openBudget
  , holding
  , budgetGrant
  , budgetHeldBytes
  , budgetHeldSlots
    -- * The operations
  , admit
  , admitFirst
  , release
  , settle
  ) where

import Amoebius.Calculus.Budget.Grant
  ( Allowance
  , Bytes (..)
  , Grant
  , Location
  , Purpose
  , Slots (..)
  , addBytes
  , addSlots
  , allowanceCeiling
  , allowanceConcurrency
  , allowancePerItem
  , grantAllowance
  , grantLocation
  , grantPurpose
  , subtractBytes
  , subtractSlots
  )
import Data.Text (Text)

-- | One materialization's declared worst case, at a location and for a purpose.
--
-- The worst case is /declared/ rather than measured, because admission happens before the
-- rendering exists. Section 7 records what that costs: a recipe exceeding its own
-- declaration is refused mid-write instead, and that refusal is the store's problem
-- rather than admission's.
data Demand = Demand
  { demandLocation :: Location
  , demandPurpose :: Purpose
  , demandWorstCase :: Bytes
  }
  deriving stock (Eq, Ord, Show)

-- | Why a demand was refused. Every arm carries the two quantities that decided it.
--
-- 'DeclarationExceeded' is the section 7 residue and is never returned by 'admit': it is
-- the store's refusal, and it lives in this type so that a caller handles one refusal
-- vocabulary rather than two. 'admissionRefusalTags' is the subset admission can produce,
-- and the authored capacity table is joined against exactly that subset.
data Refusal
  = WrongLocation Location Location
  | WrongPurpose Purpose Purpose
  | PerItemBoundExceeded Bytes Bytes
  | CeilingExceeded Bytes Bytes
  | ConcurrencyExhausted Slots Slots
  | DeclarationExceeded Bytes Bytes
  deriving stock (Eq, Show)

-- | The reason, without its quantities. The authored table names these, because a table
-- that had to restate the arithmetic would be a second implementation rather than an
-- oracle.
data RefusalTag
  = WrongLocationTag
  | WrongPurposeTag
  | PerItemBoundExceededTag
  | CeilingExceededTag
  | ConcurrencyExhaustedTag
  | DeclarationExceededTag
  deriving stock (Eq, Ord, Show, Enum, Bounded)

refusalTag :: Refusal -> RefusalTag
refusalTag = \case
  WrongLocation _ _ -> WrongLocationTag
  WrongPurpose _ _ -> WrongPurposeTag
  PerItemBoundExceeded _ _ -> PerItemBoundExceededTag
  CeilingExceeded _ _ -> CeilingExceededTag
  ConcurrencyExhausted _ _ -> ConcurrencyExhaustedTag
  DeclarationExceeded _ _ -> DeclarationExceededTag

-- | The tags 'admit' can return, in the order it tests them. The list is written against
-- the closed 'RefusalTag' set below, so a tag added without a place in admission's order
-- fails to compile here rather than quietly going unchecked by the authored table.
admissionRefusalTags :: [RefusalTag]
admissionRefusalTags = concatMap admissionOrder [minBound .. maxBound]
  where
    admissionOrder :: RefusalTag -> [RefusalTag]
    admissionOrder = \case
      WrongLocationTag -> [WrongLocationTag]
      WrongPurposeTag -> [WrongPurposeTag]
      PerItemBoundExceededTag -> [PerItemBoundExceededTag]
      CeilingExceededTag -> [CeilingExceededTag]
      ConcurrencyExhaustedTag -> [ConcurrencyExhaustedTag]
      DeclarationExceededTag -> []

refusalTagText :: RefusalTag -> Text
refusalTagText = \case
  WrongLocationTag -> "wrong-location"
  WrongPurposeTag -> "wrong-purpose"
  PerItemBoundExceededTag -> "per-item-bound-exceeded"
  CeilingExceededTag -> "ceiling-exceeded"
  ConcurrencyExhaustedTag -> "concurrency-exhausted"
  DeclarationExceededTag -> "declaration-exceeded"

-- | A slot and the space for one worst case, taken from a budget and owed back to it.
--
-- No constructor is exported: a reservation is what 'admit' returns and nothing else, so
-- a caller cannot manufacture the authority to write by writing down a record.
data Reservation = Reservation
  { reservationBytes :: Bytes
  , reservationLocation :: Location
  , reservationPurpose :: Purpose
  }
  deriving stock (Eq, Ord, Show)

-- | A grant together with what is currently in flight against it.
--
-- The held bytes and the held slots are the two halves section 3 pairs. They are one
-- value because they are returned together: 'release' gives back both or neither.
data Budget = Budget
  { budgetGrant :: Grant
  , budgetHeldBytes :: Bytes
  , budgetHeldSlots :: Slots
  }
  deriving stock (Eq, Ord, Show)

-- | A budget holding a grant and nothing in flight.
openBudget :: Grant -> Budget
openBudget grant = holding grant (Bytes 0) (Slots 0)

-- | A budget over a grant with a stated amount already in flight.
--
-- This exists because section 2 makes the issuer's consistency model part of this
-- calculus: a process that dies holding a grant leaves in-flight work its successor has
-- to reconstitute, and a budget that could only ever start empty would have the successor
-- believe the ceiling was free. It grants no authority the grant did not already carry —
-- every 'admit' still decides against the allowance — so the introduction rule that
-- matters, the one for 'Grant' itself, stays with 'issue'.
holding :: Grant -> Bytes -> Slots -> Budget
holding grant held slots =
  Budget {budgetGrant = grant, budgetHeldBytes = held, budgetHeldSlots = slots}

-- | Decide one demand.
--
-- The order of the arms is the order the doctrine states the properties in — specificity
-- before size, the per-item bound before the ceiling, the ceiling before the concurrency
-- — and the authored table is written against that order, so a refusal is attributable to
-- one arm rather than to whichever check happened to run first.
admit :: Budget -> Demand -> Either Refusal (Reservation, Budget)
admit budget demand
  | demandLocation demand /= grantLocation grant =
      Left (WrongLocation (grantLocation grant) (demandLocation demand))
  | demandPurpose demand /= grantPurpose grant =
      Left (WrongPurpose (grantPurpose grant) (demandPurpose demand))
  | demandWorstCase demand > allowancePerItem bound =
      Left (PerItemBoundExceeded (allowancePerItem bound) (demandWorstCase demand))
  | wouldHold > allowanceCeiling bound =
      Left (CeilingExceeded (allowanceCeiling bound) wouldHold)
  | concurrencyExhausted =
      Left (ConcurrencyExhausted (allowanceConcurrency bound) (budgetHeldSlots budget))
  | otherwise = Right (reservation, taken)
  where
    grant = budgetGrant budget
    bound :: Allowance
    bound = grantAllowance grant
    wouldHold = addBytes (budgetHeldBytes budget) (demandWorstCase demand)
    reservation =
      Reservation
        { reservationBytes = demandWorstCase demand
        , reservationLocation = demandLocation demand
        , reservationPurpose = demandPurpose demand
        }
    taken =
      budget
        { budgetHeldBytes = wouldHold
        , budgetHeldSlots = addSlots (budgetHeldSlots budget) (Slots 1)
        }
#ifdef BUDGET_CALCULUS_CEILING_SEPARATED_FROM_CONCURRENCY_MUTANT
    -- The seeded split. The ceiling still holds and the concurrency it is shared across
    -- no longer does, which is the state section 3 says reads as a complete sentence and
    -- is an incomplete specification: four in-flight materializations each individually
    -- within budget overrun the ceiling together.
    concurrencyExhausted = False
#else
    concurrencyExhausted = budgetHeldSlots budget >= allowanceConcurrency bound
#endif

-- | The first candidate that fits.
--
-- A refusal names the last candidate's reason, because that is the smallest variant the
-- caller offered and therefore the one whose reason tells it something it can act on. An
-- empty candidate list is a caller asking for nothing, and is refused as a ceiling of
-- zero rather than accepted as a free write.
admitFirst :: Budget -> [Demand] -> Either Refusal (Reservation, Budget)
admitFirst budget = go (Left (CeilingExceeded (Bytes 0) (Bytes 0)))
  where
    go outcome [] = outcome
    go _ (candidate : rest) = case admit budget candidate of
      Right taken -> Right taken
      Left refusal -> go (Left refusal) rest

-- | Return the slot and the space. Both, or neither: a reservation that gave back its
-- bytes and kept its slot would leak concurrency, which is the half section 3 says is
-- easy to lose.
release :: Reservation -> Budget -> Budget
release reservation budget =
  budget
    { budgetHeldBytes = subtractBytes (budgetHeldBytes budget) (reservationBytes reservation)
    , budgetHeldSlots = subtractSlots (budgetHeldSlots budget) (Slots 1)
    }

-- | A materialization that completed. The worst case and the slot come back exactly as
-- 'release' returns them, and the artifact's /actual/ size takes their place.
--
-- Section 3 says a materialization returns both when it completes or fails; the two cases
-- differ in what is left behind, not in what is returned. A failure leaves nothing, so
-- 'release' is the whole story. A completion leaves an artifact, and the space that
-- artifact occupies is held against the ceiling until something reaps it — which is
-- section 5's question, and why a retained one needs a 'Amoebius.Calculus.Budget.Retention.Reaper'.
settle :: Reservation -> Bytes -> Budget -> Budget
settle reservation actual budget =
  let returned = release reservation budget
   in returned {budgetHeldBytes = addBytes (budgetHeldBytes returned) actual}
