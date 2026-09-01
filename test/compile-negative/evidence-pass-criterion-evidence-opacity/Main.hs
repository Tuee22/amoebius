module Main (main) where

import Amoebius.Validation.Evidence (PassCriterionEvidence)

privateSymbol :: Maybe PassCriterionEvidence
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
