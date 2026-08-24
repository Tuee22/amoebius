module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofResourceMetrics)
main :: IO ()
main = proofResourceMetrics `seq` pure ()
