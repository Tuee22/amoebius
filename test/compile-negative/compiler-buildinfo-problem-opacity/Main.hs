module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoProblem )

forbiddenProblem :: Maybe DiagnosticCompilerBuildInfoProblem
forbiddenProblem = Nothing

main :: IO ()
main = forbiddenProblem `seq` pure ()
