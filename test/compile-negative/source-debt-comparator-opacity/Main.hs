module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (sourceDebtCountMatches)

main :: IO ()
main = sourceDebtCountMatches `seq` pure ()
