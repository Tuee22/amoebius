{-# LANGUAGE OverloadedStrings #-}

-- | The illegal half of the composition pair: two paths whose layers do not meet.
--
-- The only difference from the twin is which path is inner and which is outer. The inner
-- one now ends inside a container and the outer one starts on the host, so the shared
-- layer 'compose' requires would have to be both 'InContainer' and 'OnHost' at once. The
-- program has no type, and the rejection says exactly that — which is the reason this
-- fixture asserts, rather than merely that something failed.
module LiftCalculusPathsDoNotMeet where

import Amoebius.Calculus.Lift.Compose (Path, compose, here, step)
import Amoebius.Calculus.Lift.Layer (Layer (..), SLayer (..))
import Amoebius.Calculus.Lift.Transition (enterContainer, enterFrame)
import Amoebius.Calculus.Lift.Witness (Witness)

-- The rejected program: the inner path ends inside a container and the outer one starts
-- on the host, so there is no layer for them to meet at.
reached :: Witness 'OnHost 'InFrame -> Witness 'InFrame 'InContainer -> Path 'InFrame 'InFrame
reached frame engine =
  compose (step (enterFrame frame) (here SOnHost)) (step (enterContainer engine) (here SInFrame))
