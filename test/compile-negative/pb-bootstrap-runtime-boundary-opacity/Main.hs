module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (RuntimeBoundary)
forbidden :: Maybe RuntimeBoundary
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
