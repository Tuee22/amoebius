module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (ImportBinding)
forbidden :: Maybe ImportBinding
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
