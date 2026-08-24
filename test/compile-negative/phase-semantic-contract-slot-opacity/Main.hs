module Main (main) where

import Amoebius.Validation.PhaseSemanticContract
  ( ContractSlot
  )

main :: IO ()
main = privateTypeWitness `seq` pure ()

privateTypeWitness :: ContractSlot () -> ()
privateTypeWitness _ = ()
