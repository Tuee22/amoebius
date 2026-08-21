{-# LANGUAGE OverloadedStrings #-}

-- | A claim is a value, and it names its fixture.
--
-- 'evidence_calculus_doctrine.md' section 2: a claim is a declared statement paired with
-- the fixture that would falsify it, and neither half is admissible alone. A fixture with
-- no claim is a test nobody can interpret; a claim with no fixture is prose. The pairing is
-- the constructor's argument list, so the second case has no constructor.
--
-- Two rules travel with it. A claim's strength is bounded by its fixture's kind, which is
-- what stops \"the property test passed\" from being written down as \"the property
-- holds\". And a gate declaring which register its evidence reaches may not declare one
-- stronger than the fixtures beneath it actually ran at — section 5 calls that its own
-- illegal state, the same defect as an unpinned compile-fail fixture one level up.
module Amoebius.Calculus.Evidence.Claim
  ( Claim
  , claimStatement
  , claimFixture
  , claimStrength
  , ClaimError (..)
  , claim
  , GateEvidence
  , gateName
  , gateClaims
  , gateDeclared
  , gateReached
  , EvidenceError (..)
  , declareGate
  ) where

import Amoebius.Calculus.Evidence.Fixture
  ( Fixture
  , FixtureKind
  , Strength
  , admitsStrength
  , fixtureKind
  , fixtureRegister
  )
import Amoebius.Calculus.Evidence.Register
  ( GateRegister
  , Register
  , gateRegisterReaches
  , weakestRegister
  )
import Data.Text (Text)
import Data.Text qualified as Text

-- | A statement and the fixture that would falsify it. The constructor is not exported, so
-- 'claim' is the only introduction rule and it takes the fixture.
data Claim = Claim
  { claimStatement :: Text
  , claimFixture :: Fixture
  , claimStrength :: Strength
  }
  deriving stock (Eq, Ord, Show)

-- | Why a claim is not well formed.
data ClaimError
  = -- | The statement is empty, so there is nothing for a fixture to falsify.
    ClaimStatesNothing
  | -- | The claim is stated more strongly than its fixture's kind entitles it to be.
    StrengthExceedsFixtureKind FixtureKind Strength
  deriving stock (Eq, Show)

-- | Bind a statement to the one fixture that would falsify it.
claim :: Text -> Fixture -> Strength -> Either ClaimError Claim
claim statement discharge strength
  | Text.null (Text.strip statement) = Left ClaimStatesNothing
  | not (admitsStrength (fixtureKind discharge) strength) =
      Left (StrengthExceedsFixtureKind (fixtureKind discharge) strength)
  | otherwise =
      Right
        Claim
          { claimStatement = statement
          , claimFixture = discharge
          , claimStrength = strength
          }

-- | A gate's evidence: the claims it discharges and the register it declares it reaches.
data GateEvidence = GateEvidence
  { gateName :: Text
  , gateClaims :: [Claim]
  , gateDeclared :: GateRegister
  }
  deriving stock (Eq, Show)

-- | Why a gate's declared evidence is not well formed.
data EvidenceError
  = -- | A gate that discharges no claim declares nothing.
    GateDischargesNothing
  | -- | The declared register is stronger than what the fixtures beneath it reached.
    DeclaredRegisterExceedsFixtures Register Register
  deriving stock (Eq, Show)

-- | Declare a gate's evidence.
--
-- The register comes last so that a caller who omits it has a function rather than a gate
-- with an unstated register, and the committed compile-fail twin is exactly that program.
declareGate :: Text -> [Claim] -> GateRegister -> Either EvidenceError GateEvidence
declareGate name claims declared = case weakestRegister (fmap (fixtureRegister . claimFixture) claims) of
  Nothing -> Left GateDischargesNothing
  Just reached
    | gateRegisterReaches declared > reached ->
        Left (DeclaredRegisterExceedsFixtures (gateRegisterReaches declared) reached)
    | otherwise ->
        Right GateEvidence {gateName = name, gateClaims = claims, gateDeclared = declared}

-- | The weakest register the gate's fixtures actually reached.
gateReached :: GateEvidence -> Maybe Register
gateReached = weakestRegister . fmap (fixtureRegister . claimFixture) . gateClaims
