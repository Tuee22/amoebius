module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( makeDiagnosticCompilerBuildInfoExpectations )

main :: IO ()
main = makeDiagnosticCompilerBuildInfoExpectations `seq` pure ()
