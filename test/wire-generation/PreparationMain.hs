-- | Capture the shipped preparation outputs for independent inspection.
module Main (main) where

import Amoebius.Pulsar.Wire.Generate (beginWireBindings)
import System.Environment (getArgs)
import System.FilePath ((</>))

main :: IO ()
main = do
  [directory] <- getArgs
  result <- beginWireBindings (directory </> "current")
  either (fail . show) (const (pure ())) result
