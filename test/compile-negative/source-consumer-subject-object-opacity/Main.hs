module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (haskellSubjectObjectId)
main :: IO ()
main = seq haskellSubjectObjectId (pure ())
