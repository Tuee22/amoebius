module Main (main) where

import Amoebius.Validation.Documentation (checkPolicyOwnerReferences)

main :: IO ()
main = checkPolicyOwnerReferences `seq` pure ()
