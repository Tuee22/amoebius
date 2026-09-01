module Main (main) where

import Amoebius.Validation.Evidence (captureFinalizedDispatchCandidateEvidence)

main :: IO ()
main = captureFinalizedDispatchCandidateEvidence `seq` pure ()
