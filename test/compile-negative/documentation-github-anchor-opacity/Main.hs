module Main (main) where

import Amoebius.Validation.Documentation (githubAnchor)

main :: IO ()
main = githubAnchor `seq` pure ()
