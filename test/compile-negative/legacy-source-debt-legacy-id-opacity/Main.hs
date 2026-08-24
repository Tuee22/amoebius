module Main (main) where

import Amoebius.Validation.Legacy (sourceDebtLegacyId)

main :: IO ()
main = sourceDebtLegacyId `seq` pure ()
