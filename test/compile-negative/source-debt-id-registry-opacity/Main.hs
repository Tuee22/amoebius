module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (laterOwnedSourceDebtIds)

main :: IO ()
main = laterOwnedSourceDebtIds `seq` pure ()
