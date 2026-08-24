module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (analyzeSourceConsumerGraph)
main :: IO ()
main = seq analyzeSourceConsumerGraph (pure ())
