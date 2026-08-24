module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (RawEffect)
forbidden :: Maybe RawEffect
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
