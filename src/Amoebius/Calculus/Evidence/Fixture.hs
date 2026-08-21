{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The four fixture kinds, and what a passing run of each entitles a claim to say.
--
-- 'evidence_calculus_doctrine.md' section 3 closes the set at four and fixes, for each,
-- what a pass establishes and what it never establishes. That second column is the part
-- that gets lost in prose, so it is a value here: 'Strength' is what the kind entitles the
-- claim to, and 'admitsStrength' is the pairing. A claim stated more strongly than its
-- fixture's kind allows is refused rather than reviewed.
--
-- The pairing is one-to-one, which is deliberate and is the whole content of section 3's
-- table. A compile-fail fixture establishes that /this expression/ is rejected and never
-- that no expression of that state exists. A property suite establishes that no
-- counterexample was found and never that none exists. An oracle establishes that the
-- output satisfies an independently authored predicate and never that the predicate
-- captures the requirement. A live probe establishes that the running system did this
-- once, here, and never that it will do it again or anywhere else.
module Amoebius.Calculus.Evidence.Fixture
  ( FixtureKind (..)
  , fixtureKindTag
  , fixtureKindFromTag
  , everyFixtureKind
  , Strength (..)
  , strengthTag
  , strengthFromTag
  , everyStrength
  , admitsStrength
  , Fixture
  , fixture
  , fixtureKind
  , fixturePath
  , fixtureRegister
  ) where

import Amoebius.Calculus.Evidence.Register (Register)
import Data.Text (Text)
import Data.Text qualified as Text

-- | The closed set of kinds.
data FixtureKind
  = CompileFail
  | Property
  | Oracle
  | LiveProbe
  deriving stock (Eq, Ord, Show, Enum, Bounded)

everyFixtureKind :: [FixtureKind]
everyFixtureKind = [minBound .. maxBound]

fixtureKindTag :: FixtureKind -> Text
fixtureKindTag = \case
  CompileFail -> "compile-fail"
  Property -> "property"
  Oracle -> "oracle"
  LiveProbe -> "live-probe"

fixtureKindFromTag :: Text -> Maybe FixtureKind
fixtureKindFromTag wanted =
  case [k | k <- everyFixtureKind, fixtureKindTag k == wanted] of
    (found : _) -> Just found
    [] -> Nothing

-- | What a passing run entitles the claim to say. One per kind, and no arm that says
-- something a fixture cannot establish.
data Strength
  = ThisExpressionRejected
  | NoCounterexampleFound
  | SatisfiesAuthoredPredicate
  | ObservedOnce
  deriving stock (Eq, Ord, Show, Enum, Bounded)

everyStrength :: [Strength]
everyStrength = [minBound .. maxBound]

strengthTag :: Strength -> Text
strengthTag = \case
  ThisExpressionRejected -> "this-expression-rejected"
  NoCounterexampleFound -> "no-counterexample-found"
  SatisfiesAuthoredPredicate -> "satisfies-authored-predicate"
  ObservedOnce -> "observed-once"

strengthFromTag :: Text -> Maybe Strength
strengthFromTag wanted = case [s | s <- everyStrength, strengthTag s == wanted] of
  (found : _) -> Just found
  [] -> Nothing

-- | Whether a kind entitles a claim to a strength. Every pair is named; there is no
-- fallback, because a kind added without a strength would otherwise inherit an answer.
admitsStrength :: FixtureKind -> Strength -> Bool
admitsStrength kind strength = case (kind, strength) of
  (CompileFail, ThisExpressionRejected) -> True
  (CompileFail, NoCounterexampleFound) -> False
  (CompileFail, SatisfiesAuthoredPredicate) -> False
  (CompileFail, ObservedOnce) -> False
  (Property, ThisExpressionRejected) -> False
  (Property, NoCounterexampleFound) -> True
  (Property, SatisfiesAuthoredPredicate) -> False
  (Property, ObservedOnce) -> False
  (Oracle, ThisExpressionRejected) -> False
  (Oracle, NoCounterexampleFound) -> False
  (Oracle, SatisfiesAuthoredPredicate) -> True
  (Oracle, ObservedOnce) -> False
  (LiveProbe, ThisExpressionRejected) -> False
  (LiveProbe, NoCounterexampleFound) -> False
  (LiveProbe, SatisfiesAuthoredPredicate) -> False
  (LiveProbe, ObservedOnce) -> True

-- | A fixture: its kind, the path a reader can open, and the register it runs at.
--
-- The constructor is not exported. 'fixture' is the only introduction rule, and it refuses
-- a fixture that names nothing — which is the mechanical form of section 2's rule that a
-- claim discharged by \"the suite\" is discharged by nothing in particular.
data Fixture = Fixture
  { fixtureKind :: FixtureKind
  , fixturePath :: Text
  , fixtureRegister :: Register
  }
  deriving stock (Eq, Ord, Show)

-- | Build a fixture, or refuse one that names no path.
fixture :: FixtureKind -> Text -> Register -> Maybe Fixture
fixture kind path register
  | names path = Just (Fixture {fixtureKind = kind, fixturePath = path, fixtureRegister = register})
  | otherwise = Nothing
  where
#ifdef EVIDENCE_CALCULUS_CLAIM_WITHOUT_A_FIXTURE_MUTANT
    -- The seeded hole. A fixture that names nothing is admitted, so a claim can be
    -- registered against it — which is section 2's "a claim with no fixture is prose"
    -- arriving through the one door the type could not close, since a 'Text' has no
    -- non-empty arm.
    names _candidate = True
#else
    names candidate = not (Text.null (Text.strip candidate))
#endif
