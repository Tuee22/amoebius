module Main (main) where

import Amoebius.Validation.Legacy (legacyIdClosureRule)

main :: IO ()
main = legacyIdClosureRule `seq` pure ()
