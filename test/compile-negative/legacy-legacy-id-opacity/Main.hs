module Main (main) where

import Amoebius.Validation.Legacy (LegacyId)

privateSymbol :: Maybe LegacyId
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
