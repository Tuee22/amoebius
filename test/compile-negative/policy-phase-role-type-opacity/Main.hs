module Main (main) where

import Amoebius.Validation.PolicyContract (PhaseRole)

privateSymbol :: Maybe PhaseRole
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
