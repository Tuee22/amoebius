module Main (main) where

-- Positive control for the one-symbol opacity clients: the module and its
-- sole public diagnostic entry point must remain available to an external
-- consumer while each private symbol is rejected independently.

import Amoebius.Validation.CompilerBuildInfo
  ( compilerBuildInfoDiagnostic )

main :: IO ()
main = compilerBuildInfoDiagnostic `seq` pure ()
