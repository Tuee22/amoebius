module Main (main) where

import Amoebius.Validation.Legacy (LegacyObservation)

privateSymbol :: Maybe LegacyObservation
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
