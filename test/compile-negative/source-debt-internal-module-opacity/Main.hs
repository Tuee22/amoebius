module Main (main) where

import Amoebius.Validation.SourceDebtBaseline.Internal (SourceDebtEvidence)

forbiddenInternalType :: Maybe SourceDebtEvidence
forbiddenInternalType = Nothing

main :: IO ()
main = forbiddenInternalType `seq` pure ()
