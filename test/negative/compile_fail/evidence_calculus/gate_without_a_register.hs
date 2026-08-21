{-# LANGUAGE OverloadedStrings #-}

-- | The illegal half of the register pair: evidence that does not say how far it reaches.
--
-- A pure property suite, a boundary run against fakes, and a live run on real hardware
-- discharge the same claim to three different strengths, so evidence that names no register
-- has not said what it is worth. The register is an argument, and omitting it leaves a
-- function waiting for a 'GateRegister' — which is the name the rejection carries and the
-- reason this fixture asserts.
module EvidenceCalculusGateWithoutARegister where

import Amoebius.Calculus.Evidence.Claim (Claim, EvidenceError, GateEvidence, declareGate)

-- The rejected program: claims, a name, and no statement of what register they reach.
declared :: [Claim] -> Either EvidenceError GateEvidence
declared claims = declareGate "lift-calculus-gate" claims
