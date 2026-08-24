module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (effectModulePath)
main :: IO ()
main = seq effectModulePath (pure ())
