module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofImportClosure)
main :: IO ()
main = proofImportClosure `seq` pure ()
