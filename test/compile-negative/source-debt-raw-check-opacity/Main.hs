module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (sourceDebtRawDiagnosticCheck)

main :: IO ()
main = sourceDebtRawDiagnosticCheck `seq` pure ()
