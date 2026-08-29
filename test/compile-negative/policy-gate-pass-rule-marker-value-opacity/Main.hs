module Main (main) where

import Amoebius.Validation.PolicyContract (gatePassMarker)

main :: IO ()
main = gatePassMarker `seq` pure ()
