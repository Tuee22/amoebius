module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (resourcePhysicalLines)
main :: IO ()
main = resourcePhysicalLines `seq` pure ()
