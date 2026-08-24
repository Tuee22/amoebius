module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoGeneratedInputObservation )

forbiddenGeneratedInputObservation
  :: Maybe DiagnosticCompilerBuildInfoGeneratedInputObservation
forbiddenGeneratedInputObservation = Nothing

main :: IO ()
main = forbiddenGeneratedInputObservation `seq` pure ()
