module Main (main) where

import Amoebius.Validation.PolicyContract (PbContract)

privateSymbol :: Maybe PbContract
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
