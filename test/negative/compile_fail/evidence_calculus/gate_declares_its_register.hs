{-# LANGUAGE OverloadedStrings #-}

-- | The legal twin, differing only in whether the gate declares its register.
--
-- 'evidence_calculus_doctrine.md' section 5: this calculus fixes the binding and not what a
-- discharged claim is worth, because that depends on where the fixture ran. An extension's
-- evidence component therefore declares the register each fixture reaches, and this is that
-- declaration.
module EvidenceCalculusGateDeclaresItsRegister where

import Amoebius.Calculus.Evidence.Claim (Claim, EvidenceError, GateEvidence, declareGate)
import Amoebius.Calculus.Evidence.Register (GateRegister (GateRegisterOne))

-- The accepted program: the gate says which register its evidence reaches.
declared :: [Claim] -> Either EvidenceError GateEvidence
declared claims = declareGate "lift-calculus-gate" claims GateRegisterOne
