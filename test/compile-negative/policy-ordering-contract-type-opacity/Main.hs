module Main (main) where

import Amoebius.Validation.PolicyContract (OrderingContract)

privateSymbol :: Maybe OrderingContract
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
