module Main (main) where

import Amoebius.Validation.Documentation (checkPolicyOwnerReferencesFor)

main :: IO ()
main = checkPolicyOwnerReferencesFor `seq` pure ()
