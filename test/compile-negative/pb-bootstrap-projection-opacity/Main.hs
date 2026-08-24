module Main (main) where

import Amoebius.Validation.PbBootstrapGrammar (proofSubjectSha256)

main :: IO ()
main = proofSubjectSha256 `seq` pure ()
