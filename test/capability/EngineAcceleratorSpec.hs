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
              putStrLn ("phase12-mutant: RED " <> Text.unpack mutant)
              fail ("Phase-12 mutant rejected: " <> Text.unpack mutant)
            else putStrLn ("phase12-mutant: SURVIVED " <> Text.unpack mutant)
    _ -> runEngineAcceleratorGate
