module Main (main) where

import Amoebius.Validation.PolicyContract (canonicalActiveRegisterPath)

main :: IO ()
main = canonicalActiveRegisterPath `seq` pure ()
