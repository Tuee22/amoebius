module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (CfgNodeKind)
forbidden :: Maybe CfgNodeKind
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
