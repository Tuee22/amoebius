module Main (main) where

import PolicyContractOracle (runPolicyContractOracle)
import QualificationOracle (runQualificationOracle)
import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)

main :: IO ()
main =
  runSelectorCli
    ( (selectorSuite "validation-qualification-selector-component" runQualificationOracle runSelected)
        { suiteSelectorNames = [selectorName]
        , suiteRunControl = Just (const runPolicyContractOracle)
        , suiteAssignments = [(selectorName, ["qualification diagnostic refusal"], "PolicyContractOracle")]
        }
    )

runSelected :: String -> IO ()
runSelected selector
  | selector == selectorName = runQualificationOracle
  | otherwise = fail ("unknown qualification selector: " <> selector)

selectorName :: String
selectorName = "VALIDATION_QUALIFICATION_DIAGNOSTIC_BYPASS_MUTANT"
