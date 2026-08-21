{-# LANGUAGE OverloadedStrings #-}

-- | The legal twin, differing only in whether the claim names its fixture.
--
-- 'evidence_calculus_doctrine.md' section 2: a claim is a declared statement paired with
-- the fixture that would falsify it, and neither half is admissible alone. Here both
-- halves are present, so the pairing exists and the claim can be built.
module EvidenceCalculusClaimNamesItsFixture where

import Amoebius.Calculus.Evidence.Claim (Claim, ClaimError, claim)
import Amoebius.Calculus.Evidence.Fixture (Fixture, Strength (SatisfiesAuthoredPredicate))

-- The accepted program: the statement is bound to the one fixture that would falsify it.
bound :: Fixture -> Either ClaimError Claim
bound discharge =
  claim "the relation admits exactly the pairs the doctrine admits" discharge SatisfiesAuthoredPredicate
