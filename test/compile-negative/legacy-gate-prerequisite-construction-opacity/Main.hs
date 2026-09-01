module Main (main) where

import Amoebius.Validation.Legacy
  ( assembleGateCompletionPremises
  , gatePrerequisitePassed
  )

main :: IO ()
main =
  assembleGateCompletionPremises
    [gatePrerequisitePassed "Subject"]
    `seq` pure ()
