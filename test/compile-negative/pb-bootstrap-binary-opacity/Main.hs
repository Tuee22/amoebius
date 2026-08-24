module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (BinaryProvenance)

forbiddenBinary :: Maybe BinaryProvenance
forbiddenBinary = Nothing

main :: IO ()
main = forbiddenBinary `seq` pure ()
