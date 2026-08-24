module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( foldDiagnosticCompilerBuildInfoRefusal )

main :: IO ()
main = foldDiagnosticCompilerBuildInfoRefusal `seq` pure ()
