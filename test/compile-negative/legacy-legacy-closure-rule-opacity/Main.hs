module Main (main) where

import Amoebius.Validation.Legacy (LegacyClosureRule)

privateSymbol :: Maybe LegacyClosureRule
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
