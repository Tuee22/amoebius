module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (sourceDebtEvidenceCheck)

main :: IO ()
main = sourceDebtEvidenceCheck `seq` pure ()
