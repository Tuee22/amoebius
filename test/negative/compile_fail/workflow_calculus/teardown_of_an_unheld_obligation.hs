{-# LANGUAGE OverloadedStrings #-}

-- | The illegal half: tearing down something the workflow never provisioned.
--
-- The outstanding set is a set of names, so discharging one the workflow does not hold has
-- no reduction. Rather than leaving a stuck type family for a reader to decode,
-- 'Amoebius.Calculus.Workflow.Obligation.Remove' makes its empty case a compiler message
-- that names the resource — which is what this fixture asserts.
module WorkflowCalculusTeardownOfAnUnheldObligation where

import Amoebius.Calculus.Workflow.Ledger (Ledger)
import Amoebius.Calculus.Workflow.Run (andThen, provision, runWorkflow, teardown)
import Data.Proxy (Proxy (Proxy))

-- The rejected program: a name that was never provisioned is torn down.
ran :: ((), Ledger)
ran =
  runWorkflow
    (provision (Proxy @"db-volume") `andThen` \_handle -> teardown (Proxy @"never-provisioned"))
