module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (ControlFlowGraph)

forbiddenControlFlow :: Maybe ControlFlowGraph
forbiddenControlFlow = Nothing

main :: IO ()
main = forbiddenControlFlow `seq` pure ()
