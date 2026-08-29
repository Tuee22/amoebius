module Main (main) where

import Control.Exception (SomeException, try)
import Control.Monad (forM, forM_, unless)
import PhaseContractInternalOracle
  ( phaseContractInternalExactCaseNames
  , phaseContractInternalSelectorMatrixRows
  , phaseContractInternalSelectorNames
  , runPhaseContractInternalExactCase
  , runPhaseContractInternalOracle
  , runPhaseContractInternalSelectorOracle
  , runPhaseContractInternalUnaffectedControl
  )
import System.Environment (getArgs)
import System.Exit (exitFailure)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [] -> runPhaseContractInternalOracle
    ["--all"] -> runPhaseContractInternalOracle
    ["--list"] -> mapM_ putStrLn phaseContractInternalSelectorNames
    ["--cases"] -> mapM_ putStrLn phaseContractInternalExactCaseNames
    ["--assignments"] ->
      forM_ phaseContractInternalSelectorMatrixRows $ \(selector, impacts, control) ->
        putStrLn (selector <> "\t" <> commaSeparated impacts <> "\t" <> control)
    ["--case", exactCase] -> runPhaseContractInternalExactCase exactCase
    ["--case-results"] -> runCaseResults
    ["--unaffected", selector] -> runPhaseContractInternalUnaffectedControl selector
    [selector] -> runPhaseContractInternalSelectorOracle selector
    _ -> fail "expected --all, --list, --cases, --assignments, --case CASE, --case-results, --unaffected SELECTOR, or exactly one selector"

runCaseResults :: IO ()
runCaseResults = do
  passed <-
    forM phaseContractInternalExactCaseNames $ \exactCase -> do
      attempted <- try (runPhaseContractInternalExactCase exactCase)
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
