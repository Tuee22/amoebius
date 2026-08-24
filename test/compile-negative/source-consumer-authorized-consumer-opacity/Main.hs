module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (AuthorizedConsumer)
forbidden :: Maybe AuthorizedConsumer
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
