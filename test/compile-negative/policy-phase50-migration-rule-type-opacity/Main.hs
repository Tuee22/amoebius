module Main (main) where

import Amoebius.Validation.PolicyContract (Phase50MigrationRule)

privateSymbol :: Maybe Phase50MigrationRule
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
