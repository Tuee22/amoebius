module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (ContentBinding)
forbidden :: Maybe ContentBinding
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
