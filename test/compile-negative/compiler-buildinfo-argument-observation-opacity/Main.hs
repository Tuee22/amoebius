module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoArgumentObservation )

forbiddenArgumentObservation :: Maybe DiagnosticCompilerBuildInfoArgumentObservation
forbiddenArgumentObservation = Nothing

main :: IO ()
main = forbiddenArgumentObservation `seq` pure ()
