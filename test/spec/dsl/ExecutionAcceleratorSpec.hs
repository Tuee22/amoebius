{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text qualified as Text
import ExecutionAcceleratorGate (runExecutionAcceleratorGate)
import ExecutionAcceleratorMutants (runExecutionAcceleratorMutant)
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [argument]
      | Just mutant <- Text.stripPrefix "--mutant=" (Text.pack argument) -> do
          caught <- runExecutionAcceleratorMutant mutant
          if caught
            then do
              putStrLn ("execution-accelerator-mutant: RED " <> Text.unpack mutant)
              fail ("Phase-9 mutant rejected: " <> Text.unpack mutant)
            else putStrLn ("execution-accelerator-mutant: SURVIVED " <> Text.unpack mutant)
    _ -> runExecutionAcceleratorGate
