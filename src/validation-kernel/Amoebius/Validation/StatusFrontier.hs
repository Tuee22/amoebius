{-# LANGUAGE OverloadedStrings #-}

{- | The one ordered lifecycle admitted by numbered phase validation.

A gate candidate is evaluated at a frontier: every earlier phase is Done,
the candidate phase is Active, and every later phase is Blocked.  Applying
a passing result advances that frontier by exactly one phase.  Keeping this
projection typed prevents a reset-only parser, a Markdown marker, or a hole
in the completed prefix from becoming an alternative status authority.
-}
module Amoebius.Validation.StatusFrontier (
    PlanStatus (..),
    StatusFrontier,
    frontierAfterPass,
    frontierForGate,
    initialFrontier,
    phaseStatusAt,
    renderPhaseStatusLine,
    renderSprintStatus,
    renderStatusMarker,
    renderTrackerStatus,
    sprintStatusAt,
) where

import Amoebius.Validation.PolicyContract.Internal qualified as Policy
import Data.Text (Text)

data PlanStatus
    = Done
    | ActiveNotValidated
    | BlockedNotValidated
    deriving (Eq, Ord, Show)

{- | The terminal state or one policy-bounded active ordinal.  Raw integers and
caller-supplied upper bounds are deliberately absent from the representation.
-}
data StatusFrontier
    = OpenAt Policy.PhaseOrdinal
    | AllDone
    deriving (Eq, Ord, Show)

initialFrontier :: StatusFrontier
initialFrontier = OpenAt (Policy.phaseDomainLower canonicalOrdering)

frontierForGate :: Int -> Maybe StatusFrontier
frontierForGate ordinal = OpenAt <$> Policy.mkPhaseOrdinal ordinal

frontierAfterPass :: StatusFrontier -> Int -> Maybe StatusFrontier
frontierAfterPass frontier passed = case (frontier, Policy.mkPhaseOrdinal passed) of
    (OpenAt active, Just passedOrdinal)
        | active == passedOrdinal && passedOrdinal == Policy.phaseDomainUpper canonicalOrdering -> Just AllDone
        | active == passedOrdinal -> OpenAt <$> Policy.mkPhaseOrdinal (passed + 1)
    _ -> Nothing

phaseStatusAt :: StatusFrontier -> Int -> PlanStatus
phaseStatusAt frontier ordinal = case frontier of
    AllDone -> Done
    OpenAt active
        | ordinal < activeOrdinal -> Done
        | ordinal == activeOrdinal -> ActiveNotValidated
        | otherwise -> BlockedNotValidated
      where
        activeOrdinal = Policy.phaseOrdinalNumber active

sprintStatusAt :: StatusFrontier -> Int -> Int -> PlanStatus
sprintStatusAt frontier phaseOrdinal sprintOrdinal =
    case phaseStatusAt frontier phaseOrdinal of
        Done -> Done
        ActiveNotValidated
            | sprintOrdinal == 1 -> ActiveNotValidated
            | otherwise -> BlockedNotValidated
        BlockedNotValidated -> BlockedNotValidated

renderTrackerStatus :: PlanStatus -> Text
renderTrackerStatus status = case status of
    Done -> "✅ Done"
    ActiveNotValidated -> "🔄 Active — NOT VALIDATED"
    BlockedNotValidated -> "⏸️ Blocked — NOT VALIDATED"

renderPhaseStatusLine :: PlanStatus -> Text
renderPhaseStatusLine status = renderTrackerStatus status <> "."

renderSprintStatus :: PlanStatus -> Text
renderSprintStatus status = case status of
    Done -> "Done"
    ActiveNotValidated -> "Active — NOT VALIDATED"
    BlockedNotValidated -> "Blocked — NOT VALIDATED"

renderStatusMarker :: PlanStatus -> Text
renderStatusMarker status = case status of
    Done -> "✅"
    ActiveNotValidated -> "🔄"
    BlockedNotValidated -> "⏸️"

canonicalOrdering :: Policy.OrderingContract
canonicalOrdering = Policy.orderingContract Policy.canonicalPolicyContract
