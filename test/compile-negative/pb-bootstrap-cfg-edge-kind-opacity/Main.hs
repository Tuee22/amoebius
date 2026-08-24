module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (CfgEdgeKind)
forbidden :: Maybe CfgEdgeKind
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
