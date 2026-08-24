module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (effectTarget)
main :: IO ()
main = seq effectTarget (pure ())
