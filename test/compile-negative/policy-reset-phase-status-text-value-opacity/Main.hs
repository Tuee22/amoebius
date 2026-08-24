module Main (main) where

import Amoebius.Validation.PolicyContract (resetPhaseStatusText)

main :: IO ()
main = resetPhaseStatusText `seq` pure ()
