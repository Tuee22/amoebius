module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (PyArgument)
forbidden :: Maybe PyArgument
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
