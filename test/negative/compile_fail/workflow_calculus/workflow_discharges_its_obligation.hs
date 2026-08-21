{-# LANGUAGE OverloadedStrings #-}

-- | The legal twin, differing only in whether the obligation is discharged.
--
-- 'workflow_calculus_doctrine.md' section 3: provision returns a handle and a teardown
-- obligation together, and the obligation is not optional, not defaulted, and not
-- discardable. Here it is discharged, so the workflow ends owing nothing and 'runWorkflow'
-- — whose argument is @Workflow '[] '[]@ — accepts it.
module WorkflowCalculusDischargesItsObligation where

import Amoebius.Calculus.Workflow.Ledger (Ledger)
import Amoebius.Calculus.Workflow.Run (andThen, provision, runWorkflow, teardown)
import Data.Proxy (Proxy (Proxy))

-- The accepted program: what was provisioned is returned before the workflow ends.
ran :: ((), Ledger)
ran =
  runWorkflow
    (provision (Proxy @"db-volume") `andThen` \_handle -> teardown (Proxy @"db-volume"))
