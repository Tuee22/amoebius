module Main (main) where

import EvidenceSelectorOracle
  ( evidenceSelectorAssignments
  , evidenceSelectorCaseNames
  , evidenceSelectorNames
  , runEvidenceSelectorAllOracle
  , runEvidenceSelectorCase
  , runEvidenceSelectorOracle
  , runEvidenceSelectorUnaffectedOracle
  )
import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "EvidenceSelectorOracle" runEvidenceSelectorAllOracle runEvidenceSelectorOracle)
      { suiteSelectorNames = evidenceSelectorNames
      , suiteExactCaseNames = evidenceSelectorCaseNames
      , suiteRunExactCase = Just runEvidenceSelectorCase
      , suiteRunUnaffected = Just runEvidenceSelectorUnaffectedOracle
      , suiteAssignments = evidenceSelectorAssignments
      }
