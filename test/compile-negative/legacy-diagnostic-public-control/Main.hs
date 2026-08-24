module Main (main) where

import Amoebius.Validation.Legacy (legacyDiagnostic)

main :: IO ()
main = legacyDiagnostic mempty [] [] `seq` pure ()
