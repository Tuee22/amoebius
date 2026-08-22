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
            then putStrLn ("capacity-topology-mutant: SURVIVED " <> Text.unpack mutant)
            else do
              putStrLn ("capacity-topology-mutant: RED " <> Text.unpack mutant)
              fail ("capacity/topology mutant rejected: " <> Text.unpack mutant)
    _ -> runCapacityTopologyGate
