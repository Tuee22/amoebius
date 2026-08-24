module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (PbBootstrapProof)

forbiddenProof :: Maybe PbBootstrapProof
forbiddenProof = Nothing

main :: IO ()
main = forbiddenProof `seq` pure ()
