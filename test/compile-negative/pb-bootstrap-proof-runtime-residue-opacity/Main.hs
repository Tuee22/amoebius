module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofRuntimeResidue)
main :: IO ()
main = proofRuntimeResidue `seq` pure ()
