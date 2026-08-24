module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (contentRole)
main :: IO ()
main = seq contentRole (pure ())
