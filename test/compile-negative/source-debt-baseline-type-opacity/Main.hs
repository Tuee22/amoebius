module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (SourceDebtBaseline)

forbiddenBaseline :: Maybe SourceDebtBaseline
forbiddenBaseline = Nothing

main :: IO ()
main = forbiddenBaseline `seq` pure ()
