module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (consumerGraphSnapshotIdentity)
main :: IO ()
main = seq consumerGraphSnapshotIdentity (pure ())
