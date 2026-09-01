module Main (main) where

import Amoebius.Validation.Legacy (LegacyClosure)

privateSymbol :: Maybe LegacyClosure
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
