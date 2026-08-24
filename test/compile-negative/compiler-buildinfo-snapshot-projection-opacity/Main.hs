module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( snapshotObservations )

main :: IO ()
main = snapshotObservations `seq` pure ()
