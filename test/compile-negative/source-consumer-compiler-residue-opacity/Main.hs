module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (CompilerGraphResidue)
forbidden :: Maybe CompilerGraphResidue
forbidden = Nothing
main :: IO ()
main = seq forbidden (pure ())
