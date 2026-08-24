module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofPlatformLabels)
main :: IO ()
main = proofPlatformLabels `seq` pure ()
