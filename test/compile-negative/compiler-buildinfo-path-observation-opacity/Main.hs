module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoPathObservation )

forbiddenPathObservation :: Maybe DiagnosticCompilerBuildInfoPathObservation
forbiddenPathObservation = Nothing

main :: IO ()
main = forbiddenPathObservation `seq` pure ()
