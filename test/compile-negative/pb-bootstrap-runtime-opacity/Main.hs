module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (RuntimeResidue)

forbiddenRuntime :: Maybe RuntimeResidue
forbiddenRuntime = Nothing

main :: IO ()
main = forbiddenRuntime `seq` pure ()
