module Main (main) where

import SourceAcquisitionPipelineOracle
  ( runSourceAcquisitionPipelineControl
  , runSourceAcquisitionPipelineOracle
  , runSourceAcquisitionPipelineSelectorOracle
  , sourceAcquisitionPipelineSelectorIntents
  , sourceAcquisitionPipelineSelectorNames
  )
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    ["--all"] -> runSourceAcquisitionPipelineOracle
    ["--list"] -> mapM_ putStrLn sourceAcquisitionPipelineSelectorNames
    ["--assignments"] ->
      mapM_ (\(selector, target) -> putStrLn (selector <> "\t" <> target)) sourceAcquisitionPipelineSelectorIntents
    ["--control"] -> runSourceAcquisitionPipelineControl
    [selector] -> runSourceAcquisitionPipelineSelectorOracle selector
    _ -> fail "expected --all, --list, --assignments, --control, or exactly one selector"
