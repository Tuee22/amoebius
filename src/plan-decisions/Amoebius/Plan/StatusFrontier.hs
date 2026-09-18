{-# LANGUAGE OverloadedStrings #-}

{- | The one ordered lifecycle admitted by numbered phase validation.

A gate candidate is evaluated at a frontier: every earlier phase is Done, the
candidate phase is Active, and every later phase is Blocked.  Applying a passing
result advances that frontier by exactly one table position.  Keeping this
projection typed prevents a reset-only parser, a Markdown marker, or a hole in
the completed prefix from becoming an alternative status authority.

Ordinals are positions of the phase-identity table, never arithmetic on the
number: the successor of the DSL barrier is the bootstrap handoff across the
reserved gap (DL-0008).
-}
module Amoebius.Plan.StatusFrontier
  ( PlanStatus (..)
  , StatusFrontier
  , completedPrefixDueOrdinal
  , frontierAfterPass
  , frontierForGate
  , initialFrontier
  , parseTrackerStatus
  , phaseStatusAt
  , recognizeStatusFrontier
  , renderPhaseStatusLine
  , renderSprintStatus
  , renderStatusMarker
  , renderTrackerStatus
  , sprintStatusAt
  ) where

import Amoebius.Plan.PhaseIdentity qualified as PhaseIdentity
import Data.Maybe (fromMaybe)
import Data.Text (Text)

data PlanStatus
  = Done
  | ActiveNotValidated
  | BlockedNotValidated
  deriving (Eq, Ord, Show)

-- | The terminal state or one table-bounded active ordinal. The constructor is
-- not exported: a frontier is built only through 'frontierForGate',
-- 'frontierAfterPass', and 'recognizeStatusFrontier'.
data StatusFrontier
  = OpenAt Int
  | AllDone
  deriving (Eq, Ord, Show)

initialFrontier :: StatusFrontier
initialFrontier = OpenAt PhaseIdentity.phaseDomainLowerOrdinal

frontierForGate :: Int -> Maybe StatusFrontier
frontierForGate ordinal
  | PhaseIdentity.isPhaseOrdinal ordinal = Just (OpenAt ordinal)
  | otherwise = Nothing

frontierAfterPass :: StatusFrontier -> Int -> Maybe StatusFrontier
frontierAfterPass frontier passed = case frontier of
  OpenAt active
    | active == passed && PhaseIdentity.isPhaseOrdinal passed ->
        Just (maybe AllDone OpenAt (PhaseIdentity.successorOrdinal passed))
  _ -> Nothing

{- | Recognize a recorded lifecycle only when the complete table-sized status
vector is exactly one canonical frontier.  Looking only for an @Active@ row
would admit holes, multiple active phases, and premature terminal states.

This function recognizes a structural projection; it does not prove that the
gate transitions represented by the completed prefix occurred.
-}
recognizeStatusFrontier :: [PlanStatus] -> Maybe StatusFrontier
recognizeStatusFrontier statuses = case matchingFrontiers of
  [frontier] -> Just frontier
  _ -> Nothing
 where
  matchingFrontiers =
    [ frontier
    | frontier <- canonicalFrontiers
    , statuses == fmap (phaseStatusAt frontier) PhaseIdentity.phaseOrdinals
    ]

{- | Obligations in the generic worktree diagnostic extend through the recorded
completed prefix.  At the initial frontier the first phase remains the finite
seed that must be ready before its first gate, so its ordinal is the lower
bound rather than an invented predecessor.
-}
completedPrefixDueOrdinal :: StatusFrontier -> Int
completedPrefixDueOrdinal frontier = case frontier of
  AllDone -> PhaseIdentity.phaseDomainUpperOrdinal
  OpenAt active -> fromMaybe PhaseIdentity.phaseDomainLowerOrdinal (PhaseIdentity.predecessorOrdinal active)

phaseStatusAt :: StatusFrontier -> Int -> PlanStatus
phaseStatusAt frontier ordinal = case frontier of
  AllDone -> Done
  OpenAt active
    | ordinal < active -> Done
    | ordinal == active -> ActiveNotValidated
    | otherwise -> BlockedNotValidated

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

parseTrackerStatus :: Text -> Maybe PlanStatus
parseTrackerStatus rendered = case rendered of
  "✅ Done" -> Just Done
  "🔄 Active — NOT VALIDATED" -> Just ActiveNotValidated
  "⏸️ Blocked — NOT VALIDATED" -> Just BlockedNotValidated
  _ -> Nothing

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

canonicalFrontiers :: [StatusFrontier]
canonicalFrontiers =
  [frontier | ordinal <- PhaseIdentity.phaseOrdinals, Just frontier <- [frontierForGate ordinal]]
    <> [AllDone]
