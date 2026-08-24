module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (sourceConsumerGraphCheck)
main :: IO ()
main = seq sourceConsumerGraphCheck (pure ())
