module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (resourceProblemMarkers)
main :: IO ()
main = resourceProblemMarkers `seq` pure ()
