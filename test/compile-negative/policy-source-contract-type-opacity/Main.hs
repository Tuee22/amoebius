module Main (main) where

import Amoebius.Validation.PolicyContract (SourceContract)

privateSymbol :: Maybe SourceContract
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
