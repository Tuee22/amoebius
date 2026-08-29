module Main (main) where

import Amoebius.Validation.PolicyContract (StatusTransitionRule)

privateSymbol :: Maybe StatusTransitionRule
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
