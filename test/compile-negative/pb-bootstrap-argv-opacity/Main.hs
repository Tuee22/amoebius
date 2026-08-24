module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (ArgvProvenance)

forbiddenArgv :: Maybe ArgvProvenance
forbiddenArgv = Nothing

main :: IO ()
main = forbiddenArgv `seq` pure ()
