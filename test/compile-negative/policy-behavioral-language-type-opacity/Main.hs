module Main (main) where

import Amoebius.Validation.PolicyContract (BehavioralLanguage)

privateSymbol :: Maybe BehavioralLanguage
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
