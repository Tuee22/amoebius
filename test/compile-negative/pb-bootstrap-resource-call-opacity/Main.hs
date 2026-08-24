module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (resourceCallMarkers)
main :: IO ()
main = resourceCallMarkers `seq` pure ()
