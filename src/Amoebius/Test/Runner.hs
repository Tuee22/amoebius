

module Amoebius.Test.Runner
  ( RunnerActions (..)
  , runTestTopology
  ) where

import Amoebius.Test.Topology (ProvisionedTestTopology)
import Control.Exception (finally)

data RunnerActions = RunnerActions
  { topologySpinUp :: IO ()
  , topologyRunWorkflow :: IO ()
  , topologyInjectFault :: IO ()
  , topologyEvaluate :: IO ()
  , topologyTeardown :: IO ()
  }

runTestTopology :: ProvisionedTestTopology -> RunnerActions -> IO ()
runTestTopology _ actions =
  runBody actions `finally` topologyTeardown actions
 where
  runBody steps = topologySpinUp steps >> topologyRunWorkflow steps >> topologyInjectFault steps >> topologyEvaluate steps
