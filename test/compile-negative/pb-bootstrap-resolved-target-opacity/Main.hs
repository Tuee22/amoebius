module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (ResolvedTarget)
forbidden :: Maybe ResolvedTarget
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
