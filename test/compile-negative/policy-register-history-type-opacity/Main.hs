module Main (main) where

import Amoebius.Validation.PolicyContract (RegisterHistory)

privateSymbol :: Maybe RegisterHistory
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
