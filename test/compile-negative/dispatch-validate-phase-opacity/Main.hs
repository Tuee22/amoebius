module Main (main) where

import Amoebius.Validation.Dispatch (validatePhase)

main :: IO ()
main = validatePhase `seq` pure ()
