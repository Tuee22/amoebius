module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofStaticClaims)
main :: IO ()
main = proofStaticClaims `seq` pure ()
