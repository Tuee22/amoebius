module Main (main) where

import Amoebius.Validation.PhaseContract (checkPhaseContractStructure)

main :: IO ()
main = checkPhaseContractStructure `seq` pure ()
