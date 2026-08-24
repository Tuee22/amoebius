module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (analyzeSourceConsumerGraphWithResolvedEffects)
main :: IO ()
main = seq analyzeSourceConsumerGraphWithResolvedEffects (pure ())
