module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (ClosedEnvironmentProof)

forbiddenEnvironment :: Maybe ClosedEnvironmentProof
forbiddenEnvironment = Nothing

main :: IO ()
main = forbiddenEnvironment `seq` pure ()
