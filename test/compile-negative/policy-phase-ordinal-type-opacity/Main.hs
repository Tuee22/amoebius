module Main (main) where

import Amoebius.Validation.PolicyContract (PhaseOrdinal)

privateSymbol :: Maybe PhaseOrdinal
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
