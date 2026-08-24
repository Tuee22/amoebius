module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (PyBinaryOperator)
forbidden :: Maybe PyBinaryOperator
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
