module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (PotentialEffectKind)
forbidden :: Maybe PotentialEffectKind
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
