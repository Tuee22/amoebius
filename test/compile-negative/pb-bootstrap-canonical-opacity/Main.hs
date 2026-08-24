module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (canonicalBootstrapBytes)

main :: IO ()
main = canonicalBootstrapBytes `seq` pure ()
