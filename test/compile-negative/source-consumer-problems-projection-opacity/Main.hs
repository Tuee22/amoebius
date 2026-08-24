module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (consumerGraphProblems)
main :: IO ()
main = seq consumerGraphProblems (pure ())
