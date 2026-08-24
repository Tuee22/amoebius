module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (PlatformAdapter)
forbidden :: Maybe PlatformAdapter
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
