module Main (main) where

import Amoebius.Validation.Legacy (LegacyObservedState)

privateSymbol :: Maybe LegacyObservedState
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
