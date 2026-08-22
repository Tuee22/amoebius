{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}

import Amoebius.Calculus.Workflow.Run (provision, runWorkflow)
import Data.Proxy (Proxy (Proxy))

-- This differs from the legal twin at the derivation: it provisions the gate process
-- and attempts to run without deriving the teardown arm.
illegal = runWorkflow (provision (Proxy @"phase-gate-process"))

main :: IO ()
main = print illegal
