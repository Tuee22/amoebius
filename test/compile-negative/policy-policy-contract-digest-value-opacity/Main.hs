module Main (main) where

import Amoebius.Validation.PolicyContract (policyContractDigest)

main :: IO ()
main = policyContractDigest `seq` pure ()
