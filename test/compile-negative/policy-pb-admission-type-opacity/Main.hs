module Main (main) where

import Amoebius.Validation.PolicyContract (PbAdmission)

privateSymbol :: Maybe PbAdmission
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
