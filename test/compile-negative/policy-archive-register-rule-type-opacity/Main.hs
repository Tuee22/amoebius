module Main (main) where

import Amoebius.Validation.PolicyContract (ArchiveRegisterRule)

privateSymbol :: Maybe ArchiveRegisterRule
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
