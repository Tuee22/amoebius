module Main (main) where

import Amoebius.Validation.Legacy (legacyIdOwner)

main :: IO ()
main = legacyIdOwner `seq` pure ()
