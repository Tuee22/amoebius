module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (ResolvedContentEffect)
forbidden :: Maybe ResolvedContentEffect
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
