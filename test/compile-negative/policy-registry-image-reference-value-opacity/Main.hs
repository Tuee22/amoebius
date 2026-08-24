module Main (main) where

import Amoebius.Validation.PolicyContract (registryImageReference)

main :: IO ()
main = registryImageReference `seq` pure ()
