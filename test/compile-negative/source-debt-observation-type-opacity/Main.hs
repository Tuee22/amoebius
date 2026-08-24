module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (SourceDebtObservation)

forbiddenObservation :: Maybe SourceDebtObservation
forbiddenObservation = Nothing

main :: IO ()
main = forbiddenObservation `seq` pure ()
