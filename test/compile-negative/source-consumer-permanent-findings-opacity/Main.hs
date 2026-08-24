module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (permanentFindings)
main :: IO ()
main = seq permanentFindings (pure ())
