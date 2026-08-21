{-# LANGUAGE OverloadedStrings #-}

-- | The illegal half of the transfer pair: an obligation moved with nothing said about
-- when it ends.
--
-- Omitting the condition does not produce a transfer with a hole in it; it produces a
-- function still waiting for a 'Condition', and a workflow is the one thing that cannot
-- be. The rejection therefore names 'Condition' — which is the reason this fixture
-- asserts, rather than merely that something failed.
module WorkflowCalculusTransferWithoutACondition where

import Amoebius.Calculus.Workflow.Ledger (Ledger)
import Amoebius.Calculus.Workflow.Run (andThen, provision, runWorkflow, transfer)
import Data.Proxy (Proxy (Proxy))

-- The rejected program: the obligation moves and nothing states when it ends.
ran :: ((), Ledger)
ran =
  runWorkflow
    (provision (Proxy @"cluster-lease") `andThen` \_handle -> transfer (Proxy @"cluster-lease"))
