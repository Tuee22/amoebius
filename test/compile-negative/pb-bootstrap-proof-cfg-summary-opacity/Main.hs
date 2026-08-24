module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofControlFlowSummary)
main :: IO ()
main = proofControlFlowSummary `seq` pure ()
