module Main (main) where

import Amoebius.Validation.Legacy (evaluateLegacyObservationDiagnostic)

main :: IO ()
main = evaluateLegacyObservationDiagnostic `seq` pure ()
