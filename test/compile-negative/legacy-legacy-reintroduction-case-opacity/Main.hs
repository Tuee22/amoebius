module Main (main) where

import Amoebius.Validation.Legacy (LegacyReintroductionCase)

privateSymbol :: Maybe LegacyReintroductionCase
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
