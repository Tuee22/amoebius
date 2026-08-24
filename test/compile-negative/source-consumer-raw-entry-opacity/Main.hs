module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (RawEntry)
forbidden :: Maybe RawEntry
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
