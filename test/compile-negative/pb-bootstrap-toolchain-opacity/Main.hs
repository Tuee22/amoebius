module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (ToolchainExecutableProof)
forbidden :: Maybe ToolchainExecutableProof
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
