{-# LANGUAGE OverloadedStrings #-}

-- | The legal twin, differing only in which resource is torn down.
--
-- Discharging an obligation is discharging a /named/ one: the outstanding set is a set of
-- resource names, so tearing down the resource that was provisioned removes the obligation
-- that was created. This is that program.
module WorkflowCalculusTeardownDischargesWhatWasProvisioned where

import Amoebius.Calculus.Workflow.Ledger (Ledger)
import Amoebius.Calculus.Workflow.Run (andThen, provision, runWorkflow, teardown)
import Data.Proxy (Proxy (Proxy))

-- The accepted program: the name torn down is the name provisioned.
ran :: ((), Ledger)
ran =
  runWorkflow
    (provision (Proxy @"db-volume") `andThen` \_handle -> teardown (Proxy @"db-volume"))
