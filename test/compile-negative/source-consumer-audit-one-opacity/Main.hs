module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (auditOne)
main :: IO ()
main = seq auditOne (pure ())
