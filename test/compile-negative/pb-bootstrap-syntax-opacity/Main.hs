module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (PyExpr)

forbiddenSyntax :: Maybe PyExpr
forbiddenSyntax = Nothing

main :: IO ()
main = forbiddenSyntax `seq` pure ()
