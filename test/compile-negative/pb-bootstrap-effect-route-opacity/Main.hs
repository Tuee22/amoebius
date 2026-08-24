module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (EffectRoute)
forbidden :: Maybe EffectRoute
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
