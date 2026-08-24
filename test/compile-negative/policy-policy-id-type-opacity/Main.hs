module Main (main) where

import Amoebius.Validation.PolicyContract (PolicyId)

privateSymbol :: Maybe PolicyId
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
