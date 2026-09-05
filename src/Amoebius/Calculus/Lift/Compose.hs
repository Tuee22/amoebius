{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Composition: two lifts compose exactly when the inner one's target layer is the outer
-- one's source layer.
--
-- 'lift_and_compose_doctrine.md' section 7 calls that a type equation rather than a check,
-- and 'compose' is where it is one: the shared @b@ in its signature is the whole rule, so
-- a composition whose layers do not meet has no type and the committed compile-fail pair
-- is what says so.
--
-- A 'Path' is what composition produces, and it is a separate type from a 'Lift' for a
-- reason worth stating. The relation is over /primitive/ transitions and it is deliberately
-- not transitive: the relation refuses @on-host -> in-container@, because reaching a
-- container from the host is two moves and saying so is what composition is for. If
-- 'Lift' carried its own composition constructor the relation would close under
-- transitivity and that distinction would be gone.
--
-- 'planFrom' is the same rule at the value level, for a plan assembled at run time out of
-- transitions whose indices are not known statically. It has to exist: a path decoded from
-- a declaration is a list, not an expression, and the alternative to checking it here is a
-- caller that trusts it.
module Amoebius.Calculus.Lift.Compose
  ( Path
  , here
  , step
  , compose
  , pathSource
  , pathTarget
  , pathLayers
  , PlanError (..)
  , planFrom
  ) where

import Amoebius.Calculus.Lift.Layer (Layer, SLayer, layerOf)
import Amoebius.Calculus.Lift.Transition (Lift, SomeLift (..), liftSource, liftTarget)
#ifdef LIFT_CALCULUS_COMPOSE_DROPS_MEETING_LAYER_MUTANT
import Unsafe.Coerce (unsafeCoerce)
#endif

-- | A composition of primitive transitions, from one layer to another.
--
-- The constructors are not exported: 'here' and 'step' are the introduction rules, and
-- both carry the layer indices that make a path's endpoints part of its type.
data Path (from :: Layer) (to :: Layer) where
  Here :: SLayer l -> Path l l
  Step :: Lift b c -> Path a b -> Path a c

-- | The empty path at a layer: an effect that has not moved.
here :: SLayer l -> Path l l
here = Here

-- | Extend a path by one primitive transition. The shared @b@ is the type equation: the
-- transition's source must be the path's target.
step :: Lift b c -> Path a b -> Path a c
step = Step

-- | Compose two paths. The shared @b@ says the inner one's target is the outer one's
-- source, which is the whole of section 7's composition rule.
#ifdef LIFT_CALCULUS_COMPOSE_DROPS_MEETING_LAYER_MUTANT
compose :: Path x c -> Path a y -> Path a c
compose _outer inner = unsafeCoerce inner
#else
compose :: Path b c -> Path a b -> Path a c
compose outer inner = case outer of
  Here _layer -> inner
  Step transition rest -> Step transition (compose rest inner)
#endif

-- | The layer a path starts at.
pathSource :: Path from to -> Layer
pathSource = \case
  Here layer -> layerOf layer
  Step _transition rest -> pathSource rest

-- | The layer a path ends at.
pathTarget :: Path from to -> Layer
pathTarget = \case
  Here layer -> layerOf layer
  Step transition _rest -> liftTarget transition

-- | Every layer a path passes through, from its source outward.
pathLayers :: Path from to -> [Layer]
pathLayers = \case
  Here layer -> [layerOf layer]
  Step transition rest -> pathLayers rest <> [liftTarget transition]

-- | Why a runtime-assembled plan is not a path.
--
-- There is one arm, and the reason there is only one is worth stating. A plan could fail
-- two ways in principle — a transition that does not meet the layer the plan has reached,
-- and a transition the relation does not admit — but the second cannot happen: a
-- 'SomeLift' carries a constructed 'Lift', every constructor is an admitted pair, and
-- there is no way to build one that is not. A second arm here would be an error value
-- nothing can produce, which reads as caution and is really an untested branch.
data PlanError
  = -- | The transition starts at a layer the plan is not at: the layer reached, then the
    -- layer the transition wanted.
    LayersDoNotMeet Layer Layer
  deriving stock (Eq, Show)

-- | Walk a plan from a starting layer, returning the layer it ends at.
--
-- What is checked is 'compose'\'s type equation stated over values: each transition must
-- /meet/ the layer the plan has reached. That check has to exist here because a plan
-- decoded from a declaration is a list rather than an expression, so no type equation
-- constrained how it was assembled, and the alternative to checking it is a caller that
-- trusts it.
planFrom :: Layer -> [SomeLift] -> Either PlanError Layer
planFrom start = go start
  where
    go reached [] = Right reached
    go reached (SomeLift _from _to transition : rest) =
      case meets reached (liftSource transition) of
        False -> Left (LayersDoNotMeet reached (liftSource transition))
        True -> go (liftTarget transition) rest
#ifdef LIFT_CALCULUS_COMPOSITION_JOINS_UNMET_LAYERS_MUTANT
    -- The seeded join. Two lifts are composed whether or not the inner one's target is the
    -- outer one's source, which is the type equation deleted at the one place values can
    -- reach it: a decoded plan is a list, and a list that is never checked is a path
    -- nobody proved.
    meets _reached _source = True
#else
    meets reached source = reached == source
#endif
