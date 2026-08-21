{-# LANGUAGE OverloadedStrings #-}

-- | The legal twin, differing only in whether the transfer states its condition.
--
-- 'workflow_calculus_doctrine.md' section 3 admits two ways for an obligation to leave the
-- outstanding set: the workflow tears the resource down, or it transfers the obligation to
-- something longer-lived "with a stated condition". The condition is an argument, so the
-- transfer that states one is the transfer that exists.
module WorkflowCalculusTransferNamesItsCondition where

import Amoebius.Calculus.Workflow.Arm (Condition (Condition))
import Amoebius.Calculus.Workflow.Ledger (Ledger)
import Amoebius.Calculus.Workflow.Run (andThen, provision, runWorkflow, transfer)
import Data.Proxy (Proxy (Proxy))

-- The accepted program: the obligation moves, and says under what condition it ends.
ran :: ((), Ledger)
ran =
  runWorkflow
    ( provision (Proxy @"cluster-lease") `andThen` \_handle ->
        transfer (Proxy @"cluster-lease") (Condition "when the retained deployment is deleted")
    )
