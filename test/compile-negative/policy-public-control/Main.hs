module Main (main) where

import Amoebius.Validation.PolicyContract (policyContractDiagnostic)

main :: IO ()
main = policyContractDiagnostic `seq` pure ()
