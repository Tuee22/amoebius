{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text qualified as Text
import StorageGeometryGate (runStorageGeometryGate)
import StorageGeometryMutants (runStorageMutant)
import System.Environment (getArgs)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [argument]
      | Just mutant <- Text.stripPrefix "--mutant=" (Text.pack argument) -> do
          caught <- runStorageMutant mutant
          if caught
            then do
              putStrLn ("storage-geometry-mutant: RED " <> Text.unpack mutant)
              fail ("Phase-28 mutant rejected: " <> Text.unpack mutant)
            else putStrLn ("storage-geometry-mutant: SURVIVED " <> Text.unpack mutant)
    _ -> runStorageGeometryGate
