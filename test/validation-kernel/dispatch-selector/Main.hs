module Main (main) where

import DispatchOracle
  ( dispatchSelectorAssignments
  , dispatchSelectorNames
  , runDispatchOracle
  , runDispatchSelectorOracle
  )
import PolicyContractOracle (runPolicyContractOracle)
import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "DispatchOracle" runDispatchOracle runDispatchSelectorOracle)
      { suiteSelectorNames = dispatchSelectorNames
      , suiteRunControl = Just (const runPolicyContractOracle)
      , suiteAssignments = dispatchSelectorAssignments
      }
