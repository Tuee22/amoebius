module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (laterOwnedSourceDebtBaselines)

main :: IO ()
main = laterOwnedSourceDebtBaselines `seq` pure ()
