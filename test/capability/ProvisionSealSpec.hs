{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text qualified as Text
import ProvisionMutants (runProvisionMutant)
import ProvisionSealGate (runProvisionSealGate)
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [argument]
      | Just mutant <- Text.stripPrefix "--mutant=" (Text.pack argument) -> do
          caught <- runProvisionMutant mutant
          if caught
            then do
              putStrLn ("phase11-mutant: RED " <> Text.unpack mutant)
              fail ("Phase-11 mutant rejected: " <> Text.unpack mutant)
            else putStrLn ("phase11-mutant: SURVIVED " <> Text.unpack mutant)
    _ -> runProvisionSealGate
