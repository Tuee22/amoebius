module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (effectModuleName)
main :: IO ()
main = seq effectModuleName (pure ())
