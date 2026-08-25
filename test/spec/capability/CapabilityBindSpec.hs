{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import BindGate (runBindGate)
import BindMutants (runCapabilityMutant)
import Data.Text qualified as Text
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [argument]
      | Just mutant <- Text.stripPrefix "--mutant=" (Text.pack argument) -> do
          caught <- runCapabilityMutant mutant
          if caught
            then do
              putStrLn ("capability-bind-mutant: RED " <> Text.unpack mutant)
              fail ("Phase-31 mutant rejected: " <> Text.unpack mutant)
            else putStrLn ("capability-bind-mutant: SURVIVED " <> Text.unpack mutant)
    _ -> runBindGate
