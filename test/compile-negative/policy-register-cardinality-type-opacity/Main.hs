module Main (main) where

import Amoebius.Validation.PolicyContract (RegisterCardinality)

privateSymbol :: Maybe RegisterCardinality
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
