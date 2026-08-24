module Main (main) where

import Amoebius.Validation.SourceDebtBaseline (SourceDebtEvidence (..))

forbiddenEvidence :: SourceDebtEvidence -> ()
forbiddenEvidence _ = ()

main :: IO ()
main = forbiddenEvidence `seq` pure ()
