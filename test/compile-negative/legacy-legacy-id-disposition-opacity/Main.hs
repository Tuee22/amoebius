module Main (main) where

import Amoebius.Validation.Legacy (legacyIdDisposition)

main :: IO ()
main = legacyIdDisposition `seq` pure ()
