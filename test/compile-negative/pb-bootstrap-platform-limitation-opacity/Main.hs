module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (PlatformLimitation)
forbidden :: Maybe PlatformLimitation
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
