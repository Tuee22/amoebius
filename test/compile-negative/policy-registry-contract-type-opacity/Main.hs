module Main (main) where

import Amoebius.Validation.PolicyContract (RegistryContract)

privateSymbol :: Maybe RegistryContract
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
