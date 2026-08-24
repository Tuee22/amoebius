module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (BootstrapAst)

forbiddenAst :: Maybe BootstrapAst
forbiddenAst = Nothing

main :: IO ()
main = forbiddenAst `seq` pure ()
