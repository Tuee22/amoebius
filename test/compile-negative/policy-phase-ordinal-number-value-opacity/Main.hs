module Main (main) where

import Amoebius.Validation.PolicyContract (phaseOrdinalNumber)

main :: IO ()
main = phaseOrdinalNumber `seq` pure ()
