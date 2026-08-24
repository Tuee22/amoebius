module Main (main) where

import Amoebius.Validation.PolicyContract (RegisterContract)

privateSymbol :: Maybe RegisterContract
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
