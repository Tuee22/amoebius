module Main (main) where

import Control.Exception (SomeException, try)
import Control.Monad (forM, forM_, unless)
import PhaseContractOracle
  ( phaseContractExactCaseNames
  , phaseContractSelectorMatrixRows
  , phaseContractSelectorNames
  , runPhaseContractExactCase
  , runPhaseContractOracle
  , runPhaseContractSelectorOracle
  , runPhaseContractUnaffectedControl
  )
import System.Environment (getArgs)
import System.Exit (exitFailure)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [] -> runPhaseContractOracle
    ["--all"] -> runPhaseContractOracle
    ["--list"] -> mapM_ putStrLn phaseContractSelectorNames
    ["--cases"] -> mapM_ putStrLn phaseContractExactCaseNames
    ["--assignments"] ->
      forM_ phaseContractSelectorMatrixRows $ \(selector, impacts, control) ->
        putStrLn (selector <> "\t" <> commaSeparated impacts <> "\t" <> control)
    ["--control"] -> runPhaseContractExactCase "input-entry-limit"
    ["--case", exactCase] -> runPhaseContractExactCase exactCase
    ["--case-results"] -> runCaseResults
    ["--unaffected", selector] -> runPhaseContractUnaffectedControl selector
    [selector] -> runPhaseContractSelectorOracle selector
    _ -> fail "expected --all, --list, --cases, --assignments, --control, --case CASE, --case-results, --unaffected SELECTOR, or exactly one selector"

runCaseResults :: IO ()
runCaseResults = do
  passed <-
    forM phaseContractExactCaseNames $ \exactCase -> do
      attempted <- try (runPhaseContractExactCase exactCase)
      let succeeded = case (attempted :: Either SomeException ()) of
            Right () -> True
            Left _ -> False
      putStrLn (exactCase <> "\t" <> if succeeded then "PASS" else "FAIL")
      pure succeeded
  unless (and passed) exitFailure

commaSeparated :: [String] -> String
commaSeparated values = case values of
  [] -> ""
  first : rest -> first <> concatMap (',' :) rest
