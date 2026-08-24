module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (ResolvedEffectTarget)
forbidden :: Maybe ResolvedEffectTarget
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
