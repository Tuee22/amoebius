{-# LANGUAGE CPP #-}

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
#ifdef PHASE54_SKIP_TEARDOWN_MUTANT
  runBody actions
#else
  runBody actions `finally` topologyTeardown actions
#endif
 where
  runBody steps = topologySpinUp steps >> topologyRunWorkflow steps >> topologyInjectFault steps >> topologyEvaluate steps
