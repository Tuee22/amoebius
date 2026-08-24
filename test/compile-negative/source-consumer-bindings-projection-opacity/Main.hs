module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (consumerGraphBindings)
main :: IO ()
main = seq consumerGraphBindings (pure ())
