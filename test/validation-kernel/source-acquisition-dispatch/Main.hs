module Main (main) where

import SourceAcquisitionDispatchOracle
  ( runSourceAcquisitionDispatchControl
  , runSourceAcquisitionDispatchOracle
  , runSourceAcquisitionDispatchSelectorOracle
  , sourceAcquisitionDispatchSelectorIntents
  , sourceAcquisitionDispatchSelectorNames
  )
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--all"] -> runSourceAcquisitionDispatchOracle
    ["--list"] -> mapM_ putStrLn sourceAcquisitionDispatchSelectorNames
    ["--assignments"] ->
      mapM_ (\(selector, target) -> putStrLn (selector <> "\t" <> target)) sourceAcquisitionDispatchSelectorIntents
    ["--control"] -> runSourceAcquisitionDispatchControl
    [selector] -> runSourceAcquisitionDispatchSelectorOracle selector
    _ -> fail "expected --all, --list, --assignments, --control, or exactly one selector"
