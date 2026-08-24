module Main (main) where

import Amoebius.Validation.Legacy (RegisterProblem)

privateSymbol :: Maybe RegisterProblem
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
