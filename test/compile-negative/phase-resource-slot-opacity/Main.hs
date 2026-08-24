module Main (main) where

import Amoebius.Validation.ResourceProvisionContract
  ( ResourceSlot
  )

main :: IO ()
main = privateTypeWitness `seq` pure ()

privateTypeWitness :: ResourceSlot () -> ()
privateTypeWitness _ = ()
