module Main (main) where

import Amoebius.Validation.PolicyContract (HistoricalEvidenceRule)

privateSymbol :: Maybe HistoricalEvidenceRule
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
