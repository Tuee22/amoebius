module Main (main) where

import Amoebius.Validation.PolicyContract (GenerationTiming)

privateSymbol :: Maybe GenerationTiming
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
