module Main (main) where

import SourceAcquisitionIngressOracle
  ( runSourceAcquisitionIngressControl
  , runSourceAcquisitionIngressOracle
  , runSourceAcquisitionIngressSelectorOracle
  , sourceAcquisitionIngressSelectorIntents
  , sourceAcquisitionIngressSelectorNames
  )
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--all"] -> runSourceAcquisitionIngressOracle
    ["--list"] -> mapM_ putStrLn sourceAcquisitionIngressSelectorNames
    ["--assignments"] ->
      mapM_ (\(selector, target) -> putStrLn (selector <> "\t" <> target)) sourceAcquisitionIngressSelectorIntents
    ["--control"] -> runSourceAcquisitionIngressControl
    [selector] -> runSourceAcquisitionIngressSelectorOracle selector
    _ -> fail "expected --all, --list, --assignments, --control, or exactly one selector"
