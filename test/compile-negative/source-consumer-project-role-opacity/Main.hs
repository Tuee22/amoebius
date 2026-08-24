module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (projectRole)
main :: IO ()
main = seq projectRole (pure ())
