module Main (main) where

import Amoebius.Validation.PolicyContract (renderPolicyContract)

main :: IO ()
main = renderPolicyContract `seq` pure ()
