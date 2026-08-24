module Main (main) where

import Amoebius.Validation.Legacy (legacyInternalDiagnosticProjection)

main :: IO ()
main = legacyInternalDiagnosticProjection `seq` pure ()
