module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (haskellSubjectPath)
main :: IO ()
main = seq haskellSubjectPath (pure ())
