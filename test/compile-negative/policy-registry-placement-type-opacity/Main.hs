module Main (main) where

import Amoebius.Validation.PolicyContract (RegistryPlacement)

privateSymbol :: Maybe RegistryPlacement
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
