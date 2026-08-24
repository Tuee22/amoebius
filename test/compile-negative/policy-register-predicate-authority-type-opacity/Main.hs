module Main (main) where

import Amoebius.Validation.PolicyContract (RegisterPredicateAuthority)

privateSymbol :: Maybe RegisterPredicateAuthority
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
