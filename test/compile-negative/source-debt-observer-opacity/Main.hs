module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (observeSourceDebt)

main :: IO ()
main = observeSourceDebt `seq` pure ()
