module Main (main) where

import Amoebius.Validation.Legacy (legacyIdReintroductionCases)

main :: IO ()
main = legacyIdReintroductionCases `seq` pure ()
