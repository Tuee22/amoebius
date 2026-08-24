module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (resourceControlFlowMarkers)
main :: IO ()
main = resourceControlFlowMarkers `seq` pure ()
