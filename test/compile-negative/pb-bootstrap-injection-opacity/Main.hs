module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (InjectionSeamProof)
forbidden :: Maybe InjectionSeamProof
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
