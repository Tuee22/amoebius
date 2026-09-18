{-# LANGUAGE OverloadedStrings #-}

-- | The witness a transition consumes: evidence that its precondition holds.
--
-- 'lift_and_compose_doctrine.md' section 7 states the third part of the calculus: a
-- transition consumes evidence that its precondition holds — that the frame exists, that
-- the engine is present — and the witness is /produced by observation and cannot be
-- asserted/, so a step cannot claim to have crossed a boundary it did not cross.
--
-- Two mechanisms carry that, and only one of them is a type. 'Witness' is exported
-- without its constructor, so the sole introduction rule is 'observe' and a fixture that
-- writes the record out has no type — that half is the module boundary, and the committed
-- compile-fail pair is what holds it. The other half is that 'observe' refuses: an
-- observation that does not report the precondition yields 'Nothing' rather than a
-- witness with a hopeful field, and the authored observation table is what holds that.
--
-- The witness is indexed by the transition it licenses rather than by a layer, because
-- \"the frame exists\" and \"the engine answered\" are different facts and a step that
-- crossed into a container must not be able to spend the evidence that a frame was
-- running.
module Amoebius.Calculus.Lift.Witness
  ( Observation (..)
  , observationTag
  , observationFromTag
  , everyObservation
  , Witness
  , witnessDetail
  , observe
  ) where

import Amoebius.Calculus.Lift.Layer (Layer (..), SLayer (..), layerOf)
import Data.Text (Text)

-- | What the world reported. The set is closed for the same reason the layer set is: an
-- observation amoebius cannot name is one no transition may consume, and an open
-- vocabulary here would be a hole in the closed one next door.
data Observation
  = HostResponding
  | FrameRunning Text
  | EngineResponding Text
  | NothingObserved
  deriving stock (Eq, Ord, Show)

-- | The tag the authored table names an observation by.
observationTag :: Observation -> Text
observationTag = \case
  HostResponding -> "host-responding"
  FrameRunning _ -> "frame-running"
  EngineResponding _ -> "engine-responding"
  NothingObserved -> "nothing-observed"

-- | Every observation, once, at the sample detail the table is written against.
everyObservation :: [Observation]
everyObservation =
  [ HostResponding
  , FrameRunning "lima-linux"
  , EngineResponding "containerd"
  , NothingObserved
  ]

observationFromTag :: Text -> Maybe Observation
observationFromTag wanted =
  case [seen | seen <- everyObservation, observationTag seen == wanted] of
    (found : _) -> Just found
    [] -> Nothing

-- | Evidence that a transition's precondition holds, indexed by the transition.
--
-- The constructor is not exported. 'observe' is the only introduction rule, and it takes
-- an 'Observation' — so a witness exists exactly where something was seen.
data Witness (from :: Layer) (to :: Layer) = Witness
  { witnessDetail :: Text
  }
  deriving stock (Eq, Ord, Show)

-- | Turn an observation into the witness it licenses, or refuse.
--
-- The two singletons say which transition is being witnessed, so the caller cannot spend
-- a frame observation on a container entry: the arms below decide the pair and the
-- observation together, and every pair of the closed set is named.
observe :: SLayer from -> SLayer to -> Observation -> Maybe (Witness from to)
observe from to seen = case (layerOf from, layerOf to, seen) of
  (OnHost, InFrame, FrameRunning name) -> Just (Witness ("frame:" <> name))
  (InFrame, InContainer, EngineResponding name) -> Just (Witness ("engine:" <> name))
  (OnHost, OnHost, HostResponding) -> Just (Witness "host")
  (InFrame, InFrame, FrameRunning name) -> Just (Witness ("frame:" <> name))
  (InContainer, InContainer, EngineResponding name) -> Just (Witness ("engine:" <> name))
  (OnHost, InContainer, _unseen) -> Nothing
  (InFrame, OnHost, _unseen) -> Nothing
  (InContainer, OnHost, _unseen) -> Nothing
  (InContainer, InFrame, _unseen) -> Nothing
  (InFrame, InContainer, _unseen) -> Nothing
  (OnHost, OnHost, _unseen) -> Nothing
  (InFrame, InFrame, _unseen) -> Nothing
  (InContainer, InContainer, _unseen) -> Nothing
  (OnHost, InFrame, _unseen) -> Nothing
