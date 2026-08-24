module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (GhcupEnsureProof)
forbidden :: Maybe GhcupEnsureProof
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
