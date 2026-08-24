module Main (main) where

import Amoebius.Validation.PolicyContract (PrehardwareRule)

privateSymbol :: Maybe PrehardwareRule
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
