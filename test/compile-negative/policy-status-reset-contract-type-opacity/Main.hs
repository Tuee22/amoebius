module Main (main) where

import Amoebius.Validation.PolicyContract (StatusResetContract)

privateSymbol :: Maybe StatusResetContract
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
