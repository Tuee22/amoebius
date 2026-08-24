module Main (main) where

import Amoebius.Validation.Legacy (allLegacyIds)

main :: IO ()
main = allLegacyIds `seq` pure ()
