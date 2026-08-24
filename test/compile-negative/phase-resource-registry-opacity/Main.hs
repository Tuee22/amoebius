module Main (main) where

import Amoebius.Validation.ResourceProvisionContract
  ( canonicalResourceContracts
  )

main :: IO ()
main = canonicalResourceContracts `seq` pure ()
