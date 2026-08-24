module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (EffectTarget)
forbidden :: Maybe EffectTarget
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
