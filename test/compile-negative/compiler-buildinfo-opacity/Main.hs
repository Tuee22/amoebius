module Main (main) where

-- Expected compiler diagnostic: the module does not export its raw parser.
-- Exactly one forbidden symbol is named so another private symbol cannot mask
-- a parser opacity leak.

import Amoebius.Validation.CompilerBuildInfo
  ( parseCompilerBuildInfoDiagnostic )

main :: IO ()
main = parseCompilerBuildInfoDiagnostic `seq` pure ()
