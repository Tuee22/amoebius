module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (PbTrackedMode)
forbidden :: Maybe PbTrackedMode
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
