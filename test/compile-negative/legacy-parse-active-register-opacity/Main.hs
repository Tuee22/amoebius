module Main (main) where

import Amoebius.Validation.Legacy (parseActiveRegister)

main :: IO ()
main = parseActiveRegister `seq` pure ()
