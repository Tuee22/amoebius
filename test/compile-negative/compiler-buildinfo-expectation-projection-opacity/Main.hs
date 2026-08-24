module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( expectationObservations )

main :: IO ()
main = expectationObservations `seq` pure ()
