module Main (main) where

import Amoebius.Validation.PolicyContract (GenerationRoot)

privateSymbol :: Maybe GenerationRoot
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
