module Main (main) where

import Amoebius.Validation.Legacy (legacyIdObservationRule)

main :: IO ()
main = legacyIdObservationRule `seq` pure ()
