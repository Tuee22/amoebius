module Main (main) where

import Amoebius.Validation.Dispatch (checkPhaseZeroSnapshot)

main :: IO ()
main = checkPhaseZeroSnapshot `seq` pure ()
