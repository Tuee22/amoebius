module Main (main) where

import Amoebius.Validation.Documentation (checkDocuments)

main :: IO ()
main = checkDocuments `seq` pure ()
