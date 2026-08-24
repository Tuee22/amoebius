module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (resourceSyntaxDepth)
main :: IO ()
main = resourceSyntaxDepth `seq` pure ()
