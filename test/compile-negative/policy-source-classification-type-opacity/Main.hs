module Main (main) where

import Amoebius.Validation.PolicyContract (SourceClassification)

privateSymbol :: Maybe SourceClassification
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
