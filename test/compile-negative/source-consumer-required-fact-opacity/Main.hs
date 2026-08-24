module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (RequiredCompilerFact)
forbidden :: Maybe RequiredCompilerFact
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
