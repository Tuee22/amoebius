module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (parseBootstrapAst)

main :: IO ()
main = parseBootstrapAst `seq` pure ()
