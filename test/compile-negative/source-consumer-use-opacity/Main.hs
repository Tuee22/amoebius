module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (ContentUse)
forbidden :: Maybe ContentUse
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
