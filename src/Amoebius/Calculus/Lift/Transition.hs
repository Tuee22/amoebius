{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The transition relation: total over the closed layer set, and wildcard-free.
--
-- 'lift_and_compose_doctrine.md' section 7 states the second part of the calculus: moving
-- an effect from one layer to another is a relation over the layer set, and it is
-- /total/ — every pair either has a constructor that performs the transition or has no
-- inhabitant at all. There is no fallback arm.
--
-- Totality is carried in two places and neither is redundant. At the type level, 'Lift'
-- has a constructor for exactly the admitted pairs, so @Lift 'InContainer 'OnHost@ is
-- uninhabited and the committed compile-fail fixture is what says so. At the value level,
-- 'admits' names all nine ordered pairs one by one; the authored pair table is joined
-- against it, and the seeded fallback mutant is caught by the scan for a catch-all arm
-- rather than by the table — because a fallback that answers correctly today is still the
-- thing that will answer for a layer added tomorrow.
--
-- Which pairs are admitted follows from what the layers are.
-- 'substrate_doctrine.md' section 4 has a host synthesize a Linux frame and that frame run
-- a container, so the relation moves outward one layer at a time. Nothing moves inward: an
-- effect confined by a frame cannot reach the host that provides it, which is the whole
-- point of the confinement. And nothing skips: reaching a container from the host is two
-- transitions, which is what composition is for.
module Amoebius.Calculus.Lift.Transition
  ( Lift
  , liftSource
  , liftTarget
  , liftDetail
  , enterFrame
  , enterContainer
  , remain
  , SomeLift (..)
  , admits
  ) where

import Amoebius.Calculus.Lift.Layer (Layer (..), SLayer (..), layerOf)
import Amoebius.Calculus.Lift.Witness (Witness, witnessDetail)
import Data.Text (Text)

-- | A primitive transition from one layer to the next, carrying the witness that licensed
-- it. The constructors are not exported: the three smart constructors below are the only
-- introduction rules, and each takes a witness of exactly its own transition.
data Lift (from :: Layer) (to :: Layer) where
  EnterFrame :: Witness 'OnHost 'InFrame -> Lift 'OnHost 'InFrame
  EnterContainer :: Witness 'InFrame 'InContainer -> Lift 'InFrame 'InContainer
  Remain :: SLayer l -> Witness l l -> Lift l l

-- | Enter a frame the host provides. The witness is the observation that it is running.
enterFrame :: Witness 'OnHost 'InFrame -> Lift 'OnHost 'InFrame
enterFrame = EnterFrame

-- | Enter a container the frame runs. The witness is the observation that its engine
-- answered.
enterContainer :: Witness 'InFrame 'InContainer -> Lift 'InFrame 'InContainer
enterContainer = EnterContainer

-- | Stay where you are. This is the relation's identity, and it takes a witness like every
-- other transition: \"the effect is still running where it was\" is a claim about the
-- world, and an unwitnessed identity would be the one arm through which an unobserved
-- layer could enter a path.
remain :: SLayer l -> Witness l l -> Lift l l
remain = Remain

-- | The source layer of a transition, as a value.
liftSource :: Lift from to -> Layer
liftSource = \case
  EnterFrame _witness -> OnHost
  EnterContainer _witness -> InFrame
  Remain layer _witness -> layerOf layer

-- | The target layer of a transition, as a value.
liftTarget :: Lift from to -> Layer
liftTarget = \case
  EnterFrame _witness -> InFrame
  EnterContainer _witness -> InContainer
  Remain layer _witness -> layerOf layer

-- | What the witness that licensed the transition recorded.
liftDetail :: Lift from to -> Text
liftDetail = \case
  EnterFrame witness -> witnessDetail witness
  EnterContainer witness -> witnessDetail witness
  Remain _layer witness -> witnessDetail witness

-- | A transition with its indices hidden, carrying the singletons that recover them.
--
-- A plan assembled at run time is a list of these, and the singletons are what let it be
-- checked under the same type equation a statically written composition obeys.
data SomeLift where
  SomeLift :: SLayer from -> SLayer to -> Lift from to -> SomeLift

-- | The relation, as a decision over the closed set.
--
-- All nine ordered pairs are named. There is no catch-all arm, and the gate scans this
-- module for one: a fallback is not wrong because of the answer it gives today, it is
-- wrong because it is the arm a fourth layer would silently fall into.
admits :: Layer -> Layer -> Bool
admits from to = case (from, to) of
  (OnHost, OnHost) -> True
#ifndef LIFT_CALCULUS_REMOVE_ENTER_FRAME_RELATION_MUTANT
  (OnHost, InFrame) -> True
#endif
  (OnHost, InContainer) -> False
  (InFrame, InFrame) -> True
#ifndef LIFT_CALCULUS_REMOVE_ENTER_CONTAINER_RELATION_MUTANT
  (InFrame, InContainer) -> True
#endif
  (InContainer, InContainer) -> True
#ifdef LIFT_CALCULUS_DISPATCH_ADMITS_A_FALLBACK_MUTANT
  -- The seeded fallback admits every otherwise-refused inward/skip pair. The independent
  -- relation rejects those exact cells, while the source-shape check separately keeps a
  -- wildcard from becoming the authority for any future layer.
  (_from, _to) -> True
#else
  (InFrame, OnHost) -> False
  (InContainer, OnHost) -> False
  (InContainer, InFrame) -> False
#endif
