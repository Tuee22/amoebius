{-# LANGUAGE OverloadedStrings #-}

-- | The legal twin, differing only in where the witness comes from.
--
-- 'lift_and_compose_doctrine.md' section 7 says a witness is produced by observation and
-- cannot be asserted. This is what that leaves a caller: hand 'observe' what the world
-- reported, and take the witness if the report licenses the move.
module LiftCalculusWitnessComesFromAnObservation where

import Amoebius.Calculus.Lift.Layer (Layer (..), SLayer (..))
import Amoebius.Calculus.Lift.Witness (Observation (FrameRunning), Witness, observe)

-- The accepted program: the witness exists because something was seen.
entering :: Maybe (Witness 'OnHost 'InFrame)
entering = observe SOnHost SInFrame (FrameRunning "lima-linux")
