module Main (main) where

import Amoebius.Validation.PolicyContract (PredecessorRule)

privateSymbol :: Maybe PredecessorRule
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
