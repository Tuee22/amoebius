module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (residueHaskellSubjects)
main :: IO ()
main = seq residueHaskellSubjects (pure ())
