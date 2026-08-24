module Main (main) where

import Amoebius.Validation.Legacy (LegacyObservationRule)

privateSymbol :: Maybe LegacyObservationRule
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
