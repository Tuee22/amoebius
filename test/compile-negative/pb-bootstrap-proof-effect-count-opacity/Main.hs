module Main (main) where
import Amoebius.Validation.PbBootstrapGrammar (proofPotentialEffectCount)
main :: IO ()
main = proofPotentialEffectCount `seq` pure ()
