module Main (main) where

import Amoebius.Validation.PolicyContract (GenerationContract)

privateSymbol :: Maybe GenerationContract
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
