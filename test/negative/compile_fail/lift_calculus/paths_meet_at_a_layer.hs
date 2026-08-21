{-# LANGUAGE OverloadedStrings #-}

-- | The legal twin, differing only in the order the two paths are composed.
--
-- 'lift_and_compose_doctrine.md' section 7 says two lifts compose exactly when the inner
-- one's target layer is the outer one's source layer, and calls that a type equation
-- rather than a check. Here the equation holds: the inner path ends inside the frame and
-- the outer path starts there, so the composition has a type and it is
-- @Path 'OnHost 'InContainer@ — the two-move path the relation deliberately refuses to
-- admit as one primitive.
module LiftCalculusPathsMeetAtALayer where

import Amoebius.Calculus.Lift.Compose (Path, compose, here, step)
import Amoebius.Calculus.Lift.Layer (Layer (..), SLayer (..))
import Amoebius.Calculus.Lift.Transition (enterContainer, enterFrame)
import Amoebius.Calculus.Lift.Witness (Observation (EngineResponding, FrameRunning), Witness, observe)

-- The accepted program: on-host to in-frame, then in-frame to in-container.
reached :: Witness 'OnHost 'InFrame -> Witness 'InFrame 'InContainer -> Path 'OnHost 'InContainer
reached frame engine =
  compose (step (enterContainer engine) (here SInFrame)) (step (enterFrame frame) (here SOnHost))

-- Both witnesses come from an observation; neither is written down.
observed :: Maybe (Path 'OnHost 'InContainer)
observed = do
  frame <- observe SOnHost SInFrame (FrameRunning "lima-linux")
  engine <- observe SInFrame SInContainer (EngineResponding "containerd")
  pure (reached frame engine)
