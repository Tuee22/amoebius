module Main (main) where

import Amoebius.Validation.PolicyContract (PublicBehaviorAuthority)

privateSymbol :: Maybe PublicBehaviorAuthority
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
