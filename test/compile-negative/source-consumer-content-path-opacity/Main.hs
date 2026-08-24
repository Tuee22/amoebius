module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (contentPath)
main :: IO ()
main = seq contentPath (pure ())
