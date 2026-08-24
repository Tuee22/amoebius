module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (PbProblem)

forbiddenProblem :: Maybe PbProblem
forbiddenProblem = Nothing

main :: IO ()
main = forbiddenProblem `seq` pure ()
