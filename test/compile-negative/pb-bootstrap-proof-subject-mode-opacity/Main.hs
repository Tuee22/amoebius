module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofSubjectMode)
main :: IO ()
main = proofSubjectMode `seq` pure ()
