module Main (main) where

import Amoebius.Validation.PolicyContract (PolicyContract)

privateSymbol :: Maybe PolicyContract
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
