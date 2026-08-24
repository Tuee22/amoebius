module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (contentAuthorizedConsumers)
main :: IO ()
main = seq contentAuthorizedConsumers (pure ())
