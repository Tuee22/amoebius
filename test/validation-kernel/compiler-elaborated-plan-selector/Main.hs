module Main (main) where

import CompilerElaboratedPlanOracle
  ( compilerElaboratedPlanSelectorNames
  , runCompilerElaboratedPlanOracle
  , runCompilerElaboratedPlanSelectorImpactOracle
  , runCompilerElaboratedPlanSelectorIsolationOracle
  , runCompilerElaboratedPlanSelectorOracle
  )
import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "CompilerElaboratedPlanOracle" runCompilerElaboratedPlanOracle runCompilerElaboratedPlanSelectorOracle)
      { suiteSelectorNames = compilerElaboratedPlanSelectorNames
      , suiteRunImpacted = Just runCompilerElaboratedPlanSelectorImpactOracle
      , suiteRunUnaffected = Just runCompilerElaboratedPlanSelectorIsolationOracle
      }
