module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (requiredCompilerFacts)
main :: IO ()
main = seq requiredCompilerFacts (pure ())
