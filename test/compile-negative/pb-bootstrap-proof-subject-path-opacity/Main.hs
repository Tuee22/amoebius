module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofSubjectPath)
main :: IO ()
main = proofSubjectPath `seq` pure ()
