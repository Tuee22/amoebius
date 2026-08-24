module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (residueRequiredFacts)
main :: IO ()
main = seq residueRequiredFacts (pure ())
