module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (sourceDebtBaseline)

main :: IO ()
main = sourceDebtBaseline `seq` pure ()
