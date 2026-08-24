module Main (main) where

import Amoebius.Validation.PhaseContract (phaseContractDiagnostic)

main :: IO ()
main = phaseContractDiagnostic [] `seq` pure ()
