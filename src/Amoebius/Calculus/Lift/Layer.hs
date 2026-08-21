{-# LANGUAGE OverloadedStrings #-}

-- | The closed layer set: where an effect runs.
--
-- 'lift_and_compose_doctrine.md' section 7 states the first of the calculus's three
-- parts: every effect executes at exactly one layer — on the host, inside a frame the
-- host provides, inside a container that frame runs — and the set is /closed/, so
-- \"somewhere else\" has no constructor. The layer is part of an effect's type rather
-- than part of its documentation, which is what 'Amoebius.Calculus.Lift.Transition'
-- makes of it.
--
-- The set is promoted and carried at the type level by 'SLayer', because a transition's
-- source and target are what index it. A value-level 'Layer' travels beside the singleton
-- for the places that enumerate, tag, or compare — an authored table names a layer by its
-- tag, and a plan assembled at run time compares two of them.
module Amoebius.Calculus.Lift.Layer
  ( Layer (..)
  , SLayer (..)
  , SomeLayer (..)
  , layerOf
  , layerTag
  , layerFromTag
  , everyLayer
  , sameLayer
  ) where

import Data.Text (Text)
import Data.Type.Equality ((:~:) (Refl))

-- | The closed set. Three members and no @Other@ arm: a fourth layer is a change to this
-- module, never a string a caller invents, and every function over the set below names
-- all three rather than falling through.
data Layer
  = OnHost
  | InFrame
  | InContainer
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | The singleton. A transition is indexed by two of these, so \"this step runs inside a
-- container\" is a type and not a comment.
data SLayer (l :: Layer) where
  SOnHost :: SLayer 'OnHost
  SInFrame :: SLayer 'InFrame
  SInContainer :: SLayer 'InContainer

deriving stock instance Eq (SLayer l)

deriving stock instance Show (SLayer l)

-- | A layer with its index hidden, for the places that enumerate the whole set.
data SomeLayer where
  SomeLayer :: SLayer l -> SomeLayer

-- | The value-level layer a singleton stands for.
layerOf :: SLayer l -> Layer
layerOf = \case
  SOnHost -> OnHost
  SInFrame -> InFrame
  SInContainer -> InContainer

-- | The tag an authored table names a layer by. Derived from the constructor rather than
-- authored beside it, so a layer added without a tag fails to compile here.
layerTag :: Layer -> Text
layerTag = \case
  OnHost -> "on-host"
  InFrame -> "in-frame"
  InContainer -> "in-container"

-- | The inverse, total over the closed set: a tag no layer carries is 'Nothing' rather
-- than a layer nobody meant.
layerFromTag :: Text -> Maybe Layer
layerFromTag wanted = case [layer | layer <- everyLayerValue, layerTag layer == wanted] of
  (found : _) -> Just found
  [] -> Nothing

everyLayerValue :: [Layer]
everyLayerValue = [minBound .. maxBound]

-- | Every layer, once, with its singleton. The list is written against the promoted set,
-- so a member added to 'Layer' without an 'SLayer' constructor fails to compile here
-- rather than silently shrinking whatever enumerates it.
everyLayer :: [SomeLayer]
everyLayer = fmap witness everyLayerValue
  where
    witness :: Layer -> SomeLayer
    witness = \case
      OnHost -> SomeLayer SOnHost
      InFrame -> SomeLayer SInFrame
      InContainer -> SomeLayer SInContainer

-- | Decide two layers equal, and hand back the type-level evidence when they are.
--
-- This is what lets a plan assembled at run time be composed under the same type equation
-- a statically written one obeys: the equality is /discovered/, and the proof it produces
-- is what the composition consumes. Without it a runtime plan would have to be trusted.
sameLayer :: SLayer a -> SLayer b -> Maybe (a :~: b)
sameLayer left right = case (left, right) of
  (SOnHost, SOnHost) -> Just Refl
  (SOnHost, SInFrame) -> Nothing
  (SOnHost, SInContainer) -> Nothing
  (SInFrame, SOnHost) -> Nothing
  (SInFrame, SInFrame) -> Just Refl
  (SInFrame, SInContainer) -> Nothing
  (SInContainer, SOnHost) -> Nothing
  (SInContainer, SInFrame) -> Nothing
  (SInContainer, SInContainer) -> Just Refl
