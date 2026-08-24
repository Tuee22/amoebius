module Main (main) where

import Amoebius.Validation.Legacy (legacyRawDiagnosticJoins)

main :: IO ()
main = legacyRawDiagnosticJoins `seq` pure ()
