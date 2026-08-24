module Main (main) where
import Amoebius.Validation.SourceConsumerGraph.Internal (SourceConsumerGraph)
forbidden :: Maybe SourceConsumerGraph
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
