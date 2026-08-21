{-# LANGUAGE OverloadedStrings #-}

-- | The illegal half: a workflow that ends while it still owes a teardown.
--
-- This is the program section 3 says must be rejected at compile time, and the rejection
-- is not a refusal 'runWorkflow' performs — it is that the application has no type.
-- 'runWorkflow' takes a workflow whose outstanding set is empty; this one's still names the
-- resource it provisioned, so the compiler reports which obligation was left owing.
module WorkflowCalculusEndsOwingATeardown where

import Amoebius.Calculus.Workflow.Ledger (Ledger)
import Amoebius.Calculus.Workflow.Run (Handle, provision, runWorkflow)
import Data.Proxy (Proxy (Proxy))

-- The rejected program: provisioned, never returned.
ran :: (Handle, Ledger)
ran = runWorkflow (provision (Proxy @"db-volume"))
