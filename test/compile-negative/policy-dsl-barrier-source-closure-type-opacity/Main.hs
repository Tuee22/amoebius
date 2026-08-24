module Main (main) where

import Amoebius.Validation.PolicyContract (DslBarrierSourceClosure)

privateSymbol :: Maybe DslBarrierSourceClosure
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
