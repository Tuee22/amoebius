module Main (main) where

import Amoebius.Validation.Legacy (legacyCheckAcquired)

main :: IO ()
main = legacyCheckAcquired `seq` pure ()
