module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoPackageObservation )

forbiddenPackageObservation :: Maybe DiagnosticCompilerBuildInfoPackageObservation
forbiddenPackageObservation = Nothing

main :: IO ()
main = forbiddenPackageObservation `seq` pure ()
