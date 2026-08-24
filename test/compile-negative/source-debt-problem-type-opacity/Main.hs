module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (SourceDebtProblem)

forbiddenProblem :: Maybe SourceDebtProblem
forbiddenProblem = Nothing

main :: IO ()
main = forbiddenProblem `seq` pure ()
