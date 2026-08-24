module Main (main) where

import Amoebius.Validation.PhaseSemanticContract
  ( PhaseSemanticContract
  )

main :: IO ()
main = privateTypeWitness `seq` pure ()

privateTypeWitness :: PhaseSemanticContract -> ()
privateTypeWitness _ = ()
