module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( componentObservations )

main :: IO ()
main = componentObservations `seq` pure ()
