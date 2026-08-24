module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (BindingKind)
forbidden :: Maybe BindingKind
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
