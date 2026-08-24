module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (effectUse)
main :: IO ()
main = seq effectUse (pure ())
