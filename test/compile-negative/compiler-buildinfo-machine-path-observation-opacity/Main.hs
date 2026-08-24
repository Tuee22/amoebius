module Main (main) where

import Amoebius.Validation.CompilerBuildInfo
  ( DiagnosticCompilerBuildInfoMachinePathObservation )

forbiddenMachinePathObservation
  :: Maybe DiagnosticCompilerBuildInfoMachinePathObservation
forbiddenMachinePathObservation = Nothing

main :: IO ()
main = forbiddenMachinePathObservation `seq` pure ()
