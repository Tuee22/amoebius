module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (consumerGraphResidue)
main :: IO ()
main = seq consumerGraphResidue (pure ())
