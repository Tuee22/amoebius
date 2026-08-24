module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (CfgEdge)
forbidden :: Maybe CfgEdge
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
