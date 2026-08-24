module Main (main) where

import Amoebius.Validation.PolicyContract (checkPolicyContract)

main :: IO ()
main = checkPolicyContract `seq` pure ()
