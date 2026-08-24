module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (sourceDebtProblems)

main :: IO ()
main = sourceDebtProblems `seq` pure ()
