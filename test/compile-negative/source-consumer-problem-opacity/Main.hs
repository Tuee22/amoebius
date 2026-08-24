module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (ConsumerGraphProblem)
forbidden :: Maybe ConsumerGraphProblem
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
