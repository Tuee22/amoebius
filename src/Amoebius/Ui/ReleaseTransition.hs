{-# LANGUAGE CPP #-}

module Amoebius.Ui.ReleaseTransition
  ( Release (..)
  , TransitionState (..)
  , TransitionError (..)
  , beginRelease
  , observeWatermark
  , shiftGateway
  , stalePlanDecision
  ) where

data Release = ReleaseA | ReleaseB deriving stock (Eq, Ord, Show)
data TransitionState = TransitionState
  { desiredRelease :: Release
  , projectorWatermark :: Release
  , gatewayRelease :: Release
  , activePlans :: [Release]
  }
  deriving stock (Eq, Show)
data TransitionError = ProjectorNotCaughtUp | ReloadRequired deriving stock (Eq, Show)

beginRelease :: Release -> TransitionState -> TransitionState
beginRelease release state = state {desiredRelease = release, activePlans = [ReleaseA, ReleaseB]}
observeWatermark :: Release -> TransitionState -> TransitionState
observeWatermark release state = state {projectorWatermark = release}
shiftGateway :: TransitionState -> Either TransitionError TransitionState
#ifdef PHASE57_SHIFT_BEFORE_WATERMARK_MUTANT
shiftGateway state = Right state {gatewayRelease = desiredRelease state}
#else
shiftGateway state
  | desiredRelease state == projectorWatermark state = Right state {gatewayRelease = desiredRelease state}
  | otherwise = Left ProjectorNotCaughtUp
#endif
stalePlanDecision :: Release -> TransitionState -> Either TransitionError ()
stalePlanDecision client state
  | client == gatewayRelease state = Right ()
  | otherwise = Left ReloadRequired
