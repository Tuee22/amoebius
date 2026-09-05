{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The register model as a value: how far a fixture's evidence actually reaches.
--
-- 'evidence_calculus_doctrine.md' section 5 draws the line this module sits on. The
-- evidence calculus fixes the /binding/ between a claim and the fixture that would falsify
-- it; what a discharged claim is /worth/ depends on where that fixture ran, and the scale
-- is the register model owned by
-- 'testing_doctrine.md' section 2. Making it a value is what lets a gate declare which
-- register its evidence reaches, and lets a check refuse a declaration the fixtures cannot
-- support.
--
-- Four registers, and one of them is not a gate register. Deterministic simulation is an
-- /activity/ between the boundary and live registers, never a phase gate, and the tracker
-- keys every gate to 1, 2 or 3 and never to 2.5. That asymmetry is the reason 'Register'
-- and 'GateRegister' are two types rather than one with a comment: a gate that declared
-- 2.5 would be spelling something the plan does not admit.
module Amoebius.Calculus.Evidence.Register
  ( Register (..)
  , registerTag
  , registerOrdinal
  , registerFromTag
  , everyRegister
  , weakestRegister
  , GateRegister (..)
  , gateRegister
  , gateRegisterReaches
  ) where

import Data.Text (Text)

-- | Where a fixture ran, weakest first. The 'Ord' instance is the scale: a claim inherits
-- the weakest register among the fixtures discharging it, so \"weakest\" has to be a
-- comparison rather than a convention.
data Register
  = -- | Register 1: in-process, no cluster, no mocks because pure code has nothing to mock.
    PureRegister
  | -- | Register 2: the binary's boundary, through fake tools or controlled subprocesses.
    BoundaryRegister
  | -- | Register 2.5: the real daemon code under deterministic simulation against modeled
    -- substrates. An activity, never a phase gate.
    SimulationRegister
  | -- | Register 3: a real cluster, a real workflow, real teardown.
    LiveRegister
  deriving stock (Eq, Ord, Show, Enum, Bounded)

everyRegister :: [Register]
everyRegister = [minBound .. maxBound]

registerTag :: Register -> Text
registerTag = \case
  PureRegister -> "pure"
  BoundaryRegister -> "boundary"
  SimulationRegister -> "simulation"
  LiveRegister -> "live"

-- | The number the tracker keys a gate to. Simulation's is @2.5@ and is the one no gate
-- carries, which is why this is a rendering rather than an index.
registerOrdinal :: Register -> Text
registerOrdinal = \case
  PureRegister -> "1"
  BoundaryRegister -> "2"
  SimulationRegister -> "2.5"
  LiveRegister -> "3"

registerFromTag :: Text -> Maybe Register
registerFromTag wanted = case [r | r <- everyRegister, registerTag r == wanted] of
  (found : _) -> Just found
  [] -> Nothing

-- | The weakest register among some fixtures' — the one a claim over them inherits.
--
-- An empty list has no weakest register and is 'Nothing' rather than a default: a claim
-- discharged by nothing does not reach register 1, it reaches none, and answering
-- otherwise would make \"discharged by nothing\" indistinguishable from \"discharged
-- purely\".
weakestRegister :: [Register] -> Maybe Register
weakestRegister = \case
  [] -> Nothing
  (first : rest) -> Just (foldr weaker first rest)
  where
    weaker left right = if left <= right then left else right

-- | A register a phase gate may key to. Three arms, and no simulation arm.
data GateRegister
  = GateRegisterOne
  | GateRegisterTwo
  | GateRegisterThree
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | The gate register a register corresponds to, when it is one at all.
gateRegister :: Register -> Maybe GateRegister
gateRegister = \case
  PureRegister -> Just GateRegisterOne
  BoundaryRegister -> Just GateRegisterTwo
#ifdef EVIDENCE_CALCULUS_SIMULATION_IS_GATE_REGISTER_MUTANT
  SimulationRegister -> Just GateRegisterTwo
#else
  SimulationRegister -> Nothing
#endif
  LiveRegister -> Just GateRegisterThree

-- | The register a gate register stands for, so a declaration can be compared against what
-- the fixtures actually reached.
gateRegisterReaches :: GateRegister -> Register
gateRegisterReaches = \case
  GateRegisterOne -> PureRegister
  GateRegisterTwo -> BoundaryRegister
  GateRegisterThree -> LiveRegister
