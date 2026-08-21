{-# LANGUAGE OverloadedStrings #-}

-- | The illegal half of the claim pair: a statement with nothing that would falsify it.
--
-- This is the sentence section 2 calls prose. Omitting the fixture does not produce a
-- claim with a hole in it; it produces a function still waiting for a 'Fixture', and the
-- annotation this module gives it is the one thing that cannot be. The rejection therefore
-- names 'Fixture' — which is what this fixture asserts, rather than merely that something
-- failed.
module EvidenceCalculusClaimWithoutAFixture where

import Amoebius.Calculus.Evidence.Claim (Claim, ClaimError, claim)
import Amoebius.Calculus.Evidence.Fixture (Strength (SatisfiesAuthoredPredicate))

-- The rejected program: a statement, a strength, and nothing that would falsify it.
bound :: Either ClaimError Claim
bound = claim "the relation admits exactly the pairs the doctrine admits" SatisfiesAuthoredPredicate
