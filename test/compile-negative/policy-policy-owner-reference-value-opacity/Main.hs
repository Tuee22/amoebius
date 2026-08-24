module Main (main) where

import Amoebius.Validation.PolicyContract (policyOwnerReference)

main :: IO ()
main = policyOwnerReference `seq` pure ()
