module Main (main) where

import Amoebius.Validation.Legacy (legacyIdAnalyzer)

main :: IO ()
main = legacyIdAnalyzer `seq` pure ()
