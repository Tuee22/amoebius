module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (roleForAdmittedPath)
main :: IO ()
main = seq roleForAdmittedPath (pure ())
