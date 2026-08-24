module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (auditResolvedEffects)
main :: IO ()
main = seq auditResolvedEffects (pure ())
