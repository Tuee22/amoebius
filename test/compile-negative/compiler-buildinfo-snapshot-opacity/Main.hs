module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoSnapshot )

forbiddenSnapshot :: Maybe DiagnosticCompilerBuildInfoSnapshot
forbiddenSnapshot = Nothing

main :: IO ()
main = forbiddenSnapshot `seq` pure ()
