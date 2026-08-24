module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofResolvedCallCount)
main :: IO ()
main = proofResolvedCallCount `seq` pure ()
