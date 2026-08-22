{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Test.WorkflowAlgebra

main :: IO ()
main = print . sealedWorkflowName . sealWorkflow $
  beginWorkflow (WorkflowDeclaration "compile-illegal" LinuxCpu CoreBranch (TestCredential "vault/test/workflow" True) ampleSupply)

ampleSupply :: ResourceVector
ampleSupply = ResourceVector 10000 20000000000 70000000000 10000000000 5000000000 32 32 8 100
