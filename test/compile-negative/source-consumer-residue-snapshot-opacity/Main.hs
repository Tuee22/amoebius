module Main (main) where
import Amoebius.Validation.SourceConsumerGraph (residueSnapshotIdentity)
main :: IO ()
main = seq residueSnapshotIdentity (pure ())
