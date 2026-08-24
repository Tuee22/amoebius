module Main (main) where

import Amoebius.Validation.Dispatch (phaseZeroReadinessBlockers)

main :: IO ()
main = phaseZeroReadinessBlockers `seq` pure ()
