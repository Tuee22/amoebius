module Main (main) where

import Amoebius.Validation.PhaseSemanticContract
  ( canonicalPhaseRegistry
  )

main :: IO ()
main = canonicalPhaseRegistry `seq` pure ()
