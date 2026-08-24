module Main (main) where

import Amoebius.Validation.Documentation (checkDocumentStructure)

main :: IO ()
main = checkDocumentStructure `seq` pure ()
