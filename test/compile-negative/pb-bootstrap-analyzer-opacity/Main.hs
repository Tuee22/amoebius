module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (analyzePbBootstrap)

main :: IO ()
main = analyzePbBootstrap `seq` pure ()
