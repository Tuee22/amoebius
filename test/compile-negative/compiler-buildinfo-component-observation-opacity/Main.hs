module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoComponentObservation )

forbiddenComponentObservation :: Maybe DiagnosticCompilerBuildInfoComponentObservation
forbiddenComponentObservation = Nothing

main :: IO ()
main = forbiddenComponentObservation `seq` pure ()
