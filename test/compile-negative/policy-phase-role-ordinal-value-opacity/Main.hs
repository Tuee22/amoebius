module Main (main) where

import Amoebius.Validation.PolicyContract (phaseRoleOrdinal)

main :: IO ()
main = phaseRoleOrdinal `seq` pure ()
