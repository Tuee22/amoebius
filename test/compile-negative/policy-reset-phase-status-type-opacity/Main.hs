module Main (main) where

import Amoebius.Validation.PolicyContract (ResetPhaseStatus)

privateSymbol :: Maybe ResetPhaseStatus
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
