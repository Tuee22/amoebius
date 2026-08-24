module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (Binding)

forbiddenBinding :: Maybe Binding
forbiddenBinding = Nothing

main :: IO ()
main = forbiddenBinding `seq` pure ()
