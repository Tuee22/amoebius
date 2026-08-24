module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (analyzeAcquiredSourceDebt)

main :: IO ()
main = analyzeAcquiredSourceDebt `seq` pure ()
