module Main (main) where

import Amoebius.Validation.Legacy (LegacyDisposition)

privateSymbol :: Maybe LegacyDisposition
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
