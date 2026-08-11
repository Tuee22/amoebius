{-# LANGUAGE CPP #-}

module Amoebius.Release.RolloutPlan
  ( RolloutPhase (..)
  , rolloutPlan
  , ReadinessObservation (..)
  , RolloutState
  , emptyRolloutState
  , appliedPhases
  , RolloutError (..)
  , applyPhase
  ) where

data RolloutPhase = BaseApply | SchemaMigration | Finalize
  deriving stock (Eq, Ord, Read, Show)

rolloutPlan :: [RolloutPhase]
#ifdef PHASE39_ROLLOUT_REORDERS_RETIRE_MUTANT
rolloutPlan = [BaseApply, Finalize, SchemaMigration]
#else
rolloutPlan = [BaseApply, SchemaMigration, Finalize]
#endif

data ReadinessObservation
  = LiveObjectReady RolloutPhase
  | SelfReportedDone RolloutPhase
  deriving stock (Eq, Show)

newtype RolloutState = RolloutState {appliedPhases :: [RolloutPhase]}
  deriving stock (Eq, Show)

emptyRolloutState :: RolloutState
emptyRolloutState = RolloutState []

data RolloutError
  = PhaseOutOfOrder RolloutPhase RolloutPhase
  | PhaseReadinessNotExternallyObserved RolloutPhase
  | RolloutAlreadyComplete
  deriving stock (Eq, Show)

applyPhase :: RolloutPhase -> ReadinessObservation -> RolloutState -> Either RolloutError RolloutState
applyPhase phase observation state = case drop (length (appliedPhases state)) rolloutPlan of
  [] -> Left RolloutAlreadyComplete
  expected : _
    | phase /= expected -> Left (PhaseOutOfOrder expected phase)
    | not (accepted observation) -> Left (PhaseReadinessNotExternallyObserved phase)
    | otherwise -> Right (RolloutState (appliedPhases state <> [phase]))
 where
  accepted (LiveObjectReady observed) = observed == phase
#ifdef PHASE39_PHASE_GATE_SELFREPORT_MUTANT
  accepted (SelfReportedDone observed) = observed == phase
#else
  accepted (SelfReportedDone _) = False
#endif
