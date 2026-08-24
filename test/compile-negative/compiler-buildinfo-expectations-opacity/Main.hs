module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoExpectations )

forbiddenExpectations :: Maybe DiagnosticCompilerBuildInfoExpectations
forbiddenExpectations = Nothing

main :: IO ()
main = forbiddenExpectations `seq` pure ()
