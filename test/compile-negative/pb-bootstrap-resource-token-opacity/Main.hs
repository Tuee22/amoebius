module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (resourceLexicalUnits)
main :: IO ()
main = resourceLexicalUnits `seq` pure ()
