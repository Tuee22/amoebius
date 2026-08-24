module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (haskellSubjectMode)
main :: IO ()
main = seq haskellSubjectMode (pure ())
