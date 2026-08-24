module Main (main) where

import Amoebius.Validation.Legacy qualified as Public

main :: IO ()
main = Public.legacyBinding `seq` pure ()
