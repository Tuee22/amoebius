module Main (main) where

import CompilerSourceGraphAcquiredOracle
  ( runCompilerSourceGraphAcquiredOracle
  , runCompilerSourceGraphAcquiredSelectorImpactOracle
  , runCompilerSourceGraphAcquiredSelectorIsolationOracle
  , runCompilerSourceGraphAcquiredSelectorOracle
  , runCompilerSourceGraphAcquiredSelectorProductControlOracle
  )
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [] -> runCompilerSourceGraphAcquiredOracle
    ["--all"] -> runCompilerSourceGraphAcquiredOracle
    ["--impacted", selector] -> runCompilerSourceGraphAcquiredSelectorImpactOracle selector
    ["--unaffected", selector] -> runCompilerSourceGraphAcquiredSelectorIsolationOracle selector
    ["--control", selector] -> runCompilerSourceGraphAcquiredSelectorProductControlOracle selector
    [selector] -> runCompilerSourceGraphAcquiredSelectorOracle selector
    _ -> fail "CompilerSourceGraphAcquiredOracle requires no argument, --all, one selector, or --impacted/--unaffected/--control SELECTOR"
