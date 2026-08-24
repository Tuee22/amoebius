module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( problemFinding )

main :: IO ()
main = problemFinding `seq` pure ()
