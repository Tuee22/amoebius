module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoSourceOwnershipObservation )

forbiddenSourceOwnershipObservation
  :: Maybe DiagnosticCompilerBuildInfoSourceOwnershipObservation
forbiddenSourceOwnershipObservation = Nothing

main :: IO ()
main = forbiddenSourceOwnershipObservation `seq` pure ()
