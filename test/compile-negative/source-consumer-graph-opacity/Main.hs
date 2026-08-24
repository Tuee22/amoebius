module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (SourceConsumerGraph)
forbidden :: Maybe SourceConsumerGraph
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
