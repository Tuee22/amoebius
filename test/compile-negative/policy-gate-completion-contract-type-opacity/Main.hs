module Main (main) where

import Amoebius.Validation.PolicyContract (GateCompletionContract)

privateSymbol :: Maybe GateCompletionContract
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
