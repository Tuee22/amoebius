module Main (main) where

import CompilerComponentPlanOracle
  ( compilerComponentPlanExactCaseNames
  , compilerComponentPlanSelectorMatrixRows
  , compilerComponentPlanSelectorNames
  , runCompilerComponentPlanExactCase
  , runCompilerComponentPlanOracle
  , runCompilerComponentPlanSelectorImpactOracle
  , runCompilerComponentPlanSelectorIsolationOracle
  , runCompilerComponentPlanSelectorOracle
  , runCompilerComponentPlanSelectorProductControlOracle
  )
import SelectorCli
  ( SelectorSuite (..)
  , runSelectorCli
  , selectorSuite
  )

main :: IO ()
main =
  runSelectorCli
    (selectorSuite
      "CompilerComponentPlanOracle"
      runCompilerComponentPlanOracle
      runCompilerComponentPlanSelectorOracle)
      { suiteSelectorNames = compilerComponentPlanSelectorNames
      , suiteExactCaseNames = compilerComponentPlanExactCaseNames
      , suiteRunExactCase = Just runCompilerComponentPlanExactCase
      , suiteRunImpacted = Just runCompilerComponentPlanSelectorImpactOracle
      , suiteRunUnaffected = Just runCompilerComponentPlanSelectorIsolationOracle
      , suiteRunControl = Just runCompilerComponentPlanSelectorProductControlOracle
      , suiteAssignments = compilerComponentPlanSelectorMatrixRows
      }
