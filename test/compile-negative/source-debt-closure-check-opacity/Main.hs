module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (sourceDebtClosureDiagnosticCheck)

main :: IO ()
main = sourceDebtClosureDiagnosticCheck `seq` pure ()
