{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import CapacityTopologyGate (runCapacityTopologyGate)
import CapacityTopologyMutants (runCapacityMutant)
import Data.Text qualified as Text
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [argument]
      | Just mutant <- Text.stripPrefix "--mutant=" (Text.pack argument) -> do
          survived <- runCapacityMutant mutant
          if survived
            then putStrLn ("phase7-mutant: SURVIVED " <> Text.unpack mutant)
            else do
              putStrLn ("phase7-mutant: RED " <> Text.unpack mutant)
              fail ("Phase-7 mutant rejected: " <> Text.unpack mutant)
    _ -> runCapacityTopologyGate
