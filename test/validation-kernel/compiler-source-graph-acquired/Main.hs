module Main (main) where

import CompilerSourceGraphAcquiredOracle
  ( runCompilerSourceGraphAcquiredOracle
  , runCompilerSourceGraphAcquiredSelectorImpactOracle
  , runCompilerSourceGraphAcquiredSelectorIsolationOracle
  , runCompilerSourceGraphAcquiredSelectorOracle
  , runCompilerSourceGraphAcquiredSelectorProductControlOracle
  )
import CompilerSubjectRegistryOracle (runCompilerSubjectRegistryOracle)
import SelectorCli
  ( SelectorSuite (..)
  , runSelectorCli
  , selectorSuite
  )

main :: IO ()
main = do
  runCompilerSubjectRegistryOracle
  runSelectorCli
    (selectorSuite
      "CompilerSourceGraphAcquiredOracle"
      runCompilerSourceGraphAcquiredOracle
      runCompilerSourceGraphAcquiredSelectorOracle)
      { suiteRunImpacted = Just runCompilerSourceGraphAcquiredSelectorImpactOracle
      , suiteRunUnaffected = Just runCompilerSourceGraphAcquiredSelectorIsolationOracle
      , suiteRunControl = Just runCompilerSourceGraphAcquiredSelectorProductControlOracle
      }
