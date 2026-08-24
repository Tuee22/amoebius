module Main (main) where

import Amoebius.Validation.PhaseSemanticJoin
  ( parsePhaseDocument
  )

main :: IO ()
main = parsePhaseDocument `seq` pure ()
