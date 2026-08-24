module Main (main) where

import Amoebius.Validation.PhaseContract (checkPhaseContracts)

main :: IO ()
main = checkPhaseContracts `seq` pure ()
