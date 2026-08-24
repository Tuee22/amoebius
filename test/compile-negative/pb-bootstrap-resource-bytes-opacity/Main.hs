module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (resourceSourceBytes)
main :: IO ()
main = resourceSourceBytes `seq` pure ()
