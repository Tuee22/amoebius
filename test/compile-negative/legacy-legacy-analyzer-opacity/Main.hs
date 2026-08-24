module Main (main) where

import Amoebius.Validation.Legacy (LegacyAnalyzer)

privateSymbol :: Maybe LegacyAnalyzer
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
