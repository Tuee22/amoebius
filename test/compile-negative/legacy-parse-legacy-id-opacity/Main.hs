module Main (main) where

import Amoebius.Validation.Legacy (parseLegacyId)

main :: IO ()
main = parseLegacyId `seq` pure ()
