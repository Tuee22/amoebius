{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Test.WorkflowAlgebra
import Data.Maybe (fromJust)

main :: IO ()
main = print . terminalResult . observeTeardown WorkflowSucceeded TeardownSucceeded $ topology

topology :: TestTopology TeardownPending
topology = either (error . show) id (suggestTest model)

model :: SuppliedTestModel
model = SuppliedTestModel "compile-legal" LinuxCpu CoreBranch
  (FlaggedTestAuthority (fromJust (authorityRef "authority/compile-test")))
  (Just TestOwnedIntent)
  (ResourceVector 10000 20000000000 70000000000 10000000000 5000000000 32 32 8 100)
  [] [WorkflowCompletes, CleanupObserved]
