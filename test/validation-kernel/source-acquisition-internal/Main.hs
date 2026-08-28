module Main (main) where

import SourceAcquisitionInternalOracle
  ( runSourceAcquisitionInternalOracle
  , runSourceAcquisitionInternalSelectorOracle
  , sourceAcquisitionInternalSelectorIntents
  , sourceAcquisitionInternalSelectorNames
  )
import SourceAcquisitionOracle
  ( runSourceAcquisitionCanonicalControl
  )
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--all"] -> runSourceAcquisitionInternalOracle
    ["--list"] -> mapM_ putStrLn sourceAcquisitionInternalSelectorNames
    ["--assignments"] ->
      mapM_ (\(selector, target) -> putStrLn (selector <> "\t" <> target)) sourceAcquisitionInternalSelectorIntents
    ["--control"] -> runSourceAcquisitionCanonicalControl
    [selector] -> runSourceAcquisitionInternalSelectorOracle selector
    _ -> fail "expected --all, --list, --assignments, --control, or exactly one selector"
