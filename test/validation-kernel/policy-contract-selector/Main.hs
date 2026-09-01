module Main (main) where

import PolicyContractOracle
  ( policyContractSelectorAssignments
  , policyContractSelectorNames
  , runPolicyContractOracle
  , runPolicyContractSelectorOracle
  , runPolicyContractUnaffectedControl
  )
import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "PolicyContractOracle" runPolicyContractOracle runPolicyContractSelectorOracle)
      { suiteSelectorNames = policyContractSelectorNames
      , suiteRunUnaffected = Just (const runPolicyContractUnaffectedControl)
      , suiteAssignments =
          [ (selector, [exactCase], "canonical unaffected control")
          | (selector, exactCase) <- policyContractSelectorAssignments
          ]
      }
