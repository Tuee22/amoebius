module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofSubjectBytes)
main :: IO ()
main = proofSubjectBytes `seq` pure ()
