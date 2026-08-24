module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (resourceAstNodes)
main :: IO ()
main = resourceAstNodes `seq` pure ()
