module Main (main) where

import Amoebius.Validation.PolicyContract (PolicyOwnerReference)

privateSymbol :: Maybe PolicyOwnerReference
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
