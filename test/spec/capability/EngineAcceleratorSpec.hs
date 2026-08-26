{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text qualified as Text
import EngineAcceleratorGate (runEngineAcceleratorGate)
import EngineAcceleratorMutants (runEngineAcceleratorMutant)
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [argument]
      | Just mutant <- Text.stripPrefix "--mutant=" (Text.pack argument) -> do
          caught <- runEngineAcceleratorMutant mutant
          if caught
            then do
              putStrLn ("inference-accelerator-mutant: RED " <> Text.unpack mutant)
              fail ("Phase-32 mutant rejected: " <> Text.unpack mutant)
            else putStrLn ("inference-accelerator-mutant: SURVIVED " <> Text.unpack mutant)
    _ -> runEngineAcceleratorGate
