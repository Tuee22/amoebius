module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (EffectOrigin)
forbidden :: Maybe EffectOrigin
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
