module Main (main) where

import CompilerSourceGraphOracle
  ( compilerSourceGraphSelectorNames
  , runCompilerSourceGraphOracle
  , runCompilerSourceGraphSelectorOracle
  , runCompilerSourceGraphSelectorProductControlOracle
  )
import SelectorCli (SelectorSuite (..), runSelectorCli, selectorSuite)

main :: IO ()
main =
  runSelectorCli
    (selectorSuite "CompilerSourceGraphOracle" runCompilerSourceGraphOracle runCompilerSourceGraphSelectorOracle)
      { suiteSelectorNames = compilerSourceGraphSelectorNames
      , suiteRunControl = Just runCompilerSourceGraphSelectorProductControlOracle
      }
