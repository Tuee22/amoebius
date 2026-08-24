module Main (main) where

import Amoebius.Validation.PhaseIdentity
  ( allPhaseIdentities
  )

main :: IO ()
main = allPhaseIdentities `seq` pure ()
