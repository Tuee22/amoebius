module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (PyStmt)
forbidden :: Maybe PyStmt
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
