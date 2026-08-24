module Main (main) where

import Amoebius.Validation.PolicyContract (TrackedGeneratedArtifact)

privateSymbol :: Maybe TrackedGeneratedArtifact
privateSymbol = Nothing

main :: IO ()
main = privateSymbol `seq` pure ()
