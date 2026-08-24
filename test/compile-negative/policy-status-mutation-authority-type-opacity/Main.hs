module Main (main) where

import Amoebius.Validation.PolicyContract (StatusMutationAuthority)

privateSymbol :: Maybe StatusMutationAuthority
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
