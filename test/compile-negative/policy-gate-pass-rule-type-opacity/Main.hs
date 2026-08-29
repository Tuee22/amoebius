module Main (main) where

import Amoebius.Validation.PolicyContract (GatePassRule)

privateSymbol :: Maybe GatePassRule
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
