module Main (main) where

import Amoebius.Validation.Legacy (GateCompletionPremises)

privateSymbol :: Maybe GateCompletionPremises
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
