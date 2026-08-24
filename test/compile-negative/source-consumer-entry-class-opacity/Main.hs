module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (EntryClass)
forbidden :: Maybe EntryClass
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
