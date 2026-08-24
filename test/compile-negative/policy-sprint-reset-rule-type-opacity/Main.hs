module Main (main) where

import Amoebius.Validation.PolicyContract (SprintResetRule)

privateSymbol :: Maybe SprintResetRule
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
