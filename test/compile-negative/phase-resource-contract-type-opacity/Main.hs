module Main (main) where

import Amoebius.Validation.ResourceProvisionContract
  ( ResourceProvisionContract
  )

main :: IO ()
main = privateTypeWitness `seq` pure ()

privateTypeWitness :: ResourceProvisionContract -> ()
privateTypeWitness _ = ()
