{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

import Amoebius.Calculus.Workflow.Ledger (Ledger)
import Amoebius.Calculus.Workflow.Run (runWorkflow)
import Amoebius.Gate.SelfReferential

legal :: (GateEvidence, Ledger)
legal = runWorkflow (gateWorkflow declaration GatePassed)
 where
  declaration = GateDeclaration 49 "phase-49" "python3 tools/self_referential_gates_gate.py"

main :: IO ()
main = print legal
