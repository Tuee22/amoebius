module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (resourceEffectMarkers)
main :: IO ()
main = resourceEffectMarkers `seq` pure ()
