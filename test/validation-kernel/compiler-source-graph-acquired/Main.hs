module Main (main) where

import CompilerSourceGraphAcquiredOracle
  ( runCompilerSourceGraphAcquiredOracle
  , runCompilerSourceGraphAcquiredSelectorImpactOracle
  , runCompilerSourceGraphAcquiredSelectorIsolationOracle
  , runCompilerSourceGraphAcquiredSelectorOracle
  , runCompilerSourceGraphAcquiredSelectorProductControlOracle
  )
import CompilerSubjectRegistryOracle (runCompilerSubjectRegistryOracle)
import RepositoryLayoutRunOracle (runRepositoryLayoutRunOracle)
import ToolchainSpikeRunOracle (runToolchainSpikeRunOracle)
import SelectorCli
  ( SelectorSuite (..)
  , runSelectorCli
  , selectorSuite
  )

main :: IO ()
main = do
  runCompilerSubjectRegistryOracle
  runToolchainSpikeRunOracle
  runRepositoryLayoutRunOracle
  runSelectorCli
    (selectorSuite
      "CompilerSourceGraphAcquiredOracle"
      runCompilerSourceGraphAcquiredOracle
      runCompilerSourceGraphAcquiredSelectorOracle)
      { suiteRunImpacted = Just runCompilerSourceGraphAcquiredSelectorImpactOracle
      , suiteRunUnaffected = Just runCompilerSourceGraphAcquiredSelectorIsolationOracle
      , suiteRunControl = Just runCompilerSourceGraphAcquiredSelectorProductControlOracle
      }
