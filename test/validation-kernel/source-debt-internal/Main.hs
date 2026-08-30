module Main (main) where

import SelectorCli
  ( SelectorSuite (..)
  , runSelectorCli
  , selectorSuite
  )
import SourceDebtBaselineInternalOracle
  ( runSourceDebtBaselineInternalExactCaseOracle
  , runSourceDebtBaselineInternalOracle
  , runSourceDebtBaselineInternalSelectorImpactOracle
  , runSourceDebtBaselineInternalSelectorIsolationOracle
  , runSourceDebtBaselineInternalSelectorOracle
  , sourceDebtBaselineInternalExactCaseLabels
  , sourceDebtBaselineInternalSelectorNames
  )

main :: IO ()
main =
  runSelectorCli
    (selectorSuite
      "SourceDebtBaselineInternalOracle"
      runSourceDebtBaselineInternalOracle
      runSourceDebtBaselineInternalSelectorOracle)
      { suiteSelectorNames = sourceDebtBaselineInternalSelectorNames
      , suiteExactCaseNames = sourceDebtBaselineInternalExactCaseLabels
      , suiteRunExactCase = Just runSourceDebtBaselineInternalExactCaseOracle
      , suiteRunImpacted = Just runSourceDebtBaselineInternalSelectorImpactOracle
      , suiteRunUnaffected = Just runSourceDebtBaselineInternalSelectorIsolationOracle
      }
