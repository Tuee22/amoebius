module Main (main) where

import CompilerBuildInfoOracle
  ( compilerBuildInfoSelectorNames
  , runCompilerBuildInfoOracle
  , runCompilerBuildInfoSelectorImpactOracle
  , runCompilerBuildInfoSelectorIsolationOracle
  , runCompilerBuildInfoSelectorOracle
  , runCompilerBuildInfoSelectorProductControlOracle
  )
import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "CompilerBuildInfoOracle" runCompilerBuildInfoOracle runCompilerBuildInfoSelectorOracle)
      { suiteSelectorNames = compilerBuildInfoSelectorNames
      , suiteRunImpacted = Just runCompilerBuildInfoSelectorImpactOracle
      , suiteRunUnaffected = Just runCompilerBuildInfoSelectorIsolationOracle
      , suiteRunControl = Just runCompilerBuildInfoSelectorProductControlOracle
      }
