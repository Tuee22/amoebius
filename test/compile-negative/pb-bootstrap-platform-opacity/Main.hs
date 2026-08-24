module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (PlatformArtifact)

forbiddenPlatform :: Maybe PlatformArtifact
forbiddenPlatform = Nothing

main :: IO ()
main = forbiddenPlatform `seq` pure ()
