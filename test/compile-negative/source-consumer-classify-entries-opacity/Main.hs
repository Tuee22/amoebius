module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (classifyEntries)
main :: IO ()
main = seq classifyEntries (pure ())
