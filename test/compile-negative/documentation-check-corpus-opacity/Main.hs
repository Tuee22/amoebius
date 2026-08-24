module Main (main) where

import Amoebius.Validation.Documentation (checkCorpus)

main :: IO ()
main = checkCorpus `seq` pure ()
