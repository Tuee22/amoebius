{-# LANGUAGE OverloadedStrings #-}

module TestWorkflowAlgebraOracle
  ( OracleBranch (..)
  , OracleTerminal (..)
  , expectedBranchDemands
  , expectedInventoryDomains
  , expectedProjectionLines
  , expectedTerminalCases
  ) where

import Data.Text (Text)

data OracleBranch = OracleBranch
  { oracleBranchName :: Text
  , oracleDemand :: [Integer]
  }
  deriving stock (Eq, Show)

data OracleTerminal = OracleTerminal
  { oracleWorkflow :: Text
  , oracleTeardown :: Text
  , oracleTerminal :: Text
  }
  deriving stock (Eq, Show)

expectedBranchDemands :: [OracleBranch]
expectedBranchDemands =
  [ OracleBranch "core" [3000, 3221225472, 8589934592, 1073741824, 536870912, 4, 4, 1, 1]
  , OracleBranch "registry" [3500, 4294967296, 12884901888, 3221225472, 536870912, 5, 5, 2, 2]
  , OracleBranch "provider" [4000, 5368709120, 12884901888, 2147483648, 1073741824, 6, 6, 3, 8]
  , OracleBranch "migration" [4500, 6442450944, 17179869184, 4294967296, 536870912, 7, 7, 4, 4]
  , OracleBranch "accelerator" [5000, 8589934592, 21474836480, 2147483648, 2147483648, 8, 8, 4, 6]
  ]

expectedTerminalCases :: [OracleTerminal]
expectedTerminalCases =
  [ OracleTerminal "success" "success" "success"
  , OracleTerminal "success" "failure:cleanup" "teardown-failure:cleanup"
  , OracleTerminal "success" "repeated" "repeated-teardown"
  , OracleTerminal "failure:primary" "success" "workflow-failure:primary"
  , OracleTerminal "failure:primary" "failure:cleanup" "workflow-failure:primary"
  , OracleTerminal "failure:primary" "repeated" "workflow-failure:primary"
  ]

expectedInventoryDomains :: [Text]
expectedInventoryDomains = ["registry", "provider", "storage", "runtime-metadata", "accelerator"]

expectedProjectionLines :: [Text]
expectedProjectionLines =
  [ "name=oracle-projection"
  , "substrate=linux-cpu"
  , "branch=core"
  , "authority=flagged-test:authority/test-workflow"
  , "ownership=test-owned"
  , "teardown=required"
  , "faults=delegated-failover"
  , "expectations=workflow-completes,cleanup-observed,no-modeled-residue"
  , "demand=3000,3221225472,8589934592,1073741824,536870912,4,4,1,1"
  ]
