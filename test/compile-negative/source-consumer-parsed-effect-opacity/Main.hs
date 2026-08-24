module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (ParsedEffect)
forbidden :: Maybe ParsedEffect
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
