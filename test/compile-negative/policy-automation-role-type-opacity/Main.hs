module Main (main) where

import Amoebius.Validation.PolicyContract (AutomationRole)

privateSymbol :: Maybe AutomationRole
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
