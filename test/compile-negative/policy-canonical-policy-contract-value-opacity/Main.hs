module Main (main) where

import Amoebius.Validation.PolicyContract (canonicalPolicyContract)

main :: IO ()
main = canonicalPolicyContract `seq` pure ()
