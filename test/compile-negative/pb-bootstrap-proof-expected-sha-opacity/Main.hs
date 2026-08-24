module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofExpectedSha256)
main :: IO ()
main = proofExpectedSha256 `seq` pure ()
