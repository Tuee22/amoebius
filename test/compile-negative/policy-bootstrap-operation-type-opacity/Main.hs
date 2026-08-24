module Main (main) where

import Amoebius.Validation.PolicyContract (BootstrapOperation)

privateSymbol :: Maybe BootstrapOperation
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
