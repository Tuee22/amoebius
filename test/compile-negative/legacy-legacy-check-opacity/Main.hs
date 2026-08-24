module Main (main) where

import Amoebius.Validation.Legacy (legacyCheck)

main :: IO ()
main = legacyCheck `seq` pure ()
