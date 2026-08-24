module Main (main) where

import Amoebius.Validation.Legacy (legacyRawDiagnosticBindings)

main :: IO ()
main = legacyRawDiagnosticBindings `seq` pure ()
