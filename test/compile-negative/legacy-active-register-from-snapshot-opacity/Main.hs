module Main (main) where

import Amoebius.Validation.Legacy (activeRegisterFromSnapshot)

main :: IO ()
main = activeRegisterFromSnapshot `seq` pure ()
