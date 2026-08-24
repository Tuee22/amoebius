module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (effectBindingName)
main :: IO ()
main = seq effectBindingName (pure ())
