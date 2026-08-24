module Main (main) where

import Amoebius.Validation.Legacy (activeRegisterPath)

main :: IO ()
main = activeRegisterPath `seq` pure ()
