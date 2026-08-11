module Amoebius.Sim.Fakes.Clock
  ( ClockState
  , emptyClock
  , advanceClock
  , elapsedMicros
  ) where

newtype ClockState = ClockState Int
  deriving stock (Eq, Show)

emptyClock :: ClockState
emptyClock = ClockState 0

advanceClock :: Int -> ClockState -> ClockState
advanceClock ticks (ClockState elapsed) = ClockState (elapsed + max 0 ticks)

elapsedMicros :: ClockState -> Int
elapsedMicros (ClockState elapsed) = elapsed
