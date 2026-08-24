module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (SourceDebtEvidence)

forbiddenEvidence :: Maybe SourceDebtEvidence
forbiddenEvidence = Nothing

main :: IO ()
main = forbiddenEvidence `seq` pure ()
