module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (FunctionControlFlow)
forbidden :: Maybe FunctionControlFlow
forbidden = Nothing
main :: IO ()
main = forbidden `seq` pure ()
