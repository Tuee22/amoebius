module Main (main) where

import Amoebius.Validation.PolicyContract (RegistryProvider)

privateSymbol :: Maybe RegistryProvider
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
