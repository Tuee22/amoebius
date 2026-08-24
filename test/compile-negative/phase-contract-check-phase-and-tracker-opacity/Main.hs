module Main (main) where

import Amoebius.Validation.PhaseContract (checkPhaseAndTracker)

main :: IO ()
main = checkPhaseAndTracker `seq` pure ()
