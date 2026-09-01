module Main (main) where

import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)
import SourceDebtBaselineOracle
  ( runSourceDebtBaselineExactCaseOracle
  , runSourceDebtBaselineOracle
  , runSourceDebtBaselineSelectorControlOracle
  , runSourceDebtBaselineSelectorImpactOracle
  , runSourceDebtBaselineSelectorIsolationOracle
  , runSourceDebtBaselineSelectorOracle
  , sourceDebtBaselineExactCaseLabels
  , sourceDebtBaselineSelectorNames
  )

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "SourceDebtBaselineOracle" runSourceDebtBaselineOracle runSourceDebtBaselineSelectorOracle)
      { suiteSelectorNames = sourceDebtBaselineSelectorNames
      , suiteExactCaseNames = sourceDebtBaselineExactCaseLabels
      , suiteRunExactCase = Just runSourceDebtBaselineExactCaseOracle
      , suiteRunImpacted = Just runSourceDebtBaselineSelectorImpactOracle
      , suiteRunUnaffected = Just runSourceDebtBaselineSelectorIsolationOracle
      , suiteRunControl = Just runSourceDebtBaselineSelectorControlOracle
      }
