module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (ContentRole)
forbidden :: Maybe ContentRole
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
