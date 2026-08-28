module Main (main) where

import SourceDebtBaselineInternalOracle
  ( runSourceDebtBaselineInternalExactCaseOracle
  , runSourceDebtBaselineInternalOracle
  , runSourceDebtBaselineInternalSelectorImpactOracle
  , runSourceDebtBaselineInternalSelectorIsolationOracle
  , runSourceDebtBaselineInternalSelectorOracle
  , sourceDebtBaselineInternalExactCaseLabels
  , sourceDebtBaselineInternalSelectorNames
  )
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--all"] -> runSourceDebtBaselineInternalOracle
    ["--list"] -> mapM_ putStrLn sourceDebtBaselineInternalSelectorNames
    ["--case-list"] -> mapM_ putStrLn sourceDebtBaselineInternalExactCaseLabels
    ["--case", label] -> runSourceDebtBaselineInternalExactCaseOracle label
    ["--impacted", selector] -> runSourceDebtBaselineInternalSelectorImpactOracle selector
    ["--unaffected", selector] -> runSourceDebtBaselineInternalSelectorIsolationOracle selector
    [selector] -> runSourceDebtBaselineInternalSelectorOracle selector
    _ -> fail "expected --all, --list, --case-list, --case LABEL, --impacted/--unaffected SELECTOR, or SELECTOR"
