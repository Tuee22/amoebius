module Main (main) where

import Amoebius.Validation.PolicyContract (PbTransportRule)

privateSymbol :: Maybe PbTransportRule
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
