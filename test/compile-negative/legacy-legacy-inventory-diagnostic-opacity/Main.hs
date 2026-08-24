module Main (main) where

import Amoebius.Validation.Legacy (legacyInventoryDiagnostic)

main :: IO ()
main = legacyInventoryDiagnostic `seq` pure ()
