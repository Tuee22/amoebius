module Main (main) where

import Amoebius.Validation.PolicyContract (PbSourceLanguage)

privateSymbol :: Maybe PbSourceLanguage
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
