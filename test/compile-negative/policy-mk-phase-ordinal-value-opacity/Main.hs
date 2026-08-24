module Main (main) where

import Amoebius.Validation.PolicyContract (mkPhaseOrdinal)

main :: IO ()
main = mkPhaseOrdinal `seq` pure ()
