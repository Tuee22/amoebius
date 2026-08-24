module Main (main) where

import Amoebius.Validation.Legacy (renderLegacyId)

main :: IO ()
main = renderLegacyId `seq` pure ()
