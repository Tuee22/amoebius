module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (CfgNode)
forbidden :: Maybe CfgNode
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
